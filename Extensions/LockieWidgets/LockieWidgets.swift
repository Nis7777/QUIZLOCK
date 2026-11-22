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

// MARK: - "Your puzzle": a one-tap route into the waiting puzzle

/// The puzzle waiting after "Solve to unlock" (from PendingPuzzleNote), or none.
struct PuzzleEntry: TimelineEntry {
    let date: Date
    let waiting: Bool
    let appName: String?
}

struct PuzzleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PuzzleEntry {
        PuzzleEntry(date: Date(), waiting: true, appName: "Instagram")
    }

    func getSnapshot(in context: Context, completion: @escaping (PuzzleEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current(Date()))
    }

    /// Now, plus the moment the puzzle stops counting as waiting. The shield and the app reload this
    /// timeline whenever a puzzle is asked for or solved.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PuzzleEntry>) -> Void) {
        let now = Date()
        var entries = [current(now)]
        if let note = PendingPuzzleNote.current(now: now) {
            entries.append(PuzzleEntry(date: note.at.addingTimeInterval(Brand.autoResumeWindow), waiting: false, appName: nil))
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func current(_ now: Date) -> PuzzleEntry {
        let note = PendingPuzzleNote.current(now: now)
        return PuzzleEntry(date: now, waiting: note != nil, appName: note?.appName)
    }
}

struct PuzzleSmallView: View {
    let entry: PuzzleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.fill")
                Text(verbatim: Brand.appName)
            }
            .font(.caption.weight(.heavy))
            .foregroundStyle(coral)
            Spacer(minLength: 0)
            if entry.waiting {
                Text("Tap to solve 🧩")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.7)
                Text(unlockLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("No puzzle waiting")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                Text("Open a locked app to get one.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { peach }
        .widgetURL(Brand.unlockDeepLink)
        .accessibilityElement(children: .combine)
    }

    private var unlockLine: String {
        if let name = entry.appName { return String(localized: "Unlocks \(name)") }
        return String(localized: "Unlocks your app")
    }
}

struct PuzzleAccessoryView: View {
    let entry: PuzzleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: entry.waiting ? "puzzlepiece.extension.fill" : "puzzlepiece")
                        .font(.title2)
                }
            case .accessoryInline:
                Label(entry.waiting ? String(localized: "Tap to solve") : String(localized: "No puzzle waiting"),
                      systemImage: "puzzlepiece.fill")
            default:
                HStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.fill").font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.waiting ? "Tap to solve" : "No puzzle waiting").font(.headline)
                        if entry.waiting, let name = entry.appName {
                            Text("Unlocks \(name)").font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetAccentable()
        .widgetURL(Brand.unlockDeepLink)
        .accessibilityElement(children: .combine)
    }
}

struct PuzzleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PuzzleWidget", provider: PuzzleProvider()) { entry in
            PuzzleSmallView(entry: entry)
        }
        .configurationDisplayName("Your puzzle")
        .description("One tap into the puzzle that unlocks your app.")
        .supportedFamilies([.systemSmall])
    }
}

struct PuzzleLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PuzzleLockScreenWidget", provider: PuzzleProvider()) { entry in
            PuzzleAccessoryView(entry: entry)
        }
        .configurationDisplayName("Your puzzle")
        .description("One tap into your puzzle from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LockieWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        StreakLockScreenWidget()
        PuzzleWidget()
        PuzzleLockScreenWidget()
    }
}
