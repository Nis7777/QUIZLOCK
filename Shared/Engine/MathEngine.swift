import Foundation

public struct MathQuestion: Codable, Hashable, Sendable {
    /// Topic sub-label, e.g. "ARITHMETIC", "ALGEBRA".
    public let topic: String
    /// Typeset question shown to the player (uses ×, ÷, −, ², √).
    public let text: String
    /// Machine-readable expression. Either an arithmetic expression, or an equation in `x`
    /// (contains "="). Supports + - * / ^, parentheses and sqrt(...).
    public let expression: String
    public let answer: Double

    public init(topic: String, text: String, expression: String, answer: Double) {
        self.topic = topic; self.text = text; self.expression = expression; self.answer = answer
    }

    public var answerText: String { MathEngine.format(answer) }
}

public enum MathEngine {
    public static let minus = "\u{2212}"

    /// Formats an answer as an integer or with at most 2 decimals.
    public static func format(_ v: Double) -> String {
        let rounded = (v * 100).rounded() / 100
        if rounded == rounded.rounded() {
            let i = Int(rounded)
            return i < 0 ? minus + String(-i) : String(i)
        }
        var s = String(format: "%.2f", abs(rounded))
        while s.hasSuffix("0") { s.removeLast() }
        return (rounded < 0 ? minus : "") + s
    }

    /// Parses the user's typed answer ("−12", "0.75", ".5").
    public static func parse(_ input: String) -> Double? {
        let s = input.replacingOccurrences(of: minus, with: "-").trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s != "-", s != "." else { return nil }
        return Double(s)
    }

    public static func isCorrect(_ input: String, answer: Double) -> Bool {
        guard let v = parse(input) else { return false }
        return abs(v - answer) < 0.000_1
    }

    private static func m(_ n: Int) -> String { n < 0 ? minus + String(-n) : String(n) }

    public static func generate<R: RandomNumberGenerator>(difficulty: Difficulty, using rng: inout R) -> MathQuestion {
        switch difficulty {
        case .quick, .easy:
            return Int.random(in: 0..<4, using: &rng) < 3 ? easyArithmetic(&rng) : easyPercent(&rng)
        case .medium:
            switch Int.random(in: 0..<4, using: &rng) {
            case 0: return mediumArithmetic(&rng)
            case 1: return mediumPercent(&rng)
            case 2: return linearEquation(&rng)
            default: return orderOfOperations(&rng)
            }
        case .hard:
            switch Int.random(in: 0..<4, using: &rng) {
            case 0: return hardMultiply(&rng)
            case 1: return twoStepEquation(&rng)
            case 2: return powersAndRoots(&rng)
            default: return fractionToDecimal(&rng)
            }
        }
    }

    // MARK: Easy

    static func easyArithmetic<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        switch Int.random(in: 0..<4, using: &rng) {
        case 0:
            let a = Int.random(in: 10...99, using: &rng), b = Int.random(in: 10...99, using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) + \(b) = ?", expression: "\(a)+\(b)", answer: Double(a + b))
        case 1:
            let a = Int.random(in: 20...99, using: &rng), b = Int.random(in: 10...(a - 1), using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) \(minus) \(b) = ?", expression: "\(a)-\(b)", answer: Double(a - b))
        case 2:
            let a = Int.random(in: 2...12, using: &rng), b = Int.random(in: 2...12, using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) × \(b) = ?", expression: "\(a)*\(b)", answer: Double(a * b))
        default:
            let b = Int.random(in: 2...12, using: &rng), q = Int.random(in: 2...12, using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(b * q) ÷ \(b) = ?", expression: "\(b * q)/\(b)", answer: Double(q))
        }
    }

    static func easyPercent<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        let p = [10, 25, 50].randomElement(using: &rng) ?? 10
        let n = Int.random(in: 1...20, using: &rng) * 20
        return MathQuestion(topic: "PERCENT", text: "What is \(p)% of \(n)?", expression: "\(p)/100*\(n)", answer: Double(p * n) / 100)
    }

    // MARK: Medium

    static func mediumArithmetic<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        switch Int.random(in: 0..<3, using: &rng) {
        case 0:
            let a = Int.random(in: 100...999, using: &rng), b = Int.random(in: 100...999, using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) + \(b) = ?", expression: "\(a)+\(b)", answer: Double(a + b))
        case 1:
            let a = Int.random(in: 200...999, using: &rng), b = Int.random(in: 100...(a - 1), using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) \(minus) \(b) = ?", expression: "\(a)-\(b)", answer: Double(a - b))
        default:
            let a = Int.random(in: 12...99, using: &rng), b = Int.random(in: 3...9, using: &rng)
            return MathQuestion(topic: "ARITHMETIC", text: "\(a) × \(b) = ?", expression: "\(a)*\(b)", answer: Double(a * b))
        }
    }

    static func mediumPercent<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        let p = [5, 15, 20, 30, 40, 60, 75].randomElement(using: &rng) ?? 15
        let n = Int.random(in: 1...20, using: &rng) * 20
        return MathQuestion(topic: "PERCENT", text: "What is \(p)% of \(n)?", expression: "\(p)/100*\(n)", answer: Double(p * n) / 100)
    }

    static func linearEquation<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        let a = Int.random(in: 2...9, using: &rng), x = Int.random(in: 1...12, using: &rng), b = Int.random(in: 1...20, using: &rng)
        let subtract = Bool.random(using: &rng) && a * x > b
        let c = subtract ? a * x - b : a * x + b
        let op = subtract ? minus : "+"
        let exprOp = subtract ? "-" : "+"
        return MathQuestion(topic: "ALGEBRA", text: "If \(a)x \(op) \(b) = \(c), what is x?",
                            expression: "\(a)*x\(exprOp)\(b)=\(c)", answer: Double(x))
    }

    static func orderOfOperations<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        switch Int.random(in: 0..<4, using: &rng) {
        case 0:
            let a = Int.random(in: 2...20, using: &rng), b = Int.random(in: 2...9, using: &rng), c = Int.random(in: 2...9, using: &rng)
            return MathQuestion(topic: "ORDER OF OPERATIONS", text: "\(a) + \(b) × \(c) = ?", expression: "\(a)+\(b)*\(c)", answer: Double(a + b * c))
        case 1:
            let a = Int.random(in: 2...9, using: &rng), b = Int.random(in: 2...9, using: &rng), c = Int.random(in: 2...9, using: &rng)
            return MathQuestion(topic: "ORDER OF OPERATIONS", text: "(\(a) + \(b)) × \(c) = ?", expression: "(\(a)+\(b))*\(c)", answer: Double((a + b) * c))
        case 2:
            let a = Int.random(in: 3...12, using: &rng), b = Int.random(in: 3...12, using: &rng), c = Int.random(in: 2...20, using: &rng)
            return MathQuestion(topic: "ORDER OF OPERATIONS", text: "\(a) × \(b) \(minus) \(c) = ?", expression: "\(a)*\(b)-\(c)", answer: Double(a * b - c))
        default:
            let c = Int.random(in: 2...9, using: &rng), q = Int.random(in: 2...9, using: &rng), a = Int.random(in: 10...50, using: &rng)
            return MathQuestion(topic: "ORDER OF OPERATIONS", text: "\(a) \(minus) \(c * q) ÷ \(c) = ?", expression: "\(a)-\(c * q)/\(c)", answer: Double(a - q))
        }
    }

    // MARK: Hard

    static func hardMultiply<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        let a = Int.random(in: 11...99, using: &rng), b = Int.random(in: 11...99, using: &rng)
        return MathQuestion(topic: "ARITHMETIC", text: "\(a) × \(b) = ?", expression: "\(a)*\(b)", answer: Double(a * b))
    }

    static func twoStepEquation<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        let x = Int.random(in: -9...15, using: &rng)
        if Bool.random(using: &rng) {
            // a·x + b = c·x + d
            let c = Int.random(in: 2...6, using: &rng), a = c + Int.random(in: 1...5, using: &rng)
            let b = Int.random(in: 1...20, using: &rng)
            let d = (a - c) * x + b
            let dText = d < 0 ? "\(minus) \(-d)" : "+ \(d)"
            let dExpr = d < 0 ? "-\(-d)" : "+\(d)"
            return MathQuestion(topic: "ALGEBRA", text: "Solve for x:\n\(a)x + \(b) = \(c)x \(dText)",
                                expression: "\(a)*x+\(b)=\(c)*x\(dExpr)", answer: Double(x))
        } else {
            // a(x − b) = c
            let a = Int.random(in: 2...9, using: &rng), b = Int.random(in: 1...9, using: &rng)
            let c = a * (x - b)
            return MathQuestion(topic: "ALGEBRA", text: "Solve for x:\n\(a)(x \(minus) \(b)) = \(m(c))",
                                expression: "\(a)*(x-\(b))=\(c)", answer: Double(x))
        }
    }

    static func powersAndRoots<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        switch Int.random(in: 0..<3, using: &rng) {
        case 0:
            let n = Int.random(in: 11...25, using: &rng)
            return MathQuestion(topic: "SQUARES & ROOTS", text: "\(n)² = ?", expression: "\(n)^2", answer: Double(n * n))
        case 1:
            let n = Int.random(in: 11...30, using: &rng)
            return MathQuestion(topic: "SQUARES & ROOTS", text: "√\(n * n) = ?", expression: "sqrt(\(n * n))", answer: Double(n))
        default:
            let n = Int.random(in: 2...9, using: &rng), k = Int.random(in: 2...9, using: &rng)
            return MathQuestion(topic: "SQUARES & ROOTS", text: "\(n)² + √\(k * k) = ?", expression: "\(n)^2+sqrt(\(k * k))", answer: Double(n * n + k))
        }
    }

    static func fractionToDecimal<R: RandomNumberGenerator>(_ rng: inout R) -> MathQuestion {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        let q = [4, 5, 20, 25, 50].randomElement(using: &rng) ?? 4
        var p = Int.random(in: 1..<q, using: &rng)
        while gcd(p, q) != 1 { p = Int.random(in: 1..<q, using: &rng) }
        return MathQuestion(topic: "FRACTIONS", text: "Write \(p)/\(q) as a decimal", expression: "\(p)/\(q)", answer: Double(p) / Double(q))
    }
}

public struct MathRound: PuzzleRound, Equatable {
    public var game: GameID { .math }
    public let difficulty: Difficulty
    public let question: MathQuestion
    public static let maxWrong = 3

    public var input: String = ""
    public private(set) var wrongCount = 0
    public private(set) var status: RoundStatus = .playing

    public init(question: MathQuestion, difficulty: Difficulty) {
        self.question = question
        self.difficulty = difficulty
    }

    public enum CheckResult: Equatable { case correct, wrong(triesLeft: Int), failed, empty }

    public mutating func type(_ key: String) {
        guard status == .playing, input.count < 9 || key == MathEngine.minus || key == "-" else { return }
        switch key {
        case ".":
            if !input.contains(".") { input += input.isEmpty || input == MathEngine.minus ? "0." : "." }
        case MathEngine.minus, "-":
            // Toggles the sign at any point, like a calculator's ± key.
            if input.hasPrefix(MathEngine.minus) { input.removeFirst() } else { input = MathEngine.minus + input }
        default:
            if key.count == 1, key.first?.isNumber == true { input += key }
        }
    }

    public mutating func backspace() {
        guard status == .playing, !input.isEmpty else { return }
        input.removeLast()
    }

    public mutating func check() -> CheckResult {
        guard status == .playing else { return status == .solved ? .correct : .failed }
        guard MathEngine.parse(input) != nil else { return .empty }
        if MathEngine.isCorrect(input, answer: question.answer) {
            status = .solved
            return .correct
        }
        wrongCount += 1
        input = ""
        if wrongCount >= Self.maxWrong {
            status = .failed
            return .failed
        }
        return .wrong(triesLeft: Self.maxWrong - wrongCount)
    }
}

public struct MathGame: PuzzleGame {
    public let id: GameID = .math
    public init() {}

    public func makeRound(difficulty: Difficulty) async -> any PuzzleRound {
        var rng = SystemRandomNumberGenerator()
        return MathRound(question: MathEngine.generate(difficulty: difficulty, using: &rng), difficulty: difficulty)
    }
}
