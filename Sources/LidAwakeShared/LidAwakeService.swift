import Foundation
import Security

/// What the app asks of the helper daemon over XPC, for "Awake with lid
/// closed".
@objc public protocol LidAwakeService {
    /// Keeps the Mac awake with the lid closed for `seconds`, until `disable`,
    /// or until the calling app goes away, whichever comes first. Refuses more
    /// than `LidAwake.maximumDuration`, a low battery and a hot Mac. Replies
    /// nil when it took effect, or why not.
    func enable(seconds: Double, reply: @escaping @Sendable (String?) -> Void)

    /// Lets closing the lid put the Mac to sleep again.
    func disable(reply: @escaping @Sendable () -> Void)
}

/// What the helper daemon tells the app, over the same connection.
@objc public protocol LidAwakeEvents {
    /// The daemon ended it on its own: the deadline passed, the battery ran
    /// low or the Mac got too hot.
    func lidAwakeEnded(reason: String)
}

/// Names and rules the app and the helper daemon share.
public enum LidAwake {
    public static let appIdentifier = "io.github.martijnmul.getcaffeinated"
    /// The daemon's launchd label, Mach service name and signing identifier.
    public static let helperLabel = "io.github.martijnmul.getcaffeinated.helper"
    /// The longest the lid can stay closed without sleep in one go. The
    /// daemon refuses anything longer, whatever the app asks.
    public static let maximumDuration: TimeInterval = 60 * 60
    /// The durations the menu offers, in minutes.
    public static let menuMinutes = [15, 30, 45, 60]
    /// On battery at or below this percentage, the daemon refuses or ends it.
    public static let minimumBatteryPercent = 15

    /// The Team ID this process is signed with, or nil when it is ad-hoc
    /// signed (a build without a certificate).
    public static var ownTeamID: String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// A code signing requirement for the other side of the connection: an
    /// Apple-issued certificate of the same team, and the given identifier.
    public static func requirement(identifier: String, teamID: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(teamID)\""
    }
}
