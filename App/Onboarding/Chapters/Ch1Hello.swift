import SwiftUI

// MARK: - Chapter 1: Hello

/// 1.1 Hero: a big waving Lockie, the wordmark and "Get started", over the coral sky and drifting clouds
/// (drawn by OnboardingFlowView behind every screen, so they can cross-fade out when this screen leaves).
struct HeroView: View {
    let onStart: () -> Void
    @Environment(\.openURL) private var openURL

    /// Real App Store numbers only. Left empty until the app has public ratings (no fake social proof).
    static let appStoreRatingText: String? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                MascotSlot(expression: .wave, size: 250)
                    .staggeredAppear(0)
                VStack(spacing: 8) {
                    Text(verbatim: Brand.appName)
                        .appFont(48, .black, design: .rounded)
                        .foregroundStyle(.white)
                        .shadow(color: Color.brandDeep.opacity(0.35), radius: 10, y: 4)
                    Text("The app blocker that makes you smarter")
                        .appFont(19, .semibold)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 18)
                .padding(.horizontal, 28)
                .staggeredAppear(1)
                if let rating = Self.appStoreRatingText {
                    Text(verbatim: rating)
                        .appFont(14, .semibold)
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                }
                Spacer(minLength: 24)
                ChunkyButton(title: "Get started", style: .white, action: onStart)
                    .accessibilityIdentifier("onboarding.start")
                    .padding(.horizontal, 20)
                    .staggeredAppear(2)
                HStack(spacing: 6) {
                    Button("Terms") { openURL(Brand.termsURL) }
                    Text(verbatim: "·").accessibilityHidden(true)
                    Button("Privacy") { openURL(Brand.privacyURL) }
                }
                .appFont(13, .semibold)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 14)
                .padding(.bottom, 10)
                .staggeredAppear(3)
            }
        }
    }
}

/// 1.2 "Hey! I'm Lockie." and, after 1s, the grey aside.
struct MeetLockieView: View {
    let onContinue: () -> Void
    @State private var showAside = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingPage {
            VStack(spacing: 18) {
                MascotSlot(expression: .wave, size: 230)
                    .padding(.top, 24)
                Text("Hey! I'm Lockie.")
                    .appFont(34, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppear(0)
                Text("(the little voice telling you to put the phone down)")
                    .appFont(16)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showAside ? 1 : 0)
            }
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
        }
        .task {
            if !reduceMotion { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            withAnimation(Motion.gentle) { showAside = true }
        }
    }
}

/// 1.3 "What should I call you?" The title, field and underline arrive as ONE group, the keyboard slides
/// up with them, and typing never moves anything:
/// - the text lives in `NameDraft`, read only by the small field view, so a keystroke re-renders just
///   the field (this screen only hears when "has a letter" flips);
/// - no ScrollView (a scroll view nudges itself to keep the caret visible on every keystroke);
/// - content is pinned to the top and the buttons sit in a bottom safe-area inset, so if the keyboard
///   changes height only the buttons ride with it;
/// - no `.textContentType(.givenName)`: its QuickType name suggestions make the keyboard change height
///   while typing.
struct AskNameView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @State private var draft = NameDraft()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            NameEntryGroup(draft: draft, focused: $focused) { if draft.hasLetter { save() } }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .staggeredAppear(0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                ChunkyButton(title: "Continue", isEnabled: draft.hasLetter, action: save)
                    .accessibilityIdentifier("onboarding.continue")
                OnboardingLink(title: "Skip") {
                    focused = false
                    model.updateProfile { $0.name = "" }
                    onContinue()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .staggeredAppear(1)
        }
        .onAppear {
            draft.set(model.profile.name)
            // Straight away, so the keyboard slides up together with the content, not after it.
            focused = true
        }
    }

    private func save() {
        focused = false
        let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        model.updateProfile { $0.name = String(trimmed.prefix(30)) }
        onContinue()
    }
}

/// The name being typed. Only views that read `text` re-render on a keystroke; `hasLetter` is set only
/// when it actually flips, so the screen around the field doesn't re-render while typing.
@Observable
final class NameDraft {
    private(set) var text = ""
    private(set) var hasLetter = false

    func set(_ value: String) {
        guard value != text else { return }
        text = value
        let letter = value.contains { $0.isLetter }
        if letter != hasLetter { hasLetter = letter }
    }
}

/// Title + field + underline, laid out once. No animation is tied to the text.
private struct NameEntryGroup: View {
    let draft: NameDraft
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        // Read here so a prefilled name shows; only this small view re-renders on a keystroke.
        let current = draft.text
        VStack(spacing: 36) {
            Text("What should I call you?")
                .appFont(30, .heavy, design: .rounded)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 6) {
                TextField("", text: Binding(get: { current }, set: { draft.set($0) }), prompt: Text("Your name").foregroundStyle(Color.textSecondary.opacity(0.6)))
                    .appFont(30, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused(focused)
                    .onSubmit(onSubmit)
                    .accessibilityIdentifier("onboarding.name")
                // Coral from the start: it arrives with the group instead of changing colour on its own.
                Rectangle()
                    .fill(Color.brand)
                    .frame(height: 2)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .transaction { $0.animation = nil }   // nothing inside animates with keystrokes
    }
}

extension AppModel {
    /// "{name}" for copy; falls back to "friend" when they skipped the name.
    var friendlyName: String {
        let n = profile.trimmedName
        return n.isEmpty ? String(localized: "friend") : n
    }
}
