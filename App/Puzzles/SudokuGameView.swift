import Observation
import SwiftUI

@Observable
@MainActor
final class SudokuViewModel {
    private(set) var round: SudokuRound
    var selected: Int?
    var notesMode = false
    var flashing = false
    var shakeTrigger = 0

    @ObservationIgnored var onUpdate: (SudokuRound) -> Void = { _ in }
    @ObservationIgnored var onFinish: (RoundStatus) -> Void = { _ in }

    init(round: SudokuRound) {
        self.round = round
        selected = (0..<round.layout.cellCount).first { round.cells[$0] == 0 }
    }

    var layout: SudokuLayout { round.layout }

    func select(_ i: Int) {
        guard round.status == .playing else { return }
        Haptics.tap()
        withAnimation(.selectionSpring) { selected = i }
    }

    func enter(_ digit: Int) {
        guard let i = selected, round.status == .playing, !round.isGiven(i) else { return }
        Haptics.tap()
        if notesMode {
            round.toggleNote(digit, at: i)
        } else {
            round.set(digit, at: i)
            if round.conflicts.contains(i) {
                Haptics.error()
            }
        }
        changed()
    }

    func erase() {
        guard let i = selected else { return }
        Haptics.tap()
        round.erase(at: i)
        changed()
    }

    func hint() {
        guard round.hintsLeft > 0 else {
            Haptics.error()
            return
        }
        if let filled = round.hint(at: selected) {
            Haptics.tap()
            withAnimation(.selectionSpring) { selected = filled }
            changed()
        }
    }

    private func changed() {
        onUpdate(round)
        if round.status == .solved {
            Haptics.success()
            flashing = true
            Task {
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                onFinish(.solved)
            }
        }
    }
}

struct SudokuGameView: View {
    @State private var vm: SudokuViewModel
    @Environment(\.palette) private var palette

    init(round: SudokuRound, onUpdate: @escaping (SudokuRound) -> Void, onFinish: @escaping (RoundStatus) -> Void) {
        let model = SudokuViewModel(round: round)
        model.onUpdate = onUpdate
        model.onFinish = onFinish
        _vm = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 14) {
            SudokuBoard(vm: vm)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            toolRow
            numberPad
        }
        .padding(.bottom, 4)
    }

    private var toolRow: some View {
        HStack(spacing: 10) {
            tool(icon: "eraser", title: "Erase", active: false) { vm.erase() }
            tool(icon: vm.notesMode ? "pencil.circle.fill" : "pencil", title: vm.notesMode ? "Notes On" : "Notes", active: vm.notesMode) {
                Haptics.tap()
                withAnimation(.selectionSpring) { vm.notesMode.toggle() }
            }
            tool(icon: "lightbulb", title: "Hint (\(vm.round.hintsLeft))", active: false) { vm.hint() }
                .opacity(vm.round.hintsLeft > 0 ? 1 : 0.4)
        }
    }

    private func tool(icon: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(active ? Color.brandRed : palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
    }

    private var numberPad: some View {
        let size = vm.layout.size
        let columns = size == 9 ? 5 : 6
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(1...size, id: \.self) { d in
                let done = vm.round.placedCount(d) >= size
                Button { vm.enter(d) } label: {
                    Text("\(d)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.brandRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                }
                .buttonStyle(PressableStyle())
                .opacity(done ? 0 : 1)
                .disabled(done)
                .animation(.easeOut(duration: 0.25), value: done)
                .accessibilityLabel("\(d)")
            }
        }
    }
}

struct SudokuBoard: View {
    let vm: SudokuViewModel

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let n = vm.layout.size
            let cell = side / CGFloat(n)
            ZStack(alignment: .topLeading) {
                ForEach(0..<vm.layout.cellCount, id: \.self) { i in
                    SudokuCell(vm: vm, index: i, size: cell)
                        .position(x: (CGFloat(vm.layout.col(i)) + 0.5) * cell, y: (CGFloat(vm.layout.row(i)) + 0.5) * cell)
                }
                SudokuGridLines(layout: vm.layout)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SudokuCell: View {
    let vm: SudokuViewModel
    let index: Int
    let size: CGFloat

    var body: some View {
        let round = vm.round
        let layout = round.layout
        let value = round.cells[index]
        let isConflict = value != 0 && round.conflicts.contains(index)
        ZStack {
            cellColor
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: size * 0.56, weight: round.isGiven(index) ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isConflict ? Color(hex: 0xE5292F) : (round.isGiven(index) ? Color.textPrimary : Color.brandRed))
            } else if round.notes[index] != 0 {
                notesGrid(layout: layout)
            }
            Color.correctGreen
                .allowsHitTesting(false)
                .modifier(FlashModifier(active: vm.flashing, delay: Double(layout.row(index) + layout.col(index)) * 0.04))
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { vm.select(index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(value: value, isConflict: isConflict))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(vm.selected == index ? .isSelected : [])
    }

    private var cellColor: Color {
        let round = vm.round
        let layout = round.layout
        guard let s = vm.selected else { return .white }
        if s == index { return Color.brandRed.opacity(0.2) }
        let selValue = round.cells[s]
        if selValue != 0 && round.cells[index] == selValue { return Color.brandRed.opacity(0.09) }
        if layout.row(s) == layout.row(index) || layout.col(s) == layout.col(index) || layout.box(s) == layout.box(index) {
            return Color(hex: 0xF1F1F4)
        }
        return .white
    }

    private func notesGrid(layout: SudokuLayout) -> some View {
        let cols = 3
        let rows = layout.size / cols
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        let d = r * cols + c + 1
                        Text(vm.round.hasNote(d, at: index) ? "\(d)" : " ")
                            .font(.system(size: size * 0.22, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(size * 0.06)
    }

    private func accessibilityText(value: Int, isConflict: Bool) -> String {
        let layout = vm.round.layout
        var s = "Row \(layout.row(index) + 1), column \(layout.col(index) + 1), "
        if value == 0 {
            let notes = (1...layout.size).filter { vm.round.hasNote($0, at: index) }
            s += notes.isEmpty ? "empty" : "empty, notes \(notes.map(String.init).joined(separator: " "))"
        } else {
            s += "\(value)" + (vm.round.isGiven(index) ? ", given" : "") + (isConflict ? ", conflict" : "")
        }
        return s
    }
}

/// A green flash that cascades across the board when solved.
private struct FlashModifier: ViewModifier {
    let active: Bool
    let delay: Double
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onChange(of: active) { _, isOn in
                guard isOn else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    withAnimation(.easeOut(duration: 0.25)) { opacity = 0.6 }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.easeIn(duration: 0.4)) { opacity = 0.2 }
                }
            }
    }
}

/// Thin 0.5pt cell lines and 2pt box lines.
struct SudokuGridLines: View {
    let layout: SudokuLayout

    var body: some View {
        Canvas { context, size in
            let n = layout.size
            let cell = size.width / CGFloat(n)
            var thin = Path()
            var thick = Path()
            for i in 0...n {
                let p = CGFloat(i) * cell
                let vertical = Path { $0.move(to: CGPoint(x: p, y: 0)); $0.addLine(to: CGPoint(x: p, y: size.height)) }
                let horizontal = Path { $0.move(to: CGPoint(x: 0, y: p)); $0.addLine(to: CGPoint(x: size.width, y: p)) }
                if i % layout.boxCols == 0 { thick.addPath(vertical) } else { thin.addPath(vertical) }
                if i % layout.boxRows == 0 { thick.addPath(horizontal) } else { thin.addPath(horizontal) }
            }
            context.stroke(thin, with: .color(Color(hex: 0xB8B8C0)), lineWidth: 0.5)
            context.stroke(thick, with: .color(Color.textPrimary), lineWidth: 2)
        }
    }
}
