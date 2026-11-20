import SwiftUI

/// "Puzzles per unlock" bottom sheet (medium detent).
struct PuzzlesPerUnlockSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let count = model.lock.puzzlesPerUnlock
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Puzzles per unlock") { dismiss() }
            Text("Puzzles you need to solve to unlock any app. One math answer, one word, one Sudoku grid or one chess puzzle each counts as one.")
                .font(.system(size: 16))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
            HStack {
                Text("\(count) puzzle\(count == 1 ? "" : "s")")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText())
                Spacer()
                HStack(spacing: 0) {
                    stepButton("minus", enabled: count > 1) { set(count - 1) }
                    Rectangle().fill(palette.separator).frame(width: 1, height: 22)
                    stepButton("plus", enabled: count < 10) { set(count + 1) }
                }
                .background(palette.fieldFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .card()
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .accessibilityValue("\(count)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: set(count + 1)
                case .decrement: set(count - 1)
                @unknown default: break
                }
            }
            FooterText(text: "Choose 1–10. Progress is saved if you leave. Changes apply to the next unlock.")
            Spacer()
        }
        .screenBackground()
    }

    private func set(_ value: Int) {
        let v = min(10, max(1, value))
        Haptics.tap()
        withAnimation(.selectionSpring) { model.updateLock(applyShield: false) { $0.puzzlesPerUnlock = v } }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? palette.textPrimary : palette.textSecondary.opacity(0.5))
                .frame(width: 52, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}

/// Centred sheet title with a coral "Done" pill.
struct SheetHeader: View {
    let title: String
    let onDone: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(palette.textPrimary)
            HStack {
                Spacer()
                PillButton(title: "Done", action: onDone)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }
}
