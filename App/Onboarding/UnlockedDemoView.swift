import SwiftUI

/// S06: "You unlocked the app!" with a phone showing the iOS back breadcrumb. Auto-advances after 2s or on tap.
struct UnlockedDemoView: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false
    @State private var advanced = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            ScreenTitle(title: "You unlocked the app!", size: 34)
            GeometryReader { geo in
                let width = min(geo.size.width * 0.66, geo.size.height / 2.05)
                PhoneMockup(width: width) {
                    VStack(spacing: width * 0.07) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrowtriangle.left.fill").font(.system(size: width * 0.03))
                            Text("Instagram").font(.system(size: width * 0.045, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(Color(hex: 0x0A84FF))
                        .padding(.horizontal, width * 0.06)
                        .padding(.top, -width * 0.06)
                        Spacer()
                        ZStack {
                            Circle().fill(Color.pinkTint).frame(width: width * 0.36, height: width * 0.36)
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: width * 0.15, weight: .semibold))
                                .foregroundStyle(Color.brandRed)
                        }
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        Text("Tap Instagram at the top left\nto return to your app.")
                            .font(.system(size: width * 0.055, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        Spacer()
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 20)
        }
        .screenBackground()
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        onNext()
    }
}
