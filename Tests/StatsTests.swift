import XCTest

final class StatsTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    func testStreakCountsQualifyingDays() {
        var s = Stats()
        var solved = DayStats(); solved.solved["math"] = 1
        var idle = DayStats(); idle.active = true                       // active, zero unlocks → counts
        var unlockedOnly = DayStats(); unlockedOnly.active = true; unlockedOnly.unlocksEarned = 2  // doesn't count
        s.days[StatsStore.key(for: date("2026-11-18 10:00"), calendar: cal)] = solved
        s.days[StatsStore.key(for: date("2026-11-19 10:00"), calendar: cal)] = idle
        s.days[StatsStore.key(for: date("2026-11-20 10:00"), calendar: cal)] = solved
        XCTAssertEqual(s.streak(now: date("2026-11-20 12:00"), calendar: cal), 3)
        // Today not done yet → streak continues from yesterday.
        XCTAssertEqual(s.streak(now: date("2026-11-21 08:00"), calendar: cal), 3)
        s.days[StatsStore.key(for: date("2026-11-19 10:00"), calendar: cal)] = unlockedOnly
        XCTAssertEqual(s.streak(now: date("2026-11-20 12:00"), calendar: cal), 1)
    }

    func testEmergencyBreaksStreakAndIsLimited() {
        var s = Stats()
        var d = DayStats(); d.solved["word"] = 2; d.emergencyUsed = true
        let now = date("2026-11-20 12:00")
        s.days[StatsStore.key(for: now, calendar: cal)] = d
        XCTAssertEqual(s.streak(now: now, calendar: cal), 0)
        s.emergencyUnlocks = [now.addingTimeInterval(-3600), now.addingTimeInterval(-86400), now.addingTimeInterval(-8 * 86400)]
        XCTAssertEqual(s.emergencyUnlocksLeft(now: now), 1)
    }

    func testMilestonesAndFormatting() {
        var s = Stats()
        let now = date("2026-11-20 12:00")
        for i in 0..<7 {
            var d = DayStats(); d.solved["chess"] = 1
            s.days[StatsStore.key(for: now.addingTimeInterval(Double(-i) * 86400), calendar: cal)] = d
        }
        XCTAssertEqual(s.pendingMilestone(now: now), 7)
        s.celebratedMilestones = [3, 7]
        XCTAssertNil(s.pendingMilestone(now: now))
        XCTAssertEqual(StatsStore.formatMinutes(160), "2h 40m")
        XCTAssertEqual(StatsStore.formatMinutes(35), "35m")
        XCTAssertEqual(StatsStore.formatMinutes(120), "2h")
    }
}
