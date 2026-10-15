import ServiceManagement

/// Starts Get Caffeinated at login, through `SMAppService`. The state lives in
/// macOS, not in our settings, because people can also switch it off in
/// System Settings > General > Login Items.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can wait for the user's approval; send them there.
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
