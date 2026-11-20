import XCTest

final class ChessEngineTests: XCTestCase {
    func testPerftStartPositionDepth3() {
        XCTAssertEqual(Position.start.perft(1), 20)
        XCTAssertEqual(Position.start.perft(2), 400)
        XCTAssertEqual(Position.start.perft(3), 8902)
    }

    func testPerftKiwipeteDepth2() throws {
        let p = try Position(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        XCTAssertEqual(p.perft(1), 48)
        XCTAssertEqual(p.perft(2), 2039)
    }

    func testPerftEdgeCases() throws {
        // Position 3 and 4 from the Chess Programming Wiki (en passant, promotion, checks).
        XCTAssertEqual(try Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1").perft(3), 2812)
        XCTAssertEqual(try Position(fen: "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1").perft(3), 9467)
    }

    func testFENRoundTripAndSAN() throws {
        XCTAssertEqual(Position.start.fen, Position.startFEN)
        let p = try Position(fen: "6k1/5ppp/8/8/8/8/q4PPP/3R2K1 w - - 0 1")
        XCTAssertEqual(p.san(Move(uci: "d1d8")!), "Rd8#")
        XCTAssertTrue(p.applying(unchecked: Move(uci: "d1d8")!).isCheckmate)
    }

    func testFallbackPuzzle() throws {
        var round = try ChessRound(puzzle: ChessPuzzleBank.fallback, difficulty: .easy)
        XCTAssertEqual(round.headerText, "White to move. Mate in one.")
        XCTAssertEqual(round.play(Move(uci: "g1f1")!), .wrong(triesLeft: 2))
        XCTAssertEqual(round.play(Move(uci: "d1d8")!), .solved(san: "Rd8#"))
    }

    func testEveryBundledPuzzleIsLegalAndEndsInMate() throws {
        let bank = try XCTUnwrap(TestResources.chessBank)
        XCTAssertGreaterThan(bank.puzzles.count, 100)
        for d in [Difficulty.easy, .medium, .hard] { XCTAssertFalse(bank.puzzles(for: d).isEmpty, "\(d)") }
        XCTAssertEqual(bank.firstEasyMateInOne?.mateIn, 1)
        for puzzle in bank.puzzles {
            var pos = try puzzle.startPosition()
            XCTAssertEqual(puzzle.solution.count, puzzle.mateIn * 2 - 1, puzzle.id)
            for uci in puzzle.solution {
                let m = try XCTUnwrap(Move(uci: uci), puzzle.id)
                XCTAssertTrue(pos.isLegal(m), "\(puzzle.id): \(uci) illegal in \(pos.fen)")
                pos = pos.applying(unchecked: m)
            }
            XCTAssertTrue(pos.isCheckmate, "\(puzzle.id) does not end in mate")
            // And the round accepts the full line.
            var round = try ChessRound(puzzle: puzzle, difficulty: puzzle.difficulty)
            for (i, uci) in puzzle.solution.enumerated() where i % 2 == 0 {
                let outcome = round.play(Move(uci: uci)!)
                if i == puzzle.solution.count - 1 {
                    if case .solved = outcome {} else { XCTFail("\(puzzle.id): final move not accepted") }
                } else {
                    XCTAssertEqual(round.playOpponentReply(), Move(uci: puzzle.solution[i + 1]))
                }
            }
            XCTAssertEqual(round.status, .solved, puzzle.id)
        }
    }
}
