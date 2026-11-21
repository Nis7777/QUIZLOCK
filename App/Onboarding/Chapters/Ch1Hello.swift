import SwiftUI

// MARK: - Chapter 1: Hello

/// 1.1 Hero: coral sky, drifting clouds, a big waving Lockie, the wordmark and "Get started".
struct HeroView: View {
    let onStart: () -> Void
    @Environment(\.openURL) private var openURL

    /// Real App Store numbers only. Left empty until the app has public ratings (no fake social proof).
    static let appStoreRatingText: String? = nil

    var body: some View {
        ZStack {
            CoralSky()
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
                    .staggeredAppear(1)
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

/// 1.3 "What should I call you?" — autofocused, underlined field.
struct AskNameView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @FocusState private var focused: Bool

    private var hasLetter: Bool { name.contains { $0.isLetter } }

    var body: some View {
        OnboardingPage(title: "What should I call you?") {
            VStack(spacing: 6) {
                TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Color.textSecondary.opacity(0.6)))
                    .appFont(30, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit { if hasLetter { save() } }
                    .accessibilityIdentifier("onboarding.name")
                Rectangle()
                    .fill(focused ? Color.brand : Color.textSecondary.opacity(0.3))
                    .frame(height: 2)
                    .animation(Motion.snappy, value: focused)
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .staggeredAppear(1)
        } footer: {
            VStack(spacing: 4) {
                ChunkyButton(title: "Continue", isEnabled: hasLetter, action: save)
                    .accessibilityIdentifier("onboarding.continue")
                OnboardingLink(title: "Skip") {
                    model.updateProfile { $0.name = "" }
                    onContinue()
                }
            }
        }
        .onAppear {
            name = model.profile.name
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                focused = true
            }
        }
    }

    private func save() {
        focused = false
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.updateProfile { $0.name = String(trimmed.prefix(30)) }
        onContinue()
    }
}

extension AppModel {
    /// "{name}" for copy; falls back to "friend" when they skipped the name.
    var friendlyName: String {
        let n = profile.trimmedName
        return n.isEmpty ? String(localized: "friend") : n
    }
}
