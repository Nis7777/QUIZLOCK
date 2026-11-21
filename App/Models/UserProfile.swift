import Foundation

/// Answers from the onboarding questions (stored in the App Group; used for personalisation).
struct UserProfile: Codable, Equatable {
    enum AgeRange: String, Codable, CaseIterable, Identifiable {
        case under18, from18to24, from25to34, from35to44, over45
        var id: String { rawValue }
        var label: String {
            switch self {
            case .under18: return "Under 18"
            case .from18to24: return "18–24"
            case .from25to34: return "25–34"
            case .from35to44: return "35–44"
            case .over45: return "45+"
            }
        }
        /// Midpoint age used for the reality check.
        var midpoint: Double {
            switch self {
            case .under18: return 15
            case .from18to24: return 21
            case .from25to34: return 29.5
            case .from35to44: return 39.5
            case .over45: return 52
            }
        }
    }

    enum ScreenTimeRange: String, Codable, CaseIterable, Identifiable {
        case oneToTwo, threeToFour, fiveToSix, sevenPlus, unknown
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneToTwo: return "1–2 hours"
            case .threeToFour: return "3–4 hours"
            case .fiveToSix: return "5–6 hours"
            case .sevenPlus: return "7+ hours"
            case .unknown: return "I don't know"
            }
        }
        var hours: Double {
            switch self {
            case .oneToTwo: return 1.5
            case .threeToFour: return 3.5
            case .fiveToSix: return 5.5
            case .sevenPlus: return 7.5
            case .unknown: return 4
            }
        }
    }

    enum Waster: String, Codable, CaseIterable, Identifiable {
        case shortVideos, socialMedia, games, news, messaging, shopping, longVideos, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .shortVideos: return "Short videos"
            case .socialMedia: return "Social media"
            case .games: return "Games"
            case .news: return "News"
            case .messaging: return "Messaging"
            case .shopping: return "Shopping"
            case .longVideos: return "Long videos"
            case .other: return "Other"
            }
        }
        var symbol: String {
            switch self {
            case .shortVideos: return "play.square.stack.fill"
            case .socialMedia: return "person.2.fill"
            case .games: return "gamecontroller.fill"
            case .news: return "newspaper.fill"
            case .messaging: return "message.fill"
            case .shopping: return "bag.fill"
            case .longVideos: return "play.tv.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }

    enum Goal: String, Codable, CaseIterable, Identifiable {
        case focus, sleep, present, learn, doomscroll
        var id: String { rawValue }
        var label: String {
            switch self {
            case .focus: return "Focus on studies or work"
            case .sleep: return "Sleep better"
            case .present: return "Be more present"
            case .learn: return "Learn something every day"
            case .doomscroll: return "Break the doom-scrolling habit"
            }
        }
        var symbol: String {
            switch self {
            case .focus: return "target"
            case .sleep: return "moon.zzz.fill"
            case .present: return "figure.2.and.child.holdinghands"
            case .learn: return "brain.head.profile"
            case .doomscroll: return "hand.raised.fill"
            }
        }
        /// The promise, in the user's words.
        var promise: String {
            switch self {
            case .focus: return "I'll focus on what matters, not on my feed."
            case .sleep: return "I'll put my phone down and sleep better."
            case .present: return "I'll be more present with the people around me."
            case .learn: return "I'll learn something every day instead of scrolling."
            case .doomscroll: return "I'll break the doom-scrolling habit."
            }
        }
    }

    enum Feeling: String, Codable, CaseIterable, Identifiable {
        case drained, anxious, bored, guilty, fine
        var id: String { rawValue }
        var label: String {
            switch self {
            case .drained: return "Drained"
            case .anxious: return "Anxious"
            case .bored: return "Bored"
            case .guilty: return "Guilty"
            case .fine: return "Fine actually"
            }
        }
        var symbol: String {
            switch self {
            case .drained: return "battery.25"
            case .anxious: return "waveform.path.ecg"
            case .bored: return "zzz"
            case .guilty: return "exclamationmark.bubble.fill"
            case .fine: return "hand.thumbsup.fill"
            }
        }
    }

    enum When: String, Codable, CaseIterable, Identifiable {
        case morning, work, evenings, lateNight
        var id: String { rawValue }
        var label: String {
            switch self {
            case .morning: return "Morning in bed"
            case .work: return "At work or class"
            case .evenings: return "Evenings"
            case .lateNight: return "Late at night"
            }
        }
        var symbol: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .work: return "briefcase.fill"
            case .evenings: return "sunset.fill"
            case .lateNight: return "moon.stars.fill"
            }
        }
    }

    var name = ""
    var ageRange: AgeRange?
    var screenTime: ScreenTimeRange?
    var wasters: [Waster] = []
    var goal: Goal?
    var feelings: [Feeling] = []
    var when: When?
    var committed = false

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// X = (dailyHours / 24) × (80 − age midpoint), rounded to 1 decimal.
    var yearsOnPhone: Double {
        let hours = (screenTime ?? .unknown).hours
        let age = (ageRange ?? .from25to34).midpoint
        return ((hours / 24) * max(0, 80 - age) * 10).rounded() / 10
    }

    /// With QuizLock: 50% less.
    var yearsWithQuizLock: Double { (yearsOnPhone / 2 * 10).rounded() / 10 }

    // MARK: Plan

    var suggestedDuration: UnlockDuration { goal == .doomscroll ? .minutes(5) : .minutes(15) }

    var suggestedCategories: [Waster] {
        let picked = wasters.filter { $0 != .other }
        return picked.isEmpty ? [.shortVideos, .socialMedia] : picked
    }
}
