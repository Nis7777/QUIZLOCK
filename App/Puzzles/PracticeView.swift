import SwiftUI

/// Standalone practice ("Try") from the Puzzles tab. Requires lifetime access.
struct PracticeView: View {
    let game: GameID
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var round: AnyRound?
    @State private var solvedCount = 0
    @State private var showSolved = false

    var body: some View {
        PuzzleChrome(game: game, subLabel: round?.subLabel ?? "", isPractice: true, onClose: { dismiss() }) {
            ZStack {
                if let round {
                    PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary,
                                   onFinish: { finished($0) })
                        .id("\(solvedCount)-\(round.identity)")
                        .transition(.push(forward: true))
                } else {
                    ProgressView().tint(palette.accent)
                }
                if showSolved {
                    solvedCard.transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .task { await load() }
    }

    private var solvedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .appFont(54)
                .foregroundStyle(Color.correctGreen)
            Text("Solved!").appFont(28, .bold).foregroundStyle(palette.textPrimary)
            PrimaryButton(title: "Next puzzle") {
                withAnimation { showSolved = false }
                Task { await load() }
            }
            Button("Done") { dismiss() }
                .tapTarget()
                .appFont(17, .semibold)
                .foregroundStyle(palette.accentText)
        }
        .card(padding: 24)
        .padding(.horizontal, 8)
    }

    private func finished(_ status: RoundStatus) {
        if status == .solved {
            solvedCount += 1
            withAnimation(.selectionSpring) { showSolved = true }
        } else {
            Task { await load() }
        }
    }

    private func load() async {
        let next = await model.rounds.nextRound(game, difficulty: model.settings.difficulty(for: game))
        withAnimation(.easeInOut(duration: 0.3)) { round = next }
    }
}
