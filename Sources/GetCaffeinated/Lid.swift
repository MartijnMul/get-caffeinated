import Foundation
import IOKit

/// The MacBook lid: whether there is one, whether it is closed, and a way to
/// hear when it opens or closes.
enum Lid {
    /// `kIOPMMessageClamshellStateChange` from IOPM.h, a macro Swift does not
    /// import: `iokit_family_msg(sub_iokit_powermanagement, 0x100)`.
    private static let clamshellStateChange: natural_t = 0xE003_4100

    /// A desktop Mac has no lid, so "until lid closed" means nothing there.
    static var exists: Bool { state != nil }

    /// True while the lid is shut, also when an external display keeps the
    /// Mac awake.
    static var isClosed: Bool { state ?? false }

    /// Calls `handler` on the main thread whenever the lid opens or closes.
    /// The registration lasts as long as the app.
    static func observeChanges(_ handler: @escaping @MainActor () -> Void) {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return }
        defer { IOObjectRelease(rootDomain) }

        let box = Unmanaged.passRetained(Handler(handler)).toOpaque()
        var notification: io_object_t = 0
        IOServiceAddInterestNotification(port, rootDomain, kIOGeneralInterest, { refcon, _, message, _ in
            guard message == Lid.clamshellStateChange, let refcon else { return }
            let handler = Unmanaged<Handler>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated(handler.call)
        }, box, &notification)
    }

    /// The root domain's `AppleClamshellState`, or nil when the Mac has no
    /// lid.
    private static var state: Bool? {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return nil }
        defer { IOObjectRelease(rootDomain) }
        let value = IORegistryEntryCreateCFProperty(rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return value?.takeRetainedValue() as? Bool
    }

    private final class Handler: Sendable {
        let call: @MainActor () -> Void
        init(_ call: @escaping @MainActor () -> Void) { self.call = call }
    }
}
