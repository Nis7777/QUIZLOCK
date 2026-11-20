import Observation
import SwiftUI

@Observable
@MainActor
final class WordViewModel {
    private(set) var round: WordRound
    let dictionary: WordDictionary
    var toast: String?
    var shakeTrigger = 0
    /// Rows whose colours are visible on the keyboard (updated after the flip finishes).
    var keyboardRows: Int
    var bounceRow: Int?
    var isBusy = false

    @ObservationIgnored var onUpdate: (WordRound) -> Void = { _ in }
    @ObservationIgnored var onFinish: (RoundStatus) -> Void = { _ in }

    init(round: WordRound, dictionary: WordDictionary) {
        self.round = round
        self.dictionary = dictionary
        self.keyboardRows = round.guesses.count
    }

    func type(_ ch: Character) {
        guard !isBusy, round.status == .playing else { return }
        if round.type(ch) {
            Haptics.tap()
            onUpdate(round)
        }
    }

    func delete() {
        guard !isBusy else { return }
        if round.deleteLast() {
            Haptics.tap()
            onUpdate(round)
        }
    }

    func submit() {
        guard !isBusy, round.status == .playing else { return }
        switch round.submit(dictionary: dictionary) {
        case .notEnoughLetters: reject("Not enough letters")
        case .notInWordList: reject("Not in word list")
        case .hardMode(let message): reject(message)
        case .roundOver: break
        case .accepted:
            onUpdate(round)
            isBusy = true
            let row = round.guesses.count - 1
            Task {
                // 5 tiles: 100 ms stagger + 250 ms flip.
                try? await Task.sleep(nanoseconds: 700_000_000)
                keyboardRows = round.guesses.count
                switch round.status {
                case .solved:
                    Haptics.success()
                    bounceRow = row
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    onFinish(.solved)
                case .failed:
                    Haptics.error()
                    showToast(round.answer.uppercased(), seconds: 2.2)
                    try? await Task.sleep(nanoseconds: 2_300_000_000)
                    onFinish(.failed)
                case .playing:
                    isBusy = false
                }
            }
        }
    }

    private func reject(_ message: String) {
        Haptics.error()
        withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
        showToast(message)
    }

    func showToast(_ text: String, seconds: Double = 1.4) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if toast == text { withAnimation(.easeIn(duration: 0.2)) { toast = nil } }
        }
    }

    var keyColors: [Character: LetterScore] {
        var map: [Character: LetterScore] = [:]
        for (word, score) in zip(round.guesses.prefix(keyboardRows), round.scores.prefix(keyboardRows)) {
            for (ch, s) in zip(word, score) {
                if let existing = map[ch], existing >= s { continue }
                map[ch] = s
            }
        }
        return map
    }
}

struct WordGameView: View {
    @State private var vm: WordViewModel
    @FocusState private var focused: Bool

    init(round: WordRound, dictionary: WordDictionary,
         onUpdate: @escaping (WordRound) -> Void, onFinish: @escaping (RoundStatus) -> Void) {
        let model = WordViewModel(round: round, dictionary: dictionary)
        model.onUpdate = onUpdate
        model.onFinish = onFinish
        _vm = State(initialValue: model)
    }

    var body: some View {
        GeometryReader { geo in
            let tile = Self.tileSize(in: geo.size, rows: vm.round.maxTries)
            VStack(spacing: 0) {
                WordGrid(vm: vm, tile: tile)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 12)
                WordKeyboard(colors: vm.keyColors,
                             onLetter: { vm.type($0) },
                             onEnter: { vm.submit() },
                             onDelete: { vm.delete() })
            }
            .overlay(alignment: .top) {
                if let toast = vm.toast {
                    Toast(text: toast).padding(.top, 4)
                }
            }
        }
        .padding(.bottom, 4)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            if press.key == .return {
                vm.submit()
                return .handled
            }
            if press.key == .delete {
                vm.delete()
                return .handled
            }
            let chars = press.characters
            if chars.count == 1, let ch = chars.first, ch.isASCII, ch.isLetter {
                vm.type(ch)
                return .handled
            }
            return .ignored
        }
        .onAppear { focused = true }
    }

    private static func tileSize(in size: CGSize, rows: Int) -> CGFloat {
        let keyboardHeight: CGFloat = 3 * 56 + 2 * 8
        let n = CGFloat(rows)
        let byWidth: CGFloat = (size.width - 24) / 5.6
        let byHeight: CGFloat = (size.height - keyboardHeight - 40 - (n - 1) * 6) / n
        return max(36, min(60, min(byWidth, byHeight)))
    }
}

private struct WordGrid: View {
    let vm: WordViewModel
    let tile: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<vm.round.maxTries, id: \.self) { row in
                rowView(row)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Int) -> some View {
        let round = vm.round
        let isCurrent = row == round.guesses.count && round.status == .playing
        let word: [Character] = row < round.guesses.count ? Array(round.guesses[row]) : (isCurrent ? Array(round.current) : [])
        let scores: [LetterScore]? = row < round.scores.count ? round.scores[row] : nil
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { col in
                WordTile(letter: col < word.count ? word[col] : nil,
                         score: scores?[col],
                         index: col,
                         size: tile,
                         bounce: vm.bounceRow == row)
            }
        }
        .modifier(ShakeEffect(animatableData: isCurrent ? CGFloat(vm.shakeTrigger) : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibility(word: word, scores: scores, row: row))
    }

    private func rowAccessibility(word: [Character], scores: [LetterScore]?, row: Int) -> String {
        if word.isEmpty { return "Row \(row + 1), empty" }
        let letters = word.enumerated().map { i, ch -> String in
            let s = scores.map { sc -> String in
                switch sc[i] { case .correct: return " correct"; case .present: return " in word"; case .absent: return " not in word" }
            } ?? ""
            return String(ch).uppercased() + s
        }
        return "Row \(row + 1): " + letters.joined(separator: ", ")
    }
}

/// One tile: pops when typed, flips (rotation3DEffect on X) to reveal its colour.
struct WordTile: View {
    let letter: Character?
    let score: LetterScore?
    let index: Int
    let size: CGFloat
    var bounce = false
    /// When false, an already-scored tile appears without the flip (e.g. restored progress).
    var animateReveal = true

    @State private var angle: Double = 0
    @State private var showFace = false
    @State private var scale: CGFloat = 1
    @State private var lift: CGFloat = 0

    var body: some View {
        ZStack {
            if showFace, let score {
                RoundedRectangle(cornerRadius: 3).fill(color(score))
            } else {
                RoundedRectangle(cornerRadius: 3).fill(Color.white)
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(letter == nil ? Color.keyGrey : Color(hex: 0x878A8C), lineWidth: 2)
            }
            if let letter {
                Text(String(letter).uppercased())
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(showFace ? Color.white : Color.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .offset(y: lift)
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0))
        .onAppear {
            if score != nil { showFace = true }
        }
        .onChange(of: score) { _, newValue in
            if newValue == nil {
                showFace = false
            } else if animateReveal {
                flip()
            } else {
                showFace = true
            }
        }
        .onChange(of: letter) { old, new in
            if new != nil && old == nil { pop() }
        }
        .onChange(of: bounce) { _, isOn in
            if isOn { jump() }
        }
    }

    private func color(_ s: LetterScore) -> Color {
        switch s {
        case .correct: return .wordGreen
        case .present: return .wordYellow
        case .absent: return .wordGrey
        }
    }

    private func flip() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(index) * 100_000_000)
            withAnimation(.easeIn(duration: 0.125)) { angle = 90 }
            try? await Task.sleep(nanoseconds: 125_000_000)
            showFace = true
            withAnimation(.easeOut(duration: 0.125)) { angle = 0 }
        }
    }

    private func pop() {
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.06)) { scale = 1.12 }
            try? await Task.sleep(nanoseconds: 70_000_000)
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { scale = 1 }
        }
    }

    private func jump() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(index) * 90_000_000)
            withAnimation(.easeOut(duration: 0.15)) { lift = -size * 0.35 }
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { lift = 0 }
        }
    }
}

/// Custom on-screen QWERTY keyboard.
struct WordKeyboard: View {
    let colors: [Character: LetterScore]
    let onLetter: (Character) -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void

    private let rows: [[Character]] = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let keyWidth = (geo.size.width - 9 * spacing) / 10
            VStack(spacing: 8) {
                HStack(spacing: spacing) { ForEach(rows[0], id: \.self) { letterKey($0, width: keyWidth) } }
                HStack(spacing: spacing) { ForEach(rows[1], id: \.self) { letterKey($0, width: keyWidth) } }
                HStack(spacing: spacing) {
                    actionKey(label: Text("ENTER").font(.system(size: 13, weight: .bold)), width: keyWidth * 1.5, a11y: "Enter", action: onEnter)
                    ForEach(rows[2], id: \.self) { letterKey($0, width: keyWidth) }
                    actionKey(label: Image(systemName: "delete.left").font(.system(size: 19, weight: .semibold)),
                              width: keyWidth * 1.5, a11y: "Delete", action: onDelete)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 3 * 56 + 2 * 8)
    }

    private func letterKey(_ ch: Character, width: CGFloat) -> some View {
        let state = colors[ch]
        let bg: Color
        switch state {
        case .correct: bg = .wordGreen
        case .present: bg = .wordYellow
        case .absent: bg = .wordGrey
        case nil: bg = .keyGrey
        }
        return Button { onLetter(ch) } label: {
            Text(String(ch).uppercased())
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(state == nil ? Color.textPrimary : Color.white)
                .frame(width: width, height: 56)
                .background(bg, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(ch).uppercased())
    }

    private func actionKey<L: View>(label: L, width: CGFloat, a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .foregroundStyle(Color.textPrimary)
                .frame(width: width, height: 56)
                .background(Color.keyGrey, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}
