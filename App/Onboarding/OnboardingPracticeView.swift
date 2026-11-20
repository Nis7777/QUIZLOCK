import SwiftUI

/// S05: full-screen practice puzzle (deliberately easy).
struct OnboardingPracticeView: View {
    let game: GameID
    let onClose: () -> Void
    let onSuccess: () -> Void
    @Environment(AppModel.self) private var model
    @State private var round: AnyRound?
    @State private var attempt = 0

    var body: some View {
        PuzzleChrome(game: game, subLabel: round?.subLabel ?? "", isPractice: true, onClose: onClose) {
            if let round {
                PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary, onFinish: { status in
                    switch status {
                    case .solved:
                        onSuccess()
                    case .failed:
                        // Word: the answer was revealed; continue anyway. Others: serve another easy round.
                        if game == .word {
                            onSuccess()
                        } else {
                            attempt += 1
                            self.round = model.rounds.onboardingRound(game)
                        }
                    case .playing:
                        break
                    }
                })
                .id("\(attempt)-\(round.identity)")
            }
        }
        .onAppear {
            if round == nil { round = model.rounds.onboardingRound(game) }
        }
    }
}
