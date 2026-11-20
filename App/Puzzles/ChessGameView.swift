import Observation
import SwiftUI

struct BoardPiece: Identifiable, Equatable {
    let id: Int
    var piece: Piece
    var square: Int
}

@Observable
@MainActor
final class ChessViewModel {
    private(set) var round: ChessRound
    private(set) var pieces: [BoardPiece] = []
    var selected: Int?
    var targets: [Int] = []
    var highlight: [Int] = []
    var shakeTrigger = 0
    var promotion: (from: Int, to: Int)?
    var answerText: String?
    var answerIsSuccess = true
    var statusText: String?
    var isAnimating = false
    var dragPieceID: Int?
    var dragOffset: CGSize = .zero

    @ObservationIgnored private var nextID = 0
    @ObservationIgnored var onUpdate: (ChessRound) -> Void = { _ in }
    @ObservationIgnored var onFinish: (RoundStatus) -> Void = { _ in }

    init(round: ChessRound) {
        self.round = round
        if round.step == 0, round.misses == 0, let initial = round.initialPosition, let first = Move(uci: round.puzzle.opponentFirstMove) {
            rebuild(from: initial)
            isAnimating = true
            Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                animate(first, before: initial)
                isAnimating = false
            }
        } else {
            rebuild(from: round.position)
            if let m = round.lastMove { highlight = [m.from, m.to] }
        }
    }

    var playerColor: PieceColor { round.playerColor }
    var flipped: Bool { playerColor == .black }

    private func rebuild(from position: Position) {
        pieces = (0..<64).compactMap { sq in
            guard let p = position[sq] else { return nil }
            nextID += 1
            return BoardPiece(id: nextID, piece: p, square: sq)
        }
    }

    /// Updates the visual pieces for a move (slide animation), handling captures, en passant, castling and promotion.
    private func animate(_ move: Move, before: Position) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let captured = pieces.firstIndex(where: { $0.square == move.to }) {
                pieces.remove(at: captured)
            } else if before[move.from]?.kind == .pawn, Square.file(move.from) != Square.file(move.to) {
                let epSquare = move.to + (before[move.from]?.color == .white ? -8 : 8)
                pieces.removeAll { $0.square == epSquare }
            }
            if let i = pieces.firstIndex(where: { $0.square == move.from }) {
                pieces[i].square = move.to
                if let promo = move.promotion { pieces[i].piece = Piece(pieces[i].piece.color, promo) }
            }
            if before[move.from]?.kind == .king, abs(Square.file(move.to) - Square.file(move.from)) == 2 {
                let base = Square.rank(move.from) * 8
                let (rookFrom, rookTo) = Square.file(move.to) == 6 ? (base + 7, base + 5) : (base, base + 3)
                if let r = pieces.firstIndex(where: { $0.square == rookFrom }) { pieces[r].square = rookTo }
            }
            highlight = [move.from, move.to]
        }
    }

    func piece(at sq: Int) -> BoardPiece? { pieces.first { $0.square == sq } }

    // MARK: Input

    func tap(_ sq: Int) {
        guard round.isPlayersTurn, !isAnimating else { return }
        if let s = selected, targets.contains(sq) {
            attempt(from: s, to: sq)
            return
        }
        if let p = round.position[sq], p.color == playerColor {
            Haptics.tap()
            withAnimation(.selectionSpring) {
                selected = sq
                targets = Array(Set(round.position.legalMoves(from: sq).map(\.to)))
            }
        } else if let s = selected {
            // Tapping a non-target square with a selection: treat as an attempted move (wrong) only if it's empty/enemy.
            attempt(from: s, to: sq)
        }
    }

    func canDrag(_ sq: Int) -> Bool {
        guard round.isPlayersTurn, !isAnimating, let p = round.position[sq] else { return false }
        return p.color == playerColor
    }

    func drop(from: Int, to: Int?) {
        guard let to, to != from else {
            withAnimation(.spring(response: 0.25)) { dragOffset = .zero }
            dragPieceID = nil
            return
        }
        attempt(from: from, to: to, fromDrag: true)
    }

    func attempt(from: Int, to: Int, fromDrag: Bool = false) {
        let candidates = round.position.legalMoves(from: from).filter { $0.to == to }
        if candidates.count > 1 {
            // Promotion: show the 4-piece picker.
            dragOffset = .zero
            dragPieceID = nil
            promotion = (from, to)
            return
        }
        play(candidates.first ?? Move(from: from, to: to), fromDrag: fromDrag)
    }

    func choosePromotion(_ kind: PieceKind) {
        guard let p = promotion else { return }
        promotion = nil
        play(Move(from: p.from, to: p.to, promotion: kind), fromDrag: false)
    }

    private func play(_ move: Move, fromDrag: Bool) {
        let before = round.position
        let outcome = round.play(move)
        selected = nil
        targets = []
        switch outcome {
        case .illegal:
            // Not a legal move: just snap back / deselect (doesn't use a try).
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
            dragPieceID = nil
        case .wrong(let left):
            onUpdate(round)
            wrongFeedback(message: "Not quite. \(left) \(left == 1 ? "try" : "tries") left")
        case .correctContinue:
            commitDrag()
            animate(move, before: before)
            statusText = nil
            onUpdate(round)
            isAnimating = true
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                let beforeReply = round.position
                if let reply = round.playOpponentReply() {
                    animate(reply, before: beforeReply)
                    onUpdate(round)
                }
                isAnimating = false
            }
        case .solved(let san):
            commitDrag()
            animate(move, before: before)
            statusText = nil
            onUpdate(round)
            Haptics.success()
            withAnimation(.selectionSpring.delay(0.25)) {
                answerIsSuccess = true
                answerText = san.hasSuffix("#") ? "\(san) · Checkmate ✓" : "\(san)# · Checkmate ✓"
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onFinish(.solved)
            }
        case .failed:
            onUpdate(round)
            wrongFeedback(message: "Out of tries. Here's the solution.")
            playSolution()
        }
    }

    private func commitDrag() {
        dragOffset = .zero
        dragPieceID = nil
    }

    private func wrongFeedback(message: String?) {
        Haptics.error()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { dragOffset = .zero }
        dragPieceID = nil
        withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
        if let message { withAnimation { statusText = message } }
    }

    private func playSolution() {
        isAnimating = true
        let moves = ChessRound.solutionLine(for: round.puzzle).dropFirst(round.step)
        Task {
            var position = round.position
            var lastSAN = ""
            try? await Task.sleep(nanoseconds: 700_000_000)
            for m in moves {
                lastSAN = position.san(m)
                animate(m, before: position)
                position = position.applying(unchecked: m)
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            withAnimation(.selectionSpring) {
                answerIsSuccess = false
                answerText = "Solution: \(lastSAN)"
            }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            onFinish(.failed)
        }
    }
}

struct ChessGameView: View {
    @State private var vm: ChessViewModel
    @Environment(\.palette) private var palette

    init(round: ChessRound, onUpdate: @escaping (ChessRound) -> Void, onFinish: @escaping (RoundStatus) -> Void) {
        let model = ChessViewModel(round: round)
        model.onUpdate = onUpdate
        model.onFinish = onFinish
        _vm = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(vm.round.headerText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ChessBoardView(vm: vm)
                .aspectRatio(1, contentMode: .fit)
                .modifier(ShakeEffect(animatableData: CGFloat(vm.shakeTrigger)))
            if let answer = vm.answerText {
                AnswerBar(text: answer, success: vm.answerIsSuccess)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let status = vm.statusText {
                Text(status)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.errorRed)
                    .transition(.opacity)
            } else {
                Text("Tap a piece, then a square. Or drag it.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .overlay {
            if vm.promotion != nil {
                PromotionPicker(color: vm.playerColor) { vm.choosePromotion($0) }
            }
        }
    }
}

struct AnswerBar: View {
    let text: String
    var success = true

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(success ? Color.answerGreen : Color.textPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityAddTraits(.isStaticText)
    }
}

struct ChessBoardView: View {
    let vm: ChessViewModel
    @State private var dragStart: Int?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            ZStack(alignment: .topLeading) {
                ForEach(0..<64, id: \.self) { sq in
                    squareView(sq, cell: cell)
                        .position(point(sq, cell: cell))
                }
                ForEach(vm.pieces) { bp in
                    PieceGlyph(piece: bp.piece, size: cell)
                        .frame(width: cell, height: cell)
                        .offset(bp.id == vm.dragPieceID ? vm.dragOffset : .zero)
                        .scaleEffect(bp.id == vm.dragPieceID ? 1.15 : 1)
                        .position(point(bp.square, cell: cell))
                        .zIndex(bp.id == vm.dragPieceID ? 10 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(dragGesture(cell: cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func point(_ sq: Int, cell: CGFloat) -> CGPoint {
        let f = Square.file(sq), r = Square.rank(sq)
        let col = vm.flipped ? 7 - f : f
        let row = vm.flipped ? r : 7 - r
        return CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }

    private func square(at p: CGPoint, cell: CGFloat) -> Int? {
        let col = Int(floor(p.x / cell)), row = Int(floor(p.y / cell))
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        let f = vm.flipped ? 7 - col : col
        let r = vm.flipped ? row : 7 - row
        return r * 8 + f
    }

    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = square(at: value.startLocation, cell: cell)
                }
                guard let start = dragStart, hypot(value.translation.width, value.translation.height) > 6,
                      vm.canDrag(start), let bp = vm.piece(at: start) else { return }
                if vm.dragPieceID != bp.id {
                    vm.dragPieceID = bp.id
                    vm.selected = start
                    vm.targets = Array(Set(vm.round.position.legalMoves(from: start).map(\.to)))
                }
                vm.dragOffset = value.translation
            }
            .onEnded { value in
                defer { dragStart = nil }
                let distance = hypot(value.translation.width, value.translation.height)
                if distance <= 6 || vm.dragPieceID == nil {
                    if let sq = square(at: value.location, cell: cell) { vm.tap(sq) }
                    return
                }
                guard let start = dragStart else { return }
                vm.drop(from: start, to: square(at: value.location, cell: cell))
            }
    }

    @ViewBuilder
    private func squareView(_ sq: Int, cell: CGFloat) -> some View {
        let f = Square.file(sq), r = Square.rank(sq)
        let isLight = (f + r) % 2 == 1
        let col = vm.flipped ? 7 - f : f
        let row = vm.flipped ? r : 7 - r
        ZStack {
            Rectangle().fill(isLight ? Color.chessLight : Color.chessDark)
            if vm.highlight.contains(sq) || vm.selected == sq {
                Rectangle().fill(Color.chessHighlight)
            }
            if vm.targets.contains(sq) {
                if vm.round.position[sq] != nil {
                    Circle().strokeBorder(Color.black.opacity(0.22), lineWidth: cell * 0.08)
                } else {
                    Circle().fill(Color.black.opacity(0.22)).frame(width: cell * 0.3, height: cell * 0.3)
                }
            }
            if col == 0 {
                Text("\(r + 1)")
                    .font(.system(size: cell * 0.2, weight: .bold))
                    .foregroundStyle(isLight ? Color.chessDark : Color.chessLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
            }
            if row == 7 {
                Text(String(Array("abcdefgh")[f]))
                    .font(.system(size: cell * 0.2, weight: .bold))
                    .foregroundStyle(isLight ? Color.chessDark : Color.chessLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
        }
        .frame(width: cell, height: cell)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(sq))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { vm.tap(sq) }
    }

    private func accessibilityText(_ sq: Int) -> String {
        var s = Square.name(sq)
        if let p = vm.round.position[sq] { s += ", " + p.accessibilityName }
        if vm.selected == sq { s += ", selected" }
        if vm.targets.contains(sq) { s += ", legal move" }
        return s
    }
}

/// A piece drawn with the filled Unicode glyph (+U+FE0E) in "Apple Symbols".
/// White pieces are white with a 1.5pt dark outline; black pieces are near-black.
struct PieceGlyph: View {
    let piece: Piece
    let size: CGFloat

    private static let outline: [CGSize] = [
        CGSize(width: -1.5, height: 0), CGSize(width: 1.5, height: 0), CGSize(width: 0, height: -1.5), CGSize(width: 0, height: 1.5),
        CGSize(width: -1.1, height: -1.1), CGSize(width: 1.1, height: -1.1), CGSize(width: -1.1, height: 1.1), CGSize(width: 1.1, height: 1.1),
    ]

    var body: some View {
        let font = Font.custom("Apple Symbols", size: size * 0.86)
        ZStack {
            if piece.color == .white {
                ForEach(0..<Self.outline.count, id: \.self) { i in
                    Text(piece.glyph).font(font).foregroundStyle(Color(hex: 0x1F1F1F)).offset(Self.outline[i])
                }
                Text(piece.glyph).font(font).foregroundStyle(Color.white)
            } else {
                Text(piece.glyph).font(font).foregroundStyle(Color(hex: 0x141414))
            }
        }
        .offset(y: -size * 0.03)
    }
}

struct PromotionPicker: View {
    let color: PieceColor
    let onPick: (PieceKind) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Promote to").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.textPrimary)
                HStack(spacing: 12) {
                    ForEach([PieceKind.queen, .rook, .bishop, .knight], id: \.self) { kind in
                        Button { onPick(kind) } label: {
                            PieceGlyph(piece: Piece(color, kind), size: 56)
                                .frame(width: 60, height: 60)
                                .background(Color.chessLight, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(kind.rawValue)
                    }
                }
            }
            .padding(20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
