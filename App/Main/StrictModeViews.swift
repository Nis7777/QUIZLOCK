import SwiftUI

/// Turn on strict mode for 1, 4 or 24 hours.
struct StrictModeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Strict mode") { dismiss() }
            Text("While strict mode is on, you can't turn off locks, remove apps or change the lock schedule unless you solve 3 hard puzzles.")
                .appFont(16)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
            VStack(spacing: 10) {
                ForEach([1, 4, 24], id: \.self) { h in
                    ChoiceCard(title: h == 1 ? String(localized: "1 hour") : String(localized: "\(h) hours"), selected: hours == h) {
                        hours = h
                    }
                }
            }
            .padding(.horizontal, 16)
            Spacer()
            PrimaryButton(title: "Turn On Strict Mode", systemImage: "lock.shield.fill") {
                model.startStrictMode(hours: hours)
                dismiss()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .screenBackground()
    }
}

/// Solve 3 hard puzzles to end strict mode (and then perform the blocked action).
struct StrictChallengeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var solved = 0
    @State private var round: AnyRound?
    @State private var startedAt = Date()
    private let games: [GameID] = [.math, .word, .chess]
    private let required = 3

    var body: some View {
        PuzzleChrome(game: games[min(solved, required - 1)],
                     subLabel: String(localized: "STRICT MODE · HARD"),
                     progress: "\(min(solved + 1, required)) of \(required)",
                     onClose: { model.strictChallengeCancelled() }) {
            if let round {
                PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary, onFinish: { finished($0) })
                    .id("\(solved)-\(round.identity)")
            } else {
                ProgressView().tint(palette.accent)
            }
        }
        .task { await load() }
    }

    private func finished(_ status: RoundStatus) {
        model.recordResult(game: games[min(solved, required - 1)], status: status, startedAt: startedAt)
        if status == .solved {
            solved += 1
            if solved >= required {
                model.strictChallengeCompleted()
                return
            }
        }
        Task { await load() }
    }

    private func load() async {
        round = nil
        round = await model.rounds.nextRound(games[min(solved, required - 1)], difficulty: .hard)
        startedAt = Date()
    }
}
