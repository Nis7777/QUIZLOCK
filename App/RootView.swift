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
        // The intro sits above everything, full-screen, and swipes away to reveal the app.
        .overlay {
            if intro != .done {
                GeometryReader { proxy in
                    LaunchIntroView(
                        screen: proxy.size,
                        greeting: introGreeting,
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

/// The "opening the app" moment, once per cold launch (~1.5s).
///
/// 1. It starts on exactly the system launch screen: Lockie waving (`LaunchMascot`, 180pt, centred).
/// 2. "Lockie" writes itself on under him, and a speech bubble pops out of him with a hello made for this
///    person ("Morning, Dinis! ☀️", "Day 6 🔥 Let's go, Dinis!").
/// 3. He does one happy hop: crouch, stretch, jump, squash on landing (light haptic on take-off).
/// 4. The whole intro swipes up and away like a card (one smooth spring, no bounce): its corners round
///    and it casts a soft shadow as it lifts, revealing the app underneath.
/// Transforms and opacity only; Lockie is a still image here. Reduce Motion: a fade.
struct LaunchIntroView: View {
    let screen: CGSize
    var greeting: String?
    var onReveal: () -> Void
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let mascotSize: CGFloat = 180    // the launch image's size
    private static let wordSize: CGFloat = 40
    private static let wordGap: CGFloat = 34          // title centre below Lockie's bottom edge

    @State private var writeOn: CGFloat = 0
    @State private var wordRise: CGFloat = 10
    @State private var bubbleShown = false
    @State private var hopTick = 0
    @State private var takeOff = false
    /// 0 = on screen, 1 = swiped away.
    @State private var exit: CGFloat = 0
    @State private var fade: Double = 1

    private var center: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            mascot
                .position(center)
            word
                .position(x: center.x, y: center.y + Self.mascotSize / 2 + Self.wordGap)
            if let greeting {
                GreetingBubble(text: greeting)
                    // Just above his head, popping from the tail; never wider than the screen allows.
                    .frame(maxWidth: screen.width - 48)
                    .scaleEffect(bubbleShown ? 1 : 0.4, anchor: .bottomLeading)
                    .opacity(bubbleShown ? 1 : 0)
                    .position(x: center.x + 20, y: center.y - Self.mascotSize / 2 - 18)
            }
        }
        .frame(width: screen.width, height: screen.height)
        // The swipe: a card lifting off the app.
        .clipShape(RoundedRectangle(cornerRadius: 44 * exit, style: .continuous))
        .shadow(color: .black.opacity(0.18 * Double(exit)), radius: 24, y: 10)
        .offset(y: -(screen.height + 40) * exit)
        .opacity(fade)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: takeOff)
        .task { await play() }
    }

    private var mascot: some View {
        MascotView(expression: .wave, size: Self.mascotSize, isLive: false, popsIn: false)
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
    }

    private var word: some View {
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
    }

    private struct Hop {
        var sx: CGFloat = 1
        var sy: CGFloat = 1
        var y: CGFloat = 0
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
            withAnimation(.easeOut(duration: 0.25)) { fade = 0 }
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
        await pause(470)
        // 4. Swipe away: the app comes in underneath as the intro lifts off (critically damped: smooth,
        //    no bounce).
        onReveal()
        withAnimation(.spring(response: 0.55, dampingFraction: 1)) { exit = 1 }
        await pause(520)
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
        LaunchIntroView(screen: proxy.size, greeting: "Morning, Dinis! ☀️", onReveal: {}, onFinished: {})
    }
}
