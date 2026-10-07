import Foundation

/// The end times offered under "Until": every half hour from 15 minutes to
/// 8 hours ahead.
enum UntilTimes {
    static func times(from now: Date) -> [Date] {
        let earliest = now.addingTimeInterval(15 * 60)
        let latest = now.addingTimeInterval(8 * 60 * 60)
        guard let hour = Calendar.current.dateInterval(of: .hour, for: earliest)?.start else { return [] }

        return stride(from: 0.0, through: 9 * 60 * 60, by: 30 * 60)
            .map { hour.addingTimeInterval($0) }
            .filter { $0 >= earliest && $0 <= latest }
    }
}
