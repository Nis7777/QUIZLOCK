import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let brandRed = Color(hex: Brand.Hex.brandRed)
    static let wordmarkRed = Color(hex: Brand.Hex.wordmarkRed)
    static let appBg = Color(hex: Brand.Hex.bg)
    static let cardWhite = Color(hex: Brand.Hex.card)
    static let textPrimary = Color(hex: Brand.Hex.textPrimary)
    static let textSecondary = Color(hex: Brand.Hex.textSecondary)
    static let correctGreenBg = Color(hex: Brand.Hex.correctGreenBg)
    static let correctGreen = Color(hex: Brand.Hex.correctGreen)
    static let answerGreen = Color(hex: 0x1E7B34)
    static let darkCard = Color(hex: Brand.Hex.darkCard)
    static let pinkTint = Color.brandRed.opacity(0.13)
    static let wordGreen = Color(hex: Brand.Hex.wordGreen)
    static let wordYellow = Color(hex: Brand.Hex.wordYellow)
    static let wordGrey = Color(hex: Brand.Hex.wordGrey)
    static let keyGrey = Color(hex: Brand.Hex.keyGrey)
    static let chessLight = Color(hex: Brand.Hex.chessLight)
    static let chessDark = Color(hex: Brand.Hex.chessDark)
    static let chessHighlight = Color(hex: Brand.Hex.chessHighlight, opacity: 0.6)
    static let paywallCream = Color(hex: Brand.Hex.paywallCream)
    static let lightGreyFill = Color(hex: 0xE9E9EE)
    static let toggleOffTrack = Color(hex: 0xD9D9DE)
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case classic, dark
    var id: String { rawValue }
    var title: String { self == .classic ? "Classic" : "Dark" }
    var subtitle: String { self == .classic ? "Light & red" : "Black & white" }
}

/// Colours that change with the Appearance setting. Puzzle boards and tiles keep their own colours.
struct Palette: Equatable {
    let accent: Color
    let onAccent: Color
    let bg: Color
    let card: Color
    let textPrimary: Color
    let textSecondary: Color
    let tint: Color
    let fieldFill: Color
    let separator: Color
    let wordmark: Color
    let isDark: Bool

    static let classic = Palette(
        accent: .brandRed, onAccent: .white, bg: .appBg, card: .cardWhite,
        textPrimary: .textPrimary, textSecondary: .textSecondary, tint: .pinkTint,
        fieldFill: .lightGreyFill, separator: Color.black.opacity(0.08), wordmark: .wordmarkRed, isDark: false)

    static let dark = Palette(
        accent: .white, onAccent: .black, bg: .black, card: Color(hex: 0x1C1C1E),
        textPrimary: .white, textSecondary: Color(hex: 0x9A9AA0), tint: Color.white.opacity(0.14),
        fieldFill: Color(hex: 0x2C2C2E), separator: Color.white.opacity(0.12), wordmark: .white, isDark: true)

    static func forTheme(_ theme: AppTheme) -> Palette { theme == .dark ? .dark : .classic }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.classic
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

extension Animation {
    static let selectionSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
}

extension AnyTransition {
    /// Push-style slide + fade used between onboarding screens.
    static func push(forward: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }
}
