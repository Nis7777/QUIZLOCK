import SwiftUI

/// Full-screen unlock puzzle (S05 chrome without "PRACTICE", plus "1 of N").
struct UnlockFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var confirmEmergency = false

    var body: some View {
        ZStack {
            if let result = model.unlockResult {
                UnlockSuccessView(appName: result.appName, duration: result.duration) {
                    model.finishUnlockResult()
                }
                .transition(.opacity)
            } else if let session = model.unlockSession {
                PuzzleChrome(game: session.current?.game ?? session.currentGame,
                             subLabel: session.current?.subLabel ?? "",
                             progress: "\(min(session.solved + 1, session.required)) of \(session.required)",
                             isPractice: false,
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

/// "You unlocked the app!" (S06 style), shown after a real unlock.
struct UnlockSuccessView: View {
    let appName: String
    let duration: UnlockDuration
    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(palette.tint).frame(width: 120, height: 120)
                Image(systemName: "lock.open.fill")
                    .appFont(50, .semibold)
                    .foregroundStyle(palette.accent)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            ScreenTitle(title: "You unlocked the app!",
                        subtitle: String(localized: "Go back to \(appName) — it's unlocked for \(duration.localizedSentenceLabel)."))
            Spacer()
            PrimaryButton(title: "Done", action: onDone)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .screenBackground()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
