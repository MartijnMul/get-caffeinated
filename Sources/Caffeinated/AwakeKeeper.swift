import AppKit
import IOKit.pwr_mgt

/// Keeps the Mac awake by holding a power-management assertion: like
/// `caffeinate -d` when the screen stays on, like `caffeinate -i` when only
/// the system stays awake.
@MainActor
final class AwakeKeeper: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activeUntil: Date?
    /// The session ends when the power adapter is disconnected.
    @Published private(set) var endsWhenUnplugged = false
    /// The session ends when the Mac leaves the network it started on.
    @Published private(set) var endsOnLeavingNetwork = false

    /// Keep the display on as well, or only the system. Remembered between
    /// launches, and applied straight away to a running session.
    @Published var keepsScreenOn: Bool {
        didSet {
            UserDefaults.standard.set(keepsScreenOn, forKey: Self.keepsScreenOnKey)
            if isActive { holdAssertion() }
        }
    }

    private static let keepsScreenOnKey = "keepsScreenOn"
    /// How long the network may be gone before the session ends, so a Wi-Fi
    /// hiccup does not end it.
    private static let networkGracePeriod: TimeInterval = 2 * 60

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private var startNetworks: Set<String> = []
    private var networkGraceTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        keepsScreenOn = UserDefaults.standard.object(forKey: Self.keepsScreenOnKey) as? Bool ?? true

        // The Mac can still sleep while we hold the assertion (lid closed, Apple
        // menu > Sleep), and a Timer fires late after that. On wake, measure the
        // time left against the clock again.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleTimer()
                self?.stopIfUnplugged()
                // A grace period that ran while asleep says nothing; Wi-Fi
                // reconnects only after waking. Start counting again.
                self?.networkGraceTimer?.invalidate()
                self?.networkGraceTimer = nil
                self?.checkNetwork()
            }
        }

        PowerSource.observeChanges { [weak self] in self?.stopIfUnplugged() }
        NetworkSignature.observeChanges { [weak self] in self?.checkNetwork() }
    }

    /// Starts keeping the Mac awake. Pass `nil` to stay awake until stopped.
    func start(for duration: TimeInterval?) {
        start(until: duration.map { Date().addingTimeInterval($0) })
    }

    /// Starts keeping the Mac awake until `end`. Pass `nil` to stay awake
    /// until stopped.
    func start(until end: Date?) {
        stop()
        guard holdAssertion() else { return }

        activeUntil = end
        scheduleTimer()
    }

    /// Starts keeping the Mac awake until the power adapter is disconnected.
    /// Does nothing on battery.
    func startUntilUnplugged() {
        guard PowerSource.isOnAC else { return }
        start(until: nil)
        endsWhenUnplugged = isActive
    }

    /// Starts keeping the Mac awake until it leaves the network it is on now.
    /// Does nothing without a network.
    func startUntilLeavingNetwork() {
        let networks = NetworkSignature.current
        guard !networks.isEmpty else { return }
        start(until: nil)
        guard isActive else { return }
        startNetworks = networks
        endsOnLeavingNetwork = true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        networkGraceTimer?.invalidate()
        networkGraceTimer = nil
        activeUntil = nil
        endsWhenUnplugged = false
        endsOnLeavingNetwork = false
        startNetworks = []
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

    private func stopIfUnplugged() {
        if endsWhenUnplugged && !PowerSource.isOnAC { stop() }
    }

    /// Ends the session on another network straight away. Without any
    /// network it waits for the grace period, in case the old one comes back.
    private func checkNetwork() {
        guard endsOnLeavingNetwork else { return }
        let networks = NetworkSignature.current

        if !networks.isDisjoint(with: startNetworks) {
            networkGraceTimer?.invalidate()
            networkGraceTimer = nil
        } else if !networks.isEmpty {
            stop()
        } else if networkGraceTimer == nil {
            networkGraceTimer = Timer.scheduledTimer(withTimeInterval: Self.networkGracePeriod, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
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
