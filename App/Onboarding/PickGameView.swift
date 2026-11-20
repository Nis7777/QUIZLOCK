import SwiftUI

/// S03: "Try your first puzzle" — a 2×2 grid of tall game cards.
struct PickGameView: View {
    let onBack: () -> Void
    let onPick: (GameID) -> Void
    @Environment(\.palette) private var palette

    private let order: [GameID] = [.math, .word, .sudoku, .chess]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            ScreenTitle(title: "Try your first puzzle", subtitle: "Pick a game. Just one quick round.")
                .padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(order) { game in
                    Button {
                        Haptics.tap()
                        onPick(game)
                    } label: {
                        card(game)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(game.displayName). \(game.onboardingSubtitle)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            Spacer()
        }
        .screenBackground()
    }

    private func card(_ game: GameID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GameIcon(game: game, size: 46, color: palette.accent)
            Spacer()
            Text(game.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.textPrimary)
            Text(game.onboardingSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}
