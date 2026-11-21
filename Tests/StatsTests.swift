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

    /// iCloud merge (new phone / two devices): higher counts win, flags OR, nothing is lost.
    func testMergeKeepsTheHigherStreakAndTotals() {
        let k1 = StatsStore.key(for: date("2026-11-19 10:00"), calendar: cal)
        let k2 = StatsStore.key(for: date("2026-11-20 10:00"), calendar: cal)
        let k3 = StatsStore.key(for: date("2026-11-18 10:00"), calendar: cal)

        var local = Stats()
        var a = DayStats(); a.solved["math"] = 2; a.unlocksEarned = 1; a.minutesSaved = 15
        local.days[k1] = a
        local.quickSolveStreak["math"] = 4
        local.bestStreak = 2
        local.celebratedMilestones = [3]

        var cloud = Stats()
        var b = DayStats(); b.solved["math"] = 1; b.solved["word"] = 3; b.unlocksEarned = 2; b.dailyPuzzleSolved = true
        cloud.days[k1] = b
        var c = DayStats(); c.solved["chess"] = 1
        cloud.days[k2] = c
        cloud.days[k3] = c
        cloud.bestStreak = 9
        cloud.celebratedMilestones = [3, 7]
        cloud.quickSolveStreak["math"] = 0

        let merged = local.merged(with: cloud)
        XCTAssertEqual(merged.days[k1]?.solved["math"], 2)
        XCTAssertEqual(merged.days[k1]?.solved["word"], 3)
        XCTAssertEqual(merged.days[k1]?.unlocksEarned, 2)
        XCTAssertEqual(merged.days[k1]?.minutesSaved, 15)
        XCTAssertEqual(merged.days[k1]?.dailyPuzzleSolved, true)
        XCTAssertEqual(merged.days.count, 3)
        XCTAssertEqual(merged.bestStreak, 9)
        XCTAssertEqual(merged.celebratedMilestones, [3, 7])
        XCTAssertEqual(merged.quickSolveStreak["math"], 4, "progression counters stay device-local")
        XCTAssertEqual(merged.streak(now: date("2026-11-20 12:00"), calendar: cal), 3)
        XCTAssertGreaterThanOrEqual(merged.streak(now: date("2026-11-20 12:00"), calendar: cal),
                                    local.streak(now: date("2026-11-20 12:00"), calendar: cal))
        // Merging is symmetric for progress and idempotent.
        XCTAssertEqual(cloud.merged(with: local).days, merged.days)
        XCTAssertEqual(merged.merged(with: cloud), merged)
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
