import SwiftUI
import UIKit

/// Full-screen state shown when Screen Time authorization has been revoked.
struct ReconnectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 110, height: 110)
                .background(palette.tint, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            ScreenTitle(title: "Reconnect Screen Time",
                        subtitle: "\(Brand.appName) doesn't have Screen Time permission, so your apps aren't locked right now.")
            Spacer()
            PrimaryButton(title: requesting ? "Requesting Access…" : "Reconnect", isLoading: requesting) {
                Task {
                    requesting = true
                    _ = await model.requestScreenTimeAuthorization()
                    requesting = false
                    model.refreshFromStore()
                }
            }
            HStack(spacing: 28) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not Now") {
                    withAnimation { model.reconnectSnoozed = true }
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(palette.accentText)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}
