import SwiftUI

/// S11: "Choose your puzzle reward" (step 3 of 3).
struct RewardView: View {
    let onBack: () -> Void
    let onChangeApps: () -> Void
    let onTurnOn: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack, steps: 3, current: 2)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Image(systemName: "timer")
                        .appFont(44, .semibold)
                        .foregroundStyle(palette.accent)
                        .frame(width: 100, height: 100)
                        .background(palette.tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(palette.accent.opacity(0.2), lineWidth: 1))
                    ScreenTitle(title: "Choose your\npuzzle reward",
                                subtitle: "Choose how long your apps stay unlocked after you solve a puzzle.", size: 38)
                    Text("Your first \(Brand.freeUnlocks) app unlocks are free. After that, lifetime access is a one-time purchase. Standalone puzzle practice requires lifetime access.")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).fill(palette.accent).frame(width: 14, height: 14)
                        Text(model.selectedCountText).appFont(16, .bold).foregroundStyle(palette.accentText)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(palette.tint, in: Capsule())
                    DurationRadioCards(selection: model.lock.defaultDuration) { d in
                        model.updateLock(applyShield: false) { $0.defaultDuration = d }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    Text("You can change your puzzle reward later in Settings.")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                    Button("Change apps", action: onChangeApps)
                        .tapTarget()
                        .appFont(16, .bold)
                        .foregroundStyle(palette.accentText)
                }
                .padding(.bottom, 16)
            }
            PrimaryButton(title: "Turn On Locks", trailingImage: "checkmark", action: onTurnOn)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .screenBackground()
    }
}
