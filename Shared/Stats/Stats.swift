import Foundation

/// One day of activity. Keys of `solved` are game ids ("chess", "sudoku", "math", "word").
public struct DayStats: Codable, Equatable {
    public var solved: [String: Int] = [:]
    public var unlocksEarned = 0
    public var unlocksSkipped = 0
    /// Estimated minutes saved by skipped unlocks (skips × the unlock time at that moment).
    public var minutesSaved = 0
    /// The app (or a shield button) was used this day.
    public var active = false
    public var emergencyUsed = false
    public var dailyPuzzleSolved = false

    public init() {}

    public var puzzlesSolved: Int { solved.values.reduce(0, +) }

    /// A day keeps the streak alive with ≥1 puzzle solved, or an active day with zero unlocks.
    /// An emergency unlock breaks it.
    public var keepsStreak: Bool {
        !emergencyUsed && (puzzlesSolved > 0 || (active && unlocksEarned == 0))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        solved = (try? c.decodeIfPresent([String: Int].self, forKey: .solved)) ?? [:]
        unlocksEarned = (try? c.decodeIfPresent(Int.self, forKey: .unlocksEarned)) ?? 0
        unlocksSkipped = (try? c.decodeIfPresent(Int.self, forKey: .unlocksSkipped)) ?? 0
        minutesSaved = (try? c.decodeIfPresent(Int.self, forKey: .minutesSaved)) ?? 0
        active = (try? c.decodeIfPresent(Bool.self, forKey: .active)) ?? false
        emergencyUsed = (try? c.decodeIfPresent(Bool.self, forKey: .emergencyUsed)) ?? false
        dailyPuzzleSolved = (try? c.decodeIfPresent(Bool.self, forKey: .dailyPuzzleSolved)) ?? false
    }
}

public struct Stats: Codable, Equatable {
    /// "yyyy-MM-dd" → day.
    public var days: [String: DayStats] = [:]
    public var celebratedMilestones: [Int] = []
    /// Consecutive quick solves / fails per game (difficulty progression).
    public var quickSolveStreak: [String: Int] = [:]
    public var failStreak: [String: Int] = [:]
    public var emergencyUnlocks: [Date] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = (try? c.decodeIfPresent([String: DayStats].self, forKey: .days)) ?? [:]
        celebratedMilestones = (try? c.decodeIfPresent([Int].self, forKey: .celebratedMilestones)) ?? []
        quickSolveStreak = (try? c.decodeIfPresent([String: Int].self, forKey: .quickSolveStreak)) ?? [:]
        failStreak = (try? c.decodeIfPresent([String: Int].self, forKey: .failStreak)) ?? [:]
        emergencyUnlocks = (try? c.decodeIfPresent([Date].self, forKey: .emergencyUnlocks)) ?? []
    }

    public static let milestones = [3, 7, 30]
    public static let emergencyLimitPerWeek = 3

    public func day(_ date: Date, calendar: Calendar = .current) -> DayStats {
        days[StatsStore.key(for: date, calendar: calendar)] ?? DayStats()
    }

    /// Consecutive qualifying days ending today (today counts once it qualifies; until then, from yesterday).
    public func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        var date = calendar.startOfDay(for: now)
        if !day(date, calendar: calendar).keepsStreak {
            guard let y = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = y
        }
        var count = 0
        while day(date, calendar: calendar).keepsStreak {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    /// Last 7 days, oldest first.
    public func lastSevenDays(now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, stats: DayStats)] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (d, day(d, calendar: calendar))
        }
    }

    public var totalSolvedByGame: [String: Int] {
        days.values.reduce(into: [:]) { acc, d in
            for (g, n) in d.solved { acc[g, default: 0] += n }
        }
    }

    public var totalUnlocksEarned: Int { days.values.reduce(0) { $0 + $1.unlocksEarned } }
    public var totalUnlocksSkipped: Int { days.values.reduce(0) { $0 + $1.unlocksSkipped } }
    public var totalMinutesSaved: Int { days.values.reduce(0) { $0 + $1.minutesSaved } }

    public func minutesSavedThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        lastSevenDays(now: now, calendar: calendar).reduce(0) { $0 + $1.stats.minutesSaved }
    }

    public func emergencyUnlocksLeft(now: Date = Date()) -> Int {
        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        return max(0, Self.emergencyLimitPerWeek - emergencyUnlocks.filter { $0 > weekAgo }.count)
    }

    /// A milestone reached but not yet celebrated.
    public func pendingMilestone(now: Date = Date()) -> Int? {
        let s = streak(now: now)
        return Self.milestones.last { s >= $0 && !celebratedMilestones.contains($0) }
    }
}

/// App Group persistence for `Stats`. Self-contained (used by the app, the shield action extension and the widget).
public enum StatsStore {
    static let key = "stats.v1"

    private static var defaults: UserDefaults { UserDefaults(suiteName: Brand.appGroup) ?? .standard }

    public static func load() -> Stats {
        guard let data = defaults.data(forKey: key), let s = try? JSONDecoder().decode(Stats.self, from: data) else { return Stats() }
        return s
    }

    public static func save(_ stats: Stats) {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: key) }
    }

    @discardableResult
    public static func update(_ change: (inout Stats) -> Void) -> Stats {
        var s = load()
        change(&s)
        // Keep ~1 year of days.
        if s.days.count > 400 {
            let keep = Set(s.days.keys.sorted().suffix(370))
            s.days = s.days.filter { keep.contains($0.key) }
        }
        save(s)
        return s
    }

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func updateToday(_ now: Date = Date(), _ change: (inout DayStats) -> Void) {
        update { s in
            let k = key(for: now)
            var d = s.days[k] ?? DayStats()
            change(&d)
            s.days[k] = d
        }
    }

    // MARK: Events

    public static func recordActive() { updateToday { $0.active = true } }

    public static func recordSolve(game: String) {
        updateToday { d in
            d.active = true
            d.solved[game, default: 0] += 1
        }
    }

    public static func recordUnlockEarned() { updateToday { $0.active = true; $0.unlocksEarned += 1 } }

    /// "NOT NOW" on the shield: an unlock skipped.
    public static func recordSkip(minutes: Int) {
        updateToday { d in
            d.active = true
            d.unlocksSkipped += 1
            d.minutesSaved += max(0, minutes)
        }
    }

    public static func recordEmergency(at now: Date = Date()) {
        update { s in
            let k = key(for: now)
            var d = s.days[k] ?? DayStats()
            d.active = true
            d.emergencyUsed = true
            s.days[k] = d
            s.emergencyUnlocks.append(now)
            s.emergencyUnlocks = s.emergencyUnlocks.filter { $0 > now.addingTimeInterval(-30 * 24 * 3600) }
        }
    }

    public static func recordDailyPuzzle() { updateToday { $0.dailyPuzzleSolved = true } }

    /// "2h 40m" / "35m".
    public static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
