import SwiftUI

// MARK: - Chapter 4: Getting to know you

/// 4.0 "Let's set you up, {name}!" with Lockie holding a clipboard.
struct SetupIntroView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        OnboardingPage {
            VStack(spacing: 16) {
                MascotSlot(expression: .clipboard, size: 220)
                    .padding(.top, 20)
                Text("Let's set you up, \(model.friendlyName)!")
                    .appFont(32, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppear(1)
                Text("I'll ask a few quick questions to build your plan.")
                    .appFont(17)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .staggeredAppear(2)
            }
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
    }
}

/// Shared layout for a question: title, optional subtitle, staggered cards, optional Continue.
private struct QuestionPage<Cards: View>: View {
    let title: String
    var subtitle: String?
    /// Multi-select questions show Continue (enabled once something is picked).
    var continueEnabled: Bool?
    var onContinue: () -> Void = {}
    @ViewBuilder var cards: () -> Cards

    var body: some View {
        OnboardingPage(title: title, subtitle: subtitle, centered: false) {
            VStack(spacing: 10) { cards() }
        } footer: {
            if let continueEnabled {
                ChunkyButton(title: "Continue", isEnabled: continueEnabled, action: onContinue)
                    .accessibilityIdentifier("onboarding.continue")
            }
        }
    }
}

/// Toggles `item` in `list`.
private func toggled<T: Equatable>(_ list: [T], _ item: T) -> [T] {
    list.contains(item) ? list.filter { $0 != item } : list + [item]
}

// MARK: 4.1 Source

struct SourceQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        QuestionPage(title: "Where did you hear about us?") {
            ForEach(Array(UserProfile.Source.allCases.enumerated()), id: \.element) { i, source in
                ChoiceCard(title: source.label, symbol: source.symbol, selected: model.profile.source == source,
                           dimmed: model.profile.source != nil) {
                    model.updateProfile { $0.source = source }
                    flow.react(source == .friend ? ["love that", "tell them thanks!"] : ["nice", "got it", "noted ✍️"])
                    autoAdvance { flow.go(.qHours) }
                }
                .staggeredAppear(i + 2)
            }
        }
    }
}

// MARK: 4.2 Hours

struct HoursQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        QuestionPage(title: "How many hours do you spend scrolling each day?",
                     subtitle: "Don't worry about the exact number, just a best guess.") {
            ForEach(Array(UserProfile.ScrollHours.allCases.enumerated()), id: \.element) { i, hours in
                ChoiceCard(title: hours.label, symbol: "clock", selected: model.profile.scrollHours == hours,
                           dimmed: model.profile.scrollHours != nil) {
                    model.updateProfile { $0.scrollHours = hours }
                    switch hours {
                    case .under2: flow.react(["not bad!", "nice"])
                    case .from2to4: flow.react(["classic", "relatable"])
                    case .from4to6: flow.react(["hmm", "we can fix that"])
                    case .from6to8: flow.react(["oof", "yikes"])
                    case .over8: flow.react(["oof", "ok we got work to do"])
                    }
                    autoAdvance { flow.go(.qApps) }
                }
                .staggeredAppear(i + 2)
            }
        }
    }
}

// MARK: 4.3 Apps

struct AppsQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        let picked = model.profile.wasters
        QuestionPage(title: "Which apps eat most of your time?", continueEnabled: !picked.isEmpty,
                     onContinue: { flow.go(.qFeelings) }) {
            ForEach(Array(UserProfile.Waster.allCases.enumerated()), id: \.element) { i, waster in
                ChoiceCard(title: waster.label, symbol: waster.symbol, selected: picked.contains(waster), multi: true) {
                    let adding = !picked.contains(waster)
                    model.updateProfile { $0.wasters = toggled($0.wasters, waster) }
                    if adding {
                        flow.react(waster == .shortVideos ? ["the worst one", "classic"] : ["same", "yep", "noted"])
                    }
                }
                .staggeredAppear(i + 2)
            }
        }
    }
}

// MARK: 4.4 Feelings

struct FeelingsQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        let picked = model.profile.feelings
        QuestionPage(title: "How do you feel after scrolling?", continueEnabled: !picked.isEmpty,
                     onContinue: { flow.go(.qWants) }) {
            ForEach(Array(UserProfile.Feeling.allCases.enumerated()), id: \.element) { i, feeling in
                ChoiceCard(title: feeling.label, emoji: feeling.emoji, selected: picked.contains(feeling), multi: true) {
                    let adding = !picked.contains(feeling)
                    model.updateProfile { $0.feelings = toggled($0.feelings, feeling) }
                    guard adding else { return }
                    switch feeling {
                    case .guilty: flow.react(["same", "been there"])
                    case .fine: flow.react(["love that for you", "lucky!"])
                    case .wasting: flow.react(["not anymore", "we'll fix it"])
                    default: flow.react(["same", "i get it", "felt that"])
                    }
                }
                .staggeredAppear(i + 2)
            }
        }
    }
}

// MARK: 4.5 Wants

struct WantsQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        let picked = model.profile.wants
        QuestionPage(title: "What do you want more of?", continueEnabled: !picked.isEmpty,
                     onContinue: { flow.go(.qPuzzles) }) {
            ForEach(Array(UserProfile.Want.Area.allCases.enumerated()), id: \.element) { a, area in
                ChoiceSectionHeader(title: area.rawValue)
                    .staggeredAppear(a * 4 + 2)
                ForEach(Array(UserProfile.Want.allCases.filter { $0.area == area }.enumerated()), id: \.element) { i, want in
                    ChoiceCard(title: want.label, emoji: want.emoji, selected: picked.contains(want), multi: true) {
                        let adding = !picked.contains(want)
                        model.updateProfile { $0.wants = toggled($0.wants, want) }
                        if adding { flow.react(["good one", "yes!", "love it", "great pick"]) }
                    }
                    .staggeredAppear(a * 4 + i + 3)
                }
            }
        }
    }
}

// MARK: 4.6 Puzzles

struct PuzzlesQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    private func emoji(_ game: GameID) -> String {
        switch game {
        case .chess: return "♟️"
        case .sudoku: return "🔢"
        case .math: return "➗"
        case .word: return "🔤"
        }
    }

    var body: some View {
        let enabled = model.settings.enabledGames
        QuestionPage(title: "Which puzzles sound fun?", continueEnabled: !enabled.isEmpty, onContinue: {
            flow.react(["great choice", "nice mix", "your brain says thanks"])
            flow.go(.qChallenge)
        }) {
            ForEach(Array(GameID.allCases.enumerated()), id: \.element) { i, game in
                ChoiceCard(title: game.displayName, emoji: emoji(game), selected: enabled.contains(game), multi: true) {
                    // At least one game stays on (setGame refuses to turn off the last one).
                    _ = model.setGame(game, enabled: !enabled.contains(game))
                }
                .staggeredAppear(i + 2)
            }
        }
    }
}

// MARK: 4.7 Challenge

struct ChallengeQuestion: View {
    let flow: OnboardingModel
    @Environment(AppModel.self) private var model

    var body: some View {
        let current = model.profile.challenge ?? .balanced
        QuestionPage(title: "How hard should unlocking be?") {
            ForEach(Array(UserProfile.Challenge.allCases.enumerated()), id: \.element) { i, challenge in
                ChoiceCard(title: challenge.label, emoji: challenge.emoji, selected: current == challenge, dimmed: true) {
                    model.applyChallenge(challenge)
                    switch challenge {
                    case .chill: flow.react(["easy does it", "chill it is"])
                    case .balanced: flow.react(["smart pick", "perfect balance"])
                    case .tough: flow.react(["respect 💪", "let's go"])
                    case .monk: flow.react(["whoa. respect", "monk mode 🧘"])
                    }
                    autoAdvance { flow.go(.turnIntro) }
                }
                .staggeredAppear(i + 2)
            }
        }
        .onAppear {
            // "Balanced" is the default.
            if model.profile.challenge == nil { model.applyChallenge(.balanced) }
        }
    }
}
