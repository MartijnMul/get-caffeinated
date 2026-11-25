import Foundation
import LidAwakeShared

/// The root daemon behind "Awake with lid closed". macOS puts a MacBook to
/// sleep when the lid closes, whatever power assertion an app holds; only the
/// system-wide `pmset disablesleep` setting prevents that, and it needs root.
///
/// The daemon turns that setting on for one app connection at a time and
/// turns it off again when the app asks, when the deadline passes, or when
/// the app goes away (quit or crash). A marker file records that the setting
/// is ours, so a daemon that crashed or a Mac that restarted while it was on
/// gets it turned off at the next start: launchd runs the daemon at boot.
final class LidAwakeDaemon: NSObject, NSXPCListenerDelegate, LidAwakeService, @unchecked Sendable {
    // All state below is touched on the main queue only.
    private var owner: NSXPCConnection?
    private var deadline: DispatchSourceTimer?

    private static let markerPath = "/var/db/\(LidAwake.helperLabel).on"
    private let teamID = LidAwake.ownTeamID

    /// Turns the setting off if a previous run left it on.
    func restoreLeftover() {
        if FileManager.default.fileExists(atPath: Self.markerPath) {
            restore()
        }
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

        let id = ObjectIdentifier(connection)
        let ended: @Sendable () -> Void = { [weak self] in
            DispatchQueue.main.async { self?.connectionEnded(id) }
        }
        connection.invalidationHandler = ended
        connection.interruptionHandler = ended
        connection.resume()
        return true
    }

    // MARK: LidAwakeService

    func enable(seconds: Double, reply: @escaping @Sendable (Bool) -> Void) {
        nonisolated(unsafe) let connection = NSXPCConnection.current()
        guard let connection, seconds.isFinite, seconds > 0 else { return reply(false) }
        let duration = min(seconds, LidAwake.maximumDuration)

        DispatchQueue.main.async { [self] in
            // The marker goes first: if anything fails halfway, the next
            // start still turns the setting off.
            FileManager.default.createFile(atPath: Self.markerPath, contents: nil)
            guard setSleepDisabled(true) else {
                restore()
                return reply(false)
            }
            owner = connection

            deadline?.cancel()
            // A wall-clock deadline keeps counting if the Mac sleeps anyway.
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(wallDeadline: .now() + duration)
            timer.setEventHandler { [weak self] in self?.restore() }
            timer.resume()
            deadline = timer
            reply(true)
        }
    }

    func disable(reply: @escaping @Sendable () -> Void) {
        nonisolated(unsafe) let connection = NSXPCConnection.current()
        DispatchQueue.main.async { [self] in
            if let connection, owner === connection { restore() }
            reply()
        }
    }

    // MARK: Private

    private func connectionEnded(_ id: ObjectIdentifier) {
        // `owner` holds the connection strongly, so its identifier cannot
        // have been reused by another one.
        if let owner, ObjectIdentifier(owner) == id { restore() }
    }

    private func restore() {
        deadline?.cancel()
        deadline = nil
        owner = nil
        // Keep the marker when this fails, so the next start tries again.
        if setSleepDisabled(false) {
            try? FileManager.default.removeItem(atPath: Self.markerPath)
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
}

let daemon = LidAwakeDaemon()
daemon.restoreLeftover()

let listener = NSXPCListener(machServiceName: LidAwake.helperLabel)
listener.delegate = daemon
listener.resume()
dispatchMain()
