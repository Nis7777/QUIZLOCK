import SwiftUI

/// Thin coral progress bar (question chapter). The width springs to each new value (Motion.smooth),
/// with a small glow at the leading edge.
struct QuizProgressBar: View {
    let progress: Double
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = max(8, geo.size.width * min(1, max(0, progress)))
            ZStack(alignment: .leading) {
                Capsule().fill(palette.fieldFill)
                Capsule()
                    .fill(Color.brand)
                    .frame(width: width)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(Color.brand.opacity(0.55))
                            .frame(width: 14, height: 14)
                            .blur(radius: 6)
                            .offset(x: 4)
                    }
            }
        }
        .frame(height: 6)
        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: progress)
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(verbatim: "\(Int(progress * 100))%"))
    }
}

/// Answer card (single and multi select): white, radius 16, 1pt light border. On the left: a brand app icon,
/// an SF Symbol in a coral-tinted rounded square, or an emoji. Then a bold title (with an optional coral
/// pill such as "Recommended") over an optional grey subtitle, and the radio on the right.
/// Selected: 2pt coral border, peach fill, coral radio with a check (Motion.bouncy) and a selection haptic.
struct ChoiceCard: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var emoji: String?
    /// A BrandAppIcon name ("tiktok", "instagram"…).
    var logo: String?
    var badge: String?
    let selected: Bool
    var multi = false
    var dimmed = false
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { action() }
        } label: {
            HStack(spacing: 14) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(title))
                            .appFont(17, .bold)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let badge {
                            Text(LocalizedStringKey(badge))
                                .appFont(11, .heavy)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.brand, in: Capsule())
                                .fixedSize()
                        }
                    }
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .appFont(14)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                Spacer(minLength: 8)
                ChoiceRadio(selected: selected, square: multi)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(selected ? Color.brandTint : palette.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.brand : palette.separator, lineWidth: selected ? 2 : 1)
            )
            .opacity(dimmed && !selected ? 0.85 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .animation(Motion.snappy, value: selected)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("quiz.choice")
    }

    @ViewBuilder
    private var leading: some View {
        if let logo {
            BrandAppIcon(name: logo, size: 40)
                .accessibilityHidden(true)
        } else if let symbol {
            Image(systemName: symbol)
                .appFont(18, .semibold)
                .foregroundStyle(Color.brand)
                .frame(width: 40, height: 40)
                .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
        } else if let emoji {
            Text(verbatim: emoji).appFont(24).frame(width: 40).accessibilityHidden(true)
        }
    }
}

/// Empty ring, or a coral circle (square for multi-select) with a white check that scales in from 0.5.
struct ChoiceRadio: View {
    let selected: Bool
    var square = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: square ? 7 : 13, style: .continuous)
        ZStack {
            shape.strokeBorder(Color(hex: 0xC7C7CC), lineWidth: 2)
                .opacity(selected ? 0 : 1)
            shape.fill(Color.brand)
                .scaleEffect(selected ? 1 : 0.5)
                .opacity(selected ? 1 : 0)
            Image(systemName: "checkmark")
                .appFont(13, .heavy)
                .foregroundStyle(.white)
                .scaleEffect(selected ? 1 : 0.5)
                .opacity(selected ? 1 : 0)
        }
        .frame(width: 26, height: 26)
        .animation(Motion.bouncy, value: selected)
        .accessibilityHidden(true)
    }
}

/// Small grey section header for grouped multi-select questions.
struct ChoiceSectionHeader: View {
    let title: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(LocalizedStringKey(title))
            .appFont(13, .bold)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Runs `action` after `delay` seconds (single-choice auto-advance: 0.35s).
@MainActor
func autoAdvance(after delay: Double = 0.35, _ action: @escaping () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        action()
    }
}
