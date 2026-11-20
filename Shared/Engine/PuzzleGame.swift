import Foundation

public enum GameID: String, Codable, CaseIterable, Identifiable, Sendable {
    case chess, sudoku, math, word

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chess: return "Chess"
        case .sudoku: return "Sudoku"
        case .math: return "Math"
        case .word: return "Word"
        }
    }

    /// Available difficulties, in display order.
    public var difficulties: [Difficulty] {
        switch self {
        case .sudoku: return [.quick, .easy, .medium, .hard]
        default: return [.easy, .medium, .hard]
        }
    }
}

public enum Difficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick, easy, medium, hard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .quick: return "Quick 6×6"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

public enum RoundStatus: String, Codable, Sendable {
    case playing, solved, failed
}

/// A single playable round of a puzzle game. A round reports `.solved` or `.failed`
/// (failed → a new round of the same game is served; it never counts).
public protocol PuzzleRound: Codable, Sendable {
    var game: GameID { get }
    var difficulty: Difficulty { get }
    var status: RoundStatus { get }
}

public protocol PuzzleGame: Sendable {
    var id: GameID { get }
    func makeRound(difficulty: Difficulty) async -> any PuzzleRound
}

/// Type-erased, persistable round (used to save a half-finished puzzle).
public enum AnyRound: Codable, Sendable {
    case word(WordRound)
    case chess(ChessRound)
    case sudoku(SudokuRound)
    case math(MathRound)

    public init?(_ round: any PuzzleRound) {
        switch round {
        case let r as WordRound: self = .word(r)
        case let r as ChessRound: self = .chess(r)
        case let r as SudokuRound: self = .sudoku(r)
        case let r as MathRound: self = .math(r)
        default: return nil
        }
    }

    public var round: any PuzzleRound {
        switch self {
        case .word(let r): return r
        case .chess(let r): return r
        case .sudoku(let r): return r
        case .math(let r): return r
        }
    }

    public var game: GameID { round.game }
}

/// Small seeded RNG so engines can be tested deterministically.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
