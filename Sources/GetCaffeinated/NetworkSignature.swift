import Foundation
import SystemConfiguration
import notify

/// Recognises the network the Mac is on by its router, without asking for
/// Location Services (which macOS requires for the Wi-Fi name).
enum NetworkSignature {
    /// One signature per connected network that has a router with a hardware
    /// address, such as "IPv4.Router=192.168.1.1;IPv4.RouterHardwareAddress=…".
    /// VPN tunnels have no router hardware address and are left out.
    static var current: Set<String> {
        guard let store = SCDynamicStoreCreate(nil, "Get Caffeinated" as CFString, nil, nil),
              let keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/[^/]+/IPv4" as CFString) as? [String]
        else { return [] }

        return Set(keys.compactMap { key in
            let value = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any]
            let signature = value?["NetworkSignature"] as? String
            return signature?.contains("RouterHardwareAddress") == true ? signature : nil
        })
    }

    /// Calls `handler` on the main thread whenever the network configuration
    /// changes. The registration lasts as long as the app.
    static func observeChanges(_ handler: @escaping @MainActor () -> Void) {
        var token: Int32 = 0
        notify_register_dispatch(kNotifySCNetworkChange, &token, .main) { _ in
            MainActor.assumeIsolated(handler)
        }
    }
}
