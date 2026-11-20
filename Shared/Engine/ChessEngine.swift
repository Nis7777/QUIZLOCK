import Foundation

public enum PieceColor: String, Codable, Sendable {
    case white, black
    public var opposite: PieceColor { self == .white ? .black : .white }
}

public enum PieceKind: String, Codable, Sendable, CaseIterable {
    case king, queen, rook, bishop, knight, pawn

    public var sanLetter: String {
        switch self {
        case .king: return "K"
        case .queen: return "Q"
        case .rook: return "R"
        case .bishop: return "B"
        case .knight: return "N"
        case .pawn: return ""
        }
    }

    init?(fenChar: Character) {
        switch fenChar.lowercased() {
        case "k": self = .king
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        case "p": self = .pawn
        default: return nil
        }
    }
}

public struct Piece: Codable, Hashable, Sendable {
    public let color: PieceColor
    public let kind: PieceKind
    public init(_ color: PieceColor, _ kind: PieceKind) { self.color = color; self.kind = kind }

    public var fenChar: Character {
        let c: Character
        switch kind {
        case .king: c = "k"
        case .queen: c = "q"
        case .rook: c = "r"
        case .bishop: c = "b"
        case .knight: c = "n"
        case .pawn: c = "p"
        }
        return color == .white ? Character(c.uppercased()) : c
    }

    /// Filled Unicode chess glyph followed by U+FE0E (text presentation) so iOS never draws it as emoji.
    public var glyph: String {
        let base: String
        switch kind {
        case .king: base = "\u{265A}"
        case .queen: base = "\u{265B}"
        case .rook: base = "\u{265C}"
        case .bishop: base = "\u{265D}"
        case .knight: base = "\u{265E}"
        case .pawn: base = "\u{265F}"
        }
        return base + "\u{FE0E}"
    }

    public var accessibilityName: String { "\(color.rawValue) \(kind.rawValue)" }
}

public struct Move: Codable, Hashable, Sendable, CustomStringConvertible {
    public let from: Int
    public let to: Int
    public let promotion: PieceKind?

    public init(from: Int, to: Int, promotion: PieceKind? = nil) {
        self.from = from; self.to = to; self.promotion = promotion
    }

    public init?(uci: String) {
        let chars = Array(uci.lowercased())
        guard chars.count == 4 || chars.count == 5,
              let f = Square.index(chars[0], chars[1]),
              let t = Square.index(chars[2], chars[3]) else { return nil }
        var promo: PieceKind?
        if chars.count == 5 {
            guard let p = PieceKind(fenChar: chars[4]), p != .king, p != .pawn else { return nil }
            promo = p
        }
        self.init(from: f, to: t, promotion: promo)
    }

    public var uci: String {
        var s = Square.name(from) + Square.name(to)
        if let p = promotion { s += String(Piece(.black, p).fenChar) }
        return s
    }

    public var description: String { uci }
}

public enum Square {
    public static func file(_ sq: Int) -> Int { sq & 7 }
    public static func rank(_ sq: Int) -> Int { sq >> 3 }
    public static func index(file: Int, rank: Int) -> Int? {
        guard (0..<8).contains(file), (0..<8).contains(rank) else { return nil }
        return rank * 8 + file
    }
    static func index(_ f: Character, _ r: Character) -> Int? {
        guard let fa = f.asciiValue, let ra = r.asciiValue,
              fa >= 97, fa <= 104, ra >= 49, ra <= 56 else { return nil }
        return Int(ra - 49) * 8 + Int(fa - 97)
    }
    public static func name(_ sq: Int) -> String {
        let files = Array("abcdefgh")
        return "\(files[file(sq)])\(rank(sq) + 1)"
    }
    public static func parse(_ s: String) -> Int? {
        let c = Array(s)
        guard c.count == 2 else { return nil }
        return index(c[0], c[1])
    }
}

public enum ChessError: Error, Equatable {
    case invalidFEN(String)
    case illegalMove(String)
}

public struct CastlingRights: Codable, Hashable, Sendable {
    public var whiteKing = false, whiteQueen = false, blackKing = false, blackQueen = false
}

public struct Position: Codable, Hashable, Sendable {
    public var board: [Piece?]
    public var sideToMove: PieceColor
    public var castling: CastlingRights
    public var enPassant: Int?
    public var halfmoveClock: Int
    public var fullmoveNumber: Int

    public static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    public init(fen: String) throws {
        let parts = fen.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { throw ChessError.invalidFEN(fen) }
        var board = [Piece?](repeating: nil, count: 64)
        let rows = parts[0].split(separator: "/")
        guard rows.count == 8 else { throw ChessError.invalidFEN(fen) }
        for (i, row) in rows.enumerated() {
            let rank = 7 - i
            var file = 0
            for ch in row {
                if let d = ch.wholeNumberValue {
                    file += d
                } else {
                    guard let kind = PieceKind(fenChar: ch), file < 8 else { throw ChessError.invalidFEN(fen) }
                    board[rank * 8 + file] = Piece(ch.isUppercase ? .white : .black, kind)
                    file += 1
                }
            }
            guard file == 8 else { throw ChessError.invalidFEN(fen) }
        }
        self.board = board
        switch parts[1] {
        case "w": sideToMove = .white
        case "b": sideToMove = .black
        default: throw ChessError.invalidFEN(fen)
        }
        var c = CastlingRights()
        if parts.count > 2 {
            c.whiteKing = parts[2].contains("K")
            c.whiteQueen = parts[2].contains("Q")
            c.blackKing = parts[2].contains("k")
            c.blackQueen = parts[2].contains("q")
        }
        castling = c
        enPassant = parts.count > 3 && parts[3] != "-" ? Square.parse(parts[3]) : nil
        halfmoveClock = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        fullmoveNumber = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
        guard kingSquare(.white) != nil, kingSquare(.black) != nil else { throw ChessError.invalidFEN(fen) }
    }

    public static var start: Position {
        (try? Position(fen: startFEN)) ?? Position(board: [Piece?](repeating: nil, count: 64), sideToMove: .white)
    }

    /// Raw initializer (no validation).
    init(board: [Piece?], sideToMove: PieceColor, castling: CastlingRights = CastlingRights(),
         enPassant: Int? = nil, halfmoveClock: Int = 0, fullmoveNumber: Int = 1) {
        self.board = board
        self.sideToMove = sideToMove
        self.castling = castling
        self.enPassant = enPassant
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    public var fen: String {
        var s = ""
        for rank in stride(from: 7, through: 0, by: -1) {
            var empty = 0
            for file in 0..<8 {
                if let p = board[rank * 8 + file] {
                    if empty > 0 { s += "\(empty)"; empty = 0 }
                    s.append(p.fenChar)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { s += "\(empty)" }
            if rank > 0 { s += "/" }
        }
        s += sideToMove == .white ? " w " : " b "
        var cr = ""
        if castling.whiteKing { cr += "K" }
        if castling.whiteQueen { cr += "Q" }
        if castling.blackKing { cr += "k" }
        if castling.blackQueen { cr += "q" }
        s += cr.isEmpty ? "-" : cr
        s += " " + (enPassant.map(Square.name) ?? "-")
        s += " \(halfmoveClock) \(fullmoveNumber)"
        return s
    }

    public subscript(_ sq: Int) -> Piece? { board[sq] }

    public func kingSquare(_ color: PieceColor) -> Int? {
        board.firstIndex { $0 == Piece(color, .king) }
    }

    // MARK: Attacks

    private static let knightOffsets = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingOffsets = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let bishopDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    public func isAttacked(_ sq: Int, by color: PieceColor) -> Bool {
        let f = Square.file(sq), r = Square.rank(sq)
        // Pawns
        let pawnRank = color == .white ? r - 1 : r + 1
        for df in [-1, 1] {
            if let s = Square.index(file: f + df, rank: pawnRank), board[s] == Piece(color, .pawn) { return true }
        }
        for (df, dr) in Self.knightOffsets {
            if let s = Square.index(file: f + df, rank: r + dr), board[s] == Piece(color, .knight) { return true }
        }
        for (df, dr) in Self.kingOffsets {
            if let s = Square.index(file: f + df, rank: r + dr), board[s] == Piece(color, .king) { return true }
        }
        for (df, dr) in Self.rookDirs {
            var nf = f + df, nr = r + dr
            while let s = Square.index(file: nf, rank: nr) {
                if let p = board[s] {
                    if p.color == color && (p.kind == .rook || p.kind == .queen) { return true }
                    break
                }
                nf += df; nr += dr
            }
        }
        for (df, dr) in Self.bishopDirs {
            var nf = f + df, nr = r + dr
            while let s = Square.index(file: nf, rank: nr) {
                if let p = board[s] {
                    if p.color == color && (p.kind == .bishop || p.kind == .queen) { return true }
                    break
                }
                nf += df; nr += dr
            }
        }
        return false
    }

    public func isInCheck(_ color: PieceColor) -> Bool {
        guard let k = kingSquare(color) else { return false }
        return isAttacked(k, by: color.opposite)
    }

    public var isCheck: Bool { isInCheck(sideToMove) }
    public var isCheckmate: Bool { isCheck && legalMoves().isEmpty }
    public var isStalemate: Bool { !isCheck && legalMoves().isEmpty }

    // MARK: Move generation

    public func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let us = sideToMove
        for sq in 0..<64 {
            guard let p = board[sq], p.color == us else { continue }
            let f = Square.file(sq), r = Square.rank(sq)
            switch p.kind {
            case .pawn:
                let dir = us == .white ? 1 : -1
                let startRank = us == .white ? 1 : 6
                let promoRank = us == .white ? 7 : 0
                func add(_ to: Int) {
                    if Square.rank(to) == promoRank {
                        for k in [PieceKind.queen, .rook, .bishop, .knight] { moves.append(Move(from: sq, to: to, promotion: k)) }
                    } else {
                        moves.append(Move(from: sq, to: to))
                    }
                }
                if let one = Square.index(file: f, rank: r + dir), board[one] == nil {
                    add(one)
                    if r == startRank, let two = Square.index(file: f, rank: r + 2 * dir), board[two] == nil {
                        moves.append(Move(from: sq, to: two))
                    }
                }
                for df in [-1, 1] {
                    guard let t = Square.index(file: f + df, rank: r + dir) else { continue }
                    if let target = board[t], target.color != us {
                        add(t)
                    } else if t == enPassant {
                        moves.append(Move(from: sq, to: t))
                    }
                }
            case .knight:
                for (df, dr) in Self.knightOffsets {
                    if let t = Square.index(file: f + df, rank: r + dr), board[t]?.color != us { moves.append(Move(from: sq, to: t)) }
                }
            case .king:
                for (df, dr) in Self.kingOffsets {
                    if let t = Square.index(file: f + df, rank: r + dr), board[t]?.color != us { moves.append(Move(from: sq, to: t)) }
                }
                moves.append(contentsOf: castlingMoves(kingSquare: sq))
            case .rook, .bishop, .queen:
                let dirs: [(Int, Int)] = p.kind == .rook ? Self.rookDirs : p.kind == .bishop ? Self.bishopDirs : Self.rookDirs + Self.bishopDirs
                for (df, dr) in dirs {
                    var nf = f + df, nr = r + dr
                    while let t = Square.index(file: nf, rank: nr) {
                        if let target = board[t] {
                            if target.color != us { moves.append(Move(from: sq, to: t)) }
                            break
                        }
                        moves.append(Move(from: sq, to: t))
                        nf += df; nr += dr
                    }
                }
            }
        }
        return moves
    }

    private func castlingMoves(kingSquare sq: Int) -> [Move] {
        let us = sideToMove
        let them = us.opposite
        let homeRank = us == .white ? 0 : 7
        guard sq == homeRank * 8 + 4, !isAttacked(sq, by: them) else { return [] }
        var result: [Move] = []
        let canKing = us == .white ? castling.whiteKing : castling.blackKing
        let canQueen = us == .white ? castling.whiteQueen : castling.blackQueen
        let base = homeRank * 8
        if canKing, board[base + 7] == Piece(us, .rook),
           board[base + 5] == nil, board[base + 6] == nil,
           !isAttacked(base + 5, by: them), !isAttacked(base + 6, by: them) {
            result.append(Move(from: sq, to: base + 6))
        }
        if canQueen, board[base] == Piece(us, .rook),
           board[base + 1] == nil, board[base + 2] == nil, board[base + 3] == nil,
           !isAttacked(base + 3, by: them), !isAttacked(base + 2, by: them) {
            result.append(Move(from: sq, to: base + 2))
        }
        return result
    }

    public func legalMoves() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves().filter { m in
            let next = applying(unchecked: m)
            return !next.isInCheck(us)
        }
    }

    public func legalMoves(from sq: Int) -> [Move] {
        legalMoves().filter { $0.from == sq }
    }

    public func isLegal(_ move: Move) -> Bool {
        legalMoves().contains(move)
    }

    /// Applies a move that is known to be legal (or at least pseudo-legal).
    public func applying(unchecked m: Move) -> Position {
        var p = self
        guard let piece = board[m.from] else { return p }
        let us = piece.color
        let captured = board[m.to]
        var isCapture = captured != nil

        p.board[m.from] = nil
        // En passant capture
        if piece.kind == .pawn, m.to == enPassant, captured == nil, Square.file(m.from) != Square.file(m.to) {
            let capSq = m.to + (us == .white ? -8 : 8)
            p.board[capSq] = nil
            isCapture = true
        }
        p.board[m.to] = m.promotion.map { Piece(us, $0) } ?? piece

        // Castling: move the rook
        if piece.kind == .king, abs(Square.file(m.to) - Square.file(m.from)) == 2 {
            let base = Square.rank(m.from) * 8
            if Square.file(m.to) == 6 {
                p.board[base + 5] = p.board[base + 7]; p.board[base + 7] = nil
            } else {
                p.board[base + 3] = p.board[base]; p.board[base] = nil
            }
        }

        // Castling rights
        if piece.kind == .king {
            if us == .white { p.castling.whiteKing = false; p.castling.whiteQueen = false } else { p.castling.blackKing = false; p.castling.blackQueen = false }
        }
        for sq in [m.from, m.to] {
            switch sq {
            case 0: p.castling.whiteQueen = false
            case 7: p.castling.whiteKing = false
            case 56: p.castling.blackQueen = false
            case 63: p.castling.blackKing = false
            default: break
            }
        }

        // En passant square
        if piece.kind == .pawn, abs(m.to - m.from) == 16 {
            p.enPassant = (m.from + m.to) / 2
        } else {
            p.enPassant = nil
        }

        p.halfmoveClock = (piece.kind == .pawn || isCapture) ? 0 : halfmoveClock + 1
        if us == .black { p.fullmoveNumber += 1 }
        p.sideToMove = us.opposite
        return p
    }

    public func applying(_ m: Move) throws -> Position {
        guard isLegal(m) else { throw ChessError.illegalMove(m.uci) }
        return applying(unchecked: m)
    }

    // MARK: SAN

    public func san(_ m: Move) -> String {
        guard let piece = board[m.from] else { return m.uci }
        var s: String
        if piece.kind == .king, abs(Square.file(m.to) - Square.file(m.from)) == 2 {
            s = Square.file(m.to) == 6 ? "O-O" : "O-O-O"
        } else {
            let isCapture = board[m.to] != nil || (piece.kind == .pawn && Square.file(m.from) != Square.file(m.to))
            if piece.kind == .pawn {
                s = isCapture ? String(Square.name(m.from).prefix(1)) + "x" : ""
                s += Square.name(m.to)
                if let promo = m.promotion { s += "=" + promo.sanLetter }
            } else {
                s = piece.kind.sanLetter
                let others = legalMoves().filter { $0.to == m.to && $0.from != m.from && board[$0.from] == piece }
                if !others.isEmpty {
                    let sameFile = others.contains { Square.file($0.from) == Square.file(m.from) }
                    let sameRank = others.contains { Square.rank($0.from) == Square.rank(m.from) }
                    let name = Square.name(m.from)
                    if !sameFile {
                        s += String(name.prefix(1))
                    } else if !sameRank {
                        s += String(name.suffix(1))
                    } else {
                        s += name
                    }
                }
                if isCapture { s += "x" }
                s += Square.name(m.to)
            }
        }
        let next = applying(unchecked: m)
        if next.isCheck { s += next.legalMoves().isEmpty ? "#" : "+" }
        return s
    }

    // MARK: Perft

    public func perft(_ depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = legalMoves()
        if depth == 1 { return moves.count }
        return moves.reduce(0) { $0 + applying(unchecked: $1).perft(depth - 1) }
    }
}
