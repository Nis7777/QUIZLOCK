import SwiftUI

/// Full-screen unlock puzzle (S05 chrome without "PRACTICE", plus "1 of N").
struct UnlockFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var confirmEmergency = false

    var body: some View {
        ZStack {
            if let result = model.unlockResult {
                UnlockSuccessView(appName: result.appName, duration: result.duration,
                                  opensApp: result.openURL != nil) {
                    model.finishUnlockResult()
                }
                .transition(.opacity)
            } else if model.unlockSession != nil, model.needsProForUnlock {
                OutOfFreeUnlocksView(onStartTrial: { model.presentPaywall(.unlockLimit) },
                                     onClose: { model.closeUnlockFlow() })
                    .transition(.opacity)
            } else if let session = model.unlockSession {
                PuzzleChrome(game: session.current?.game ?? session.currentGame,
                             subLabel: session.current?.subLabel ?? "",
                             progress: "\(min(session.solved + 1, session.required)) of \(session.required)",
                             isPractice: false,
                             eyebrow: eyebrow(for: session),
                             onClose: { model.closeUnlockFlow() },
                             headerAccessory: AnyView(emergencyButton)) {
                    if let round = session.current {
                        PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary,
                                       onUpdate: { model.sessionRoundUpdated($0) },
                                       onFinish: { model.sessionRoundFinished($0) })
                            .id("\(session.solved)-\(round.identity)")
                            .transition(.push(forward: true))
                    } else {
                        ProgressView().tint(palette.accent)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.unlockResult)
        .screenBackground()
        .appToast()
        .fullScreenCover(isPresented: paywallBinding) {
            PaywallView()
                .environment(model)
                .environment(\.palette, model.palette)
        }
    }

    /// "UNLOCK INSTAGRAM" (or "UNLOCK YOUR APP" when the name isn't known).
    private func eyebrow(for session: UnlockSession) -> String {
        let name = session.pending.appName ?? SharedStore.tokenNames[session.pending.itemKey]
            ?? String(localized: "your app")
        return String(localized: "Unlock \(name)").uppercased()
    }

    private var emergencyButton: some View {
        Button {
            Haptics.tap()
            confirmEmergency = true
        } label: {
            Text("Emergency unlock")
                .appFont(13, .semibold)
                .foregroundStyle(palette.textSecondary)
                .underline()
                .tapTarget()
        }
        .buttonStyle(.plain)
        .disabled(model.emergencyUnlocksLeft == 0)
        .opacity(model.emergencyUnlocksLeft == 0 ? 0.4 : 1)
        .confirmationDialog("Emergency unlock", isPresented: $confirmEmergency, titleVisibility: .visible) {
            Button("Unlock for 1 minute") { model.emergencyUnlock() }
            Button("Keep solving", role: .cancel) {}
        } message: {
            Text("Opens the app for 1 minute without a puzzle. You have \(model.emergencyUnlocksLeft) of 3 left this week, and it breaks today's streak.")
        }
    }

    private var paywallBinding: Binding<Bool> {
        Binding(get: { model.paywallReason == .unlockLimit },
                set: { if !$0 { model.closePaywall() } })
    }
}

/// Shown instead of a puzzle once the free unlocks are used up (no subscription).
struct OutOfFreeUnlocksView: View {
    let onStartTrial: () -> Void
    let onClose: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CloseButton(action: onClose)
            }
            .padding(.horizontal, 12)
            Spacer(minLength: 12)
            VStack(spacing: 14) {
                MascotView(expression: .pointing, size: 150)
                    .accessibilityHidden(true)
                Text("You've used your \(Brand.freeUnlocks) free unlocks")
                    .appFont(26, .bold)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("unlock.outOfFreeUnlocks")
                Text("Keep earning unlocks with puzzles with \(Brand.subscriptionGroupName).")
                    .appFont(17)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 24, radius: 28)
            .padding(.horizontal, 20)
            Spacer()
            PrimaryButton(title: buttonTitle, action: onStartTrial)
                .accessibilityIdentifier("unlock.startTrial")
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .screenBackground()
        .task { await model.store.loadProductsIfNeeded() }
    }

    /// "Start 7-day free trial" while the user is eligible (length from StoreKit); otherwise "See plans".
    private var buttonTitle: String {
        if model.store.showsTrial, let days = model.store.trialDays {
            return String(localized: "Start \(days)-day free trial")
        }
        return String(localized: "See plans")
    }
}

/// "You unlocked the app!" (S06 style), shown after a real unlock.
struct UnlockSuccessView: View {
    let appName: String
    let duration: UnlockDuration
    /// The button opens the app itself ("Open Instagram") instead of just closing.
    var opensApp = false
    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            // Lockie celebrates: a jump with arms up (MascotView's celebrate), with the confetti and the
            // success haptic below. The shield is already lifted when this appears.
            MascotView(animation: .celebrate, size: 200)
                .accessibilityHidden(true)
            ScreenTitle(title: String(localized: "Unlocked for \(duration.localizedSentenceLabel)"),
                        subtitle: opensApp ? String(localized: "\(appName) is ready for you.")
                                           : String(localized: "Go back to \(appName). It's ready for you."))
            Spacer()
            PrimaryButton(title: opensApp ? String(localized: "Open \(appName)") : String(localized: "Done"),
                          action: onDone)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .screenBackground()
        .confetti(appeared)
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }
}
