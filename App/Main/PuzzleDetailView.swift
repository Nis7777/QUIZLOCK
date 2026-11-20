import SwiftUI

/// Puzzle detail: hero image, difficulty, how to play, and a pinned bottom bar.
struct PuzzleDetailView: View {
    let game: GameID
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        BackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.top, 4)
                    AssetImage(name: game.coverAsset, placeholderSymbol: game.systemIcon)
                        .frame(height: 230)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text(game.displayName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(game.tagline).font(.system(size: 18)).foregroundStyle(palette.textSecondary)
                    Text(game.metaLine(chessCount: model.rounds.chessBank.puzzles.count))
                        .font(.system(size: 15)).foregroundStyle(palette.textSecondary)

                    Text("Difficulty")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, 8)
                    Picker("Difficulty", selection: difficultyBinding) {
                        ForEach(game.difficulties) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            Haptics.tap()
                            withAnimation(.selectionSpring) { showRules.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Text("How to play").font(.system(size: 17, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .rotationEffect(.degrees(showRules ? 180 : 0))
                            }
                            .foregroundStyle(palette.accentText)
                        }
                        .buttonStyle(.plain)
                        if showRules {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(game.howToPlay, id: \.self) { rule in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle().fill(palette.accent).frame(width: 6, height: 6).padding(.top, 8)
                                        Text(rule).font(.system(size: 16)).foregroundStyle(palette.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 200)
            }
            bottomBar
                .padding(.bottom, 96)
        }
        .screenBackground()
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding(get: { model.settings.difficulty(for: game) },
                set: { model.setDifficulty($0, for: game) })
    }

    private var bottomBar: some View {
        HStack {
            Text("Use for unlocks").font(.system(size: 16, weight: .medium)).foregroundStyle(palette.textPrimary)
            Spacer()
            PillToggle(isOn: Binding(get: { model.settings.isEnabled(game) },
                                     set: { on in if !model.setGame(game, enabled: on) { Haptics.error() } }),
                       label: "Use \(game.displayName) for unlocks")
            Button { model.tryPractice(game) } label: {
                HStack(spacing: 4) {
                    Text("Try")
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.accentText)
                .padding(.leading, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 70)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
        .padding(.horizontal, 16)
    }
}
