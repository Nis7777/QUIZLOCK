import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The launch intro (LaunchIntroView) plays once per cold launch; UI tests and screenshots skip it.
    @State private var intro: IntroStage = RootView.skipsIntro ? .done : .playing

    private enum IntroStage { case playing, revealing, done }

    private static var skipsIntro: Bool {
        let args = ProcessInfo.processInfo.arguments
        // Also skipped when a puzzle is waiting: Lockie opens straight into it.
        return args.contains("-uiTestFreshInstall") || args.contains("-demoData") || PendingPuzzleNote.current() != nil
    }

    var body: some View {
        ZStack {
            // Keeps this stack full-screen even while the app is still hidden under the intro. The intro
            // measures the screen and the header from this stack; when it was empty it had almost no
            // size, so the intro's background was a small box and Lockie flew to the wrong spot.
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        // The intro sits above everything, full-screen, and swipes away to reveal the app.
        .overlay {
            if intro != .done {
                GeometryReader { proxy in
                    LaunchIntroView(
                        screen: proxy.size,
                        onReveal: { withAnimation(Motion.smooth) { intro = .revealing } },
                        onFinished: { intro = .done }
                    )
                }
                .ignoresSafeArea()
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

/// The "opening the app" moment, once per cold launch (~1.2s).
///
/// 1. It starts on exactly the system launch screen: Lockie waving (`LaunchMascot`, 180pt, centred).
/// 2. "Lockie" writes itself on under him.
/// 3. The whole intro swipes up and away, revealing the app underneath.
/// For a perfectly smooth swipe the intro is flattened into one layer (`drawingGroup`) and only its
/// position moves, on one ease-in-out curve: no per-frame corner rounding, shadows or redraws.
/// Reduce Motion: a fade.
struct LaunchIntroView: View {
    let screen: CGSize
    var onReveal: () -> Void
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let mascotSize: CGFloat = 180    // the launch image's size
    private static let wordSize: CGFloat = 40
    private static let wordGap: CGFloat = 34          // title centre below Lockie's bottom edge

    @State private var writeOn: CGFloat = 0
    @State private var wordRise: CGFloat = 10
    /// 0 = on screen, 1 = swiped away.
    @State private var exit: CGFloat = 0
    @State private var fade: Double = 1

    private var center: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            MascotView(expression: .wave, size: Self.mascotSize, isLive: false, popsIn: false)
                .position(center)
            Text(verbatim: Brand.appName)
                .font(.system(size: Self.wordSize, weight: .black, design: .rounded))
                .tracking(-0.5 * Self.wordSize / 34)
                .foregroundStyle(Color.brand)
                .lineLimit(1)
                .fixedSize()   // always the whole word
                .mask(alignment: .leading) {
                    Rectangle().scaleEffect(x: writeOn, y: 1, anchor: .leading)
                }
                .offset(y: wordRise)
                .position(x: center.x, y: center.y + Self.mascotSize / 2 + Self.wordGap)
        }
        .frame(width: screen.width, height: screen.height)
        .drawingGroup()                     // one flat layer: moving it costs nothing per frame
        .offset(y: -screen.height * exit)
        .opacity(fade)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func pause(_ ms: Int) async {
        try? await Task.sleep(for: .milliseconds(ms))
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            writeOn = 1
            wordRise = 0
            await pause(400)
            onReveal()
            withAnimation(.easeOut(duration: 0.25)) { fade = 0 }
            await pause(260)
            onFinished()
            return
        }

        // A beat on the launch screen, so the hand-off from iOS is invisible.
        await pause(120)
        // "Lockie" writes itself on.
        withAnimation(.easeOut(duration: 0.4)) { writeOn = 1 }
        withAnimation(Motion.smooth) { wordRise = 0 }
        await pause(520)
        // Swipe up and away: a gentle ease-in-out glide, with the app coming in underneath.
        onReveal()
        withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 0.6)) { exit = 1 }
        await pause(620)
        onFinished()
    }
}

#Preview("Launch intro") {
    GeometryReader { proxy in
        LaunchIntroView(screen: proxy.size, onReveal: {}, onFinished: {})
    }
}
