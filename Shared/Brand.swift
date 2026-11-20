import Foundation

/// Every brand / configuration value lives here. Change them in one place.
public enum Brand {
    public static let appName = "QuizLock"
    public static let appNameCaps = "QUIZLOCK"
    public static let tagline = "Get smarter before scrolling"
    public static let bundleID = "com.dinismagina.quizlock"
    public static let appGroup = "group.com.dinismagina.quizlock"
    public static let supportEmail = "nismagina@gmail.com"
    public static let termsURL = URL(string: "https://example.com/terms")!
    public static let privacyURL = URL(string: "https://example.com/privacy")!
    public static let iapLifetimeStandard = "com.dinismagina.quizlock.lifetime"       // $29.99 non-consumable
    public static let iapLifetimePromo = "com.dinismagina.quizlock.lifetime.discount" // $4.99 non-consumable
    public static let freeUnlocks = 5
    public static let minIOS = "17.0"

    public static let urlScheme = "quizlock"
    public static let unlockDeepLink = URL(string: "quizlock://unlock")!
    public static let credits = "Chess puzzles from the Lichess puzzle database (CC0)."

    /// Brand colours as 0xRRGGBB. SwiftUI / UIKit wrappers live in the App target.
    public enum Hex {
        public static let brandRed: UInt32 = 0xD3251E
        public static let wordmarkRed: UInt32 = 0xF7271E
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
    }
}
