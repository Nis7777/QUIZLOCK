import Observation
import SwiftUI

@Observable
@MainActor
final class MathViewModel {
    private(set) var round: MathRound
    var shakeTrigger = 0
    var showWrongTint = false
    var revealedAnswer: String?
    var isBusy = false

    @ObservationIgnored var onUpdate: (MathRound) -> Void = { _ in }
    @ObservationIgnored var onFinish: (RoundStatus) -> Void = { _ in }

    init(round: MathRound) { self.round = round }

    func press(_ key: String) {
        guard !isBusy else { return }
        Haptics.tap()
        if key == "⌫" { round.backspace() } else { round.type(key) }
        showWrongTint = false
        onUpdate(round)
    }

    func check() {
        guard !isBusy else { return }
        let result = round.check()
        onUpdate(round)
        switch result {
        case .empty:
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
        case .correct:
            Haptics.success()
            isBusy = true
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                onFinish(.solved)
            }
        case .wrong:
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
            withAnimation(.easeOut(duration: 0.2)) { showWrongTint = true }
        case .failed:
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
            withAnimation { revealedAnswer = round.question.answerText }
            isBusy = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                onFinish(.failed)
            }
        }
    }
}

struct MathGameView: View {
    @State private var vm: MathViewModel
    @Environment(\.palette) private var palette

    init(round: MathRound, onUpdate: @escaping (MathRound) -> Void, onFinish: @escaping (RoundStatus) -> Void) {
        let model = MathViewModel(round: round)
        model.onUpdate = onUpdate
        model.onFinish = onFinish
        _vm = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            Text(vm.round.question.text)
                .appFont(34, .bold)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(spoken(vm.round.question.text))
            Spacer(minLength: 12)
            answerField
                .modifier(ShakeModifier(trigger: vm.shakeTrigger))
            if let answer = vm.revealedAnswer {
                Text("Answer: \(answer)")
                    .appFont(19, .bold)
                    .foregroundStyle(Color.errorRed)
                    .padding(.top, 10)
                    .transition(.opacity)
            } else if vm.round.wrongCount > 0 && vm.round.status == .playing {
                Text("\(MathRound.maxWrong - vm.round.wrongCount) tries left")
                    .appFont(15, .medium)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 10)
            }
            Spacer(minLength: 12)
            MathKeypad(onKey: { vm.press($0) }, onCheck: { vm.check() })
        }
        .padding(.bottom, 4)
    }

    private var answerField: some View {
        let solved = vm.round.status == .solved
        let text = vm.round.input.isEmpty ? (solved ? vm.round.question.answerText : "?") : vm.round.input
        return HStack(spacing: 12) {
            Text(text)
                .appFont(60, .bold, design: .rounded)
                .foregroundStyle(vm.round.input.isEmpty && !solved ? Color(hex: 0xC7C7CC) : (solved ? Color.answerGreen : Color.textPrimary))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if solved {
                Image(systemName: "checkmark.circle.fill")
                    .appFont(34)
                    .foregroundStyle(Color.correctGreen)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .background(fieldColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .animation(.selectionSpring, value: solved)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(solved ? "Correct, \(text)" : "Your answer: \(vm.round.input.isEmpty ? "empty" : text)")
    }

    private var fieldColor: Color {
        if vm.round.status == .solved { return .correctGreenBg }
        if vm.showWrongTint || vm.revealedAnswer != nil { return Color.errorRed.opacity(0.12) }
        return .white
    }

    private func spoken(_ s: String) -> String {
        s.replacingOccurrences(of: "×", with: " times ")
            .replacingOccurrences(of: "÷", with: " divided by ")
            .replacingOccurrences(of: MathEngine.minus, with: " minus ")
            .replacingOccurrences(of: "²", with: " squared")
            .replacingOccurrences(of: "√", with: "square root of ")
    }
}

/// Custom numeric keypad: 1–9, ".", 0, "±" (flips the sign), ⌫ and a full-width Check button.
struct MathKeypad: View {
    let onKey: (String) -> Void
    let onCheck: () -> Void
    @Environment(\.palette) private var palette

    private let rows: [[String]] = [["1", "2", "3", "⌫"], ["4", "5", "6", MathEngine.minus], ["7", "8", "9", "."]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in keyButton(key) }
                }
            }
            keyButton("0")
            Button(action: onCheck) {
                Text("Check")
                    .appFont(19, .bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button { onKey(key) } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left").appFont(22, .semibold)
                } else {
                    // The minus key flips the sign of the answer, so it reads "±".
                    Text(key == MathEngine.minus ? "±" : key).appFont(26, .semibold, design: .rounded)
                }
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(key == "⌫" ? "Delete" : key == MathEngine.minus ? "Plus or minus" : key == "." ? "Point" : key)
    }
}
