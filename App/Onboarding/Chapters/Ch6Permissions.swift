import FamilyControls
import ManagedSettings
import StoreKit
import SwiftUI
import UIKit

// MARK: - Chapter 6: Permissions

/// 6.1 "Let's lock your first apps" → Screen Time prompt → app picker → confirmation (icons pop in).
struct ConnectScreenTimeStepView: View {
    /// True when coming back from "Pick apps to lock": the picker opens straight away.
    var openPicker = false
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
        .task {
            guard openPicker else { return }
            try? await Task.sleep(nanoseconds: 450_000_000) // let the slide-in finish
            await connect()
        }
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
                ChunkyButton(title: model.isAuthorized ? "Choose apps" : "Continue", isLoading: requesting) {
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
        OnboardingPage(title: "Ready to lock", subtitle: model.selectedCountText) {
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
                BrandAppIcon(name: MockApps.logo(name), size: 54)
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

/// 6.2 Notifications, with the reason up front: "so I can hand you your puzzle instantly". A preview of
/// the real "Tap to solve" notification slides in. After the system prompt, if Time Sensitive is off,
/// a second step shows the switch and opens Settings (Time Sensitive lets the puzzle through Focus
/// and Sleep). Declining is fine: Settings offers it again later, and the shield tells people to open
/// Lockie themselves.
struct NotificationsStepView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var asking = false
    @State private var showTimeSensitive = false
    @State private var bannerIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if showTimeSensitive { timeSensitiveStep.transition(Motion.stepTransition(forward: true, reduceMotion: reduceMotion)) }
            else { askStep.transition(Motion.stepTransition(forward: false, reduceMotion: reduceMotion)) }
        }
        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: showTimeSensitive)
    }

    private var askStep: some View {
        OnboardingPage(title: "Let me hand you your puzzle instantly",
                       subtitle: "When you open a locked app, I'll send one notification. Tap it and your puzzle is open.") {
            VStack(spacing: 14) {
                NotificationPreview()
                    .offset(y: bannerIn || reduceMotion ? 0 : -24)
                    .opacity(bannerIn ? 1 : 0)
                    .accessibilityHidden(true)
                MascotSlot(expression: .pointing, size: 170)
                    .offset(x: 40)
            }
            .padding(.top, 6)
        } footer: {
            // App Review 5.1.1(iv): before a system permission prompt, the button says "Continue" (not
            // "Allow") and there's no way to skip the prompt; people decide in Apple's own alert.
            VStack(spacing: 4) {
                ChunkyButton(title: "Continue", isLoading: asking) {
                    Task {
                        asking = true
                        await model.requestNotificationPermission()
                        asking = false
                        if model.timeSensitiveOff { showTimeSensitive = true } else { onContinue() }
                    }
                }
                .accessibilityIdentifier("onboarding.notifications")
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(Motion.respecting(reduceMotion, Motion.landing)) { bannerIn = true }
        }
    }

    private var timeSensitiveStep: some View {
        OnboardingPage(title: "One more switch",
                       subtitle: "Turn on Time Sensitive so your puzzle still reaches you in Focus and Sleep.") {
            TimeSensitiveIllustration()
                .padding(.top, 12)
                .staggeredAppear(1)
                .accessibilityHidden(true)
        } footer: {
            VStack(spacing: 4) {
                ChunkyButton(title: "Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    onContinue()
                }
                OnboardingLink(title: "Not now", action: onContinue)
            }
        }
    }
}

/// What the "Tap to solve" notification looks like (illustration).
private struct NotificationPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            MascotView(expression: .happy, size: 38, isLive: false, popsIn: false)
                .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Tap to solve 🧩").appFont(15, .semibold).foregroundStyle(Color.textPrimary)
                Text("Instagram unlocks as soon as you solve it.").appFont(14).foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Text("now").appFont(12).foregroundStyle(Color.textSecondary)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .padding(.horizontal, 4)
    }
}

/// The two switches in Settings → Notifications → Lockie, with Time Sensitive highlighted.
private struct TimeSensitiveIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            row("Allow Notifications", highlighted: false)
            Divider().padding(.leading, 16)
            row("Time Sensitive Notifications", highlighted: true)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.brand, lineWidth: 2)
                .frame(height: 50)
                .padding(4)
        }
    }

    private func row(_ title: LocalizedStringKey, highlighted: Bool) -> some View {
        HStack {
            Text(title).appFont(16, highlighted ? .semibold : .regular).foregroundStyle(Color.textPrimary)
            Spacer()
            Capsule().fill(Color.correctGreen).frame(width: 46, height: 28)
                .overlay(alignment: .trailing) { Circle().fill(.white).padding(2) }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

