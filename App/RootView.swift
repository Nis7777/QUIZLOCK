import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The launch intro (LaunchIntroView) plays once per cold launch; UI tests and screenshots skip it.
    @State private var intro: IntroStage = RootView.skipsIntro ? .done : .playing

    private enum IntroStage { case playing, revealing, done }
    private static var skipsIntro: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-uiTestFreshInstall") || args.contains("-demoData")
    }

    var body: some View {
        ZStack {
            // The app's screens come in only as the intro zooms away, so their own entrance
            // animations (onboarding's staggered titles, the dashboard cards) play where you can see them.
            if intro != .playing {
                Group {
                    switch model.phase {
                    case .splash, .onboarding:
                        OnboardingFlowView()
                            .transition(.opacity)
                    case .main:
                        MainTabView()
                            .transition(.opacity)
                    }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            if model.phase == .main && model.welcomeBack {
                WelcomeBackView()
                    .transition(.opacity)
                    .zIndex(11)
            } else if model.phase == .main && !model.isAuthorized && !model.reconnectSnoozed {
                ReconnectView()
                    .transition(.opacity)
                    .zIndex(10)
            }
            if intro != .done {
                LaunchIntroView(
                    onReveal: { withAnimation(Motion.smooth) { intro = .revealing } },
                    onFinished: { intro = .done }
                )
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
        .fullScreenCover(isPresented: unlockPresented) {
            UnlockFlowView()
                .environment(model)
                .environment(\.palette, model.palette)
        }
        .background(
            Color.clear
                .fullScreenCover(isPresented: paywallPresented) {
                    PaywallView()
                        .environment(model)
                        .environment(\.palette, model.palette)
                }
        )
        .background(
            Color.clear
                .fullScreenCover(item: practiceGame) { game in
                    PracticeView(game: game)
                        .environment(model)
                        .environment(\.palette, model.palette)
                        .appToast()
                }
        )
        .background(
            Color.clear
                .fullScreenCover(isPresented: Binding(get: { model.strictChallengeActive },
                                                      set: { if !$0 { model.strictChallengeCancelled() } })) {
                    StrictChallengeView()
                        .environment(model)
                        .environment(\.palette, model.palette)
                        .appToast()
                }
        )
        .background(
            Color.clear
                .fullScreenCover(isPresented: Binding(get: { model.dailyPuzzleOpen }, set: { model.dailyPuzzleOpen = $0 })) {
                    DailyPuzzleView()
                        .environment(model)
                        .environment(\.palette, model.palette)
                        .appToast()
                }
        )
        .background(
            Color.clear
                .fullScreenCover(isPresented: Binding(get: { model.milestone != nil && model.phase == .main },
                                                      set: { if !$0 { model.milestoneCelebrated() } })) {
                    MilestoneView(days: model.milestone ?? 3) { model.milestoneCelebrated() }
                        .environment(\.palette, model.palette)
                }
        )
        .alert(progressionTitle, isPresented: Binding(get: { model.progressionOffer != nil },
                                                      set: { if !$0 { model.progressionOffer = nil } })) {
            Button("Level up") { model.acceptProgression() }
            Button("Not now", role: .cancel) { model.progressionOffer = nil }
        } message: {
            Text("You've solved 5 in a row quickly. Want to try a harder level?")
        }
        .appToast()
        .task {
            model.bootstrap()
            #if DEBUG
            DemoData.route(model)
            #endif
            // Authorization status can lag right after launch; check again shortly.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            model.refreshFromStore()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { model.refreshFromStore() }
        }
    }

    private var progressionTitle: String {
        guard let game = model.progressionOffer, let next = model.nextDifficulty(for: game) else { return "" }
        return String(localized: "Ready for \(next.localizedName)?")
    }

    private var unlockPresented: Binding<Bool> {
        Binding(get: { model.unlockSession != nil || model.unlockResult != nil },
                set: { if !$0 { model.closeUnlockFlow() } })
    }

    private var paywallPresented: Binding<Bool> {
        Binding(get: { model.paywallReason != nil && model.paywallReason != .unlockLimit },
                set: { if !$0 { model.closePaywall() } })
    }

    private var practiceGame: Binding<GameID?> {
        Binding(get: { model.practiceGame }, set: { model.practiceGame = $0 })
    }
}

// MARK: - Launch intro

/// The "opening the app" moment, played once per cold launch.
///
/// iOS's static launch screen shows Lockie waving (`LaunchMascot`: the wave art at 180pt, centred on
/// `LaunchBackground`). This starts on exactly that frame, with the same art at the same size and
/// place, so there's no jump. Then "Lockie" pops in under him, he does a happy hop (light haptic on
/// take-off), and both lean in toward you and fade while the background fades to reveal the app.
/// About 1.45s. With Reduce Motion on, it's a plain 0.25s fade.
struct LaunchIntroView: View {
    /// Called as the zoom starts, so the app can bring its content in underneath.
    var onReveal: () -> Void
    /// Called when the intro is fully gone.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wordmarkShown = false
    @State private var groupScale: CGFloat = 1
    @State private var groupOpacity = 1.0
    @State private var backgroundOpacity = 1.0
    @State private var takeOff = false

    /// The launch image's size in points (LaunchMascot.imageset is 180pt).
    private static let mascotSize: CGFloat = 180

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(backgroundOpacity)
            ZStack {
                // The hop is MascotView's own entrance (`.happy`, keeping the wave art), 0.3s in.
                MascotView(expression: .wave, size: Self.mascotSize, entrance: .happy, popsIn: false)
                Text(verbatim: Brand.appName)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Color.brand)
                    .scaleEffect(wordmarkShown ? 1 : 0.85)
                    .opacity(wordmarkShown ? 1 : 0)
                    .offset(y: Self.mascotSize / 2 + 34)
            }
            .scaleEffect(groupScale)
            .opacity(groupOpacity)
        }
        // Centred on the whole screen, like the system launch screen (it ignores the safe area).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: takeOff)
        .task { await play() }
    }

    private func pause(_ ms: Int) async {
        try? await Task.sleep(for: .milliseconds(ms))
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            await pause(150)
            onReveal()
            withAnimation(.easeOut(duration: 0.25)) {
                groupOpacity = 0
                backgroundOpacity = 0
            }
            await pause(260)
            onFinished()
            return
        }

        // 1. "Lockie" pops in under him.
        await pause(150)
        withAnimation(Motion.bouncy) { wordmarkShown = true }

        // 2. The hop leaves the ground at ~0.43s (0.3s entrance delay + 130ms crouch) and lands at ~0.81s.
        await pause(280)
        takeOff.toggle()
        await pause(470)

        // 3. A small squeeze, then both lean in toward you and fade as the app comes in underneath.
        withAnimation(Motion.snappy) { groupScale = 0.96 }
        await pause(110)
        onReveal()
        withAnimation(.spring(response: 0.45, dampingFraction: 1)) {
            groupScale = 1.6
            groupOpacity = 0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 1).delay(0.05)) {
            backgroundOpacity = 0
        }
        await pause(450)
        onFinished()
    }
}

#Preview("Launch intro") {
    LaunchIntroView(onReveal: {}, onFinished: {})
}
