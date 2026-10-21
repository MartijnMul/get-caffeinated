import Foundation
import Testing
@testable import GetCaffeinated

struct UntilTimesTests {
    /// A day without a daylight saving switch, at `hour`:`minute` local time.
    private func date(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: hour, minute: minute))!
    }

    @Test func startsAtLeastFifteenMinutesAhead() {
        #expect(UntilTimes.times(from: date(10, 0)).first == date(10, 30))
        #expect(UntilTimes.times(from: date(10, 14)).first == date(10, 30))
        #expect(UntilTimes.times(from: date(10, 20)).first == date(11, 0))
    }

    @Test func includesATimeExactlyFifteenMinutesAhead() {
        #expect(UntilTimes.times(from: date(10, 15)).first == date(10, 30))
    }

    @Test func endsAtMostEightHoursAhead() {
        #expect(UntilTimes.times(from: date(10, 0)).last == date(18, 0))
        #expect(UntilTimes.times(from: date(10, 20)).last == date(18, 0))
    }

    @Test func offersEveryHalfHourInOrder() {
        let times = UntilTimes.times(from: date(10, 0))
        #expect(times.count == 16)
        for (earlier, later) in zip(times, times.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) == 30 * 60)
        }
    }

    @Test func goesPastMidnight() {
        let times = UntilTimes.times(from: date(22, 0))
        #expect(times.first == date(22, 30))
        #expect(times.last == Calendar.current.date(byAdding: .hour, value: 8, to: date(22, 0)))
    }
}
