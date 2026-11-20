import SwiftUI

/// Two stacked toggle pills (Settings tab icon, "You're all set" banner).
struct TogglePillsIcon: View {
    var color: Color
    var size: CGFloat = 26

    var body: some View {
        VStack(spacing: size * 0.12) {
            pill(knobLeading: false)
            pill(knobLeading: true)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func pill(knobLeading: Bool) -> some View {
        ZStack(alignment: knobLeading ? .leading : .trailing) {
            Capsule().strokeBorder(color, lineWidth: size * 0.08)
                .background(Capsule().fill(knobLeading ? Color.clear : color))
            Circle().fill(knobLeading ? color : Color.white)
                .frame(width: size * 0.26, height: size * 0.26)
                .padding(.horizontal, size * 0.08)
        }
        .frame(width: size, height: size * 0.42)
    }
}

/// Two overlapping chat bubbles (Feedback tab icon).
struct ChatBubblesIcon: View {
    var color: Color
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: size * 0.78))
                .foregroundStyle(color)
                .offset(x: -size * 0.14, y: -size * 0.1)
            Image(systemName: "text.bubble.fill")
                .font(.system(size: size * 0.78))
                .foregroundStyle(color)
                .background(
                    Image(systemName: "bubble.right.fill")
                        .font(.system(size: size * 0.92))
                        .foregroundStyle(Color.white)
                )
                .offset(x: size * 0.16, y: size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A 4×4 checkerboard drawn in SwiftUI.
struct CheckerIcon: View {
    var color: Color = .brand
    var size: CGFloat = 40

    var body: some View {
        let cell = size / 4
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { c in
                        Rectangle()
                            .fill((r + c).isMultiple(of: 2) ? color : Color.white)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous).strokeBorder(color, lineWidth: 2))
        .accessibilityHidden(true)
    }
}

/// Big coral game icon used on the "Try your first puzzle" cards and sheets.
struct GameIcon: View {
    let game: GameID
    var size: CGFloat = 44
    var color: Color = .brand

    var body: some View {
        Group {
            switch game {
            case .math:
                Text("f(x)")
                    .font(.system(size: size * 0.78, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(color)
            case .word:
                Text("Abc")
                    .font(.system(size: size * 0.74, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
            case .sudoku:
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: size * 0.9, weight: .semibold))
                    .foregroundStyle(color)
            case .chess:
                CheckerIcon(color: color, size: size * 0.9)
            }
        }
        .frame(height: size, alignment: .leading)
        .accessibilityHidden(true)
    }
}

extension GameID {
    var systemIcon: String {
        switch self {
        case .chess: return "checkerboard.rectangle"
        case .sudoku: return "square.grid.3x3"
        case .math: return "function"
        case .word: return "textformat.abc"
        }
    }

    var coverAsset: String { "game_\(rawValue)" }

    var tagline: String {
        switch self {
        case .chess: return "Find the checkmate."
        case .sudoku: return "Fill the 9×9 grid."
        case .math: return "Quick mental math."
        case .word: return "Guess the 5-letter word."
        }
    }

    var onboardingSubtitle: String {
        switch self {
        case .chess: return "Mate in one"
        case .sudoku: return "Fill the grid"
        case .math: return "Find the answer"
        case .word: return "Guess the word"
        }
    }

    var howToPlay: [String] {
        switch self {
        case .chess:
            return ["Find the move that checkmates. Mate-in-2 puzzles need two moves; the opponent replies in between.",
                    "Tap a piece to see its legal moves, then tap a square. You can also drag pieces.",
                    "Any move that delivers checkmate on your final move counts.",
                    "You have 3 tries per puzzle."]
        case .sudoku:
            return ["Fill every row, column and box with each digit exactly once.",
                    "Tap a cell, then a number. Use Notes for pencil marks.",
                    "Duplicates turn red right away.",
                    "Hints fill a cell for you (3 per puzzle)."]
        case .math:
            return ["Solve the question and type your answer with the keypad.",
                    "Answers are whole numbers or decimals with up to 2 places.",
                    "You get 3 tries per question."]
        case .word:
            return ["Guess the hidden 5-letter word. Each guess must be a real word.",
                    "Green: right letter, right spot. Yellow: in the word, wrong spot. Grey: not in the word.",
                    "Medium and Hard use hard mode: revealed hints must be used in later guesses."]
        }
    }

    var accessibilityRole: String { displayName }
}
