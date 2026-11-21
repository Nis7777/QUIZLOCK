import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

// Renders on-device Screen Time numbers inside QuizLock's "Today" card. By Apple's design this
// extension runs in a sandbox with no network access, and the data never reaches the app itself.

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let lockedApps = Self("Locked Apps")
}

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { TotalActivityView(summary: $0) }
        LockedAppsReport { LockedAppsView(summary: $0) }
    }
}

struct ActivitySummary {
    struct AppUsage: Identifiable {
        let id = UUID()
        let name: String
        let token: ApplicationToken?
        let duration: TimeInterval
    }
    var total: TimeInterval = 0
    var apps: [AppUsage] = []

    static func make(from data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        var summary = ActivitySummary()
        var byName: [String: (ApplicationToken?, TimeInterval)] = [:]
        for await d in data {
            for await segment in d.activitySegments {
                summary.total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "App"
                        let current = byName[name]?.1 ?? 0
                        byName[name] = (app.application.token, current + app.totalActivityDuration)
                    }
                }
            }
        }
        summary.apps = byName.map { AppUsage(name: $0.key, token: $0.value.0, duration: $0.value.1) }
            .filter { $0.duration >= 60 }
            .sorted { $0.duration > $1.duration }
        return summary
    }

    static func format(_ t: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = t >= 3600 ? [.hour, .minute] : [.minute]
        f.unitsStyle = .abbreviated
        return f.string(from: t) ?? "0m"
    }
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivitySummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        await ActivitySummary.make(from: data)
    }
}

struct LockedAppsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .lockedApps
    let content: (ActivitySummary) -> LockedAppsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        await ActivitySummary.make(from: data)
    }
}

private let coral = Color(red: 1, green: 90 / 255, blue: 54 / 255)

/// "3h 12m": today's total screen time.
struct TotalActivityView: View {
    let summary: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ActivitySummary.format(summary.total))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(coral)
            Text("screen time today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Top locked apps today.
struct LockedAppsView: View {
    let summary: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if summary.apps.isEmpty {
                Text("No time in your locked apps today. Nice!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.apps.prefix(3)) { app in
                    HStack(spacing: 10) {
                        if let token = app.token {
                            Label(token).labelStyle(.iconOnly).frame(width: 24, height: 24)
                        }
                        Text(app.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Text(ActivitySummary.format(app.duration))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(coral)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
