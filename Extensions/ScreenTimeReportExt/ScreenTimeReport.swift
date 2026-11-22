import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

// Renders on-device Screen Time inside Lockie's "Today" card. By Apple's design this extension runs in a
// sandbox with no network access, and the data never reaches the app itself.
//
// Kept deliberately light (report extensions have a small memory limit): one pass over the data, plain
// numbers in the configuration, SwiftUI shapes for the bars (no Charts framework, no images; app icons
// come from `Label(token)`, drawn by the system).

extension DeviceActivityReport.Context {
    /// Must match `DeviceActivityReport.Context.today` in the app (TodayCard.swift) exactly.
    static let today = Self("Today")
}

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayReport { TodayReportView(summary: $0) }
    }
}

/// Today's numbers, built once per refresh: the total, minutes in each hour, and the top 3 apps.
struct TodaySummary {
    struct App: Identifiable {
        let id: String
        let name: String
        let token: ApplicationToken?
        let duration: TimeInterval
    }

    var total: TimeInterval = 0
    /// Seconds of use in each hour of the day (index = hour, 0–23).
    var hours = [TimeInterval](repeating: 0, count: 24)
    var topApps: [App] = []
    var currentHour = Calendar.current.component(.hour, from: Date())

    static func make(from data: DeviceActivityResults<DeviceActivityData>) async -> TodaySummary {
        var summary = TodaySummary()
        var apps: [String: (name: String, token: ApplicationToken?, duration: TimeInterval)] = [:]
        let calendar = Calendar.current
        for await device in data {
            for await segment in device.activitySegments {
                let hour = calendar.component(.hour, from: segment.dateInterval.start)
                summary.total += segment.totalActivityDuration
                if (0..<24).contains(hour) { summary.hours[hour] += segment.totalActivityDuration }
                for await category in segment.categories {
                    for await usage in category.applications {
                        let app = usage.application
                        let key = app.bundleIdentifier ?? app.localizedDisplayName ?? "app"
                        let name = app.localizedDisplayName ?? app.bundleIdentifier ?? "App"
                        let previous = apps[key]?.duration ?? 0
                        apps[key] = (name, app.token, previous + usage.totalActivityDuration)
                    }
                }
            }
        }
        summary.topApps = apps
            .filter { $0.value.duration >= 60 }
            .sorted { $0.value.duration > $1.value.duration }
            .prefix(3)
            .map { App(id: $0.key, name: $0.value.name, token: $0.value.token, duration: $0.value.duration) }
        return summary
    }

    /// "2h 14m", "38m".
    static func format(_ t: TimeInterval) -> String {
        let minutes = Int(t / 60)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}

struct TodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .today
    let content: (TodaySummary) -> TodayReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TodaySummary {
        await TodaySummary.make(from: data)
    }
}

// MARK: - Look (Lockie's warm cream and coral)

private let coral = Color(red: 1, green: 90 / 255, blue: 54 / 255)
private let cream = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
    ? UIColor(red: 0x2A / 255, green: 0x1D / 255, blue: 0x19 / 255, alpha: 1)
    : UIColor(red: 0xFF / 255, green: 0xF4 / 255, blue: 0xEE / 255, alpha: 1) })
private let ink = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .white
    : UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1) })
private let subdued = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
    ? UIColor.white.withAlphaComponent(0.7)
    : UIColor(red: 0x6B / 255, green: 0x4A / 255, blue: 0x43 / 255, alpha: 1) })

/// The Today report: total, hourly bars, top 3 apps. With no use yet today it draws nothing at all, so
/// the app's own empty state (Lockie and a message, behind this view) shows through.
struct TodayReportView: View {
    let summary: TodaySummary

    var body: some View {
        if summary.total < 60 {
            Color.clear
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                HourlyBars(hours: summary.hours, currentHour: summary.currentHour)
                    .frame(height: 56)
                if !summary.topApps.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(summary.topApps) { AppRow(app: $0) }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(TodaySummary.format(summary.total))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(coral)
                .monospacedDigit()
            Text("screen time today")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(subdued)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 24 rounded bars, one per hour; the current hour is full coral, earlier hours a softer coral.
private struct HourlyBars: View {
    let hours: [TimeInterval]
    let currentHour: Int

    var body: some View {
        let peak = max(hours.max() ?? 0, 60)
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    let fraction = hours[h] / peak
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(h == currentHour ? coral : coral.opacity(h < currentHour ? 0.55 : 0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(4, 40 * fraction))
                }
            }
            .frame(height: 40, alignment: .bottom)
            HStack {
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { label in
                    Text(verbatim: label).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(subdued)
        }
        .accessibilityHidden(true)
    }
}

private struct AppRow: View {
    let app: TodaySummary.App

    var body: some View {
        HStack(spacing: 10) {
            if let token = app.token {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 22, height: 22)
            }
            Text(app.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(TodaySummary.format(app.duration))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(coral)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
