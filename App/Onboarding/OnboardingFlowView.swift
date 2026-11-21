import Observation
import SwiftUI

/// Story-mode onboarding (ONBOARDING_V3.md). Steps are stored by name so killing the app resumes here.
enum OnboardingStep: String, CaseIterable {
    // 1. Hello
    case hero, meetLockie, askName
    // 2. The chat
    case talkIntro, chat
    // 3. How it works
    case howItWorks
    // 4. Getting to know you
    case setupIntro, qSource, qHours, qApps, qFeelings, qWants, qPuzzles, qChallenge
    // 5. The turn
    case turnIntro, realityCheck, getBack, projection
    // 6. Permissions
    case connectScreenTime, reward, notifications, rating
    // 7. Commitment
    case commit, aboutTo, settingUp, planReady

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Full-bleed screens draw their own background/header (no container back button).
    var isFullBleed: Bool { [.hero, .chat, .aboutTo, .planReady].contains(self) }

    var showsBack: Bool { !isFullBleed && ![.settingUp].contains(self) }

    static let questionSteps: [OnboardingStep] = [.setupIntro, .qSource, .qHours, .qApps, .qFeelings, .qWants, .qPuzzles, .qChallenge]

    /// Thin coral progress bar: only in the question chapter.
    var questionProgress: Double? {
        guard let i = Self.questionSteps.firstIndex(of: self) else { return nil }
        return Double(i + 1) / Double(Self.questionSteps.count)
    }

    /// Steps the back button skips over.
    var skippedOnBack: Bool { [.talkIntro, .settingUp, .aboutTo].contains(self) }

    /// Where to resume after the app was killed on this step.
    var resumeStep: OnboardingStep {
        switch self {
        case .settingUp: return .planReady
        case .aboutTo: return .commit
        default: return self
        }
    }
}

@Observable
@MainActor
final class OnboardingModel {
    var step: OnboardingStep = .hero
    var forward = true
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var onStepChange: (OnboardingStep) -> Void = { _ in }

    func restore(_ saved: String?) {
        guard let saved, let s = OnboardingStep(rawValue: saved) else { return }
        step = s.resumeStep
    }

    func go(_ next: OnboardingStep) {
        forward = next.index >= step.index
        withAnimation(Motion.respecting(reduceMotion, Motion.smooth)) { step = next }
        onStepChange(next)
    }

    func next() {
        let all = OnboardingStep.allCases
        if step.index + 1 < all.count { go(all[step.index + 1]) }
    }

    func back() {
        var i = step.index - 1
        while i > 0, OnboardingStep.allCases[i].skippedOnBack { i -= 1 }
        guard i >= 0, i < step.index else { return }
        go(OnboardingStep.allCases[i])
    }
}

/// Holds the back button and progress bar (they don't re-render between steps) and the shared Lockie.
/// Only the content area changes, with a 40pt slide + fade.
struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model
    @State private var flow = OnboardingModel()
    @State private var restored = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBg.ignoresSafeArea()
            ZStack {
                screen(flow.step)
                    .id(flow.step)
                    .transition(transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !flow.step.isFullBleed { header }
            }
            .modifier(SharedMascotOverlay())
        }
        .environment(\.palette, .classic)
        .environment(\.colorScheme, .light)
        .onAppear {
            flow.reduceMotion = reduceMotion
            if !restored {
                restored = true
                flow.restore(model.settings.onboardingStep)
                flow.onStepChange = { step in model.updateSettings { $0.onboardingStep = step.rawValue } }
            }
            if model.phase == .splash { model.phase = .onboarding }
        }
    }

    // MARK: Header (back + progress)

    private var header: some View {
        HStack(spacing: 14) {
            Button { flow.back() } label: {
                Image(systemName: "arrow.left")
                    .appFont(22, .bold)
                    .foregroundStyle(Color.brand)
                    .tapTarget()
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(flow.step.showsBack ? 1 : 0)
            .disabled(!flow.step.showsBack)
            .accessibilityLabel(Text("Back"))
            if let progress = flow.step.questionProgress {
                QuizProgressBar(progress: progress)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .animation(Motion.smooth, value: flow.step.questionProgress != nil)
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Color.appBg.opacity(0.001))
    }

    // MARK: Transitions

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        switch flow.step {
        case .chat where flow.forward:
            // Zoom out of the notification banner.
            return .asymmetric(insertion: .scale(scale: 0.2, anchor: .top).combined(with: .opacity), removal: .opacity)
        case .howItWorks where flow.forward, .aboutTo, .planReady:
            return .opacity
        default:
            let dx: CGFloat = flow.forward ? 40 : -40
            return .asymmetric(insertion: .offset(x: dx).combined(with: .opacity),
                               removal: .offset(x: -dx).combined(with: .opacity))
        }
    }

    // MARK: Screens

    @ViewBuilder
    private func screen(_ step: OnboardingStep) -> some View {
        let next = { flow.next() }
        switch step {
        // 1. Hello
        case .hero: HeroView(onStart: next)
        case .meetLockie: MeetLockieView(onContinue: next)
        case .askName: AskNameView(onContinue: next)
        // 2. The chat
        case .talkIntro: TalkIntroView(onOpenChat: next)
        case .chat: LockieChatView(onBack: { flow.go(.talkIntro) }, onDone: { flow.go(.howItWorks) })
        // 3. How it works
        case .howItWorks: HowItWorksCardsView(onContinue: next)
        // 4. Getting to know you
        case .setupIntro: SetupIntroView(onContinue: next)
        case .qSource: SourceQuestion(flow: flow)
        case .qHours: HoursQuestion(flow: flow)
        case .qApps: AppsQuestion(flow: flow)
        case .qFeelings: FeelingsQuestion(flow: flow)
        case .qWants: WantsQuestion(flow: flow)
        case .qPuzzles: PuzzlesQuestion(flow: flow)
        case .qChallenge: ChallengeQuestion(flow: flow)
        // 5. The turn
        case .turnIntro: TurnIntroView(onContinue: next)
        case .realityCheck: RealityCheckView(onContinue: next)
        case .getBack: GetBackView(onContinue: next)
        case .projection: ProjectionView(onContinue: next)
        // 6. Permissions
        case .connectScreenTime: ConnectScreenTimeStepView(onContinue: next)
        case .reward:
            RewardView(onChangeApps: { flow.go(.connectScreenTime) }) {
                model.turnOnLocksFromOnboarding()
                next()
            }
        case .notifications: NotificationsStepView(onContinue: next)
        case .rating: RatingStepView(onContinue: next)
        // 7. Commitment
        case .commit: CommitView(onCommitted: next)
        case .aboutTo: AboutToView(onContinue: next)
        case .settingUp: SettingUpView(onDone: next)
        case .planReady: PlanReadyView { model.finishOnboarding() }
        }
    }
}

// MARK: - Page layout

/// Standard onboarding page: staggered title → subtitle → content, and a footer pinned at the bottom.
struct OnboardingPage<Content: View, Footer: View>: View {
    var title: String?
    var subtitle: String?
    var centered = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: centered ? .center : .leading, spacing: 12) {
                    if let title {
                        Text(LocalizedStringKey(title))
                            .appFont(30, .heavy, design: .rounded)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(centered ? .center : .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .staggeredAppear(0)
                    }
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .appFont(17)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(centered ? .center : .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .staggeredAppear(1)
                    }
                    content()
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            footer()
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .staggeredAppear(6)
        }
    }
}

extension OnboardingPage where Footer == EmptyView {
    init(title: String? = nil, subtitle: String? = nil, centered: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, centered: centered, content: content, footer: { EmptyView() })
    }
}

/// Small coral text link ("Skip", "Not now").
struct OnboardingLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .appFont(16, .semibold)
                .foregroundStyle(Color.brandDeep)
                .tapTarget()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Soft clouds drawn in SwiftUI, drifting slowly (static with Reduce Motion).
struct CloudLayer: View {
    var opacity: Double = 0.55
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    cloud(width: w * 0.55).position(x: drift(t, speed: 9, base: w * 0.2, span: w * 1.4), y: h * 0.12)
                    cloud(width: w * 0.42).position(x: drift(t, speed: 6, base: w * 0.75, span: w * 1.4), y: h * 0.24)
                    cloud(width: w * 0.6).position(x: drift(t, speed: 4, base: w * 0.45, span: w * 1.5), y: h * 0.62)
                    cloud(width: w * 0.38).position(x: drift(t, speed: 7, base: w * 0.9, span: w * 1.4), y: h * 0.8)
                }
                .opacity(opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drift(_ t: Double, speed: Double, base: CGFloat, span: CGFloat) -> CGFloat {
        let x = Double(base) + (t * speed).truncatingRemainder(dividingBy: Double(span))
        return CGFloat(x.truncatingRemainder(dividingBy: Double(span))) - span * 0.2
    }

    private func cloud(width: CGFloat) -> some View {
        ZStack {
            Ellipse().frame(width: width, height: width * 0.32)
            Circle().frame(width: width * 0.42).offset(x: -width * 0.12, y: -width * 0.12)
            Circle().frame(width: width * 0.32).offset(x: width * 0.16, y: -width * 0.08)
        }
        .foregroundStyle(.white)
        .blur(radius: 6)
    }
}

/// Peach → coral sky used by full-colour screens.
struct CoralSky: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0xFFE2D6), Color(hex: 0xFF9A78), Color(hex: 0xFF5A36)],
                       startPoint: .top, endPoint: .bottom)
            .overlay(CloudLayer(opacity: 0.5))
            .ignoresSafeArea()
    }
}
