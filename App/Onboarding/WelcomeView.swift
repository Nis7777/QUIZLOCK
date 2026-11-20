import SwiftUI

/// S02: auto-advancing carousel of 4 self-solving preview cards.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    @Environment(\.palette) private var palette
    @State private var page = 0
    @State private var link: URL?

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                MathPreviewCard(isActive: page == 0).tag(0)
                WordPreviewCard(isActive: page == 1).tag(1)
                SudokuPreviewCard(isActive: page == 2).tag(2)
                ChessPreviewCard(isActive: page == 3).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            PageDots(count: 4, index: page)
                .padding(.top, 14)

            VStack(spacing: 6) {
                Text("Lock your apps.")
                    .appFont(34, .bold)
                    .foregroundStyle(palette.textPrimary)
                Text("Solve a puzzle to unlock.")
                    .appFont(30, .bold)
                    .foregroundStyle(palette.textPrimary)
                Text("Scroll less.")
                    .appFont(36, .bold)
                    .foregroundStyle(palette.accent)
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .padding(.top, 26)
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)

            PrimaryButton(title: "Get Started", action: onGetStarted)
                .padding(.horizontal, 20)
                .padding(.top, 30)

            LegalLinksText(openURL: $link)
                .padding(.horizontal, 30)
                .padding(.top, 16)
                .padding(.bottom, 6)
        }
        .screenBackground()
        .safariSheet($link)
        .task(id: page) {
            // Auto-advance every ~3.5s (restarts when the user swipes).
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) { page = (page + 1) % 4 }
        }
    }
}
