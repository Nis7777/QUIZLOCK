import Foundation

/// Every brand / configuration value lives here. Change them in one place.
public enum Brand {
    public static let appName = "QuizLock"
    public static let appNameCaps = "QUIZLOCK"
    public static let tagline = "Get smarter before scrolling"
    public static let bundleID = "app.quizlock.ios"
    public static let appGroup = "group.app.quizlock.ios"
    public static let supportEmail = "nismagina@gmail.com"
    public static let termsURL = URL(string: "https://nis7777.github.io/QUIZLOCK/terms.html") ?? URL(fileURLWithPath: "/")
    public static let supportURL = URL(string: "https://nis7777.github.io/QUIZLOCK/") ?? URL(fileURLWithPath: "/")
    public static let privacyURL = URL(string: "https://nis7777.github.io/QUIZLOCK/privacy.html") ?? URL(fileURLWithPath: "/")
    /// Auto-renewable subscriptions, all in the App Store Connect subscription group "QuizLock Pro".
    /// Prices and the free trial live in App Store Connect / Products.storekit; the app always reads them from StoreKit.
    public static let subscriptionGroupName = "QuizLock Pro"
    public static let iapProYearly = "app.quizlock.ios.pro.yearly"            // yearly, 7-day free trial (intro offer)
    public static let iapProMonthly = "app.quizlock.ios.pro.monthly"          // monthly, no trial
    public static let iapProYearlyOffer = "app.quizlock.ios.pro.yearly.offer" // yearly, exit offer only, no trial
    public static let proProductIDs = [iapProYearly, iapProMonthly, iapProYearlyOffer]
    /// The trial reminder fires this many days before the trial ends (day 5 of a 7-day trial).
    public static let trialReminderDaysBeforeEnd = 2
    public static let freeUnlocks = 5
    /// Your app's numeric Apple ID from App Store Connect (App Information → Apple ID). Used by "Rate QuizLock".
    public static let appStoreID = "0000000000"
    public static var reviewURL: URL? {
        URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")
    }
    public static let minIOS = "17.0"

    public static let urlScheme = "quizlock"
    public static let unlockDeepLink = URL(string: "quizlock://unlock") ?? URL(fileURLWithPath: "/")
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
