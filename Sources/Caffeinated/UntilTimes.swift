import AppKit

/// The end times offered under "Until": every half hour from 15 minutes to
/// 8 hours ahead. A menu bar menu is built once and not rebuilt when it
/// opens, so the list refreshes itself every minute and after waking.
@MainActor
final class UntilTimes: ObservableObject {
    @Published private(set) var times = UntilTimes.times(from: Date())

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let times = Self.times(from: Date())
        if times != self.times { self.times = times }
    }

    static func times(from now: Date) -> [Date] {
        let earliest = now.addingTimeInterval(15 * 60)
        let latest = now.addingTimeInterval(8 * 60 * 60)
        guard let hour = Calendar.current.dateInterval(of: .hour, for: earliest)?.start else { return [] }

        return stride(from: 0.0, through: 9 * 60 * 60, by: 30 * 60)
            .map { hour.addingTimeInterval($0) }
            .filter { $0 >= earliest && $0 <= latest }
    }
}
