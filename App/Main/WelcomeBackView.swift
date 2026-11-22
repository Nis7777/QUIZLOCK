import SwiftUI

/// New phone, progress restored from iCloud: Screen Time selections can't move between devices,
/// so the user connects Screen Time and picks the apps to lock again. Nothing here involves payment.
struct WelcomeBackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var requesting = false
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MascotView(expression: .pointing, size: 170, entrance: .happy)
                .accessibilityHidden(true)
            ScreenTitle(title: "Welcome back!",
                        subtitle: "Your streak and stats are restored. Pick the apps to lock again.")
            if model.stats.streak() > 0 {
                Label(String(localized: "\(model.stats.streak())-day streak"), systemImage: "flame.fill")
                    .appFont(17, .bold)
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(palette.tint, in: Capsule())
            }
            Spacer()
            PrimaryButton(title: requesting ? "Requesting Access…" : "Pick apps to lock", isLoading: requesting) {
                Task {
                    if !model.isAuthorized {
                        requesting = true
                        _ = await model.requestScreenTimeAuthorization()
                        requesting = false
                    }
                    if model.isAuthorized { showPicker = true }
                }
            }
            .accessibilityIdentifier("welcomeBack.pickApps")
            Button("Not Now") { finish() }
                .appFont(16, .semibold)
                .foregroundStyle(palette.accentText)
                .tapTarget()
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .appPicker(isPresented: $showPicker)
        .onChange(of: showPicker) { _, open in
            if !open, !model.lockItems.isEmpty { finish() }
        }
    }

    private func finish() {
        model.turnOnLocksFromOnboarding()
        model.screenTime.registerSchedule(model.lock.schedule)
        withAnimation(.easeInOut(duration: 0.3)) { model.welcomeBack = false }
    }
}
