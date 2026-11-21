import Charts
import SwiftUI

/// Stats: streak flame, weekly bar chart (coral), per-game totals, unlocks earned/skipped, time saved.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    /// Every number on this screen counts up together (CountingText).
    @State private var count = CountUpState()

    var body: some View {
        let stats = model.stats
        VStack(spacing: 0) {
            PushHeader(title: "Your stats", onBack: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    streakCard(stats.streak())
                    if stats.days.values.allSatisfy({ $0.puzzlesSolved == 0 && $0.unlocksEarned == 0 && $0.unlocksSkipped == 0 }) {
                        MascotEmptyState(title: "No stats yet",
                                         message: "Solve a puzzle or skip an unlock, and your progress shows up here.")
                    } else {
                        weekChart(stats)
                        numbers(stats)
                        perGame(stats)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .screenBackground()
        .onAppear { model.statsChanged() }
        .countUp($count, after: 0.35)
    }

    private func streakCard(_ streak: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .appFont(44)
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFB020), .brand], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                CountingText(value: Double(streak) * count.progress, final: Double(streak),
                             format: { String(localized: "\(Int($0.rounded()))-day streak") }, landed: count.landed)
                    .appFont(28, .heavy, design: .rounded).foregroundStyle(palette.textPrimary)
                Text("Solve a puzzle (or skip unlocks) every day to keep it going.")
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func weekChart(_ stats: Stats) -> some View {
        let days = stats.lastSevenDays()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Puzzles solved this week").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
            Chart {
                ForEach(days, id: \.date) { item in
                    BarMark(x: .value("Day", item.date, unit: .day),
                            y: .value("Puzzles", item.stats.puzzlesSolved))
                        .foregroundStyle(Color.brand)
                        .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
        }
        .card()
    }

    private func numbers(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile(value: stats.totalUnlocksEarned, format: CountingText.integer, label: "Unlocks earned", icon: "lock.open.fill")
            tile(value: stats.totalUnlocksSkipped, format: CountingText.integer, label: "Unlocks skipped", icon: "hand.raised.fill")
            tile(value: stats.totalMinutesSaved, format: Self.minutes, label: "Time saved", icon: "hourglass")
            tile(value: stats.minutesSavedThisWeek(), format: Self.minutes, label: "Saved this week", icon: "calendar")
        }
    }

    private static let minutes: (Double) -> String = { StatsStore.formatMinutes(Int($0.rounded())) }

    private func tile(value: Int, format: @escaping (Double) -> String, label: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).appFont(18, .semibold).foregroundStyle(palette.accent).accessibilityHidden(true)
            CountingText(value: Double(value) * count.progress, final: Double(value), format: format, landed: count.landed)
                .appFont(26, .heavy, design: .rounded).foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).appFont(14).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 18)
        .accessibilityElement(children: .combine)
    }

    private func perGame(_ stats: Stats) -> some View {
        let totals = stats.totalSolvedByGame
        return VStack(alignment: .leading, spacing: 0) {
            Text("Puzzles solved").appFont(17, .semibold).foregroundStyle(palette.textPrimary).padding(.bottom, 8)
            ForEach(GameID.allCases) { game in
                HStack(spacing: 12) {
                    Image(systemName: game.systemIcon).foregroundStyle(palette.accent).frame(width: 28).accessibilityHidden(true)
                    Text(LocalizedStringKey(game.displayName)).appFont(16).foregroundStyle(palette.textPrimary)
                    Spacer()
                    let total = Double(totals[game.rawValue] ?? 0)
                    CountingText(value: total * count.progress, final: total, format: CountingText.integer, landed: count.landed)
                        .appFont(17, .bold, design: .rounded).foregroundStyle(palette.textPrimary)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                if game != GameID.allCases.last { Divider() }
            }
        }
        .card()
    }
}

/// Mascot + message, used for empty states.
struct MascotEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            AssetImage(name: "mascot_pointing", placeholderSymbol: "face.smiling", contentMode: .fit)
                .frame(height: 140)
                .accessibilityHidden(true)
            Text(title).appFont(19, .bold).foregroundStyle(palette.textPrimary)
            Text(message).appFont(15).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22)
    }
}

/// Full-screen celebration for 3 / 7 / 30-day streaks.
struct MilestoneView: View {
    let days: Int
    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            AssetImage(name: "mascot_pointing", placeholderSymbol: "flame.fill", contentMode: .fit)
                .frame(height: 230)
                .scaleEffect(appeared ? 1 : 0.6)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(Color.brand)
                Text("\(days)-day streak!")
            }
            .appFont(34, .heavy, design: .rounded)
            .foregroundStyle(palette.textPrimary)
            Text(LocalizedStringKey(days >= 30 ? "A whole month of choosing yourself over the feed. Incredible."
                 : days >= 7 ? "A full week. You're building a real habit."
                 : "Three days in a row. Great start!"))
                .appFont(19)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            PrimaryButton(title: "Keep going", action: onDone)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .screenBackground()
        .confetti(appeared)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
