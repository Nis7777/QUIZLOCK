import SwiftUI

// MARK: - Chapter 2: The chat

/// 2.1 "{name}, we need to talk." then a fake notification banner slides down. Tapping it opens the chat.
struct TalkIntroView: View {
    let onOpenChat: () -> Void
    @Environment(AppModel.self) private var model
    @State private var showBanner = false
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 18) {
                Spacer(minLength: 40)
                MascotSlot(expression: .worried, size: 220)
                Text("\(model.friendlyName), we need to talk.")
                    .appFont(32, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppear(1)
                Spacer(minLength: 40)
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showBanner {
                VStack(spacing: 14) {
                    Button(action: onOpenChat) { banner }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("onboarding.chatBanner")
                        .accessibilityHint(Text("Opens the chat with Lockie"))
                    Text("↑ Lockie sent you a message, tap it")
                        .appFont(15, .semibold)
                        .foregroundStyle(Color.brandDeep)
                        .offset(y: bob ? -4 : 2)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: showBanner) { _, now in now }
        .task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 300_000_000 : 1_300_000_000)
            withAnimation(Motion.respecting(reduceMotion, Motion.bouncy)) { showBanner = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bob = true }
            }
        }
    }

    /// iOS-style notification banner (frosted, radius 22).
    private var banner: some View {
        HStack(spacing: 12) {
            LockieView(expression: .happy, size: 40, breathing: false)
                .frame(width: 44, height: 44)
                .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Lockie").appFont(15, .bold).foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("now").appFont(13).foregroundStyle(Color.textSecondary)
                }
                Text("hey \(model.friendlyName), got a sec?")
                    .appFont(15)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
    }
}

/// 2.2 The chat itself (script from ONBOARDING_V3 §2).
struct LockieChatView: View {
    let onBack: () -> Void
    let onDone: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        ChatView(segments: Self.script(name: model.friendlyName), onBack: onBack, onSkip: onDone, onFinish: onDone)
    }

    static func script(name: String) -> [ChatSegment] {
        func t(_ s: String.LocalizationValue) -> ChatLine { .text(String(localized: s)) }
        return [
            ChatSegment(lines: { _ in [
                t("hey \(name) 👋"),
                t("quick question"),
                t("how many times did you open your phone today without even thinking?"),
            ] }, replies: [
                ChatReply(id: "tooMany", text: "too many"),
                ChatReply(id: "dontAsk", text: "don't ask"),
                ChatReply(id: "fine", text: "i'm fine actually"),
            ]),
            ChatSegment(lines: { previous in [
                previous == "fine" ? t("respect. but let's check anyway 😏") : t("yeah… same story for most people"),
                t("it goes like this:"),
                t("you unlock your phone"),
                t("you open one app 'for a second'"),
                t("40 minutes disappear"),
                t("and you feel kinda empty after"),
            ] }, replies: [
                ChatReply(id: "me", text: "ok that's me"),
                ChatReply(id: "exposing", text: "stop exposing me"),
            ]),
            ChatSegment(lines: { _ in [
                t("it's not your fault tho"),
                .appGrid,
                t("these apps are built by **thousands** of engineers"),
                t("their whole job is keeping you scrolling"),
                t("!!willpower vs a billion-dollar algorithm?!!"),
                t("not a fair fight"),
            ] }, replies: [
                ChatReply(id: "what", text: "so what do i do"),
                ChatReply(id: "unfair", text: "that's unfair"),
            ]),
            ChatSegment(lines: { _ in [
                t("that's where i come in 🧩"),
                t("i lock the apps that steal your time"),
                t("want back in? solve a quick puzzle first"),
                t("chess, sudoku, math or a word game"),
                t("by the time you've solved it, you usually don't even want the app anymore"),
                t("and even if you do, your brain got a workout first 💪"),
            ] }, replies: [
                ChatReply(id: "smart", text: "wait that's smart"),
                ChatReply(id: "show", text: "show me"),
            ]),
            ChatSegment(lines: { _ in [
                t("let me show you how it works"),
            ] }, replies: [
                ChatReply(id: "go", text: "let's go"),
            ]),
        ]
    }
}
