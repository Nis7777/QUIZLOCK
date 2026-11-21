import Foundation

/// Answers from the onboarding (App Group + iCloud). Used for personalisation, the reality check and the plan.
struct UserProfile: Codable, Equatable {
    /// "Where did you hear about us?" (attribution).
    enum Source: String, Codable, CaseIterable, Identifiable {
        case tiktok, instagram, youtube, appStore, friend, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .tiktok: return "TikTok"
            case .instagram: return "Instagram"
            case .youtube: return "YouTube"
            case .appStore: return "App Store"
            case .friend: return "Friend"
            case .other: return "Other"
            }
        }
        var symbol: String {
            switch self {
            case .tiktok: return "music.note"
            case .instagram: return "camera"
            case .youtube: return "play.rectangle"
            case .appStore: return "bag"
            case .friend: return "person.2"
            case .other: return "ellipsis.circle"
            }
        }
        /// Real app icon (BrandAppIcon) for the apps; Friend and Other keep their SF Symbols.
        var logo: String? {
            switch self {
            case .tiktok: return "tiktok"
            case .instagram: return "instagram"
            case .youtube: return "youtube"
            case .appStore: return "appstore"
            case .friend, .other: return nil
            }
        }
        var subtitle: String {
            switch self {
            case .tiktok: return "A video on my feed"
            case .instagram: return "A post or a reel"
            case .youtube: return "A video or a Short"
            case .appStore: return "Found it while browsing"
            case .friend: return "Someone told me about it"
            case .other: return "Somewhere else"
            }
        }
    }

    enum ScrollHours: String, Codable, CaseIterable, Identifiable {
        case under2, from2to4, from4to6, from6to8, over8
        var id: String { rawValue }
        var label: String {
            switch self {
            case .under2: return "Less than 2h"
            case .from2to4: return "2–4h"
            case .from4to6: return "4–6h"
            case .from6to8: return "6–8h"
            case .over8: return "More than 8h"
            }
        }
        var subtitle: String {
            switch self {
            case .under2: return "Pretty mindful already"
            case .from2to4: return "About average"
            case .from4to6: return "Most of my free time"
            case .from6to8: return "A big part of my day"
            case .over8: return "Basically all day"
            }
        }
        var symbol: String {
            switch self {
            case .under2: return "sun.min.fill"
            case .from2to4: return "clock.fill"
            case .from4to6: return "hourglass"
            case .from6to8: return "flame.fill"
            case .over8: return "exclamationmark.triangle.fill"
            }
        }
        var hours: Double {
            switch self {
            case .under2: return 1.5
            case .from2to4: return 3
            case .from4to6: return 5
            case .from6to8: return 7
            case .over8: return 9
            }
        }
    }

    enum Waster: String, Codable, CaseIterable, Identifiable {
        case shortVideos, socialFeeds, longVideos, games, news, messaging, shopping, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .shortVideos: return "Short videos"
            case .socialFeeds: return "Social feeds"
            case .longVideos: return "YouTube-style videos"
            case .games: return "Games"
            case .news: return "News"
            case .messaging: return "Messaging"
            case .shopping: return "Shopping"
            case .other: return "Other"
            }
        }
        var symbol: String {
            switch self {
            case .shortVideos: return "play.square.stack.fill"
            case .socialFeeds: return "person.2.fill"
            case .longVideos: return "play.tv.fill"
            case .games: return "gamecontroller.fill"
            case .news: return "newspaper.fill"
            case .messaging: return "message.fill"
            case .shopping: return "bag.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }

    enum Feeling: String, Codable, CaseIterable, Identifiable {
        case guilty, empty, anxious, wasting, lowEnergy, foggy, fine
        var id: String { rawValue }
        var label: String {
            switch self {
            case .guilty: return "Guilty"
            case .empty: return "Empty"
            case .anxious: return "Anxious"
            case .wasting: return "Like I'm wasting my life"
            case .lowEnergy: return "Low energy"
            case .foggy: return "Foggy"
            case .fine: return "Fine actually"
            }
        }
        var emoji: String {
            switch self {
            case .guilty: return "😞"
            case .empty: return "😶"
            case .anxious: return "😰"
            case .wasting: return "⏳"
            case .lowEnergy: return "🪫"
            case .foggy: return "🌫️"
            case .fine: return "🙂"
            }
        }
    }

    enum Want: String, Codable, CaseIterable, Identifiable {
        case reading, learning, focus, sleep, exercise, outside, friends, creativity, calm
        var id: String { rawValue }
        enum Area: String, CaseIterable { case mind = "Mind", body = "Body", life = "Life" }
        var area: Area {
            switch self {
            case .reading, .learning, .focus: return .mind
            case .sleep, .exercise, .outside: return .body
            case .friends, .creativity, .calm: return .life
            }
        }
        var label: String {
            switch self {
            case .reading: return "Reading"
            case .learning: return "Learning"
            case .focus: return "Focus at work/school"
            case .sleep: return "Sleep"
            case .exercise: return "Exercise"
            case .outside: return "Time outside"
            case .friends: return "Friends & family"
            case .creativity: return "Creativity"
            case .calm: return "Calm"
            }
        }
        var emoji: String {
            switch self {
            case .reading: return "📚"
            case .learning: return "🧠"
            case .focus: return "🎯"
            case .sleep: return "😴"
            case .exercise: return "🏃"
            case .outside: return "🌳"
            case .friends: return "🫶"
            case .creativity: return "🎨"
            case .calm: return "🧘"
            }
        }
    }

    /// "How hard should unlocking be?"
    enum Challenge: String, Codable, CaseIterable, Identifiable {
        case chill, balanced, tough, monk
        var id: String { rawValue }
        var label: String {
            switch self {
            case .chill: return "Chill: 1 easy puzzle"
            case .balanced: return "Balanced: 1 medium puzzle"
            case .tough: return "Tough: 2 medium puzzles"
            case .monk: return "Monk mode: 3 hard puzzles"
            }
        }
        var title: String {
            switch self {
            case .chill: return "Chill"
            case .balanced: return "Balanced"
            case .tough: return "Tough"
            case .monk: return "Monk mode"
            }
        }
        var subtitle: String {
            switch self {
            case .chill: return "1 easy puzzle"
            case .balanced: return "1 medium puzzle"
            case .tough: return "2 medium puzzles"
            case .monk: return "3 hard puzzles"
            }
        }
        var symbol: String {
            switch self {
            case .chill: return "leaf.fill"
            case .balanced: return "scale.3d"
            case .tough: return "flame.fill"
            case .monk: return "figure.mind.and.body"
            }
        }
        var puzzlesPerUnlock: Int {
            switch self {
            case .chill, .balanced: return 1
            case .tough: return 2
            case .monk: return 3
            }
        }
        var difficulty: Difficulty {
            switch self {
            case .chill: return .easy
            case .balanced, .tough: return .medium
            case .monk: return .hard
            }
        }
    }

    var name = ""
    var source: Source?
    var scrollHours: ScrollHours?
    var wasters: [Waster] = []
    var feelings: [Feeling] = []
    var wants: [Want] = []
    var challenge: Challenge?
    var committed = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        source = try? c.decodeIfPresent(Source.self, forKey: .source)
        scrollHours = try? c.decodeIfPresent(ScrollHours.self, forKey: .scrollHours)
        wasters = (try? c.decodeIfPresent([Waster].self, forKey: .wasters)) ?? []
        feelings = (try? c.decodeIfPresent([Feeling].self, forKey: .feelings)) ?? []
        wants = (try? c.decodeIfPresent([Want].self, forKey: .wants)) ?? []
        challenge = try? c.decodeIfPresent(Challenge.self, forKey: .challenge)
        committed = (try? c.decodeIfPresent(Bool.self, forKey: .committed)) ?? false
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// X = (daily hours / 24) × (80 − age), rounded to 1 decimal (PROMPT_V2 formula). We don't ask the
    /// age in v3, so the age midpoint of 29.5 is used.
    var yearsOnPhone: Double {
        let hours = (scrollHours ?? .from2to4).hours
        return ((hours / 24) * (80 - 29.5) * 10).rounded() / 10
    }

    /// Y = 50% of X.
    var yearsBack: Double { (yearsOnPhone / 2 * 10).rounded() / 10 }

    /// Categories to suggest locking.
    var suggestedCategories: [Waster] {
        let picked = wasters.filter { $0 != .other }
        return picked.isEmpty ? [.shortVideos, .socialFeeds] : picked
    }
}
