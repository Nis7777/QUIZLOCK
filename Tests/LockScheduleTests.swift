import XCTest

final class LockScheduleTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    /// 2026-11-16 is a Monday.
    private func date(day: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m)) ?? Date()
    }

    func testWorkHoursOnWeekdays() {
        let s = LockSchedule(startMinute: 9 * 60, endMinute: 17 * 60, weekdays: [2, 3, 4, 5, 6])
        XCTAssertTrue(s.isActive(at: date(day: 16, 9), calendar: cal))     // Mon 09:00
        XCTAssertTrue(s.isActive(at: date(day: 20, 16, 59), calendar: cal)) // Fri 16:59
        XCTAssertFalse(s.isActive(at: date(day: 16, 17), calendar: cal))   // Mon 17:00
        XCTAssertFalse(s.isActive(at: date(day: 21, 12), calendar: cal))   // Sat
    }

    func testOvernightBelongsToStartDay() {
        let s = LockSchedule(startMinute: 22 * 60, endMinute: 7 * 60, weekdays: [6]) // Friday night
        XCTAssertTrue(s.isActive(at: date(day: 20, 23), calendar: cal))   // Fri 23:00
        XCTAssertTrue(s.isActive(at: date(day: 21, 6, 30), calendar: cal)) // Sat 06:30
        XCTAssertFalse(s.isActive(at: date(day: 21, 23), calendar: cal))  // Sat 23:00
        XCTAssertFalse(s.isActive(at: date(day: 20, 6), calendar: cal))   // Fri 06:00 (Thu not selected)
        XCTAssertEqual(LockSchedule.format(minute: 22 * 60 + 5), "22:05")
    }
}
