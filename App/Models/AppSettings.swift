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
    /// Cached "Lockie Pro" entitlement (StoreKit is the source of truth; refreshed on launch and on Transaction.updates).
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

/// Apps shown by the Simulator mock picker (FamilyControls isn't available there), drawn with BrandAppIcon.
/// On a real device the locked-apps lists use Apple's Label(token) instead.
enum MockApps {
    static let all: [(name: String, logo: String)] = [
        ("TikTok", "tiktok"),
        ("Instagram", "instagram"),
        ("YouTube", "youtube"),
        ("Snapchat", "snapchat"),
        ("Reddit", "reddit"),
        ("X", "x"),
    ]

    /// BrandAppIcon name for a mock app (old saved names fall back to a neutral tile).
    static func logo(_ name: String) -> String {
        all.first(where: { $0.name == name })?.logo ?? name.lowercased()
    }
}
