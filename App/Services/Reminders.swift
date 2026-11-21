import Foundation
import UserNotifications

/// Local, opt-in reminders. At most one per day:
/// - Evening streak reminder (20:00) if no puzzle was solved today.
/// - Weekly summary on Sunday (18:00): "You saved 2h 40m this week 🧩". On Sundays it replaces the streak reminder.
enum Reminders {
    static let streakID = "reminder.streak"
    static let weeklyID = "reminder.weekly"

    static func reschedule(settings: AppSettings, stats: Stats, now: Date = Date(), calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakID, weeklyID])

        if settings.weeklySummaryEnabled, let sunday = nextDate(weekday: 1, hour: 18, after: now, calendar: calendar) {
            let saved = StatsStore.formatMinutes(stats.minutesSavedThisWeek(now: now, calendar: calendar))
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Your week with \(Brand.appName)")
            content.body = stats.minutesSavedThisWeek(now: now, calendar: calendar) > 0
                ? String(localized: "You saved \(saved) this week 🧩")
                : String(localized: "A new week, a fresh start. Solve a puzzle today 🧩")
            schedule(content, at: sunday, id: weeklyID, calendar: calendar)
        }

        if settings.streakReminderEnabled {
            let solvedToday = stats.day(now, calendar: calendar).puzzlesSolved > 0
            var day = calendar.startOfDay(for: now)
            if solvedToday || calendar.component(.hour, from: now) >= 20 {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            }
            // Max one a day: skip Sundays when the weekly summary is on.
            if settings.weeklySummaryEnabled, calendar.component(.weekday, from: day) == 1 {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            }
            if let fire = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) {
                let streak = stats.streak(now: now, calendar: calendar)
                let content = UNMutableNotificationContent()
                content.title = streak > 0
                    ? String(localized: "Keep your \(streak)-day streak 🔥")
                    : String(localized: "Time for today's puzzle 🧩")
                content.body = String(localized: "Solve one puzzle today to keep your streak going.")
                schedule(content, at: fire, id: streakID, calendar: calendar)
            }
        }
    }

    private static func schedule(_ content: UNMutableNotificationContent, at date: Date, id: String, calendar: Calendar) {
        content.sound = .default
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func nextDate(weekday: Int, hour: Int, after now: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: 0, weekday: weekday),
                          matchingPolicy: .nextTime)
    }
}
