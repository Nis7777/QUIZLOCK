import Foundation

// Localized versions of labels that come from Shared/ (which stays plain English so the engines and
// extensions don't depend on the app's string catalog).

extension UnlockDuration {
    /// "15 minutes", "For Today", "1 hour 30 minutes", localized.
    var localizedLabel: String {
        switch self {
        case .minutes(let m): return Self.localizedDescription(totalMinutes: m)
        case .forToday: return String(localized: "For Today")
        case .custom(let h, let m): return Self.localizedDescription(totalMinutes: h * 60 + m)
        }
    }

    /// Used in sentences: "unlocked for 15 minutes" / "unlocked for today".
    var localizedSentenceLabel: String {
        if case .forToday = self { return String(localized: "today") }
        return localizedLabel
    }

    static func localizedDescription(totalMinutes: Int) -> String {
        let h = totalMinutes / 60, m = totalMinutes % 60
        let hours = String(localized: "\(h) hours")
        let minutes = String(localized: "\(m) minutes")
        switch (h, m) {
        case (0, _): return minutes
        case (_, 0): return hours
        default: return hours + " " + minutes
        }
    }

    /// Approximate minutes (For Today counts as 60) for "time saved" estimates.
    var approximateMinutes: Int {
        switch self {
        case .minutes(let m): return m
        case .forToday: return 60
        case .custom(let h, let m): return h * 60 + m
        }
    }
}

extension GameID {
    var localizedName: String { String(localized: String.LocalizationValue(displayName)) }
}

extension Difficulty {
    var localizedName: String { String(localized: String.LocalizationValue(displayName)) }
}
