import Foundation
import IOKit.pwr_mgt

/// Keeps the display (and therefore the system) awake, like `caffeinate -d`,
/// by holding a power-management assertion.
@MainActor
final class AwakeKeeper: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activeUntil: Date?

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

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
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
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
}
