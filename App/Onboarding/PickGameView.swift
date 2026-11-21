import SwiftUI

/// "Which puzzles sound fun?" — one multi-select question (all 4 pre-selected). The answer sets which games
/// are used for unlocks. Nothing is played here.
struct PickGamesView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var selected: Set<GameID> = Set(GameID.allCases)

    private let order: [GameID] = [.chess, .sudoku, .math, .word]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            ScreenTitle(title: "Which puzzles sound fun?", subtitle: "Pick all that apply. You can change this anytime.")
                .padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(order) { game in
                    Button {
                        Haptics.tap()
                        withAnimation(.selectionSpring) {
                            if selected.contains(game) { selected.remove(game) } else { selected.insert(game) }
                        }
                    } label: {
                        card(game)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(game.displayName). \(game.onboardingSubtitle)")
                    .accessibilityAddTraits(selected.contains(game) ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("onboarding.game.\(game.rawValue)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            Spacer()
            PrimaryButton(title: "Continue", isEnabled: !selected.isEmpty) {
                let games = GameID.allCases.filter { selected.contains($0) }
                model.updateSettings { $0.enabledGames = games }
                for game in games { model.setGame(game, enabled: true) }
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .onAppear {
            let saved = Set(model.settings.enabledGames)
            selected = saved.isEmpty ? Set(GameID.allCases) : saved
        }
    }

    private func card(_ game: GameID) -> some View {
        let isOn = selected.contains(game)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                GameIcon(game: game, size: 42, color: palette.accent)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .appFont(24, .semibold)
                    .foregroundStyle(isOn ? palette.accent : palette.separator)
                    .accessibilityHidden(true)
            }
            Spacer()
            Text(LocalizedStringKey(game.displayName))
                .appFont(22, .bold)
                .foregroundStyle(palette.textPrimary)
            Text(LocalizedStringKey(game.onboardingSubtitle))
                .appFont(15)
                .foregroundStyle(palette.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(isOn ? palette.accent : palette.separator, lineWidth: isOn ? 2.5 : 1))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}
