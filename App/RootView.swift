import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The launch intro (LaunchIntroView) plays once per cold launch; UI tests and screenshots skip it.
    @State private var intro: IntroStage = RootView.skipsIntro ? .done : .playing

    private enum IntroStage { case playing, revealing, done }

    /// Lockie's hello in the intro, made for this person: the streak when there is one, otherwise the time
    /// of day, with their name. None before onboarding (no name yet).
    private var introGreeting: String? {
        guard model.phase == .main else { return nil }
        let name = model.profile.trimmedName
        let streak = model.stats.streak()
        let hour = Calendar.current.component(.hour, from: Date())
        let who = name.isEmpty ? "" : ", \(name)"
        if streak >= 2 {
            return name.isEmpty ? String(localized: "Day \(streak) 🔥 Let's go!")
                                : String(localized: "Day \(streak) 🔥 Let's go, \(name)!")
        }
        switch hour {
        case 5..<12: return String(localized: "Morning\(who)! ☀️")
        case 12..<18: return String(localized: "Hey\(who)! 👋")
        case 18..<23: return String(localized: "Evening\(who)! 🌙")
        default: return String(localized: "Still up\(who)? 🌙")
        }
    }
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
        .environment(\.launchIntroCovering, intro != .done)
        // The intro sits above everything and knows where the header's Lockie and title are, so it can
        // fly its own into exactly that spot.
        .overlayPreferenceValue(LaunchIntroTargetKey.self) { target in
            if intro != .done {
                GeometryReader { proxy in
                    LaunchIntroView(
                        screen: proxy.size,
                        greeting: introGreeting,
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

/// The "opening the app" moment, once per cold launch (~1.55s).
///
/// 1. It starts on exactly the system launch screen: Lockie waving (`LaunchMascot`, 180pt, centred).
/// 2. "Lockie" writes itself on under him, and a speech bubble pops out of him with a hello made for this
///    person ("Morning, Dinis! ☀️", "Day 6 🔥 Let's go, Dinis!").
/// 3. He does one happy hop: crouch, stretch, jump, squash on landing (light haptic on take-off).
/// 4. The app comes in underneath; the bubble tucks away and Lockie + his name fly up and shrink into the
///    header's Lockie and title (same art, size, font, place), following the header's live position, while
///    the background fades. They land as the header. With no header (onboarding) they rise and fade.
/// Transforms and opacity only; Lockie is a still image here. Reduce Motion: a fade.
struct LaunchIntroView: View {
    let screen: CGSize
    var greeting: String?
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
    @State private var bubbleShown = false
    @State private var hopTick = 0
    @State private var takeOff = false
    @State private var flying = false
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
            mascot
            word
            if let greeting {
                GreetingBubble(text: greeting)
                    // Just above his head, popping from the tail; never wider than the screen allows.
                    .frame(maxWidth: screen.width - 48)
                    .scaleEffect(bubbleShown ? 1 : 0.4, anchor: .bottomLeading)
                    .opacity(bubbleShown ? 1 : 0)
                    .position(x: startMascot.x + 20, y: startMascot.y - Self.mascotSize / 2 - 18)
            }
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
        // If the header settles a moment later, the flight follows it instead of snapping at the end.
        .onChange(of: mascotTarget) { _, new in
            liveMascotTarget = new
            if flying, let m = new { withAnimation(Motion.mascot) { land(mascotOn: m) } }
        }
        .onChange(of: wordTarget) { _, new in
            liveWordTarget = new
            if flying, let w = new { withAnimation(Motion.mascot) { land(wordOn: w) } }
        }
        .task { await play() }
    }

    private var mascot: some View {
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
    }

    private var word: some View {
        Text(verbatim: Brand.appName)
            .font(.system(size: Self.wordSize, weight: .black, design: .rounded))
            .tracking(-0.5 * Self.wordSize / 34)
            .foregroundStyle(Color.brand)
            .lineLimit(1)
            .fixedSize()   // always the whole word
            .background(GeometryReader { g in Color.clear.preference(key: WordSizeKey.self, value: g.size) })
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: writeOn, y: 1, anchor: .leading)
            }
            .offset(y: wordRise)
            .scaleEffect(wordScale)
            .position(wordCenter ?? startWord)
    }

    private func land(mascotOn m: CGRect) {
        mascotCenter = CGPoint(x: m.midX, y: m.midY)
        mascotScale = m.width / Self.mascotSize
    }

    private func land(wordOn w: CGRect) {
        guard measuredWord.height > 0 else { return }
        wordCenter = CGPoint(x: w.midX, y: w.midY)
        wordScale = w.height / measuredWord.height
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
            bubbleShown = true
            await pause(500)
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
        await pause(120)
        // 1. "Lockie" writes itself on.
        withAnimation(.easeOut(duration: 0.4)) { writeOn = 1 }
        withAnimation(Motion.smooth) { wordRise = 0 }
        // 2. His hello pops out.
        await pause(160)
        withAnimation(Motion.bouncy) { bubbleShown = true }
        // 3. One happy hop; the haptic lands with the take-off.
        await pause(120)
        hopTick += 1
        await pause(130)
        takeOff.toggle()
        await pause(420)
        // 4. The app comes in underneath; give it a moment to report where the header is.
        onReveal()
        withAnimation(.easeIn(duration: 0.18)) { bubbleShown = false }
        await pause(80)
        if let m = liveMascotTarget, let w = liveWordTarget, measuredWord.height > 0 {
            art = .happy
            flying = true
            withAnimation(Motion.mascot) {
                land(mascotOn: m)
                land(wordOn: w)
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

/// Lockie's speech bubble: white, rounded, with a small tail at the bottom left pointing to him.
private struct GreetingBubble: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: Brand.Hex.textPrimary))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white)
                    BubbleTail().fill(.white).frame(width: 14, height: 10).offset(x: 14, y: 8)
                }
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview("Launch intro") {
    GeometryReader { proxy in
        LaunchIntroView(screen: proxy.size, greeting: "Morning, Dinis! ☀️", mascotTarget: nil, wordTarget: nil,
                        onReveal: {}, onFinished: {})
    }
}
