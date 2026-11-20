import SwiftUI

/// Shared puzzle screen chrome (S05), used for practice and for the real unlock flow.
struct PuzzleChrome<Content: View>: View {
    let game: GameID
    let subLabel: String
    var progress: String?
    var isPractice = false
    var onClose: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Brand.appNameCaps)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(palette.accent)
                    Text(game.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                if let onClose {
                    CloseButton(action: onClose).offset(x: 10, y: -6)
                }
            }
            .padding(.top, 8)

            HStack(alignment: .center) {
                Text(subLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                if let progress {
                    Text(progress)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityLabel("Puzzle \(progress)")
                }
            }
            .padding(.top, 18)

            YourTurnPill()
                .padding(.top, 12)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 12)

            if isPractice {
                Text("PRACTICE")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 20)
        .screenBackground()
    }
}

struct YourTurnPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.correctGreen).frame(width: 8, height: 8)
            Text("Your turn").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.correctGreenBg.opacity(0.75), in: Capsule())
    }
}

extension AnyRound {
    /// Grey caps sub-label ("ALGEBRA", "5 LETTERS · 6 TRIES", "EASY", "MATE IN 1").
    var subLabel: String {
        switch self {
        case .math(let r): return r.question.topic
        case .word(let r): return "5 LETTERS · \(r.maxTries) TRIES"
        case .sudoku(let r): return r.difficulty == .quick ? "QUICK 6×6" : r.difficulty.displayName.uppercased()
        case .chess(let r): return "MATE IN \(r.puzzle.mateIn)"
        }
    }

    /// Stable identity of the round's content (used to reset game views when a new round is served).
    var identity: String {
        switch self {
        case .math(let r): return "m:" + r.question.expression + r.question.text
        case .word(let r): return "w:" + r.answer
        case .sudoku(let r): return "s:" + r.puzzle.puzzle.map(String.init).joined()
        case .chess(let r): return "c:" + r.puzzle.id
        }
    }
}

/// Renders the right game view for a round.
struct PuzzleGameView: View {
    let round: AnyRound
    let dictionary: WordDictionary
    var onUpdate: (AnyRound) -> Void = { _ in }
    let onFinish: (RoundStatus) -> Void

    var body: some View {
        switch round {
        case .math(let r):
            MathGameView(round: r, onUpdate: { onUpdate(.math($0)) }, onFinish: onFinish)
        case .word(let r):
            WordGameView(round: r, dictionary: dictionary, onUpdate: { onUpdate(.word($0)) }, onFinish: onFinish)
        case .sudoku(let r):
            SudokuGameView(round: r, onUpdate: { onUpdate(.sudoku($0)) }, onFinish: onFinish)
        case .chess(let r):
            ChessGameView(round: r, onUpdate: { onUpdate(.chess($0)) }, onFinish: onFinish)
        }
    }
}
