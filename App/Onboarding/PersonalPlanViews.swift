import StoreKit
import UIKit
import SwiftUI

/// 8. "Calculating" (2.5s): a coral progress ring with three steps ticking off.
struct CalculatingView: View {
    let progress: Double
    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @State private var fill: Double = 0
    @State private var doneSteps = 0

    private let steps = ["Analysing your answers", "Calculating your screen time", "Building your plan"]

    var body: some View {
        VStack(spacing: 0) {
            QuizProgressBar(progress: progress)
                .padding(.horizontal, 20)
                .padding(.top, 26)
            Spacer()
            ZStack {
                Circle().stroke(palette.fieldFill, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(Int(fill * 100))%")
                    .appFont(34, .bold, design: .rounded)
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText())
            }
            .frame(width: 170, height: 170)
            .accessibilityElement()
            .accessibilityLabel("Building your plan")
            .accessibilityValue("\(Int(fill * 100)) percent")
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 12) {
                        Image(systemName: i < doneSteps ? "checkmark.circle.fill" : "circle")
                            .appFont(22)
                            .foregroundStyle(i < doneSteps ? palette.accent : Color(hex: 0xC7C7CC))
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey(step))
                            .appFont(17, .semibold)
                            .foregroundStyle(i < doneSteps ? palette.textPrimary : palette.textSecondary)
                    }
                }
            }
            .padding(.top, 40)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .task {
            withAnimation(.easeInOut(duration: 2.5)) { fill = 1 }
            for i in 1...steps.count {
                try? await Task.sleep(nanoseconds: 780_000_000)
                withAnimation(.selectionSpring) { doneSteps = i }
                Haptics.tap()
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            onDone()
        }
    }
}

/// 9. The reality check: years of life on the phone, and with QuizLock.
struct RealityCheckView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var grow = false

    var body: some View {
        let p = model.profile
        let years = p.yearsOnPhone
        let withApp = p.yearsWithQuizLock
        let name = p.trimmedName
        QuizScaffold(progress: progress,
                     title: name.isEmpty ? String(localized: "The reality check") : String(localized: "\(name), here's the reality check"),
                     onBack: onBack) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're on track to spend")
                        .appFont(20, .medium)
                        .foregroundStyle(palette.textSecondary)
                    Text("\(format(years)) years")
                        .appFont(64, .black, design: .rounded)
                        .foregroundStyle(palette.accent)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("of your life on your phone.")
                        .appFont(20, .medium)
                        .foregroundStyle(palette.textSecondary)
                }
                .accessibilityElement(children: .combine)
                VStack(spacing: 14) {
                    bar(label: String(localized: "Right now"), value: years, max: years, color: palette.textSecondary.opacity(0.45))
                    bar(label: String(localized: "With \(Brand.appName)"), value: withApp, max: years, color: palette.accent)
                }
                .card()
                Text("Estimate based on your answers.")
                    .appFont(13)
                    .foregroundStyle(palette.textSecondary)
            }
        } footer: {
            PrimaryButton(title: "Show my plan", action: onNext)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.2)) { grow = true } }
    }

    private func format(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }

    private func bar(label: String, value: Double, max maxValue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).appFont(15, .semibold).foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(format(value)) years").appFont(15, .semibold).foregroundStyle(palette.textSecondary)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(color)
                    .frame(width: grow && maxValue > 0 ? geo.size.width * value / maxValue : 8)
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 10. The personalised plan (pre-fills the later setup screens).
struct PlanView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let p = model.profile
        let name = p.trimmedName
        QuizScaffold(progress: progress,
                     title: name.isEmpty ? String(localized: "Your plan") : String(localized: "\(name), here's your plan"),
                     subtitle: String(localized: "Built from your answers. You can change everything later."),
                     onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                row(icon: p.goal?.symbol ?? "target", title: "Your goal",
                    value: String(localized: String.LocalizationValue((p.goal ?? .doomscroll).label)))
                Divider().padding(.leading, 46)
                row(icon: "lock.fill", title: "Apps to lock",
                    value: p.suggestedCategories.map { String(localized: String.LocalizationValue($0.label)) }.formatted(.list(type: .and)))
                Divider().padding(.leading, 46)
                row(icon: "timer", title: "Unlock time", value: p.suggestedDuration.localizedLabel)
                Divider().padding(.leading, 46)
                row(icon: "puzzlepiece.fill", title: "Puzzle mix",
                    value: p.suggestedGames.map { String(localized: String.LocalizationValue($0.displayName)) }.formatted(.list(type: .and)))
            }
            .card()
        } footer: {
            PrimaryButton(title: "Use this plan") {
                model.applyPlan()
                onNext()
            }
        }
    }

    private func row(icon: String, title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .appFont(20, .semibold)
                .foregroundStyle(palette.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).appFont(15, .semibold).foregroundStyle(palette.textSecondary)
                Text(value).appFont(18, .semibold).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// 11. "Hold to commit" (1.5s, a ring fills with continuous haptics, then confetti).
struct CommitmentView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var fill: Double = 0
    @State private var holding = false
    @State private var committed = false
    @State private var hapticTask: Task<Void, Never>?

    var body: some View {
        let goal = model.profile.goal ?? .doomscroll
        QuizScaffold(progress: progress, title: "Make a promise to yourself", onBack: onBack) {
            VStack(spacing: 30) {
                Text(LocalizedStringKey("“" + goal.promise + "”"))
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(22)
                    .background(palette.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                ZStack {
                    Circle().stroke(palette.fieldFill, lineWidth: 10).frame(width: 190, height: 190)
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 190, height: 190)
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 160, height: 160)
                        .scaleEffect(holding ? 0.94 : 1)
                        .shadow(color: Color.brand.opacity(0.35), radius: 16, y: 8)
                    VStack(spacing: 6) {
                        Image(systemName: committed ? "checkmark" : "hand.tap.fill")
                            .appFont(34, .bold)
                        Text(LocalizedStringKey(committed ? "Committed!" : "Hold to commit"))
                            .appFont(17, .bold)
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 60) {
                    commit()
                } onPressingChanged: { pressing in
                    pressingChanged(pressing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(committed ? "Committed" : "Hold to commit")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { commit() }
            }
        } footer: {
            if committed {
                PrimaryButton(title: "Continue", action: onNext)
                    .transition(.opacity)
            }
        }
        .confetti(committed)
        .onDisappear { hapticTask?.cancel() }
    }

    private func pressingChanged(_ pressing: Bool) {
        guard !committed else { return }
        holding = pressing
        hapticTask?.cancel()
        if pressing {
            withAnimation(.linear(duration: 1.5)) { fill = 1 }
            hapticTask = Task { @MainActor in
                let generator = UIImpactFeedbackGenerator(style: .soft)
                while !Task.isCancelled {
                    generator.impactOccurred(intensity: 0.4 + fill * 0.6)
                    try? await Task.sleep(nanoseconds: 90_000_000)
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { fill = 0 }
        }
    }

    private func commit() {
        guard !committed else { return }
        hapticTask?.cancel()
        Haptics.success()
        withAnimation(.selectionSpring) {
            fill = 1
            holding = false
            committed = true
        }
        model.updateProfile { $0.committed = true }
    }
}

/// 12. "Help us grow": asks for a rating once. Never gates anything.
struct RatingRequestView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        QuizScaffold(progress: progress, title: "Help us grow",
                     subtitle: String(localized: "\(Brand.appName) is made by a tiny team. If you like it so far, a rating helps other people find it."),
                     onBack: onBack) {
            AssetImage(name: "mascot_pointing", placeholderSymbol: "face.smiling", contentMode: .fit)
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } footer: {
            PrimaryButton(title: "Continue") {
                if !model.settings.ratingRequested {
                    model.updateSettings { $0.ratingRequested = true }
                    requestReview()
                }
                onNext()
            }
        }
    }
}
