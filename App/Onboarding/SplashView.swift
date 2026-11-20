import SwiftUI

/// S01: wordmark, tagline and a small coral spinner. Holds ~1.2s, then fades into the welcome carousel.
struct SplashView: View {
    let onFinish: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Wordmark(size: 58)
            Text(Brand.tagline)
                .appFont(20, .medium)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            ProgressView()
                .tint(palette.accent)
                .padding(.top, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .screenBackground()
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onFinish()
        }
    }
}
