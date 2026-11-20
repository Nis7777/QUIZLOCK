import SwiftUI
import UIKit

/// S09: "Connect QuizLock to Screen Time" with a permission preview, then the real request.
struct ConnectScreenTimeView: View {
    let onBack: () -> Void
    let onAuthorized: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var requesting = false
    @State private var showFailure = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            PeachArc()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    OnboardingHeader(onBack: onBack, steps: 2, current: 1)
                    ScreenTitle(title: "Connect \(Brand.appName)\nto Screen Time", size: 36)
                        .padding(.top, 10)
                    Text("To block the apps you choose, \(Brand.appName) needs Screen Time permission.")
                        .appFont(19)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                    Text("\(Brand.appName) does not collect your Screen Time usage.")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                    Text("Permission preview")
                        .appFont(15, .semibold)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, 24)
                    fakeAlert
                        .padding(.top, 10)
                        .padding(.horizontal, 36)
                        .zIndex(1)
                    AssetImage(name: "mascot_pointing", placeholderSymbol: "person.fill", contentMode: .fit)
                        .frame(height: 200)
                        .frame(maxWidth: 200)
                        .clipShape(RoundedRectangle(cornerRadius: UIImage(named: "mascot_pointing") == nil ? 20 : 0))
                        .offset(x: 46, y: -16)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 100)
            }
            VStack {
                Spacer()
                PrimaryButton(title: requesting ? "Requesting Access…" : "Continue", isLoading: requesting) {
                    Task { await request() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            if requesting {
                Color.black.opacity(0.25).ignoresSafeArea().transition(.opacity).allowsHitTesting(true)
            }
        }
        .screenBackground()
        .animation(.easeInOut(duration: 0.25), value: requesting)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        // Respect the user's choice (guideline 5.1.1(iv)): no re-asking; they can continue without access.
        .alert("Screen Time not connected", isPresented: $showFailure) {
            Button("Continue Without Access") { onAuthorized() }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("\(Brand.appName) can't block apps without Screen Time access. You can continue and connect it later from the app.")
        }
    }

    private var fakeAlert: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("“\(Brand.appName)” Would Like to Access Screen Time")
                .appFont(19, .semibold)
                .foregroundStyle(Color.textPrimary)
            Text("Providing “\(Brand.appName)” access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites.")
                .appFont(16)
                .foregroundStyle(Color(hex: 0x5A5A60))
            HStack(spacing: 10) {
                Text("Continue")
                    .appFont(18, .medium)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0xD9D9DE), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.brand, lineWidth: 3)
                            .padding(-4)
                            .opacity(pulse ? 1 : 0.35)
                            .scaleEffect(pulse ? 1.04 : 0.98)
                    )
                Text("Don't Allow")
                    .appFont(18, .medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0x0A84FF), in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Permission preview")
    }

    private func request() async {
        requesting = true
        let ok = await model.requestScreenTimeAuthorization()
        requesting = false
        if ok { onAuthorized() } else { showFailure = true }
    }
}
