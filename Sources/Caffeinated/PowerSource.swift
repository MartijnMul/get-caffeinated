import Foundation
import IOKit.ps
import notify

/// Whether the Mac runs on a power adapter, and a way to hear when that
/// changes.
enum PowerSource {
    /// True on a power adapter, false on battery or UPS.
    static var isOnAC: Bool {
        let type = IOPSGetProvidingPowerSourceType(nil).takeUnretainedValue() as String
        return type == kIOPMACPowerKey
    }

    /// Whether the Mac has a built-in battery. A desktop Mac is never
    /// unplugged, so "until unplugged" means nothing there.
    static var hasBattery: Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as NSDictionary
            return description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }

    /// Calls `handler` on the main thread whenever the Mac switches between
    /// power adapter and battery. The registration lasts as long as the app.
    static func observeChanges(_ handler: @escaping @MainActor () -> Void) {
        var token: Int32 = 0
        notify_register_dispatch(kIOPSNotifyPowerSource, &token, .main) { _ in
            MainActor.assumeIsolated(handler)
        }
    }
}
