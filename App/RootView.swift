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
/// It starts pixel-for-pixel where iOS's static launch screen ends (the same `LaunchBackground`
/// colour and the same logo, split into three aligned layers of `LaunchLogo`), so there's no jump.
/// Then: the padlock gets two quick test wiggles, the shackle clicks open (light haptic), and the
/// logo zooms through the open lock while the background fades to reveal the app. About 1.1s.
/// With Reduce Motion on, it's a plain 0.25s fade.
struct LaunchIntroView: View {
    /// Called as the zoom starts, so the app can bring its content in underneath.
    var onReveal: () -> Void
    /// Called when the intro is fully gone.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var jiggle = 0.0
    @State private var shackleLift: CGFloat = 0
    @State private var shackleAngle = 0.0
    @State private var logoScale: CGFloat = 1
    @State private var logoOpacity = 1.0
    @State private var backgroundOpacity = 1.0
    @State private var unlockClick = false

    // Points inside the logo image, as fractions of its size (measured on LaunchLogo@3x.png, 577×166).
    /// Bottom of the shackle's right leg, where it meets the lock body: the shackle swings open around it.
    private static let shackleHinge = UnitPoint(x: 0.1265, y: 0.4398)
    /// Bottom centre of the lock body: the lock wiggles around it.
    private static let lockBase = UnitPoint(x: 0.10, y: 0.84)
    /// The middle of the lock: the zoom flies through here.
    private static let lockCentre = UnitPoint(x: 0.10, y: 0.64)

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(backgroundOpacity)
            ZStack {
                ZStack {
                    Image("LaunchShackle")
                        .rotationEffect(.degrees(shackleAngle), anchor: Self.shackleHinge)
                        .offset(y: -shackleLift)
                    Image("LaunchLockBody")
                }
                .rotationEffect(.degrees(jiggle), anchor: Self.lockBase)
                Image("LaunchWordmark")
            }
            .scaleEffect(logoScale, anchor: Self.lockCentre)
            .opacity(logoOpacity)
        }
        // Centred on the whole screen, like the system launch screen (it ignores the safe area).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: unlockClick)
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
                logoOpacity = 0
                backgroundOpacity = 0
            }
            await pause(260)
            onFinished()
            return
        }

        // A beat on the launch screen, so the handoff from iOS is invisible.
        await pause(120)

        // 1. Test the lock: two quick wiggles.
        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { jiggle = -7 }
        await pause(90)
        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { jiggle = 6 }
        await pause(90)
        withAnimation(Motion.snappy) { jiggle = 0 }
        await pause(60)

        // 2. Click: the shackle pops up and swings open.
        unlockClick.toggle()
        withAnimation(Motion.bouncy) {
            shackleLift = 6
            shackleAngle = -22
        }
        await pause(300)

        // 3. A small squeeze, then zoom through the open lock into the app.
        withAnimation(Motion.snappy) { logoScale = 0.94 }
        await pause(110)
        onReveal()
        withAnimation(.spring(response: 0.42, dampingFraction: 1)) {
            logoScale = 6
            logoOpacity = 0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 1).delay(0.06)) {
            backgroundOpacity = 0
        }
        await pause(420)
        onFinished()
    }
}

#Preview("Launch intro") {
    LaunchIntroView(onReveal: {}, onFinished: {})
}
