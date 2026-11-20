import SwiftUI

// MARK: - Shared card shell

private struct PreviewCardShell<Content: View>: View {
    let icon: AnyView
    let title: String
    let dark: Bool
    let solved: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                icon
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
                ZStack {
                    Circle().fill(Color.correctGreen)
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
                .scaleEffect(solved ? 1 : 0.01)
                .opacity(solved ? 1 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: solved)
            }
            .foregroundStyle(dark ? Color.white.opacity(0.75) : Color.textSecondary)
            content()
                .frame(maxHeight: .infinity)
            Text("Preview · Answers play automatically")
                .font(.system(size: 13))
                .foregroundStyle(dark ? Color.white.opacity(0.55) : Color.textSecondary)
        }
        .padding(20)
        .background(dark ? Color.darkCard : Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 6)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 1. Math

struct MathPreviewCard: View {
    let isActive: Bool
    @State private var typed = false
    @State private var solved = false

    var body: some View {
        PreviewCardShell(icon: AnyView(Image(systemName: "function").font(.system(size: 17, weight: .semibold))),
                         title: "Math", dark: false, solved: solved) {
            VStack(spacing: 34) {
                Text("If 3x + 5 = 20,\nwhat is x?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Text(solved ? "x = 5" : (typed ? "5" : " "))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(solved ? Color.answerGreen : Color.textPrimary)
                        .contentTransition(.numericText())
                    if solved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.answerGreen)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(solved ? Color.correctGreenBg : Color(hex: 0xF4F4F7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .leading) {
                    if !typed {
                        Capsule().fill(Color.brandRed).frame(width: 2, height: 30).padding(.leading, 24)
                    }
                }
            }
        }
        .task(id: isActive) {
            typed = false
            solved = false
            guard isActive else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.2)) { typed = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.selectionSpring) { solved = true }
        }
    }
}

// MARK: - 2. Word

struct WordPreviewCard: View {
    let isActive: Bool
    private let words = ["crane", "slant", "plant"]
    @State private var letters: [[Character]] = [[], [], []]
    @State private var scores: [[LetterScore]?] = [nil, nil, nil]
    @State private var solved = false

    var body: some View {
        PreviewCardShell(icon: AnyView(Image(systemName: "textformat.abc").font(.system(size: 17, weight: .semibold))),
                         title: "Word", dark: false, solved: solved) {
            GeometryReader { geo in
                let tile = min(52, (geo.size.width - 24) / 5, (geo.size.height - 12) / 3)
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { col in
                                WordTile(letter: col < letters[row].count ? letters[row][col] : nil,
                                         score: scores[row]?[col], index: col, size: tile, bounce: solved && row == 2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 10)
        }
        .task(id: isActive) {
            letters = [[], [], []]
            scores = [nil, nil, nil]
            solved = false
            guard isActive else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            for (row, word) in words.enumerated() {
                for ch in word {
                    guard !Task.isCancelled else { return }
                    letters[row].append(ch)
                    try? await Task.sleep(nanoseconds: 90_000_000)
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
                // Colours come from the real scoring function against PLANT.
                scores[row] = WordEngine.score(guess: word, answer: "plant")
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            solved = true
        }
    }
}

// MARK: - 3. Sudoku

struct SudokuPreviewCard: View {
    let isActive: Bool
    @State private var filled = 0
    @State private var flash = false
    @State private var solved = false

    private static let puzzle: SudokuPuzzle = {
        var rng = SeededGenerator(seed: 17)
        return SudokuGenerator.nearlySolved(blanks: 4, using: &rng)
    }()

    private var blanks: [Int] { (72..<81).filter { Self.puzzle.puzzle[$0] == 0 } }

    var body: some View {
        PreviewCardShell(icon: AnyView(Image(systemName: "square.grid.3x3").font(.system(size: 17, weight: .semibold))),
                         title: "Sudoku", dark: true, solved: solved) {
            VStack(spacing: 14) {
                Text("Fill the last row")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    board(side: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                AnswerBar(text: "Row complete ✓")
                    .opacity(solved ? 1 : 0)
                    .scaleEffect(solved ? 1 : 0.92)
            }
        }
        .task(id: isActive) {
            filled = 0
            flash = false
            solved = false
            guard isActive else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            for i in 1...blanks.count {
                guard !Task.isCancelled else { return }
                withAnimation(.selectionSpring) { filled = i }
                try? await Task.sleep(nanoseconds: 420_000_000)
            }
            withAnimation(.easeOut(duration: 0.25)) { flash = true }
            withAnimation(.selectionSpring) { solved = true }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeIn(duration: 0.4)) { flash = false }
        }
    }

    private func board(side: CGFloat) -> some View {
        let cell = side / 9
        let p = Self.puzzle
        let filledSet = Set(blanks.prefix(filled))
        return ZStack(alignment: .topLeading) {
            ForEach(0..<81, id: \.self) { i in
                let isBlank = p.puzzle[i] == 0
                let show = !isBlank || filledSet.contains(i)
                ZStack {
                    Rectangle().fill(Color(hex: 0xF7EFDF))
                    if flash && i >= 72 { Rectangle().fill(Color.correctGreen.opacity(0.45)) }
                    if show {
                        Text("\(p.solution[i])")
                            .font(.system(size: cell * 0.55, weight: isBlank ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isBlank ? Color.brandRed : Color(hex: 0x2B2622))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: cell, height: cell)
                .position(x: (CGFloat(i % 9) + 0.5) * cell, y: (CGFloat(i / 9) + 0.5) * cell)
            }
            SudokuGridLines(layout: .classic)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - 4. Chess

struct ChessPreviewCard: View {
    let isActive: Bool
    @State private var pieces: [BoardPiece] = []
    @State private var highlight: [Int] = []
    @State private var solved = false

    private static let data: (puzzle: ChessPuzzle, start: Position, move: Move, san: String)? = {
        let bank = ChessPuzzleBank.load(from: .main)
        guard let puzzle = bank?.firstEasyMateInOne ?? Optional(ChessPuzzleBank.fallback),
              let start = try? puzzle.startPosition(),
              let uci = puzzle.solution.first, let move = Move(uci: uci) else { return nil }
        return (puzzle, start, move, start.san(move))
    }()

    var body: some View {
        PreviewCardShell(icon: AnyView(CheckerIcon(color: .white.opacity(0.8), size: 16)),
                         title: "Chess", dark: true, solved: solved) {
            VStack(spacing: 14) {
                Text(headerText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    ChessPreviewBoard(pieces: pieces, flipped: Self.data?.start.sideToMove == .black, highlight: highlight)
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                AnswerBar(text: "\(Self.data?.san ?? "Rd8#") · Checkmate ✓")
                    .opacity(solved ? 1 : 0)
                    .scaleEffect(solved ? 1 : 0.92)
            }
        }
        .task(id: isActive) {
            reset()
            guard isActive, let d = Self.data else { return }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                pieces.removeAll { $0.square == d.move.to }
                if let i = pieces.firstIndex(where: { $0.square == d.move.from }) { pieces[i].square = d.move.to }
                highlight = [d.move.from, d.move.to]
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.selectionSpring) { solved = true }
        }
    }

    private var headerText: String {
        guard let d = Self.data else { return "White to move. Mate in one." }
        return (d.start.sideToMove == .white ? "White" : "Black") + " to move. Mate in one."
    }

    private func reset() {
        solved = false
        highlight = []
        guard let d = Self.data else { return }
        pieces = (0..<64).compactMap { sq in d.start[sq].map { BoardPiece(id: sq, piece: $0, square: sq) } }
        if let first = Move(uci: d.puzzle.opponentFirstMove) { highlight = [first.from, first.to] }
    }
}

/// Non-interactive board used by previews.
struct ChessPreviewBoard: View {
    let pieces: [BoardPiece]
    let flipped: Bool
    let highlight: [Int]

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) / 8
            ZStack(alignment: .topLeading) {
                ForEach(0..<64, id: \.self) { sq in
                    let light = (Square.file(sq) + Square.rank(sq)) % 2 == 1
                    ZStack {
                        Rectangle().fill(light ? Color.chessLight : Color.chessDark)
                        if highlight.contains(sq) { Rectangle().fill(Color.chessHighlight) }
                    }
                    .frame(width: cell, height: cell)
                    .position(point(sq, cell))
                }
                ForEach(pieces) { bp in
                    PieceGlyph(piece: bp.piece, size: cell)
                        .frame(width: cell, height: cell)
                        .position(point(bp.square, cell))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func point(_ sq: Int, _ cell: CGFloat) -> CGPoint {
        let f = Square.file(sq), r = Square.rank(sq)
        let col = flipped ? 7 - f : f
        let row = flipped ? r : 7 - r
        return CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }
}
