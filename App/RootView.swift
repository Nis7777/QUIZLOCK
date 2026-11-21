import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch model.phase {
            case .splash, .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
            if model.phase == .main && !model.isAuthorized && !model.reconnectSnoozed {
                ReconnectView()
                    .transition(.opacity)
                    .zIndex(10)
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
