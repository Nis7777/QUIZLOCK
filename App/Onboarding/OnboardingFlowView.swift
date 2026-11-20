import Observation
import SwiftUI

/// Onboarding screens, in order. Stored by name, so killing the app mid-onboarding resumes here.
enum OnboardingStep: String, CaseIterable {
    case splash, welcome, pickGame, howItWorks, practice, unlocked, enjoyFeed
    // Personalised questions
    case askName, askAge, askScreenTime, askWasters, askGoal, askFeelings, askWhen
    case calculating, realityCheck, plan, commitment, rating
    // Setup
    case screenTimeIntro, connect, lockApps, reward, notifications

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Screens that use the thin coral progress bar.
    static let quizSteps: [OnboardingStep] = [.askName, .askAge, .askScreenTime, .askWasters, .askGoal, .askFeelings,
                                              .askWhen, .calculating, .realityCheck, .plan, .commitment, .rating]

    var quizProgress: Double {
        guard let i = Self.quizSteps.firstIndex(of: self) else { return 0 }
        return Double(i + 1) / Double(Self.quizSteps.count)
    }

    /// Screens that the back button skips over.
    var skippedOnBack: Bool { [.splash, .howItWorks, .practice, .calculating].contains(self) }

    /// Where to resume if the app was killed on this screen.
    var resumeStep: OnboardingStep {
        switch self {
        case .splash: return .welcome
        case .howItWorks, .practice: return .pickGame
        case .calculating: return .realityCheck
        default: return self
        }
    }
}

@Observable
@MainActor
final class OnboardingModel {
    var step: OnboardingStep = .splash
    var forward = true
    @ObservationIgnored var onStepChange: (OnboardingStep) -> Void = { _ in }

    func restore(_ saved: String?) {
        guard let saved, let s = OnboardingStep(rawValue: saved) else { return }
        step = s.resumeStep
    }

    func go(_ next: OnboardingStep) {
        Haptics.tap()
        forward = next.index >= step.index
        withAnimation(.easeInOut(duration: 0.38)) { step = next }
        onStepChange(next)
    }

    func back() {
        var i = step.index - 1
        while i > 0, OnboardingStep.allCases[i].skippedOnBack { i -= 1 }
        guard i >= 1 else { return }
        let previous = OnboardingStep.allCases[i]
        Haptics.tap()
        forward = false
        withAnimation(.easeInOut(duration: 0.38)) { step = previous }
        onStepChange(previous)
    }
}

/// First-launch onboarding. Every transition is a push-style slide + fade (fades with Reduce Motion).
struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model
    @State private var flow = OnboardingModel()
    @State private var restored = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            screen
                .id(flow.step)
                .transition(transition)
        }
        .screenBackground()
        .onAppear {
            if !restored {
                restored = true
                flow.restore(model.settings.onboardingStep)
                flow.onStepChange = { step in model.updateSettings { $0.onboardingStep = step.rawValue } }
            }
            if model.phase == .splash { model.phase = .onboarding }
        }
    }

    @ViewBuilder
    private var screen: some View {
        let back = { flow.back() }
        let progress = flow.step.quizProgress
        switch flow.step {
        case .splash:
            SplashView { flow.go(.welcome) }
        case .welcome:
            WelcomeView { flow.go(.pickGame) }
        case .pickGame:
            PickGameView(onBack: back) { game in
                model.updateSettings { $0.practiceGame = game }
                flow.go(.howItWorks)
            }
        case .howItWorks:
            HowItWorksView(game: model.settings.practiceGame, onBack: back) { flow.go(.practice) }
        case .practice:
            OnboardingPracticeView(game: model.settings.practiceGame, onClose: back) { flow.go(.unlocked) }
        case .unlocked:
            UnlockedDemoView(onBack: back) { flow.go(.enjoyFeed) }
        case .enjoyFeed:
            EnjoyFeedView { flow.go(.askName) }
        case .askName:
            NameQuestionView(progress: progress, onBack: back) { flow.go(.askAge) }
        case .askAge:
            AgeQuestionView(progress: progress, onBack: back) { flow.go(.askScreenTime) }
        case .askScreenTime:
            ScreenTimeQuestionView(progress: progress, onBack: back) { flow.go(.askWasters) }
        case .askWasters:
            WastersQuestionView(progress: progress, onBack: back) { flow.go(.askGoal) }
        case .askGoal:
            GoalQuestionView(progress: progress, onBack: back) { flow.go(.askFeelings) }
        case .askFeelings:
            FeelingsQuestionView(progress: progress, onBack: back) { flow.go(.askWhen) }
        case .askWhen:
            WhenQuestionView(progress: progress, onBack: back) { flow.go(.calculating) }
        case .calculating:
            CalculatingView(progress: progress) { flow.go(.realityCheck) }
        case .realityCheck:
            RealityCheckView(progress: progress, onBack: back) { flow.go(.plan) }
        case .plan:
            PlanView(progress: progress, onBack: back) { flow.go(.commitment) }
        case .commitment:
            CommitmentView(progress: progress, onBack: back) { flow.go(.rating) }
        case .rating:
            RatingRequestView(progress: progress, onBack: back) { flow.go(.screenTimeIntro) }
        case .screenTimeIntro:
            ScreenTimeIntroView(onBack: back) { flow.go(.connect) }
        case .connect:
            ConnectScreenTimeView(onBack: back) { flow.go(.lockApps) }
        case .lockApps:
            LockAppsView(onBack: back) { flow.go(.reward) }
        case .reward:
            RewardView(onBack: back, onChangeApps: back) {
                model.turnOnLocksFromOnboarding()
                flow.go(.notifications)
            }
        case .notifications:
            NotificationsExplainerView(onBack: back) {
                Task {
                    await model.requestNotificationPermission()
                    model.finishOnboarding()
                }
            }
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        switch (flow.step, flow.forward) {
        case (.welcome, true): return .opacity
        // The phone mockup zooms and fades into the full-screen practice puzzle.
        case (.practice, true): return .asymmetric(insertion: .scale(scale: 0.55).combined(with: .opacity), removal: .opacity)
        default: return .push(forward: flow.forward)
        }
    }
}
