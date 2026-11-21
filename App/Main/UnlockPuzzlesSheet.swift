import SwiftUI

/// "Unlock puzzles" bottom sheet: enable/disable games used for unlocks.
struct UnlockPuzzlesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: "Unlock puzzles") { dismiss() }
            Text("\(model.settings.enabledGames.count) enabled")
                .appFont(17, .semibold)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 22)
            VStack(spacing: 0) {
                ForEach(Array(GameID.allCases.enumerated()), id: \.element) { index, game in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack(spacing: 14) {
                        Image(systemName: game.systemIcon)
                            .appFont(20, .semibold)
                            .foregroundStyle(palette.accent)
                            .frame(width: 40, height: 40)
                            .background(palette.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(game.displayName)).appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                            Text(LocalizedStringKey(model.settings.difficulty(for: game).displayName))
                                .appFont(15).foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        PillToggle(isOn: binding(for: game), label: game.localizedName)
                    }
                    .padding(.vertical, 10)
                }
            }
            .card()
            .padding(.horizontal, 16)
            if let hint {
                Text(hint)
                    .appFont(14, .semibold)
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 22)
                    .transition(.opacity)
            }
            FooterText(text: "Your puzzles take turns in a shuffled order.")
            Button {
                Haptics.tap()
                dismiss()
                model.selectedTab = .puzzles
            } label: {
                Label("More options", systemImage: "plus")
                    .appFont(18, .semibold)
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(palette.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 16)
            Spacer()
        }
        .screenBackground()
    }

    private func binding(for game: GameID) -> Binding<Bool> {
        Binding(get: { model.settings.isEnabled(game) },
                set: { on in
                    if !model.setGame(game, enabled: on) {
                        Haptics.error()
                        withAnimation { hint = String(localized: "Keep at least one puzzle enabled.") }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { hint = nil }
                        }
                    }
                })
    }
}
