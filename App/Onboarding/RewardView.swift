import FamilyControls
import ManagedSettings
import SwiftUI

/// "Choose your reward" (Chapter 6): how long apps stay unlocked after a puzzle. Two-line cards scroll
/// above a pinned "Turn On Locks" (or "Pick apps to lock" when nothing is selected yet).
struct RewardView: View {
    let onChangeApps: () -> Void
    let onTurnOn: () -> Void
    @Environment(AppModel.self) private var model
    @State private var showCustom = false

    private struct Option: Identifiable {
        let duration: UnlockDuration
        let title: String
        let subtitle: String
        let symbol: String
        var id: String { title }
    }

    private let options: [Option] = [
        Option(duration: .minutes(5), title: "5 minutes", subtitle: "A quick check", symbol: "hare.fill"),
        Option(duration: .minutes(15), title: "15 minutes", subtitle: "Recommended", symbol: "clock.fill"),
        Option(duration: .minutes(60), title: "1 hour", subtitle: "Longer breaks", symbol: "hourglass"),
        Option(duration: .forToday, title: "Until tomorrow", subtitle: "Unlocked for the rest of the day", symbol: "moon.fill"),
    ]

    var body: some View {
        let selection = model.lock.defaultDuration
        let hasApps = !model.lockItems.isEmpty
        OnboardingPage(title: "Choose your reward",
                       subtitle: "How long should your apps stay unlocked after you solve a puzzle?") {
            VStack(spacing: 10) {
                if hasApps {
                    selectedAppsPill
                        .padding(.bottom, 6)
                        .staggeredAppear(2)
                }
                ForEach(Array(options.enumerated()), id: \.element.id) { i, option in
                    ChoiceCard(title: option.title, subtitle: option.subtitle, symbol: option.symbol,
                               badge: option.duration == .default ? "Recommended" : nil,
                               selected: selection == option.duration, dimmed: true) {
                        model.updateLock(applyShield: false) { $0.defaultDuration = option.duration }
                    }
                    .staggeredAppear(i + 3)
                }
                ChoiceCard(title: "Custom",
                           subtitle: selection.isCustom ? selection.localizedLabel : "Pick your own time",
                           symbol: "slider.horizontal.3", selected: selection.isCustom, dimmed: true) {
                    showCustom = true
                }
                .staggeredAppear(options.count + 3)
                if hasApps {
                    OnboardingLink(title: "Change apps", action: onChangeApps)
                        .padding(.top, 4)
                }
            }
        } footer: {
            if hasApps {
                // Locks take effect once Lockie Pro (or its free trial) starts, so this doesn't claim they're on.
                ChunkyButton(title: "Continue", action: onTurnOn)
                    .accessibilityIdentifier("onboarding.turnOn")
            } else {
                // Nothing to lock yet: offer the picker, but never trap anyone who declined Screen Time
                // access (App Review 5.1.1(iv)): they can carry on and pick apps later in Settings.
                VStack(spacing: 4) {
                    ChunkyButton(title: "Pick apps to lock", systemImage: "plus", action: onChangeApps)
                        .accessibilityIdentifier("onboarding.pickApps")
                    OnboardingLink(title: "Skip for now", action: onTurnOn)
                        .accessibilityIdentifier("onboarding.skipApps")
                }
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(initial: selection) { d in
                model.updateLock(applyShield: false) { $0.defaultDuration = d }
            }
            .presentationDetents([.height(420)])
            .presentationCornerRadius(28)
        }
    }

    /// "3 apps selected" with the first 3 icons stacked.
    private var selectedAppsPill: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(Array(model.lockItems.prefix(3).enumerated()), id: \.element.id) { i, item in
                    SmallLockIcon(item: item)
                        .zIndex(Double(3 - i))
                }
            }
            Text(model.selectedCountText)
                .appFont(16, .bold)
                .foregroundStyle(Color.brandDeep)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 7)
        .background(Color.brandTint, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.selectedCountText))
    }
}

/// A 30pt icon for the stacked pill: Apple's Label(token) on device, BrandAppIcon in the Simulator.
private struct SmallLockIcon: View {
    let item: LockItem

    var body: some View {
        Group {
            switch item.kind {
            case .app(let token): Label(token).labelStyle(.iconOnly)
            case .category(let token): Label(token).labelStyle(.iconOnly)
            case .web(let token): Label(token).labelStyle(.iconOnly)
            case .mock(let name): BrandAppIcon(name: MockApps.logo(name), size: 30)
            }
        }
        .frame(width: 30, height: 30)
        .background(Circle().fill(.white).padding(-2))
    }
}
