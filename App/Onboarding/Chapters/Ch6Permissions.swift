import FamilyControls
import ManagedSettings
import StoreKit
import SwiftUI
import UIKit

// MARK: - Chapter 6: Permissions

/// 6.1 "Let's lock your first apps" → Screen Time prompt → app picker → confirmation (icons pop in).
struct ConnectScreenTimeStepView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var requesting = false
    @State private var showPicker = false
    @State private var showFailure = false
    @State private var confirmed = false

    var body: some View {
        Group {
            if confirmed && !model.lockItems.isEmpty {
                confirmation.transition(.opacity)
            } else {
                intro.transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: confirmed)
        .appPicker(isPresented: $showPicker)
        .onChange(of: showPicker) { _, open in
            // The picker was dismissed: show what they picked.
            if !open, !model.lockItems.isEmpty { confirmed = true }
        }
        // Respect the user's choice (guideline 5.1.1(iv)): no nagging; they can continue without access.
        .alert("Screen Time not connected", isPresented: $showFailure) {
            Button("Continue Without Access") { onContinue() }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("\(Brand.appName) can't block apps without Screen Time access. You can continue and connect it later from the app.")
        }
    }

    private var intro: some View {
        OnboardingPage(title: "Let's lock your first apps") {
            VStack(spacing: 18) {
                MascotSlot(expression: .pointing, size: 190)
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "apple.logo")
                        .appFont(26, .semibold)
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: 0xF2F2F7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your data stays on your iPhone.")
                            .appFont(17, .bold)
                            .foregroundStyle(Color.textPrimary)
                        Text("Protected by Apple's Screen Time privacy.")
                            .appFont(15)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color.cardWhite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.black.opacity(0.06)))
                .accessibilityElement(children: .combine)
                .staggeredAppear(2)
            }
        } footer: {
            VStack(spacing: 4) {
                ChunkyButton(title: model.isAuthorized ? "Choose apps" : "Connect Screen Time", isLoading: requesting) {
                    Task { await connect() }
                }
                .accessibilityIdentifier("onboarding.connect")
                if model.isAuthorized {
                    if model.lockItems.isEmpty {
                        OnboardingLink(title: "Skip for now", action: onContinue)
                    } else {
                        OnboardingLink(title: "Keep my apps") { confirmed = true }
                    }
                }
            }
        }
    }

    private var confirmation: some View {
        OnboardingPage(title: "Locked and loaded", subtitle: model.selectedCountText) {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                    ForEach(Array(model.lockItems.prefix(16).enumerated()), id: \.element.id) { i, item in
                        LockItemIcon(item: item)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.brand, in: Circle())
                                    .offset(x: 6, y: 6)
                            }
                            .popIn(index: i)
                    }
                }
                .padding(.top, 10)
                MascotSlot(expression: .happy, size: 150)
                OnboardingLink(title: "Change apps") { showPicker = true }
            }
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
        .sensoryFeedback(.success, trigger: confirmed) { _, now in now }
    }

    private func connect() async {
        if model.isAuthorized {
            showPicker = true
            return
        }
        requesting = true
        let ok = await model.requestScreenTimeAuthorization()
        requesting = false
        if ok { showPicker = true } else { showFailure = true }
    }
}

/// Just the icon of a selected app/category/website (real token icon, or a mock in the Simulator).
struct LockItemIcon: View {
    let item: LockItem

    var body: some View {
        Group {
            switch item.kind {
            case .app(let token): Label(token).labelStyle(.iconOnly)
            case .category(let token): Label(token).labelStyle(.iconOnly)
            case .web(let token): Label(token).labelStyle(.iconOnly)
            case .mock(let name):
                let info = MockApps.info(name)
                MockAppIcon(symbol: info.symbol, colors: info.colors.map { Color(hex: $0) }, size: 54)
            }
        }
        .scaleEffect(item.isMock ? 1 : 1.8)
        .frame(width: 58, height: 58)
    }
}

private extension LockItem {
    var isMock: Bool {
        if case .mock = kind { return true }
        return false
    }
}

private struct PopIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(Motion.respecting(reduceMotion, Motion.bouncy).delay(0.15 + Double(index) * Motion.stagger * 1.5)) {
                    shown = true
                }
            }
    }
}

private extension View {
    func popIn(index: Int) -> some View { modifier(PopIn(index: index)) }
}

/// 6.2 "I'll send you gentle reminders…" — Lockie points up to where the system alert appears.
struct NotificationsStepView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @State private var asking = false

    var body: some View {
        OnboardingPage(title: "I'll send you gentle reminders to keep your streak alive") {
            VStack(spacing: 8) {
                // A faint outline where the system alert will appear.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.brand.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    .frame(height: 130)
                    .overlay(
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.brand)
                            .symbolEffect(.bounce, options: .repeat(2), value: asking)
                    )
                    .padding(.horizontal, 30)
                    .staggeredAppear(1)
                    .accessibilityHidden(true)
                MascotSlot(expression: .pointing, size: 190)
                    .offset(x: 50)
            }
        } footer: {
            VStack(spacing: 4) {
                ChunkyButton(title: "Allow notifications", isLoading: asking) {
                    Task {
                        asking = true
                        await model.requestNotificationPermission()
                        asking = false
                        onContinue()
                    }
                }
                .accessibilityIdentifier("onboarding.notifications")
                OnboardingLink(title: "Not now", action: onContinue)
            }
        }
    }
}

/// 6.3 "Help more people unlock their time": requestReview once. No fake reviews or numbers.
struct RatingStepView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview
    @State private var celebrate = false

    var body: some View {
        OnboardingPage {
            VStack(spacing: 16) {
                MascotSlot(expression: .celebrate, size: 230)
                    .padding(.top, 20)
                Text("Help more people unlock their time")
                    .appFont(30, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppear(1)
                Text("A quick rating helps others find \(Brand.appName).")
                    .appFont(17)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .staggeredAppear(2)
            }
        } footer: {
            ChunkyButton(title: "Continue") {
                if !model.settings.ratingRequested {
                    model.updateSettings { $0.ratingRequested = true }
                    requestReview()
                }
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
        }
        .confetti(celebrate)
        .task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            celebrate = true
        }
    }
}
