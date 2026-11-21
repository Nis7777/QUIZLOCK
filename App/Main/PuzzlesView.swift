import SwiftUI

/// Puzzles tab: enabled-game chips and the 4 game cards.
struct PuzzlesTab: View {
    @Environment(AppModel.self) private var model
    @State private var path: [GameID] = []

    var body: some View {
        NavigationStack(path: $path) {
            PuzzlesView(path: $path)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: GameID.self) { game in
                    PuzzleDetailView(game: game)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                }
        }
    }
}

struct PuzzlesView: View {
    @Binding var path: [GameID]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showManage = false
    @State private var hint: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                TabHeader()
                DailyPuzzleCard()
                    .padding(.top, 6)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Unlock puzzles").appFont(20, .semibold).foregroundStyle(palette.textPrimary)
                    Text("\(model.settings.enabledGames.count)").appFont(18).foregroundStyle(palette.textSecondary)
                    Spacer()
                    Button("Manage") { showManage = true }
                        .tapTarget()
                        .appFont(17, .semibold)
                        .foregroundStyle(palette.accentText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Text("Your puzzles take turns in a shuffled order.")
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 20)
                chips
                if let hint {
                    Text(hint).appFont(14, .semibold).foregroundStyle(palette.accentText)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
                Text("All puzzles")
                    .appFont(20, .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                ForEach(GameID.allCases) { game in
                    GameCard(game: game,
                             inUse: model.settings.isEnabled(game),
                             onOpen: { path.append(game) },
                             onToggle: { toggle(game, $0) },
                             onTry: { model.tryPractice(game) })
                }
            }
            .padding(.bottom, 120)
        }
        .screenBackground()
        .sheet(isPresented: $showManage) {
            UnlockPuzzlesSheet()
                .environment(model)
                .environment(\.palette, model.palette)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.settings.enabledGames) { game in
                    Button { toggle(game, false) } label: {
                        HStack(spacing: 8) {
                            Text(LocalizedStringKey(game.displayName)).appFont(16, .medium)
                            Image(systemName: "xmark").appFont(13, .semibold)
                        }
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(palette.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(String(localized: "Remove \(game.localizedName)"))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .animation(.selectionSpring, value: model.settings.enabledGames)
        }
    }

    private func toggle(_ game: GameID, _ on: Bool) {
        Haptics.tap()
        if !model.setGame(game, enabled: on) {
            Haptics.error()
            withAnimation { hint = String(localized: "Keep at least one puzzle enabled.") }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation { hint = nil }
            }
        }
    }
}

extension GameID {
    func metaLine(chessCount: Int) -> String {
        switch self {
        case .chess: return String(localized: "Mate in 1–2 · \(chessCount) puzzles")
        case .sudoku: return String(localized: "Endless · Unique solutions")
        case .math: return String(localized: "Endless · Type your answer")
        case .word:
            return String(localized: "6 tries · Real words only")
        }
    }
}

private struct GameCard: View {
    let game: GameID
    let inUse: Bool
    let onOpen: () -> Void
    let onToggle: (Bool) -> Void
    let onTry: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 16) {
                    GameIcon(game: game, size: 115)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(game.displayName)).appFont(22, .semibold).foregroundStyle(palette.textPrimary)
                        Text(LocalizedStringKey(game.tagline)).appFont(16).foregroundStyle(palette.textSecondary)
                        Text(game.metaLine(chessCount: model.rounds.chessBank.puzzles.count))
                            .appFont(14).foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
            HStack {
                Text("Use for unlocks").appFont(16).foregroundStyle(palette.textPrimary)
                Spacer()
                PillToggle(isOn: Binding(get: { inUse }, set: { onToggle($0) }), label: String(localized: "Use \(game.localizedName) for unlocks"))
                Button(action: onTry) {
                    HStack(spacing: 4) {
                        Text("Try")
                        Image(systemName: "chevron.right").appFont(14, .bold)
                    }
                    .appFont(17, .semibold)
                    .foregroundStyle(palette.accentText)
                    .padding(.leading, 14)
                    .tapTarget()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(inUse ? palette.accent : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .animation(.selectionSpring, value: inUse)
    }
}
