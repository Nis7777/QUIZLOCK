import SafariServices
import SwiftUI
import UIKit

// MARK: - Wordmark

struct Wordmark: View {
    var size: CGFloat = 34
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: size * 0.14) {
            // Lockie himself, standing beside his name (a still picture: this header is on every tab).
            MascotView(expression: .happy, size: size * 1.35, isLive: false, popsIn: false)
                .accessibilityHidden(true)
            Text(Brand.appName)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(palette.wordmark)
                .tracking(-0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Brand.appName)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

/// Primary button: rendered as a ChunkyButton (coral face on a darker 3D edge, MOTION.md press).
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var trailingImage: String?
    var isLoading = false
    var isEnabled = true
    var shimmer = false
    let action: () -> Void

    var body: some View {
        ChunkyButton(title: title, systemImage: systemImage ?? trailingImage, isEnabled: isEnabled,
                     isLoading: isLoading, shimmer: shimmer, action: action)
    }
}

/// Kept for existing call sites; same as PressableButtonStyle (MOTION.md).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableButtonStyle().makeBody(configuration: configuration)
    }
}

struct BackButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .appFont(19, .semibold)
                .foregroundStyle(palette.textPrimary)
                .frame(width: 52, height: 52)
                .background(palette.card, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Back")
    }
}

struct CloseButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .appFont(20, .medium)
                .foregroundStyle(palette.textPrimary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Close")
    }
}

/// Small rounded pill button ("Done", "Save", "Cancel").
struct PillButton: View {
    let title: String
    var filled = true
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(LocalizedStringKey(title))
                .appFont(16, .semibold)
                .foregroundStyle(filled ? palette.onAccent : palette.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(filled ? palette.accent : palette.fieldFill, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Toggles & radios

struct PillToggle: View {
    @Binding var isOn: Bool
    var label: String = ""
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? palette.accent : (palette.isDark ? Color(hex: 0x3A3A3C) : Color.toggleOffTrack))
                Capsule()
                    .fill(Color.white)
                    .frame(width: 36, height: 28)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    .padding(4)
            }
            .frame(width: 70, height: 36)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(label, isOn: $isOn)
        }
    }
}

struct RadioMark: View {
    let isSelected: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(palette.accent)
                Image(systemName: "checkmark")
                    .appFont(13, .heavy)
                    .foregroundStyle(palette.onAccent)
            } else {
                Circle().strokeBorder(Color(hex: 0xC7C7CC), lineWidth: 2)
            }
        }
        .frame(width: 28, height: 28)
        .animation(.selectionSpring, value: isSelected)
    }
}

struct PageDots: View {
    let count: Int
    let index: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? palette.accent : Color(hex: 0xC7C7CC))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
        .animation(.selectionSpring, value: index)
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}

// MARK: - Cards

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 22
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }

    /// Standard screen background.
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}

extension View {
    /// A bottom sheet exactly as tall as its content: nothing cut off at the top or bottom, no empty
    /// half-sheet, and no resizing once it's open. For sheets whose content is a fixed stack.
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}

private struct FittedSheet: ViewModifier {
    @Environment(\.palette) private var palette
    @State private var height: CGFloat = 420

    func body(content: Content) -> some View {
        content
            // Laid out at its natural height (spacers collapse), measured once, and the sheet takes it.
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { g in Color.clear.preference(key: FittedSheetHeightKey.self, value: g.size.height) })
            .onPreferenceChange(FittedSheetHeightKey.self) { h in
                if h > 0, abs(h - height) > 1 { height = h }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(height)])
            .presentationBackground(palette.bg)
    }
}

private struct FittedSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ScreenBackground: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content.background(palette.bg.ignoresSafeArea())
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
                .appFont(17, .semibold)
                .foregroundStyle(palette.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing).appFont(15).foregroundStyle(palette.textSecondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .accessibilityAddTraits(.isHeader)
    }
}

struct FooterText: View {
    let text: String
    @Environment(\.palette) private var palette
    var body: some View {
        Text(LocalizedStringKey(text))
            .appFont(14)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
    }
}

/// Icon in a tinted rounded square.
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 44
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(width: size, height: size)
            .background(palette.tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// Settings-style row: icon, title, subtitle, optional trailing value and chevron.
struct InfoRow: View {
    var icon: AnyView?
    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            if let icon { icon.frame(width: 30) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(title)).appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 8)
                    if let value {
                        Text(value).appFont(15).foregroundStyle(palette.textSecondary).lineLimit(1)
                    }
                }
                if let subtitle {
                    Text(LocalizedStringKey(subtitle)).appFont(15).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .appFont(15, .semibold)
                    .foregroundStyle(Color(hex: 0xA0A0A6))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Titles

struct ScreenTitle: View {
    let title: String
    var subtitle: String?
    var size: CGFloat = 36
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .appFont(size, .bold)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(LocalizedStringKey(subtitle))
                    .appFont(19)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Images

/// Shows a bundled image, or a neutral rounded placeholder if it's missing. Never crashes.
struct AssetImage: View {
    let name: String
    var placeholderSymbol = "photo"
    var contentMode: ContentMode = .fill

    var body: some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui).resizable().aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                Color(hex: 0xE5E5EA)
                Image(systemName: placeholderSymbol)
                    .appFont(34, .medium)
                    .foregroundStyle(Color(hex: 0x8E8E93))
            }
        }
    }
}

// MARK: - Toast & shake

/// Shows `AppModel.toast` at the top of the screen.
struct AppToastModifier: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let text = model.toast {
                Toast(text: text)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func appToast() -> some View { modifier(AppToastModifier()) }
}

struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .appFont(16, .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 9
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 6), y: 0))
    }
}

extension View {
    func shake(_ trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Safari

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Color.brand)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension View {
    /// Presents an in-app Safari sheet while `url` is non-nil.
    func safariSheet(_ url: Binding<URL?>) -> some View {
        sheet(isPresented: Binding(get: { url.wrappedValue != nil },
                                   set: { if !$0 { url.wrappedValue = nil } })) {
            if let u = url.wrappedValue {
                SafariView(url: u).ignoresSafeArea()
            }
        }
    }
}

/// "By continuing, you agree to our Terms of Service and Privacy Policy" with tappable links.
struct LegalLinksText: View {
    var prefix = String(localized: "By continuing, you agree to our ")
    @Binding var openURL: URL?
    @Environment(\.palette) private var palette

    var body: some View {
        Text(attributed)
            .appFont(14)
            .multilineTextAlignment(.center)
            .tint(palette.accentText)
            .environment(\.openURL, OpenURLAction { url in
                openURL = url
                return .handled
            })
    }

    private var attributed: AttributedString {
        var s = AttributedString(prefix)
        s.foregroundColor = palette.textSecondary
        var terms = AttributedString(localized: "Terms of Use")
        terms.foregroundColor = palette.accentText
        terms.link = Brand.termsURL
        var and = AttributedString(localized: " and ")
        and.foregroundColor = palette.textSecondary
        var privacy = AttributedString(localized: "Privacy Policy")
        privacy.foregroundColor = palette.accentText
        privacy.link = Brand.privacyURL
        return s + terms + and + privacy
    }
}

/// A game's square icon art (game_chess…), shown whole at its natural square shape. The rounded corners
/// and transparent edges are part of the image, so there's no crop, background or extra clip shape.
struct GameIcon: View {
    let game: GameID
    let size: CGFloat

    var body: some View {
        Group {
            if let ui = UIImage(named: game.coverAsset) {
                Image(uiImage: ui).resizable().scaledToFit()
            } else {
                // Missing art only: a neutral tile with the game's symbol.
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(hex: 0xE5E5EA))
                    .overlay(Image(systemName: game.systemIcon).font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8E8E93)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
