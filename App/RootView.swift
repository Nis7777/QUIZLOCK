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
        .environment(\.launchIntroCovering, intro != .done)
        // The intro sits above everything and knows where the header's Lockie and title are, so it can
        // fly its own into exactly that spot.
        .overlayPreferenceValue(LaunchIntroTargetKey.self) { target in
            if intro != .done {
                GeometryReader { proxy in
                    LaunchIntroView(
                        screen: proxy.size,
                        mascotTarget: target.mascot.map { proxy[$0] },
                        wordTarget: target.word.map { proxy[$0] },
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

/// Where the header's Lockie and title are (reported by `Wordmark`), so the intro can land on them.
struct LaunchIntroTarget {
    var mascot: Anchor<CGRect>?
    var word: Anchor<CGRect>?
}

struct LaunchIntroTargetKey: PreferenceKey {
    static let defaultValue = LaunchIntroTarget()
    static func reduce(value: inout LaunchIntroTarget, nextValue: () -> LaunchIntroTarget) {
        let next = nextValue()
        value.mascot = value.mascot ?? next.mascot
        value.word = value.word ?? next.word
    }
}

private struct LaunchIntroCoveringKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while the launch intro is still on screen.
    var launchIntroCovering: Bool {
        get { self[LaunchIntroCoveringKey.self] }
        set { self[LaunchIntroCoveringKey.self] = newValue }
    }
}

/// The "opening the app" moment, once per cold launch (~1.4s).
///
/// 1. It starts on exactly the system launch screen: Lockie waving (`LaunchMascot`, 180pt, centred).
/// 2. "Lockie" writes itself on under him, left to right, rising 10pt.
/// 3. He does one happy hop: crouch, stretch, jump, squash on landing (light haptic on take-off).
/// 4. The app comes in underneath and Lockie + his name fly up and shrink into the header's Lockie and
///    title (same art, size, font and place), while the background fades. They land as the header, so
///    nothing is left fading over the app. With no header yet (first launch, onboarding) they rise and
///    fade instead.
/// Transforms and opacity only; Lockie is a still image here (no per-frame redraws). Reduce Motion: a fade.
struct LaunchIntroView: View {
    let screen: CGSize
    let mascotTarget: CGRect?
    let wordTarget: CGRect?
    var onReveal: () -> Void
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let mascotSize: CGFloat = 180    // the launch image's size
    private static let wordSize: CGFloat = 40
    private static let wordGap: CGFloat = 34          // title centre below Lockie's bottom edge

    @State private var art = MascotExpression.wave
    @State private var writeOn: CGFloat = 0
    @State private var wordRise: CGFloat = 10
    @State private var hopTick = 0
    @State private var takeOff = false
    @State private var mascotCenter: CGPoint?
    @State private var mascotScale: CGFloat = 1
    @State private var wordCenter: CGPoint?
    @State private var wordScale: CGFloat = 1
    @State private var groupOpacity: Double = 1
    @State private var groupLift: CGFloat = 0
    @State private var backgroundOpacity: Double = 1
    @State private var measuredWord: CGSize = .zero
    /// The latest header positions (props are captured once by `.task`, these stay current).
    @State private var liveMascotTarget: CGRect?
    @State private var liveWordTarget: CGRect?

    private var startMascot: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }
    private var startWord: CGPoint {
        CGPoint(x: screen.width / 2, y: screen.height / 2 + Self.mascotSize / 2 + Self.wordGap)
    }

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(backgroundOpacity)
            MascotView(expression: art, size: Self.mascotSize, isLive: false, popsIn: false)
                .keyframeAnimator(initialValue: Hop(), trigger: hopTick) { view, hop in
                    view.scaleEffect(x: hop.sx, y: hop.sy, anchor: .bottom).offset(y: hop.y)
                } keyframes: { _ in
                    KeyframeTrack(\.sy) {
                        CubicKeyframe(0.9, duration: 0.12)      // crouch
                        CubicKeyframe(1.07, duration: 0.1)      // stretch off the ground
                        CubicKeyframe(1.0, duration: 0.2)       // round at the top
                        CubicKeyframe(0.92, duration: 0.08)     // squash on landing
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                    KeyframeTrack(\.sx) {
                        CubicKeyframe(1.06, duration: 0.12)
                        CubicKeyframe(0.96, duration: 0.1)
                        CubicKeyframe(1.0, duration: 0.2)
                        CubicKeyframe(1.05, duration: 0.08)
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                    KeyframeTrack(\.y) {
                        LinearKeyframe(0, duration: 0.12)
                        CubicKeyframe(-30, duration: 0.2)       // up, slowing at the top
                        CubicKeyframe(0, duration: 0.18)        // down, speeding up
                        LinearKeyframe(0, duration: 0.3)
                    }
                }
                .scaleEffect(mascotScale)
                .position(mascotCenter ?? startMascot)
            Text(verbatim: Brand.appName)
                .font(.system(size: Self.wordSize, weight: .black, design: .rounded))
                .tracking(-0.5 * Self.wordSize / 34)
                .foregroundStyle(Color.brand)
                .lineLimit(1)
                .fixedSize()   // always the whole word (it used to be cut to "Loc…")
                .background(GeometryReader { g in Color.clear.preference(key: WordSizeKey.self, value: g.size) })
                .mask(alignment: .leading) {
                    Rectangle().scaleEffect(x: writeOn, y: 1, anchor: .leading)
                }
                .offset(y: wordRise)
                .scaleEffect(wordScale)
                .position(wordCenter ?? startWord)
        }
        .opacity(groupOpacity)
        .offset(y: groupLift)
        .frame(width: screen.width, height: screen.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: takeOff)
        .onPreferenceChange(WordSizeKey.self) { measuredWord = $0 }
        .onAppear {
            liveMascotTarget = mascotTarget
            liveWordTarget = wordTarget
        }
        .onChange(of: mascotTarget) { _, new in liveMascotTarget = new }
        .onChange(of: wordTarget) { _, new in liveWordTarget = new }
        .task { await play() }
    }

    private struct Hop {
        var sx: CGFloat = 1
        var sy: CGFloat = 1
        var y: CGFloat = 0
    }

    private struct WordSizeKey: PreferenceKey {
        static let defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
    }

    private func pause(_ ms: Int) async {
        try? await Task.sleep(for: .milliseconds(ms))
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            writeOn = 1
            wordRise = 0
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

        // A beat on the launch screen, so the hand-off from iOS is invisible.
        await pause(150)
        // 1. "Lockie" writes itself on.
        withAnimation(.easeOut(duration: 0.45)) { writeOn = 1 }
        withAnimation(Motion.smooth) { wordRise = 0 }
        // 2. One happy hop (keyframes above); the haptic lands with the take-off.
        await pause(150)
        hopTick += 1
        await pause(130)
        takeOff.toggle()
        await pause(470)
        // 3. The app comes in underneath; give it a frame to report where the header is.
        onReveal()
        await pause(60)
        if let m = liveMascotTarget, let w = liveWordTarget, measuredWord.height > 0 {
            // 4. Fly into the header: same art, shrink to its size, land on its spot.
            art = .happy
            withAnimation(Motion.mascot) {
                mascotCenter = CGPoint(x: m.midX, y: m.midY)
                mascotScale = m.width / Self.mascotSize
                wordCenter = CGPoint(x: w.midX, y: w.midY)
                wordScale = w.height / measuredWord.height
            }
            withAnimation(.easeInOut(duration: 0.35)) { backgroundOpacity = 0 }
            await pause(560)
        } else {
            // No header on screen (onboarding): rise a little and fade.
            withAnimation(.easeOut(duration: 0.3)) {
                groupOpacity = 0
                groupLift = -16
            }
            withAnimation(.easeInOut(duration: 0.35)) { backgroundOpacity = 0 }
            await pause(380)
        }
        onFinished()
    }
}

#Preview("Launch intro") {
    GeometryReader { proxy in
        LaunchIntroView(screen: proxy.size, mascotTarget: nil, wordTarget: nil, onReveal: {}, onFinished: {})
    }
}
