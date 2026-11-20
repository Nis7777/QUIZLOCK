import Foundation

public enum LetterScore: Int, Codable, Sendable, Comparable {
    case absent = 0, present = 1, correct = 2
    public static func < (a: LetterScore, b: LetterScore) -> Bool { a.rawValue < b.rawValue }
}

/// Loads the two word lists once.
public final class WordDictionary: @unchecked Sendable {
    public let allowed: Set<String>
    public let answers: [String]

    public init(allowed: Set<String>, answers: [String]) {
        self.allowed = allowed
        self.answers = answers
    }

    public convenience init(allowedText: String, answersText: String) {
        func parse(_ s: String) -> [String] {
            s.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { WordEngine.isFiveLetters($0) }
        }
        let answers = parse(answersText)
        // Answers are always valid guesses as well.
        self.init(allowed: Set(parse(allowedText)).union(answers), answers: answers)
    }

    public convenience init?(allowedURL: URL, answersURL: URL) {
        guard let a = try? String(contentsOf: allowedURL, encoding: .utf8),
              let b = try? String(contentsOf: answersURL, encoding: .utf8) else { return nil }
        self.init(allowedText: a, answersText: b)
    }

    /// Loads `wordle_allowed.txt` and `wordle_answers.txt` from a bundle.
    public static func load(from bundle: Bundle) -> WordDictionary? {
        guard let a = bundle.url(forResource: "wordle_allowed", withExtension: "txt"),
              let b = bundle.url(forResource: "wordle_answers", withExtension: "txt") else { return nil }
        return WordDictionary(allowedURL: a, answersURL: b)
    }

    public func isAllowed(_ word: String) -> Bool {
        let w = word.lowercased()
        return WordEngine.isFiveLetters(w) && allowed.contains(w)
    }

    /// Picks a random answer that hasn't been used yet. When every answer has been used,
    /// the cycle restarts (the caller should then clear its used set).
    public func pickAnswer<R: RandomNumberGenerator>(excluding used: Set<String>, using rng: inout R) -> (answer: String, cycleReset: Bool) {
        let fresh = answers.filter { !used.contains($0) }
        if let pick = fresh.randomElement(using: &rng) { return (pick, false) }
        return (answers.randomElement(using: &rng) ?? "plant", true)
    }
}

public enum WordEngine {
    public static let length = 5

    public static func isFiveLetters(_ s: String) -> Bool {
        s.count == length && s.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
    }

    /// Two-pass scoring that handles duplicate letters correctly.
    public static func score(guess: String, answer: String) -> [LetterScore] {
        let g = Array(guess.lowercased())
        let a = Array(answer.lowercased())
        precondition(g.count == a.count, "guess and answer must be the same length")
        var result = [LetterScore](repeating: .absent, count: g.count)
        var remaining: [Character: Int] = [:]
        // Pass 1: exact matches.
        for i in 0..<g.count {
            if g[i] == a[i] {
                result[i] = .correct
            } else {
                remaining[a[i], default: 0] += 1
            }
        }
        // Pass 2: present letters, only while the answer still has unmatched copies.
        for i in 0..<g.count where result[i] != .correct {
            if let n = remaining[g[i]], n > 0 {
                result[i] = .present
                remaining[g[i]] = n - 1
            }
        }
        return result
    }
}

public enum GuessResult: Equatable, Sendable {
    case notEnoughLetters
    case notInWordList
    case hardMode(String)
    case accepted([LetterScore])
    case roundOver
}

public struct WordRound: PuzzleRound, Equatable {
    public var game: GameID { .word }
    public let difficulty: Difficulty
    public let answer: String
    public let maxTries: Int
    public let hardMode: Bool
    public private(set) var guesses: [String] = []
    public private(set) var scores: [[LetterScore]] = []
    public private(set) var status: RoundStatus = .playing
    /// Letters typed into the current (unsubmitted) row.
    public var current: String = ""

    public init(answer: String, difficulty: Difficulty) {
        self.answer = answer.lowercased()
        self.difficulty = difficulty
        switch difficulty {
        case .quick, .easy:
            maxTries = 6; hardMode = false
        case .medium:
            maxTries = 6; hardMode = true
        case .hard:
            maxTries = 5; hardMode = true
        }
    }

    public var triesLeft: Int { maxTries - guesses.count }

    /// Types a letter. Only A–Z, and the row stops at 5 letters.
    @discardableResult
    public mutating func type(_ ch: Character) -> Bool {
        guard status == .playing, current.count < WordEngine.length else { return false }
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1,
              ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) else { return false }
        current.append(Character(String(ch).lowercased()))
        return true
    }

    @discardableResult
    public mutating func deleteLast() -> Bool {
        guard status == .playing, !current.isEmpty else { return false }
        current.removeLast()
        return true
    }

    public mutating func submit(dictionary: WordDictionary) -> GuessResult {
        guard status == .playing else { return .roundOver }
        let guess = current.lowercased()
        guard guess.count == WordEngine.length else { return .notEnoughLetters }
        guard dictionary.isAllowed(guess) else { return .notInWordList }
        if hardMode, let violation = hardModeViolation(guess) { return .hardMode(violation) }
        let s = WordEngine.score(guess: guess, answer: answer)
        guesses.append(guess)
        scores.append(s)
        current = ""
        if guess == answer {
            status = .solved
        } else if guesses.count >= maxTries {
            status = .failed
        }
        return .accepted(s)
    }

    /// Hard mode: revealed hints must be used in later guesses.
    public func hardModeViolation(_ guess: String) -> String? {
        let g = Array(guess)
        for (word, score) in zip(guesses, scores) {
            let w = Array(word)
            for i in 0..<w.count where score[i] == .correct && g[i] != w[i] {
                return "\(Self.ordinal(i + 1)) letter must be \(String(w[i]).uppercased())"
            }
            // Required counts of present/correct letters.
            var needed: [Character: Int] = [:]
            for i in 0..<w.count where score[i] != .absent { needed[w[i], default: 0] += 1 }
            for (ch, n) in needed.sorted(by: { $0.key < $1.key }) where g.filter({ $0 == ch }).count < n {
                return "Guess must contain \(String(ch).uppercased())"
            }
        }
        return nil
    }

    static func ordinal(_ n: Int) -> String {
        switch n { case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"; default: return "\(n)th" }
    }

    /// Best colour seen for each letter (green > yellow > grey).
    public var keyboardState: [Character: LetterScore] {
        var map: [Character: LetterScore] = [:]
        for (word, score) in zip(guesses, scores) {
            for (ch, s) in zip(word, score) {
                if let existing = map[ch], existing >= s { continue }
                map[ch] = s
            }
        }
        return map
    }
}

public struct WordGame: PuzzleGame {
    public let id: GameID = .word
    public let dictionary: WordDictionary
    private let usedProvider: @Sendable () -> Set<String>
    private let markUsed: @Sendable (String, Bool) -> Void

    /// - Parameters:
    ///   - usedProvider: returns the answers already used (persisted in the App Group).
    ///   - markUsed: records an answer as used; the Bool is true when the cycle was reset.
    public init(dictionary: WordDictionary,
                usedProvider: @escaping @Sendable () -> Set<String> = { [] },
                markUsed: @escaping @Sendable (String, Bool) -> Void = { _, _ in }) {
        self.dictionary = dictionary
        self.usedProvider = usedProvider
        self.markUsed = markUsed
    }

    public func makeRound(difficulty: Difficulty) async -> any PuzzleRound {
        var rng = SystemRandomNumberGenerator()
        let pick = dictionary.pickAnswer(excluding: usedProvider(), using: &rng)
        markUsed(pick.answer, pick.cycleReset)
        return WordRound(answer: pick.answer, difficulty: difficulty)
    }
}
