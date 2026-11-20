import SwiftUI

/// System font that follows Dynamic Type. Sizes are the design's sizes at the default text size;
/// large display text is capped so layouts (and the puzzle boards) never break.
struct AppFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(.system(size: Self.scaled(size, for: dynamicTypeSize), weight: weight, design: design))
    }

    static func factor(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: return 0.82
        case .small: return 0.88
        case .medium: return 0.94
        case .large: return 1.0
        case .xLarge: return 1.12
        case .xxLarge: return 1.24
        case .xxxLarge: return 1.35
        case .accessibility1: return 1.6
        case .accessibility2: return 1.9
        case .accessibility3: return 2.2
        case .accessibility4: return 2.5
        case .accessibility5: return 2.8
        @unknown default: return 1.0
        }
    }

    static func scaled(_ size: CGFloat, for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let cap: CGFloat = size >= 34 ? 1.25 : (size >= 22 ? 1.5 : 2.2)
        return (size * min(factor(for: dynamicTypeSize), cap)).rounded()
    }
}

extension View {
    /// Dynamic Type–aware system font (use instead of `.font(.system(size:))`).
    func appFont(_ size: CGFloat, _ weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, design: design))
    }

    /// Guarantees Apple's minimum 44×44pt tap area.
    func tapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}

/// Shake used for wrong answers. With Reduce Motion on it doesn't move.
struct ShakeModifier: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(ShakeEffect(travel: reduceMotion ? 0 : 9, animatableData: CGFloat(trigger)))
    }
}
