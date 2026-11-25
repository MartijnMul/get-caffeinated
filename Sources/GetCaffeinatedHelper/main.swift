import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import LidAwakeShared
import os

/// The root daemon behind "Awake with lid closed". macOS puts a MacBook to
/// sleep when the lid closes, whatever power assertion an app holds; only the
/// system-wide `pmset disablesleep` setting prevents that, and it needs root.
///
/// The daemon is the safety net, so it does not trust the app on anything
/// that matters. It turns the setting on for one app connection at a time,
/// for at most `LidAwake.maximumDuration`, and turns it off again:
/// - when the app asks, or when the app goes away (quit or crash);
/// - at its own wall-clock deadline;
/// - when the battery runs low or the Mac gets hot (checked every 30 seconds);
/// - at the next start, if a crash or restart left it on (a marker file says
///   so, and launchd runs the daemon at boot).
/// If the lid is closed by then, it puts the Mac to sleep straight away.
///
/// With nothing to do it quits after a few seconds; launchd starts it again
/// when the app connects. So no daemon idles in the background, and a new
/// build's daemon takes over at the next connection.
final class LidAwakeDaemon: NSObject, NSXPCListenerDelegate, LidAwakeService, @unchecked Sendable {
    private enum EndReason: String {
        case requested = "asked by the app"
        case appGone = "the app went away"
        case deadline = "the time was up"
        case lowBattery = "the battery was low"
        case tooHot = "the Mac was too hot"
        case leftover = "left on by an earlier run"
        case failed = "the setting could not be changed"
    }

    // All state below is touched on the main queue only.
    private var owner: NSXPCConnection?
    private var deadline: DispatchSourceTimer?
    private var checks: DispatchSourceTimer?
    private var connections = 0
    private var idleExit: DispatchWorkItem?

    private static let markerPath = "/var/db/\(LidAwake.helperLabel).on"
    private static let checkInterval: TimeInterval = 30
    private static let idleTime: TimeInterval = 10
    private let teamID = LidAwake.ownTeamID
    private let log = Logger(subsystem: LidAwake.helperLabel, category: "lid")

    /// Turns the setting off if a previous run left it on.
    func restoreLeftover() {
        if FileManager.default.fileExists(atPath: Self.markerPath) {
            end(.leftover)
        }
        exitWhenIdle()
    }

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Only Get Caffeinated, signed by the same team as this daemon. An
        // ad-hoc signed daemon has no team to check against, so it serves
        // no one.
        guard let teamID else { return false }
        connection.setCodeSigningRequirement(LidAwake.requirement(identifier: LidAwake.appIdentifier, teamID: teamID))
        connection.exportedInterface = NSXPCInterface(with: LidAwakeService.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: LidAwakeEvents.self)

        // Invalidation follows interruption, so count only that.
        let id = ObjectIdentifier(connection)
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.connectionEnded(id) }
        }
        DispatchQueue.main.async { [self] in
            connections += 1
            idleExit?.cancel()
            idleExit = nil
        }
        connection.resume()
        return true
    }

    // MARK: LidAwakeService

    func enable(seconds: Double, reply: @escaping @Sendable (String?) -> Void) {
        nonisolated(unsafe) let connection = NSXPCConnection.current()
        guard let connection else { return reply("No connection.") }
        guard seconds.isFinite, seconds > 0, seconds <= LidAwake.maximumDuration else {
            return reply("At most \(Int(LidAwake.maximumDuration / 60)) minutes at a time.")
        }

        DispatchQueue.main.async { [self] in
            if batteryIsLow {
                return reply("The battery is at \(LidAwake.minimumBatteryPercent)% or lower. Connect the power adapter first.")
            }
            if isTooHot {
                return reply("The Mac is too hot. Let it cool down first.")
            }

            // The marker goes first: if anything fails halfway, the next
            // start still turns the setting off.
            FileManager.default.createFile(atPath: Self.markerPath, contents: nil)
            guard setSleepDisabled(true) else {
                end(.failed)
                return reply("The sleep setting could not be changed.")
            }
            owner = connection
            log.notice("On for \(Int(seconds)) seconds")

            // A wall-clock deadline keeps counting if the Mac sleeps anyway.
            deadline?.cancel()
            let deadlineTimer = DispatchSource.makeTimerSource(queue: .main)
            deadlineTimer.schedule(wallDeadline: .now() + seconds)
            deadlineTimer.setEventHandler { [weak self] in self?.end(.deadline) }
            deadlineTimer.resume()
            deadline = deadlineTimer

            checks?.cancel()
            let checkTimer = DispatchSource.makeTimerSource(queue: .main)
            checkTimer.schedule(deadline: .now() + Self.checkInterval, repeating: Self.checkInterval)
            checkTimer.setEventHandler { [weak self] in self?.check() }
            checkTimer.resume()
            checks = checkTimer

            reply(nil)
        }
    }

    func disable(reply: @escaping @Sendable () -> Void) {
        nonisolated(unsafe) let connection = NSXPCConnection.current()
        DispatchQueue.main.async { [self] in
            if let connection, owner === connection { end(.requested) }
            reply()
        }
    }

    // MARK: Private

    private func connectionEnded(_ id: ObjectIdentifier) {
        connections -= 1
        // `owner` holds the connection strongly, so its identifier cannot
        // have been reused by another one.
        if let owner, ObjectIdentifier(owner) == id { end(.appGone) }
        exitWhenIdle()
    }

    /// Quits after `idleTime` without connections and with the setting off.
    private func exitWhenIdle() {
        idleExit?.cancel()
        guard connections <= 0, owner == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, connections <= 0, owner == nil else { return }
            exit(0)
        }
        idleExit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleTime, execute: work)
    }

    private func check() {
        guard owner != nil else { return }
        if batteryIsLow {
            end(.lowBattery)
        } else if isTooHot {
            end(.tooHot)
        }
    }

    private func end(_ reason: EndReason) {
        let previousOwner = owner
        deadline?.cancel()
        deadline = nil
        checks?.cancel()
        checks = nil
        owner = nil

        // Keep the marker when this fails, so the next start tries again.
        if setSleepDisabled(false) {
            try? FileManager.default.removeItem(atPath: Self.markerPath)
            log.notice("Off: \(reason.rawValue, privacy: .public)")
        } else {
            log.error("Could not switch off (\(reason.rawValue, privacy: .public))")
        }

        switch reason {
        case .deadline, .lowBattery, .tooHot:
            let events = previousOwner?.remoteObjectProxyWithErrorHandler { _ in } as? LidAwakeEvents
            events?.lidAwakeEnded(reason: reason.rawValue)
        default:
            break
        }

        // Clearing the setting need not put a Mac to sleep whose lid is
        // already closed (the lid's sleep trigger fires on closing), so do
        // that here. Not at boot: a Mac that
        // starts with the lid closed has a display attached.
        if reason != .leftover, lidIsClosed {
            log.notice("Lid is closed: sleeping now")
            sleepNow()
        }
    }

    /// `pmset` is the supported way to change this setting; the IOKit call
    /// behind it is private API.
    private func setSleepDisabled(_ disabled: Bool) -> Bool {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
        do {
            try pmset.run()
            pmset.waitUntilExit()
            return pmset.terminationStatus == 0
        } catch {
            return false
        }
    }

    private var lidIsClosed: Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return false }
        defer { IOObjectRelease(rootDomain) }
        let state = IORegistryEntryCreateCFProperty(rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return state?.takeRetainedValue() as? Bool ?? false
    }

    private func sleepNow() {
        let port = IOPMFindPowerManagement(kIOMainPortDefault)
        guard port != 0 else { return }
        IOPMSleepSystem(port)
        IOServiceClose(port)
    }

    /// On battery, at or below `LidAwake.minimumBatteryPercent`.
    private var batteryIsLow: Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let providing = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        guard providing == kIOPSBatteryPowerValue else { return false }
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as NSDictionary
            guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            return current * 100 / maximum <= LidAwake.minimumBatteryPercent
        }
        return false
    }

    private var isTooHot: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}

let daemon = LidAwakeDaemon()
daemon.restoreLeftover()

let listener = NSXPCListener(machServiceName: LidAwake.helperLabel)
listener.delegate = daemon
listener.resume()
dispatchMain()
