import FamilyControls
import ManagedSettings
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
                                  opensApp: result.openURL != nil,
                                  askWhichApp: result.itemKey != nil, appToken: result.appToken,
                                  onPick: { model.pickUnlockedApp(name: $0, bundleID: $1) }) {
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

/// Shown after an unlock only when Lockie can't open the app by itself. iOS never tells Lockie which app
/// a locked item is (only an anonymous token), so the first time it asks "Which app was this?",
/// showing iOS's own icon and name for the locked app; one tap opens it and is remembered.
struct UnlockSuccessView: View {
    let appName: String
    let duration: UnlockDuration
    /// The button opens the app itself ("Open Instagram") instead of just closing.
    var opensApp = false
    /// Lockie couldn't tell which app it was (iOS keeps that private): ask once, then remember.
    var askWhichApp = false
    var appToken: ApplicationToken?
    var onPick: (String, String) -> Void = { _, _ in }
    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            // Lockie celebrates: a jump with arms up (MascotView's celebrate), with the confetti and the
            // success haptic below. The shield is already lifted when this appears.
            MascotView(animation: .celebrate, size: askWhichApp ? 130 : 200)
                .accessibilityHidden(true)
            ScreenTitle(title: String(localized: "Unlocked for \(duration.localizedSentenceLabel)"),
                        subtitle: askWhichApp ? String(localized: "Which app was this? Tap it to jump back in. I'll remember it next time.")
                                  : opensApp ? String(localized: "\(appName) is ready for you.")
                                             : String(localized: "Go back to \(appName). It's ready for you."))
            if askWhichApp { whichApp }
            Spacer(minLength: 8)
            if askWhichApp {
                Button("Not in the list") { onDone() }
                    .appFont(16, .semibold)
                    .foregroundStyle(palette.textSecondary)
                    .tapTarget()
                    .padding(.bottom, 12)
            } else {
                PrimaryButton(title: opensApp ? String(localized: "Open \(appName)") : String(localized: "Done"),
                              action: onDone)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .screenBackground()
        .confetti(appeared)
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }

    private var whichApp: some View {
        VStack(spacing: 14) {
            if let appToken {
                // iOS draws this (Lockie itself can't read it): the locked app's real icon and name.
                Label(appToken)
                    .labelStyle(.titleAndIcon)
                    .appFont(17, .semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(palette.tint, in: Capsule())
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(AppLauncher.pickable, id: \.bundleID) { app in
                    Button {
                        Haptics.tap()
                        onPick(app.name, app.bundleID)
                    } label: {
                        VStack(spacing: 6) {
                            BrandAppIcon(name: app.icon, size: 54)
                            Text(verbatim: app.name)
                                .appFont(12, .semibold)
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
