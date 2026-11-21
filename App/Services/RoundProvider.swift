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

    // MARK: Daily puzzle (same for everyone on a given day)

    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int((start.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: start))) / 86_400)
    }

    static func dailyGame(for date: Date) -> GameID {
        let games: [GameID] = [.word, .chess, .math, .sudoku]
        return games[((dayNumber(for: date) % games.count) + games.count) % games.count]
    }

    func dailyRound(for date: Date) async -> AnyRound {
        let day = Self.dayNumber(for: date)
        let seed = UInt64(truncatingIfNeeded: day) &* 0x9E37_79B9 &+ 0x5EED
        var rng = SeededGenerator(seed: seed)
        switch Self.dailyGame(for: date) {
        case .math:
            return .math(MathRound(question: MathEngine.generate(difficulty: .medium, using: &rng), difficulty: .medium))
        case .word:
            let answers = wordDictionary.answers
            let answer = answers.isEmpty ? "plant" : answers[Int(seed % UInt64(answers.count))]
            return .word(WordRound(answer: answer, difficulty: .easy))
        case .chess:
            let pool = chessBank.puzzles(for: .medium)
            guard !pool.isEmpty else { return .chess(ChessRound.fallback(difficulty: .medium)) }
            let puzzle = pool[Int(seed % UInt64(pool.count))]
            return .chess((try? ChessRound(puzzle: puzzle, difficulty: .medium)) ?? ChessRound.fallback(difficulty: .medium))
        case .sudoku:
            let puzzle = await Task.detached(priority: .userInitiated) { () -> SudokuPuzzle in
                var r = SeededGenerator(seed: seed)
                return SudokuGenerator.generate(difficulty: .easy, using: &r)
            }.value
            return .sudoku(SudokuRound(puzzle: puzzle, difficulty: .easy))
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
            return .chess((try? ChessRound(puzzle: puzzle, difficulty: .easy)) ?? ChessRound.fallback(difficulty: .easy))
        }
    }
}
