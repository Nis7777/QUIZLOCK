import XCTest

final class SudokuEngineTests: XCTestCase {
    func testGeneratedPuzzlesHaveUniqueSolutionAndRightGivens() {
        for difficulty in [Difficulty.quick, .easy, .medium, .hard] {
            var rng = SeededGenerator(seed: 42)
            let range = SudokuLayout.givens(for: difficulty)
            for n in 0..<50 {
                let p = SudokuGenerator.generate(difficulty: difficulty, using: &rng)
                XCTAssertEqual(SudokuSolver.countSolutions(p.puzzle, layout: p.layout, limit: 2), 1, "\(difficulty) #\(n)")
                XCTAssertTrue(range.contains(p.givensCount), "\(difficulty) #\(n): \(p.givensCount) givens")
                XCTAssertEqual(p.layout.size, difficulty == .quick ? 6 : 9)
                // Givens agree with the solution, and the solution is valid.
                for i in 0..<p.layout.cellCount where p.puzzle[i] != 0 { XCTAssertEqual(p.puzzle[i], p.solution[i]) }
                XCTAssertEqual(SudokuSolver.countSolutions(p.solution, layout: p.layout), 1)
            }
        }
    }

    func testRoundConflictsHintsAndSolve() {
        var rng = SeededGenerator(seed: 3)
        let p = SudokuGenerator.nearlySolved(blanks: 4, using: &rng)
        XCTAssertEqual(p.givensCount, 77)
        XCTAssertEqual(SudokuSolver.countSolutions(p.puzzle, layout: p.layout), 1)
        var round = SudokuRound(puzzle: p, difficulty: .easy)
        let empties = (0..<81).filter { p.puzzle[$0] == 0 }
        // Put a wrong digit that duplicates a peer → conflict.
        let e = empties[0]
        let givenInRow = (72..<81).first { p.puzzle[$0] != 0 }!
        round.set(p.puzzle[givenInRow], at: e)
        XCTAssertTrue(round.conflicts.contains(e))
        round.erase(at: e)
        XCTAssertTrue(round.conflicts.isEmpty)
        for i in empties.dropLast() { round.set(p.solution[i], at: i) }
        XCTAssertEqual(round.status, .playing)
        XCTAssertNotNil(round.hint(at: nil))
        XCTAssertEqual(round.status, .solved)
    }
}
