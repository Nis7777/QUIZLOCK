import SwiftUI
import WidgetKit

// Home-screen widget (streak + time saved today) and lock-screen widgets (streak + puzzle piece).
// Data comes from the App Group (StatsStore).

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let savedToday: String
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7, savedToday: "45m")
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // The app reloads timelines when stats change; also refresh just after midnight.
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1),
                                             matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [current()], policy: .after(next)))
    }

    private func current() -> StreakEntry {
        let stats = StatsStore.load()
        return StreakEntry(date: Date(), streak: stats.streak(),
                           savedToday: StatsStore.formatMinutes(stats.day(Date()).minutesSaved))
    }
}

private let coral = Color(red: 1, green: 90 / 255, blue: 54 / 255)
private let peach = Color(red: 1, green: 0xF1 / 255, blue: 0xEC / 255)

struct StreakSmallView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.fill")
                Text(verbatim: Brand.appName)
            }
            .font(.caption.weight(.heavy))
            .foregroundStyle(coral)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(coral)
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.6)
            }
            Text("day streak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(entry.savedToday) saved today")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(coral)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { peach }
        .accessibilityElement(children: .combine)
    }
}

struct StreakAccessoryView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "puzzlepiece.fill").font(.caption)
                        Text("\(entry.streak)").font(.system(size: 22, weight: .heavy, design: .rounded))
                    }
                }
            case .accessoryInline:
                Label("\(entry.streak)-day streak", systemImage: "puzzlepiece.fill")
            default:
                HStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.fill").font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(entry.streak)-day streak").font(.headline)
                        Text("\(entry.savedToday) saved today").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetAccentable()
        .accessibilityElement(children: .combine)
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: StreakProvider()) { entry in
            StreakSmallView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your puzzle streak and the time you saved today.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakLockScreenWidget", provider: StreakProvider()) { entry in
            StreakAccessoryView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your puzzle streak on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LockieWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        StreakLockScreenWidget()
    }
}
