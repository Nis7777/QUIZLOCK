import Foundation

/// Grid geometry: 9×9 with 3×3 boxes, or 6×6 with 2×3 boxes (2 rows × 3 columns).
public struct SudokuLayout: Codable, Hashable, Sendable {
    public let size: Int
    public let boxRows: Int
    public let boxCols: Int

    public static let classic = SudokuLayout(size: 9, boxRows: 3, boxCols: 3)
    public static let quick = SudokuLayout(size: 6, boxRows: 2, boxCols: 3)

    public var cellCount: Int { size * size }
    public func row(_ i: Int) -> Int { i / size }
    public func col(_ i: Int) -> Int { i % size }
    public func box(_ i: Int) -> Int { (row(i) / boxRows) * (size / boxCols) + col(i) / boxCols }

    /// Indices of all cells sharing a row, column or box with `i` (excluding `i`).
    public func peers(of i: Int) -> [Int] {
        (0..<cellCount).filter { $0 != i && (row($0) == row(i) || col($0) == col(i) || box($0) == box(i)) }
    }

    public static func forDifficulty(_ d: Difficulty) -> SudokuLayout { d == .quick ? .quick : .classic }

    /// Givens range per difficulty.
    public static func givens(for d: Difficulty) -> ClosedRange<Int> {
        switch d {
        case .quick: return 17...19
        case .easy: return 40...45
        case .medium: return 32...36
        case .hard: return 26...30
        }
    }
}

public enum SudokuSolver {
    /// Counts solutions, stopping at `limit`. `grid` uses 0 for empty.
    public static func countSolutions(_ grid: [Int], layout: SudokuLayout, limit: Int = 2) -> Int {
        var g = grid
        var rows = [Int](repeating: 0, count: layout.size)
        var cols = [Int](repeating: 0, count: layout.size)
        var boxes = [Int](repeating: 0, count: layout.size)
        for i in 0..<layout.cellCount where g[i] != 0 {
            let bit = 1 << g[i]
            if rows[layout.row(i)] & bit != 0 || cols[layout.col(i)] & bit != 0 || boxes[layout.box(i)] & bit != 0 { return 0 }
            rows[layout.row(i)] |= bit; cols[layout.col(i)] |= bit; boxes[layout.box(i)] |= bit
        }
        var count = 0
        let full = ((1 << (layout.size + 1)) - 1) & ~1

        func search() {
            if count >= limit { return }
            // Most-constrained empty cell.
            var best = -1, bestMask = 0, bestCount = Int.max
            for i in 0..<layout.cellCount where g[i] == 0 {
                let mask = full & ~(rows[layout.row(i)] | cols[layout.col(i)] | boxes[layout.box(i)])
                let c = mask.nonzeroBitCount
                if c < bestCount { best = i; bestMask = mask; bestCount = c; if c <= 1 { break } }
            }
            if best == -1 { count += 1; return }
            if bestCount == 0 { return }
            let r = layout.row(best), c = layout.col(best), b = layout.box(best)
            var m = bestMask
            while m != 0 {
                let bit = m & -m
                m &= m - 1
                let d = bit.trailingZeroBitCount
                g[best] = d
                rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
                search()
                rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit
                g[best] = 0
                if count >= limit { return }
            }
        }
        search()
        return count
    }

    /// Fills a complete valid grid using randomized backtracking.
    public static func randomFilledGrid<R: RandomNumberGenerator>(layout: SudokuLayout, using rng: inout R) -> [Int] {
        var g = [Int](repeating: 0, count: layout.cellCount)
        func valid(_ i: Int, _ d: Int) -> Bool {
            for p in layout.peers(of: i) where g[p] == d { return false }
            return true
        }
        func fill(_ i: Int) -> Bool {
            if i == layout.cellCount { return true }
            for d in Array(1...layout.size).shuffled(using: &rng) where valid(i, d) {
                g[i] = d
                if fill(i + 1) { return true }
                g[i] = 0
            }
            return false
        }
        _ = fill(0)
        return g
    }
}

public struct SudokuPuzzle: Codable, Hashable, Sendable {
    public let layout: SudokuLayout
    public let puzzle: [Int]
    public let solution: [Int]
    public var givensCount: Int { puzzle.filter { $0 != 0 }.count }
}

public enum SudokuGenerator {
    public static func generate<R: RandomNumberGenerator>(difficulty: Difficulty, using rng: inout R) -> SudokuPuzzle {
        let layout = SudokuLayout.forDifficulty(difficulty)
        let range = SudokuLayout.givens(for: difficulty)
        var bestAttempt: SudokuPuzzle?
        for _ in 0..<40 {
            let solution = SudokuSolver.randomFilledGrid(layout: layout, using: &rng)
            let target = Int.random(in: range, using: &rng)
            var puzzle = solution
            var givens = layout.cellCount
            // Symmetric pairs (point symmetry through the centre).
            var pairs: [[Int]] = []
            for i in 0..<layout.cellCount {
                let j = layout.cellCount - 1 - i
                if i < j { pairs.append([i, j]) } else if i == j { pairs.append([i]) }
            }
            pairs.shuffle(using: &rng)
            for pair in pairs {
                if givens <= target { break }
                if givens - pair.count < range.lowerBound { continue }
                let saved = pair.map { puzzle[$0] }
                for i in pair { puzzle[i] = 0 }
                if SudokuSolver.countSolutions(puzzle, layout: layout, limit: 2) == 1 {
                    givens -= pair.count
                } else {
                    for (k, i) in pair.enumerated() { puzzle[i] = saved[k] }
                }
            }
            let result = SudokuPuzzle(layout: layout, puzzle: puzzle, solution: solution)
            if range.contains(givens) { return result }
            if let best = bestAttempt, best.givensCount <= givens { continue }
            bestAttempt = result
        }
        // Unreachable in practice (40 attempts); fall back to a nearly solved grid rather than crash.
        return bestAttempt ?? nearlySolved(blanks: 4, using: &rng)
    }

    /// A valid 9×9 puzzle with only `blanks` empty cells, all in the bottom row (onboarding).
    public static func nearlySolved<R: RandomNumberGenerator>(blanks: Int = 4, using rng: inout R) -> SudokuPuzzle {
        let layout = SudokuLayout.classic
        let solution = SudokuSolver.randomFilledGrid(layout: layout, using: &rng)
        var puzzle = solution
        let lastRow = (0..<9).map { 72 + $0 }.shuffled(using: &rng).prefix(blanks)
        for i in lastRow { puzzle[i] = 0 }
        return SudokuPuzzle(layout: layout, puzzle: puzzle, solution: solution)
    }
}

public struct SudokuRound: PuzzleRound, Equatable {
    public var game: GameID { .sudoku }
    public let difficulty: Difficulty
    public let puzzle: SudokuPuzzle
    public static let maxHints = 3

    /// Current digits (givens + user entries), 0 = empty.
    public private(set) var cells: [Int]
    /// Pencil marks per cell as a bitmask (bit d set = note d).
    public private(set) var notes: [Int]
    public private(set) var hintsUsed: Int = 0
    public private(set) var status: RoundStatus = .playing

    public init(puzzle: SudokuPuzzle, difficulty: Difficulty) {
        self.puzzle = puzzle
        self.difficulty = difficulty
        self.cells = puzzle.puzzle
        self.notes = [Int](repeating: 0, count: puzzle.layout.cellCount)
    }

    public var layout: SudokuLayout { puzzle.layout }
    public func isGiven(_ i: Int) -> Bool { puzzle.puzzle[i] != 0 }
    public var hintsLeft: Int { Self.maxHints - hintsUsed }

    public mutating func set(_ digit: Int, at i: Int) {
        guard status == .playing, !isGiven(i), (1...layout.size).contains(digit) else { return }
        cells[i] = digit
        notes[i] = 0
        // Remove this digit from peers' notes.
        for p in layout.peers(of: i) { notes[p] &= ~(1 << digit) }
        checkSolved()
    }

    public mutating func toggleNote(_ digit: Int, at i: Int) {
        guard status == .playing, !isGiven(i), cells[i] == 0, (1...layout.size).contains(digit) else { return }
        notes[i] ^= (1 << digit)
    }

    public func hasNote(_ digit: Int, at i: Int) -> Bool { notes[i] & (1 << digit) != 0 }

    public mutating func erase(at i: Int) {
        guard status == .playing, !isGiven(i) else { return }
        cells[i] = 0
        notes[i] = 0
    }

    /// Fills the given cell (or a random empty / wrong cell) with the correct digit. Returns the cell filled.
    @discardableResult
    public mutating func hint(at selected: Int?) -> Int? {
        guard status == .playing, hintsUsed < Self.maxHints else { return nil }
        let target: Int?
        if let s = selected, !isGiven(s), cells[s] != puzzle.solution[s] {
            target = s
        } else {
            target = (0..<layout.cellCount).filter { cells[$0] != puzzle.solution[$0] }.randomElement()
        }
        guard let t = target else { return nil }
        hintsUsed += 1
        set(puzzle.solution[t], at: t)
        return t
    }

    /// Cells that duplicate a digit in their row, column or box.
    public var conflicts: Set<Int> {
        var result = Set<Int>()
        for i in 0..<layout.cellCount where cells[i] != 0 {
            for p in layout.peers(of: i) where cells[p] == cells[i] {
                result.insert(i)
                break
            }
        }
        return result
    }

    /// How many times each digit is placed.
    public func placedCount(_ digit: Int) -> Int { cells.filter { $0 == digit }.count }

    public var isComplete: Bool { cells == puzzle.solution }

    private mutating func checkSolved() {
        if isComplete { status = .solved }
    }
}

public struct SudokuGame: PuzzleGame {
    public let id: GameID = .sudoku
    public init() {}

    public func makeRound(difficulty: Difficulty) async -> any PuzzleRound {
        await Task.detached(priority: .userInitiated) {
            var rng = SystemRandomNumberGenerator()
            let puzzle = SudokuGenerator.generate(difficulty: difficulty, using: &rng)
            return SudokuRound(puzzle: puzzle, difficulty: difficulty)
        }.value
    }
}
