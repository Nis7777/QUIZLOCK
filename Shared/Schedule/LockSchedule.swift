import Foundation

/// When locks apply. `nil` in LockState means "Always".
public struct LockSchedule: Codable, Hashable, Sendable {
    /// Minutes after midnight.
    public var startMinute: Int
    public var endMinute: Int
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) on which the schedule *starts*.
    public var weekdays: [Int]

    public init(startMinute: Int = 9 * 60, endMinute: Int = 17 * 60, weekdays: [Int] = [2, 3, 4, 5, 6]) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public var isOvernight: Bool { endMinute < startMinute }

    /// True if locks should be on at `date`. Overnight schedules (e.g. 22:00–07:00) belong to the
    /// weekday they start on.
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let weekday = c.weekday ?? 1
        let previous = weekday == 1 ? 7 : weekday - 1
        if startMinute == endMinute { return weekdays.contains(weekday) }
        if !isOvernight {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        return (weekdays.contains(weekday) && minute >= startMinute)
            || (weekdays.contains(previous) && minute < endMinute)
    }

    public static func format(minute: Int) -> String {
        String(format: "%02d:%02d", (minute / 60) % 24, minute % 60)
    }
}
