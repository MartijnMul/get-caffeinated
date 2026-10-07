import AppKit
import IOKit.pwr_mgt

/// Keeps the Mac awake by holding a power-management assertion: like
/// `caffeinate -d` when the screen stays on, like `caffeinate -i` when only
/// the system stays awake.
@MainActor
final class AwakeKeeper: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activeUntil: Date?

    /// Keep the display on as well, or only the system. Remembered between
    /// launches, and applied straight away to a running session.
    @Published var keepsScreenOn: Bool {
        didSet {
            UserDefaults.standard.set(keepsScreenOn, forKey: Self.keepsScreenOnKey)
            if isActive { holdAssertion() }
        }
    }

    private static let keepsScreenOnKey = "keepsScreenOn"

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        keepsScreenOn = UserDefaults.standard.object(forKey: Self.keepsScreenOnKey) as? Bool ?? true

        // The Mac can still sleep while we hold the assertion (lid closed, Apple
        // menu > Sleep), and a Timer fires late after that. On wake, measure the
        // time left against the clock again.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleTimer() }
        }
    }

    /// Starts keeping the Mac awake. Pass `nil` to stay awake until stopped.
    func start(for duration: TimeInterval?) {
        stop()
        guard holdAssertion() else { return }

        if let duration {
            activeUntil = Date().addingTimeInterval(duration)
            scheduleTimer()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        activeUntil = nil
        if isActive {
            IOPMAssertionRelease(assertionID)
            isActive = false
        }
    }

    /// Takes the assertion for the current mode. A held assertion is released
    /// only after the new one is in place, so switching modes leaves no gap.
    @discardableResult
    private func holdAssertion() -> Bool {
        let type = keepsScreenOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Caffeinated" as CFString,
            &newID
        )
        guard result == kIOReturnSuccess else { return false }

        if isActive { IOPMAssertionRelease(assertionID) }
        assertionID = newID
        isActive = true
        return true
    }

    /// Sets the timer to fire at `activeUntil`, or stops right away if that
    /// moment has already passed.
    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard let activeUntil else { return }

        let remaining = activeUntil.timeIntervalSinceNow
        guard remaining > 0 else { return stop() }
        timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }
}
