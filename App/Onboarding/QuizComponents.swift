import SwiftUI

/// Thin coral progress bar for the question screens.
struct QuizProgressBar: View {
    let progress: Double
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.fieldFill)
                Capsule().fill(palette.accent).frame(width: max(6, geo.size.width * progress))
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.35), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// Layout shared by the question screens: back button + progress bar, big title, content, optional footer.
struct QuizScaffold<Content: View, Footer: View>: View {
    let progress: Double
    let title: String
    var subtitle: String?
    let onBack: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                BackButton(action: onBack)
                QuizProgressBar(progress: progress)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(title))
                        .appFont(32, .bold)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .appFont(18)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content()
                        .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            footer()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .screenBackground()
    }
}

extension QuizScaffold where Footer == EmptyView {
    init(progress: Double, title: String, subtitle: String? = nil, onBack: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(progress: progress, title: title, subtitle: subtitle, onBack: onBack, content: content, footer: { EmptyView() })
    }
}

/// White answer card that turns coral-outlined with a check when selected.
struct ChoiceCard: View {
    let title: String
    var symbol: String?
    let selected: Bool
    var multi = false
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { action() }
        } label: {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .appFont(20, .semibold)
                        .foregroundStyle(palette.accent)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                }
                Text(LocalizedStringKey(title))
                    .appFont(18, .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if multi {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .appFont(22)
                        .foregroundStyle(selected ? palette.accent : Color(hex: 0xC7C7CC))
                } else {
                    RadioMark(isSelected: selected)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? palette.accent : palette.separator, lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Square tile for the multi-select grid.
struct ChoiceTile: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { action() }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .appFont(28, .semibold)
                    .foregroundStyle(selected ? palette.accent : palette.textSecondary)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(title))
                    .appFont(15, .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? palette.accent : palette.separator, lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .appFont(18)
                        .foregroundStyle(palette.accent)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Runs `action` 0.3s after a single-choice tap.
@MainActor
func autoAdvance(_ action: @escaping () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 300_000_000)
        action()
    }
}
