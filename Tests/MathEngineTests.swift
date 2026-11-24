import XCTest

/// An independent recursive-descent evaluator used to verify generated questions.
private struct ExpressionEvaluator {
    private let chars: [Character]
    private var pos = 0
    private let x: Double

    init(_ s: String, x: Double = 0) { chars = Array(s.replacingOccurrences(of: " ", with: "")); self.x = x }

    static func evaluate(_ s: String, x: Double = 0) -> Double? {
        var e = ExpressionEvaluator(s, x: x)
        guard let v = e.expr(), e.pos == e.chars.count else { return nil }
        return v
    }

    private mutating func expr() -> Double? {
        guard var v = term() else { return nil }
        while pos < chars.count, chars[pos] == "+" || chars[pos] == "-" {
            let op = chars[pos]; pos += 1
            guard let r = term() else { return nil }
            v = op == "+" ? v + r : v - r
        }
        return v
    }

    private mutating func term() -> Double? {
        guard var v = power() else { return nil }
        while pos < chars.count, chars[pos] == "*" || chars[pos] == "/" {
            let op = chars[pos]; pos += 1
            guard let r = power() else { return nil }
            v = op == "*" ? v * r : v / r
        }
        return v
    }

    private mutating func power() -> Double? {
        guard let base = unary() else { return nil }
        if pos < chars.count, chars[pos] == "^" {
            pos += 1
            guard let e = power() else { return nil }
            return Foundation.pow(base, e)
        }
        return base
    }

    private mutating func unary() -> Double? {
        if pos < chars.count, chars[pos] == "-" { pos += 1; return unary().map { -$0 } }
        return primary()
    }

    private mutating func primary() -> Double? {
        guard pos < chars.count else { return nil }
        if chars[pos] == "(" {
            pos += 1
            let v = expr()
            guard pos < chars.count, chars[pos] == ")" else { return nil }
            pos += 1
            return v
        }
        if chars[pos] == "x" { pos += 1; return x }
        if String(chars[pos...].prefix(5)) == "sqrt(" {
            pos += 4
            return primary().map { $0.squareRoot() }
        }
        var s = ""
        while pos < chars.count, chars[pos].isNumber || chars[pos] == "." { s.append(chars[pos]); pos += 1 }
        return Double(s)
    }
}

final class MathEngineTests: XCTestCase {
    func testGeneratedAnswersMatchIndependentEvaluation() {
        for difficulty in [Difficulty.easy, .medium, .hard] {
            var rng = SeededGenerator(seed: UInt64(difficulty.hashValue & 0xFFFF) + 7)
            for _ in 0..<1000 {
                let q = MathEngine.generate(difficulty: difficulty, using: &rng)
                if q.expression.contains("=") {
                    let sides = q.expression.split(separator: "=").map(String.init)
                    XCTAssertEqual(sides.count, 2, q.expression)
                    let l = ExpressionEvaluator.evaluate(sides[0], x: q.answer)
                    let r = ExpressionEvaluator.evaluate(sides[1], x: q.answer)
                    XCTAssertNotNil(l, q.expression); XCTAssertNotNil(r, q.expression)
                    XCTAssertEqual(l ?? .nan, r ?? .nan, accuracy: 1e-9, q.expression)
                } else {
                    let v = ExpressionEvaluator.evaluate(q.expression)
                    XCTAssertNotNil(v, q.expression)
                    XCTAssertEqual(v ?? .nan, q.answer, accuracy: 1e-9, q.expression)
                }
                // Integer, or at most 2 decimal places.
                XCTAssertEqual((q.answer * 100).rounded(), q.answer * 100, accuracy: 1e-9, q.text)
                XCTAssertFalse(q.topic.isEmpty)
            }
        }
    }

    func testRoundFlow() {
        let q = MathQuestion(topic: "ALGEBRA", text: "If 3x + 5 = 20, what is x?", expression: "3*x+5=20", answer: 5)
        var round = MathRound(question: q, difficulty: .easy)
        round.type("4")
        XCTAssertEqual(round.check(), .wrong(triesLeft: 2))
        XCTAssertEqual(round.input, "")
        round.type("5")
        XCTAssertEqual(round.check(), .correct)
        XCTAssertEqual(round.status, .solved)

        var failing = MathRound(question: q, difficulty: .easy)
        for _ in 0..<3 { failing.type("1"); _ = failing.check() }
        XCTAssertEqual(failing.status, .failed)
    }

    func testParsingAndFormatting() {
        XCTAssertEqual(MathEngine.parse("\u{2212}12"), -12)
        XCTAssertEqual(MathEngine.parse("0.75"), 0.75)
        XCTAssertNil(MathEngine.parse("\u{2212}"))
        XCTAssertEqual(MathEngine.format(0.35), "0.35")
        XCTAssertEqual(MathEngine.format(12), "12")
        XCTAssertEqual(MathEngine.format(-3), "\u{2212}3")
        XCTAssertEqual(MathEngine.format(2.5), "2.5")
    }
}
