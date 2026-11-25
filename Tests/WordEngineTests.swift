import XCTest

final class WordEngineTests: XCTestCase {
    private typealias S = LetterScore

    func testScoringDuplicateLettersAbbeyBabes() {
        // answer ABBEY, guess BABES
        XCTAssertEqual(WordEngine.score(guess: "babes", answer: "abbey"),
                       [S.present, .present, .correct, .correct, .absent])
    }

    func testScoringDuplicateLettersSpeedEerie() {
        // answer SPEED, guess EERIE: two E's in the answer are not in E's positions 1,2 → yellow, yellow; R,I grey; last E grey.
        XCTAssertEqual(WordEngine.score(guess: "eerie", answer: "speed"),
                       [S.present, .present, .absent, .absent, .absent])
    }

    func testScoringExactMatch() {
        XCTAssertEqual(WordEngine.score(guess: "crane", answer: "crane"), Array(repeating: S.correct, count: 5))
    }

    func testOnboardingPreviewRows() {
        XCTAssertEqual(WordEngine.score(guess: "plant", answer: "plant"), Array(repeating: S.correct, count: 5))
        XCTAssertEqual(WordEngine.score(guess: "slant", answer: "plant"), [S.absent, .correct, .correct, .correct, .correct])
        XCTAssertEqual(WordEngine.score(guess: "crane", answer: "plant"), [S.absent, .absent, .correct, .correct, .absent])
    }

    func testRejectsWordsNotInList() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        for junk in ["abcde", "qwert", "xyzzy"] {
            XCTAssertFalse(dict.isAllowed(junk), junk)
            var round = WordRound(answer: "plant", difficulty: .easy)
            for ch in junk { round.type(ch) }
            XCTAssertEqual(round.submit(dictionary: dict), .notInWordList, junk)
            XCTAssertTrue(round.guesses.isEmpty)
        }
    }

    func testNotEnoughLettersAndKeyboardFilter() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        var round = WordRound(answer: "plant", difficulty: .easy)
        for ch in "pla" { round.type(ch) }
        XCTAssertEqual(round.submit(dictionary: dict), .notEnoughLetters)
        XCTAssertFalse(round.type("1"))
        XCTAssertFalse(round.type("é"))
        for ch in "ntxx" { round.type(ch) }
        XCTAssertEqual(round.current, "plant")
    }

    func testAnswersAreAllowedAndWellFormed() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        XCTAssertEqual(dict.answers.count, 2187) // 16 offensive or loaded words removed from the answer pool (still accepted as guesses)
        XCTAssertGreaterThanOrEqual(dict.allowed.count, 8647)
        for a in dict.answers {
            XCTAssertEqual(a.count, 5, a)
            XCTAssertTrue(a.allSatisfy { ("a"..."z").contains($0) }, a)
            XCTAssertTrue(dict.allowed.contains(a), a)
        }
    }

    func testWinAndLose() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        var win = WordRound(answer: "plant", difficulty: .easy)
        for ch in "plant" { win.type(ch) }
        XCTAssertEqual(win.submit(dictionary: dict), .accepted(Array(repeating: .correct, count: 5)))
        XCTAssertEqual(win.status, .solved)

        var lose = WordRound(answer: "plant", difficulty: .hard)
        XCTAssertEqual(lose.maxTries, 6)
        for _ in 0..<6 {
            for ch in "crane" { lose.type(ch) }
            _ = lose.submit(dictionary: dict)
        }
        XCTAssertEqual(lose.status, .failed)
    }

    /// Classic rules: a guess may ignore revealed hints at every difficulty.
    /// Classic rules: a guess may ignore revealed hints at every difficulty.
    func testGuessesMayIgnoreHints() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        for difficulty in [Difficulty.easy, .medium, .hard] {
            var round = WordRound(answer: "plant", difficulty: difficulty)
            for ch in "crane" { round.type(ch) }
            _ = round.submit(dictionary: dict)
            for ch in "moist" { round.type(ch) }   // no A, N: still allowed
            if case .accepted = round.submit(dictionary: dict) {} else { XCTFail("\(difficulty) should accept") }
        }
    }

    func testAnswerPickerNoRepeats() throws {
        let dict = try XCTUnwrap(TestResources.dictionary)
        var rng = SeededGenerator(seed: 1)
        var used = Set<String>()
        for _ in 0..<200 {
            let pick = dict.pickAnswer(excluding: used, using: &rng)
            XCTAssertFalse(used.contains(pick.answer))
            used.insert(pick.answer)
        }
    }
}
