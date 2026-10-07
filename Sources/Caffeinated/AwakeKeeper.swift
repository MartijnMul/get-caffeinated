import AppKit
import IOKit.pwr_mgt

/// Keeps the display (and therefore the system) awake, like `caffeinate -d`,
/// by holding a power-management assertion.
@MainActor
final class AwakeKeeper: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activeUntil: Date?

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
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

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Caffeinated" as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else { return }
        isActive = true

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
