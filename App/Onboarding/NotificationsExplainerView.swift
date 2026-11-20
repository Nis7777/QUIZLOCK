import SwiftUI

/// Explainer shown right before the system notification prompt (single Continue).
struct NotificationsExplainerView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.palette) private var palette
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            Spacer(minLength: 10)
            Image(systemName: "bell.badge.fill")
                .appFont(48, .semibold)
                .foregroundStyle(palette.accent)
                .frame(width: 110, height: 110)
                .background(palette.tint, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityHidden(true)
            ScreenTitle(title: "Stay on track",
                        subtitle: "Get a gentle nudge when it's time to focus. We'll never spam you.")
                .padding(.top, 24)
            Text("When you tap START PUZZLE on a locked app, a notification takes you straight to your puzzle.")
                .appFont(15)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)
            Spacer()
            PrimaryButton(title: "Continue", isLoading: requesting) {
                requesting = true
                onContinue()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .screenBackground()
    }
}
