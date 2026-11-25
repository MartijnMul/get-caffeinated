import AppKit
import LidAwakeShared
import LocalAuthentication
import ServiceManagement

/// Talks to the helper daemon that keeps the Mac awake with the lid closed.
/// The daemon is registered through `SMAppService` and approved once in System
/// Settings > General > Login Items; after that, each session asks for Touch
/// ID (or the password) before the lid may stay closed.
@MainActor
final class LidAwakeClient {
    /// Only a build signed with a certificate can use the daemon, because the
    /// daemon accepts connections from its own team only.
    static let isAvailable = LidAwake.ownTeamID != nil

    /// Called when the daemon goes away while the lid is allowed closed; the
    /// daemon turns the setting off when it restarts, so the app should too.
    var onLost: (() -> Void)?

    private let service = SMAppService.daemon(plistName: "\(LidAwake.helperLabel).plist")
    private var connection: NSXPCConnection?

    /// Asks for approval and Touch ID where needed, then keeps the Mac awake
    /// with the lid closed until `end`. Returns whether that is now the case.
    func enable(until end: Date) async -> Bool {
        guard ensureRegistered() else { return false }
        guard await authenticate() else { return false }
        let enabled = await call(seconds: end.timeIntervalSinceNow)
        if !enabled {
            alert(
                "Could not keep the Mac awake with the lid closed",
                "The helper did not respond. Try again, or turn Get Caffeinated off and on under Allow in the Background in Login Items."
            )
        }
        return enabled
    }

    func disable() {
        guard let connection else { return }
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in } as? LidAwakeService
        proxy?.disable {}
    }

    // MARK: Private

    /// Registers the daemon, or sends the user to approve it. True when it
    /// is ready to use.
    private func ensureRegistered() -> Bool {
        if service.status == .enabled { return true }
        if service.status != .requiresApproval {
            try? service.register()
            if service.status == .enabled { return true }
        }
        let open = alert(
            "Allow the helper in Login Items",
            "Keeping the Mac awake with the lid closed needs a small helper that runs as an administrator. Turn on Get Caffeinated under Allow in the Background, then choose Awake with lid closed again.",
            button: "Open System Settings"
        )
        if open { SMAppService.openSystemSettingsLoginItems() }
        return false
    }

    private func authenticate() async -> Bool {
        activate()
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "keep the Mac awake with the lid closed"
            )
        } catch {
            return false
        }
    }

    private func call(seconds: TimeInterval) async -> Bool {
        let connection = currentConnection()
        return await withCheckedContinuation { continuation in
            // XPC calls exactly one of the two: the error handler or the reply.
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                continuation.resume(returning: false)
            } as? LidAwakeService
            guard let proxy else { return continuation.resume(returning: false) }
            proxy.enable(seconds: seconds) { enabled in
                continuation.resume(returning: enabled)
            }
        }
    }

    private func currentConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: LidAwake.helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LidAwakeService.self)
        if let teamID = LidAwake.ownTeamID {
            connection.setCodeSigningRequirement(LidAwake.requirement(identifier: LidAwake.helperLabel, teamID: teamID))
        }
        let lost: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.connectionLost() }
        }
        connection.interruptionHandler = lost
        connection.invalidationHandler = lost
        connection.resume()
        self.connection = connection
        return connection
    }

    private func connectionLost() {
        let lostConnection = connection
        connection = nil
        lostConnection?.invalidate()
        onLost?()
    }

    /// A menu bar app is never the active app; bring it forward so its
    /// alerts and the Touch ID prompt show on top.
    private func activate() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Shows an alert; with `button`, returns whether that was chosen.
    @discardableResult
    private func alert(_ title: String, _ text: String, button: String? = nil) -> Bool {
        activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        if let button {
            alert.addButton(withTitle: button)
            alert.addButton(withTitle: "Cancel")
        }
        return alert.runModal() == .alertFirstButtonReturn && button != nil
    }
}
