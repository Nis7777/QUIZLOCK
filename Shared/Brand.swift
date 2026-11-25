import Foundation

/// Every brand / configuration value lives here. Change them in one place.
public enum Brand {
    public static let appName = "Lockie"
    public static let appNameCaps = "LOCKIE"
    public static let tagline = "Get smarter before scrolling"
    public static let bundleID = "app.lockie.ios"
    public static let appGroup = "group.app.lockie.ios"
    public static let supportEmail = "lockie.support@gmail.com"
    public static let termsURL = URL(string: "https://nis7777.github.io/lockie/terms.html") ?? URL(fileURLWithPath: "/")
    public static let supportURL = URL(string: "https://nis7777.github.io/lockie/") ?? URL(fileURLWithPath: "/")
    public static let privacyURL = URL(string: "https://nis7777.github.io/lockie/privacy.html") ?? URL(fileURLWithPath: "/")
    /// Auto-renewable subscriptions, all in the App Store Connect subscription group "Lockie Pro".
    /// Prices and the free trial live in App Store Connect / Products.storekit; the app always reads them from StoreKit.
    public static let subscriptionGroupName = "Lockie Pro"
    public static let iapProYearly = "app.lockie.ios.pro.yearly"            // yearly, 7-day free trial (intro offer)
    public static let iapProMonthly = "app.lockie.ios.pro.monthly"          // monthly, no trial
    public static let iapProYearlyOffer = "app.lockie.ios.pro.yearly.offer" // yearly, exit offer only, no trial
    public static let proProductIDs = [iapProYearly, iapProMonthly, iapProYearlyOffer]
    /// The trial reminder fires this many days before the trial ends (day 5 of a 7-day trial).
    public static let trialReminderDaysBeforeEnd = 2
    /// Your app's numeric Apple ID from App Store Connect (App Information → Apple ID). Used by "Rate Lockie".
    public static let appStoreID = "0000000000"
    /// nil until `appStoreID` is filled in; "Rate Lockie" then uses Apple's in-app rating prompt instead.
    public static var reviewURL: URL? {
        guard appStoreID.allSatisfy(\.isNumber), appStoreID != "0000000000" else { return nil }
        return URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")
    }
    public static let minIOS = "17.0"

    /// RevenueCat's public Apple SDK key (made to ship inside the app; never put the secret `sk_` key here).
    public static let revenueCatAPIKey = "appl_wszUHhzGeHrGJbtxpxMBUjoKwor"

    public static let urlScheme = "lockie"
    public static let unlockDeepLink = URL(string: "lockie://unlock") ?? URL(fileURLWithPath: "/")
    /// After "Solve to unlock" on the shield, how long the shield shows "Your puzzle is ready" instead.
    public static let shieldReadyWindow: TimeInterval = 5 * 60
    /// How recent a shield tap must be for Lockie to open straight into that puzzle when it's opened or
    /// brought to the front by any route (notification, app icon, widget, Spotlight, Shortcuts).
    public static let autoResumeWindow: TimeInterval = 5 * 60
    public static let credits = "Chess puzzles from the Lichess puzzle database (CC0)."

    /// Brand colours as 0xRRGGBB. SwiftUI / UIKit wrappers live in the App target.
    public enum Hex {
        /// Coral brand colour (buttons, toggles, selected states, links, icons, the wordmark).
        public static let brand: UInt32 = 0xFF5A36
        /// Darker coral for pressed states and small coral text on white (better contrast).
        public static let brandDeep: UInt32 = 0xE4421F
        /// Error states only (wrong answers, shakes, Sudoku conflicts).
        public static let errorRed: UInt32 = 0xFF3B30
        public static let bg: UInt32 = 0xF6F5F8
        public static let card: UInt32 = 0xFFFFFF
        public static let textPrimary: UInt32 = 0x18181C
        public static let textSecondary: UInt32 = 0x6E6E73
        public static let correctGreenBg: UInt32 = 0xD3EFDA
        public static let correctGreen: UInt32 = 0x34C759
        public static let darkCard: UInt32 = 0x13110F
        public static let wordGreen: UInt32 = 0x6AAA64
        public static let wordYellow: UInt32 = 0xC9B458
        public static let wordGrey: UInt32 = 0x787C7E
        public static let keyGrey: UInt32 = 0xD3D6DA
        public static let chessLight: UInt32 = 0xE7E8C8
        public static let chessDark: UInt32 = 0x65884E
        public static let chessHighlight: UInt32 = 0xF6F669
        public static let paywallCream: UInt32 = 0xFFF3DC
        /// Launch screen + splash background.
        public static let peach: UInt32 = 0xFFF1EC
    }
}

/// A plain note of the puzzle waiting after "Solve to unlock": the app's name and when it was asked.
/// Written by the shield, cleared when the unlock is earned. Plain values (no Screen Time tokens), so the
/// widget can read it too.
public enum PendingPuzzleNote {
    private static let key = "pendingPuzzleNote.v1"
    private static var defaults: UserDefaults { UserDefaults(suiteName: Brand.appGroup) ?? .standard }

    public static func set(appName: String?, at date: Date = Date()) {
        defaults.set(["name": appName ?? "", "at": date.timeIntervalSince1970], forKey: key)
    }

    public static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// The waiting puzzle, if it was asked for within `Brand.autoResumeWindow`.
    public static func current(now: Date = Date()) -> (appName: String?, at: Date)? {
        guard let note = defaults.dictionary(forKey: key), let t = note["at"] as? Double else { return nil }
        let at = Date(timeIntervalSince1970: t)
        guard now.timeIntervalSince(at) < Brand.autoResumeWindow else { return nil }
        let name = note["name"] as? String
        return (name?.isEmpty == false ? name : nil, at)
    }

    /// Lockie's picture for the "Tap to solve" notification, written into the App Group by the app
    /// (an extension can only attach a file, and the shield-action extension has no image assets).
    public static var notificationArtURL: URL? {
        #if os(Linux)
        return nil // App Groups don't exist on Linux (engine test harness only)
        #else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Brand.appGroup)?
            .appendingPathComponent("notification_lockie_v1.png")
        #endif
    }
}
