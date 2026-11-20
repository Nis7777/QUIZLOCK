import SwiftUI

// One question per screen. Single-choice screens auto-advance 0.3s after a tap;
// multi-select screens use a Continue button. Every tap has a haptic (ChoiceCard / ChoiceTile).

/// 1. "What should we call you?"
struct NameQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        QuizScaffold(progress: progress, title: "What should we call you?",
                     subtitle: "We'll use it to personalise your plan.", onBack: onBack) {
            TextField("Your name", text: $name)
                .appFont(22, .semibold)
                .foregroundStyle(palette.textPrimary)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { save() }
                .padding(.horizontal, 18)
                .frame(minHeight: 64)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(focused ? palette.accent : palette.separator, lineWidth: focused ? 2 : 1))
        } footer: {
            VStack(spacing: 6) {
                PrimaryButton(title: "Continue", isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) { save() }
                Button("Skip") {
                    model.updateProfile { $0.name = "" }
                    onNext()
                }
                .appFont(16, .semibold)
                .foregroundStyle(palette.accentText)
                .tapTarget()
            }
        }
        .onAppear {
            name = model.profile.name
            focused = name.isEmpty
        }
    }

    private func save() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !trimmed.isEmpty else { return }
        focused = false
        model.updateProfile { $0.name = trimmed }
        onNext()
    }
}

/// 2. Age range.
struct AgeQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let name = model.profile.trimmedName
        QuizScaffold(progress: progress,
                     title: name.isEmpty ? String(localized: "How old are you?") : String(localized: "Nice to meet you, \(name)!"),
                     subtitle: name.isEmpty ? nil : String(localized: "How old are you?"),
                     onBack: onBack) {
            VStack(spacing: 12) {
                ForEach(UserProfile.AgeRange.allCases) { option in
                    ChoiceCard(title: option.label, selected: model.profile.ageRange == option) {
                        model.updateProfile { $0.ageRange = option }
                        autoAdvance(onNext)
                    }
                }
            }
        }
    }
}

/// 3. Daily screen time.
struct ScreenTimeQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        QuizScaffold(progress: progress, title: "How much time do you spend on your phone each day?", onBack: onBack) {
            VStack(spacing: 12) {
                ForEach(UserProfile.ScreenTimeRange.allCases) { option in
                    ChoiceCard(title: option.label, selected: model.profile.screenTime == option) {
                        model.updateProfile { $0.screenTime = option }
                        if option != .unknown { autoAdvance(onNext) }
                    }
                }
                if model.profile.screenTime == .unknown {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(palette.accent).accessibilityHidden(true)
                        Text("Check Settings → Screen Time to see your daily average. We'll use 4 hours for now.")
                            .appFont(15)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(palette.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity)
                }
            }
        } footer: {
            if model.profile.screenTime == .unknown {
                PrimaryButton(title: "Continue", action: onNext)
            }
        }
    }
}

/// 4. Biggest time-wasters (multi-select).
struct WastersQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        QuizScaffold(progress: progress, title: "What eats most of your time?",
                     subtitle: "Pick all that apply.", onBack: onBack) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(UserProfile.Waster.allCases) { option in
                    ChoiceTile(title: option.label, symbol: option.symbol, selected: model.profile.wasters.contains(option)) {
                        model.updateProfile { p in
                            if let i = p.wasters.firstIndex(of: option) { p.wasters.remove(at: i) } else { p.wasters.append(option) }
                        }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", isEnabled: !model.profile.wasters.isEmpty, action: onNext)
        }
    }
}

/// 5. Main goal.
struct GoalQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        QuizScaffold(progress: progress, title: "What's your main goal?", onBack: onBack) {
            VStack(spacing: 12) {
                ForEach(UserProfile.Goal.allCases) { option in
                    ChoiceCard(title: option.label, symbol: option.symbol, selected: model.profile.goal == option) {
                        model.updateProfile { $0.goal = option }
                        autoAdvance(onNext)
                    }
                }
            }
        }
    }
}

/// 6. How scrolling makes you feel (multi-select).
struct FeelingsQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        QuizScaffold(progress: progress, title: "How does scrolling make you feel?",
                     subtitle: "Pick all that apply.", onBack: onBack) {
            VStack(spacing: 12) {
                ForEach(UserProfile.Feeling.allCases) { option in
                    ChoiceCard(title: option.label, symbol: option.symbol,
                               selected: model.profile.feelings.contains(option), multi: true) {
                        model.updateProfile { p in
                            if let i = p.feelings.firstIndex(of: option) { p.feelings.remove(at: i) } else { p.feelings.append(option) }
                        }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", isEnabled: !model.profile.feelings.isEmpty, action: onNext)
        }
    }
}

/// 7. When it happens most.
struct WhenQuestionView: View {
    let progress: Double
    let onBack: () -> Void
    let onNext: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        QuizScaffold(progress: progress, title: "When does it happen most?", onBack: onBack) {
            VStack(spacing: 12) {
                ForEach(UserProfile.When.allCases) { option in
                    ChoiceCard(title: option.label, symbol: option.symbol, selected: model.profile.when == option) {
                        model.updateProfile { $0.when = option }
                        autoAdvance(onNext)
                    }
                }
            }
        }
    }
}
