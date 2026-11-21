import SwiftUI

// Canvas previews for the main screens. In Xcode's canvas, switch the device between
// iPhone SE (3rd generation) and iPhone 16 Pro Max to check layouts at both sizes, and toggle
// the Color Scheme / Dynamic Type variants to check dark theme and large text.

#if DEBUG
private struct PreviewHost<Content: View>: View {
    var theme: AppTheme = .classic
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .environment(AppModel.shared)
            .environment(\.palette, Palette.forTheme(theme))
    }
}

#Preview("Welcome") { PreviewHost { WelcomeView {} } }
#Preview("Reality check") { PreviewHost { RealityCheckView(progress: 0.75, onBack: {}, onNext: {}) } }
#Preview("Commitment") { PreviewHost { CommitmentView(progress: 0.9, onBack: {}, onNext: {}) } }
#Preview("Dashboard") { PreviewHost { MainTabView() } }
#Preview("Dashboard · Dark") { PreviewHost(theme: .dark) { MainTabView() }.preferredColorScheme(.dark) }
#Preview("Stats") { PreviewHost { NavigationStack { StatsView() } } }
#Preview("Paywall") { PreviewHost { PaywallView() } }
#Preview("Math") {
    PreviewHost {
        PuzzleChrome(game: .math, subLabel: "ALGEBRA", progress: "1 of 3") {
            MathGameView(round: MathRound(question: MathQuestion(topic: "ALGEBRA", text: "If 3x + 7 = 22, what is x?",
                                                                  expression: "3*x+7=22", answer: 5), difficulty: .easy),
                         onUpdate: { _ in }, onFinish: { _ in })
        }
    }
}
#endif
