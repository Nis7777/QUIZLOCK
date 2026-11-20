import Observation
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case splash, welcome, pickGame, howItWorks, practice, unlocked, enjoyFeed, screenTimeIntro, connect, lockApps, reward
}

@Observable
@MainActor
final class OnboardingModel {
    var step: OnboardingStep = .splash
    var forward = true

    func go(_ next: OnboardingStep) {
        Haptics.tap()
        forward = next.rawValue >= step.rawValue
        withAnimation(.easeInOut(duration: 0.38)) { step = next }
    }

    func back() {
        let previous: OnboardingStep
        switch step {
        case .splash, .welcome: return
        case .pickGame: previous = .welcome
        case .howItWorks: previous = .pickGame
        case .practice: previous = .pickGame
        case .unlocked: previous = .pickGame
        case .enjoyFeed: previous = .unlocked
        case .screenTimeIntro: previous = .enjoyFeed
        case .connect: previous = .screenTimeIntro
        case .lockApps: previous = .connect
        case .reward: previous = .lockApps
        }
        Haptics.tap()
        forward = false
        withAnimation(.easeInOut(duration: 0.38)) { step = previous }
    }
}

/// First-launch onboarding (S01–S11). Every transition is a push-style slide + fade.
struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model
    @State private var flow = OnboardingModel()

    var body: some View {
        ZStack {
            Group {
                switch flow.step {
                case .splash:
                    SplashView { flow.go(.welcome) }
                case .welcome:
                    WelcomeView { flow.go(.pickGame) }
                case .pickGame:
                    PickGameView(onBack: { flow.back() }) { game in
                        model.updateSettings { $0.practiceGame = game }
                        flow.go(.howItWorks)
                    }
                case .howItWorks:
                    HowItWorksView(game: model.settings.practiceGame, onBack: { flow.back() }) { flow.go(.practice) }
                case .practice:
                    OnboardingPracticeView(game: model.settings.practiceGame, onClose: { flow.back() }) { flow.go(.unlocked) }
                case .unlocked:
                    UnlockedDemoView(onBack: { flow.back() }) { flow.go(.enjoyFeed) }
                case .enjoyFeed:
                    EnjoyFeedView { flow.go(.screenTimeIntro) }
                case .screenTimeIntro:
                    ScreenTimeIntroView(onBack: { flow.back() }) { flow.go(.connect) }
                case .connect:
                    ConnectScreenTimeView(onBack: { flow.back() }) { flow.go(.lockApps) }
                case .lockApps:
                    LockAppsView(onBack: { flow.back() }) { flow.go(.reward) }
                case .reward:
                    RewardView(onBack: { flow.back() }, onChangeApps: { flow.back() }) {
                        model.finishOnboarding(turnOnLocks: true)
                        model.requestNotificationPermission()
                    }
                }
            }
            .id(flow.step)
            .transition(transition)
        }
        .screenBackground()
        .onAppear {
            if model.phase == .splash { model.phase = .onboarding }
        }
    }

    private var transition: AnyTransition {
        switch (flow.step, flow.forward) {
        case (.welcome, true): return .opacity
        // The phone mockup zooms and fades into the full-screen practice puzzle.
        case (.practice, true): return .asymmetric(insertion: .scale(scale: 0.55).combined(with: .opacity), removal: .opacity)
        default: return .push(forward: flow.forward)
        }
    }
}
