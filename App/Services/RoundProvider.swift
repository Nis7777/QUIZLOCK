import Foundation

/// Creates puzzle rounds and keeps the next one pre-generated in the background,
/// so the unlock screen opens instantly.
@MainActor
final class RoundProvider {
    let wordDictionary: WordDictionary
    let chessBank: ChessPuzzleBank
    private var cache: [String: AnyRound] = [:]
    private var inFlight: Set<String> = []

    init(bundle: Bundle = .main) {
        wordDictionary = WordDictionary.load(from: bundle)
            ?? WordDictionary(allowed: ["plant", "crane", "slant"], answers: ["plant"])
        chessBank = ChessPuzzleBank.load(from: bundle) ?? ChessPuzzleBank(puzzles: [ChessPuzzleBank.fallback])
    }

    func game(_ id: GameID) -> any PuzzleGame {
        switch id {
        case .word:
            return WordGame(dictionary: wordDictionary,
                            usedProvider: { Set(SharedStore.load([String].self, .usedWordAnswers) ?? []) },
                            markUsed: { answer, reset in
                                var used = reset ? [] : (SharedStore.load([String].self, .usedWordAnswers) ?? [])
                                used.append(answer)
                                SharedStore.save(used, .usedWordAnswers)
                            })
        case .chess: return ChessGame(bank: chessBank)
        case .sudoku: return SudokuGame()
        case .math: return MathGame()
        }
    }

    private func key(_ id: GameID, _ d: Difficulty) -> String { id.rawValue + "." + d.rawValue }

    /// Returns a round (pre-generated if available) and starts generating the next one.
    func nextRound(_ id: GameID, difficulty: Difficulty) async -> AnyRound {
        let k = key(id, difficulty)
        if let cached = cache.removeValue(forKey: k) {
            prefetch(id, difficulty: difficulty)
            return cached
        }
        let round = await game(id).makeRound(difficulty: difficulty)
        prefetch(id, difficulty: difficulty)
        return AnyRound(round) ?? Self.fallbackRound
    }

    private static let fallbackRound = AnyRound.math(MathRound(
        question: MathQuestion(topic: "ARITHMETIC", text: "7 × 8 = ?", expression: "7*8", answer: 56), difficulty: .easy))

    func prefetch(_ id: GameID, difficulty: Difficulty) {
        let k = key(id, difficulty)
        guard cache[k] == nil, !inFlight.contains(k) else { return }
        inFlight.insert(k)
        let game = game(id)
        Task {
            let round = await game.makeRound(difficulty: difficulty)
            self.cache[k] = AnyRound(round)
            self.inFlight.remove(k)
        }
    }

    // MARK: Onboarding rounds (deliberately easy)

    func onboardingRound(_ id: GameID) -> AnyRound {
        var rng = SystemRandomNumberGenerator()
        switch id {
        case .math:
            return .math(MathRound(question: MathEngine.generate(difficulty: .easy, using: &rng), difficulty: .easy))
        case .word:
            let common = ["plant", "house", "water", "light", "smile", "happy", "music", "bread", "chair", "beach"]
            let answer = common.filter { wordDictionary.isAllowed($0) }.randomElement() ?? wordDictionary.answers.first ?? "plant"
            return .word(WordRound(answer: answer, difficulty: .easy))
        case .sudoku:
            return .sudoku(SudokuRound(puzzle: SudokuGenerator.nearlySolved(blanks: 4, using: &rng), difficulty: .easy))
        case .chess:
            let puzzle = chessBank.firstEasyMateInOne ?? ChessPuzzleBank.fallback
            if let r = try? ChessRound(puzzle: puzzle, difficulty: .easy) { return .chess(r) }
            // swiftlint:disable:next force_try
            return .chess(try! ChessRound(puzzle: ChessPuzzleBank.fallback, difficulty: .easy))
        }
    }
}
