import SwiftUI

/// "Today's puzzle": the same featured puzzle for everyone on a given day. Solving it keeps the streak alive.
struct DailyPuzzleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var round: AnyRound?
    @State private var attempt = 0
    @State private var solved = false
    @State private var startedAt = Date()

    var body: some View {
        PuzzleChrome(game: model.dailyGame, subLabel: String(localized: "TODAY'S PUZZLE"),
                     onClose: { model.dailyPuzzleOpen = false }) {
            ZStack {
                if let round, !solved {
                    PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary, onFinish: { finished($0) })
                        .id("\(attempt)-\(round.identity)")
                } else if !solved {
                    ProgressView().tint(palette.accent)
                }
                if solved {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill").appFont(56).foregroundStyle(Color.correctGreen)
                            .accessibilityHidden(true)
                        Text("Today's puzzle: solved!").appFont(26, .bold).foregroundStyle(palette.textPrimary)
                        Text("Your streak is safe for today. Come back tomorrow for a new one.")
                            .appFont(17)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "Done") { model.dailyPuzzleOpen = false }
                    }
                    .card(padding: 24)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .confetti(solved)
        }
        .task {
            round = await model.rounds.dailyRound(for: Date())
            startedAt = Date()
        }
    }

    private func finished(_ status: RoundStatus) {
        if status == .solved {
            model.dailyPuzzleSolved(startedAt: startedAt)
            withAnimation(.selectionSpring) { solved = true }
        } else {
            model.recordResult(game: model.dailyGame, status: status, startedAt: startedAt)
            attempt += 1
            Task {
                round = await model.rounds.dailyRound(for: Date())
                startedAt = Date()
            }
        }
    }
}

/// Featured card at the top of the Puzzles tab.
struct DailyPuzzleCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let game = model.dailyGame
        let done = model.dailySolvedToday
        Button {
            Haptics.tap()
            if !done { model.dailyPuzzleOpen = true }
        } label: {
            HStack(spacing: 14) {
                AssetImage(name: game.coverAsset, placeholderSymbol: game.systemIcon)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S PUZZLE").appFont(12, .bold).tracking(1.5).foregroundStyle(palette.accentText)
                    Text(LocalizedStringKey(game.displayName)).appFont(20, .bold).foregroundStyle(palette.textPrimary)
                    Text(LocalizedStringKey(done ? "Solved ✓ · Come back tomorrow" : "Keeps your streak alive"))
                        .appFont(14)
                        .foregroundStyle(done ? Color.answerGreen : palette.textSecondary)
                }
                Spacer()
                if !done {
                    Text("Play")
                        .appFont(16, .bold)
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(palette.accent, in: Capsule())
                }
            }
            .padding(14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.accent.opacity(done ? 0 : 0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 16)
        .accessibilityHint(done ? "" : "Opens today's puzzle")
    }
}
