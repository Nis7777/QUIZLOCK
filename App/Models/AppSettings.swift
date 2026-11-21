import FamilyControls
import Foundation
import ManagedSettings

/// App-only settings (persisted as JSON in the App Group).
struct AppSettings: Codable, Equatable {
    var onboardingComplete = false
    var enabledGames: [GameID] = GameID.allCases
    var difficulties: [String: Difficulty] = [:]
    var theme: AppTheme = .classic
    var showAllSetBanner = true
    var analyticsEnabled = false
    var adMeasurementEnabled = false
    var freeUnlocksUsed = 0
    /// Cached "QuizLock Pro" entitlement (StoreKit is the source of truth; refreshed on launch and on Transaction.updates).
    var isPro = false
    /// The exit offer has been shown (it appears once, when the main paywall is closed).
    var exitOfferShown = false
    var simulatorAuthorized = false
    /// Where onboarding was left (so killing the app mid-onboarding resumes there).
    var onboardingStep: String?
    var ratingRequested = false
    /// Local reminders (opt-in, off by default).
    var streakReminderEnabled = false
    var weeklySummaryEnabled = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.defaults
        onboardingComplete = (try? c.decodeIfPresent(Bool.self, forKey: .onboardingComplete)) ?? d.onboardingComplete
        enabledGames = (try? c.decodeIfPresent([GameID].self, forKey: .enabledGames)) ?? d.enabledGames
        if enabledGames.isEmpty { enabledGames = d.enabledGames }
        difficulties = (try? c.decodeIfPresent([String: Difficulty].self, forKey: .difficulties)) ?? d.difficulties
        theme = (try? c.decodeIfPresent(AppTheme.self, forKey: .theme)) ?? d.theme
        showAllSetBanner = (try? c.decodeIfPresent(Bool.self, forKey: .showAllSetBanner)) ?? d.showAllSetBanner
        analyticsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .analyticsEnabled)) ?? d.analyticsEnabled
        adMeasurementEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .adMeasurementEnabled)) ?? d.adMeasurementEnabled
        freeUnlocksUsed = (try? c.decodeIfPresent(Int.self, forKey: .freeUnlocksUsed)) ?? d.freeUnlocksUsed
        isPro = (try? c.decodeIfPresent(Bool.self, forKey: .isPro)) ?? d.isPro
        exitOfferShown = (try? c.decodeIfPresent(Bool.self, forKey: .exitOfferShown)) ?? d.exitOfferShown
        simulatorAuthorized = (try? c.decodeIfPresent(Bool.self, forKey: .simulatorAuthorized)) ?? d.simulatorAuthorized
        onboardingStep = try? c.decodeIfPresent(String.self, forKey: .onboardingStep)
        ratingRequested = (try? c.decodeIfPresent(Bool.self, forKey: .ratingRequested)) ?? d.ratingRequested
        streakReminderEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .streakReminderEnabled)) ?? d.streakReminderEnabled
        weeklySummaryEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .weeklySummaryEnabled)) ?? d.weeklySummaryEnabled
    }

    private static let defaults = AppSettings()

    func difficulty(for game: GameID) -> Difficulty {
        if let d = difficulties[game.rawValue], game.difficulties.contains(d) { return d }
        return .easy
    }

    func isEnabled(_ game: GameID) -> Bool { enabledGames.contains(game) }

    var freeUnlocksRemaining: Int { max(0, Brand.freeUnlocks - freeUnlocksUsed) }
}

/// Progress through an unlock (persisted so leaving the app doesn't lose it).
struct UnlockSession: Codable {
    var pending: PendingUnlock
    var required: Int
    var solved: Int = 0
    var order: [GameID]
    var orderIndex: Int = 0
    var current: AnyRound?

    var currentGame: GameID { order.isEmpty ? .math : order[orderIndex % order.count] }
}

/// A selected app / category / website (or a fake app in the Simulator).
struct LockItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case app(ApplicationToken)
        case category(ActivityCategoryToken)
        case web(WebDomainToken)
        case mock(String)
    }

    let kind: Kind
    let key: String
    var id: String { key }

    static func items(from state: LockState) -> [LockItem] {
        var result: [LockItem] = []
        result += state.selection.applicationTokens.map { LockItem(kind: .app($0), key: TokenKey.key($0)) }
        result += state.selection.categoryTokens.map { LockItem(kind: .category($0), key: TokenKey.key($0)) }
        result += state.selection.webDomainTokens.map { LockItem(kind: .web($0), key: TokenKey.key($0)) }
        result.sort { $0.key < $1.key }
        result += state.mockApps.map { LockItem(kind: .mock($0), key: TokenKey.mock($0)) }
        return result
    }
}

/// Fake apps used by the Simulator mock (FamilyControls isn't available there).
enum MockApps {
    static let all: [(name: String, symbol: String, colors: [UInt32])] = [
        ("Social", "camera.circle", [0x8A3AB9, 0xE95950, 0xFCCC63]),
        ("Shorts", "music.note", [0x111111, 0x333333]),
        ("Videos", "play.rectangle.fill", [0xFF3B30, 0xD70015]),
        ("Chat", "bubble.left.fill", [0xFFE600, 0xF5C400]),
        ("Forum", "bubble.left.and.bubble.right.fill", [0xFF5700, 0xFF7A33]),
        ("News", "newspaper.fill", [0x000000, 0x2C2C2E]),
    ]

    static func info(_ name: String) -> (symbol: String, colors: [UInt32]) {
        if let m = all.first(where: { $0.name == name }) { return (m.symbol, m.colors) }
        return ("app.fill", [0x8E8E93, 0x636366])
    }
}
