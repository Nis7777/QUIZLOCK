import DeviceActivity
import FamilyControls
import SwiftUI
import UIKit

extension DeviceActivityReport.Context {
    /// Must match `DeviceActivityReport.Context.today` in the report extension (ScreenTimeReport.swift).
    static let today = Self("Today")
}

/// "Today" card at the top of the dashboard: on-device Screen Time (rendered by the report extension),
/// streak and time saved, and a link to Stats.
struct TodayCard: View {
    let onOpenStats: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    /// Changes at midnight so the report and the pills start the new day by themselves.
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var asking = false

    /// The report's fixed height (the extension lays itself out inside it).
    private static let reportHeight: CGFloat = 236

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").appFont(20, .bold).foregroundStyle(palette.textPrimary)
                Spacer()
                Button(action: onOpenStats) {
                    HStack(spacing: 4) {
                        Text("Stats")
                        Image(systemName: "chevron.right").appFont(13, .bold)
                    }
                    .appFont(16, .semibold)
                    .foregroundStyle(palette.accentText)
                    .tapTarget()
                }
                .buttonStyle(.plain)
            }
            screenTime
            HStack(spacing: 12) {
                pill(icon: "flame.fill", value: "\(model.stats.streak())", label: "day streak")
                pill(icon: "hourglass", value: model.timeSavedTodayText, label: "saved today")
            }
            Label("Screen Time data stays on your iPhone. Apple shows it here; \(Brand.appName) can't read or send it.",
                  systemImage: "lock.shield")
                .appFont(12)
                .foregroundStyle(palette.textSecondary)
        }
        .card()
        .padding(.horizontal, 16)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in rollOver() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in rollOver() }
    }

    private func rollOver() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != day else { return }
        day = today
        model.statsChanged()   // streak and "saved today" re-read from the App Group
    }

    @ViewBuilder
    private var screenTime: some View {
        if ScreenTimeService.isMock {
            // The report extension doesn't run in the Simulator: a labelled sample instead.
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "2h 41m")
                    .appFont(34, .heavy, design: .rounded)
                    .foregroundStyle(palette.accent)
                Text("screen time today (Simulator sample)")
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
            }
        } else if !model.isAuthorized {
            connectScreenTime
        } else {
            // Something is always drawn here: a skeleton while the report loads, then Lockie with a
            // message. The report sits on top: opaque when there's data, transparent when there isn't.
            ZStack {
                ReportPlaceholder()
                DeviceActivityReport(.today, filter: todayFilter)
            }
            .frame(height: Self.reportHeight)
            .id(day)   // a fresh report (and placeholder) after midnight
        }
    }

    /// Today so far, hour by hour, on this iPhone.
    private var todayFilter: DeviceActivityFilter {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        return DeviceActivityFilter(
            segment: .hourly(during: DateInterval(start: start, end: max(now, start.addingTimeInterval(60)))),
            users: .all,
            devices: .init([.iPhone]))
    }

    /// Shown instead of the report when Screen Time access isn't granted.
    private var connectScreenTime: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MascotView(expression: .pointing, size: 64, isLive: false, popsIn: false)
                    .accessibilityHidden(true)
                Text("Turn on Screen Time access to see today's usage here.")
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "Turn on Screen Time access", isLoading: asking) {
                Task {
                    asking = true
                    _ = await model.requestScreenTimeAuthorization()
                    asking = false
                }
            }
        }
    }

    private func pill(icon: String, value: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(palette.accent).accessibilityHidden(true)
            Text(value).appFont(17, .bold, design: .rounded).foregroundStyle(palette.textPrimary)
            Text(label).appFont(14).foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(palette.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// What sits behind the report: a soft skeleton with a shimmer while it loads, then (after ~2.5s, if the
/// report drew nothing: no use yet today) Lockie and a friendly message.
private struct ReportPlaceholder: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            if settled {
                VStack(spacing: 10) {
                    MascotView(expression: .thinking, size: 110, isLive: false)   // still: the report may be drawn over it
                        .accessibilityHidden(true)
                    Text("Your screen time will show up here as you use your phone today")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                skeleton.transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(Motion.respecting(reduceMotion, .easeInOut(duration: 0.35))) { settled = true }
        }
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            block(width: 140, height: 34)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(palette.tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 8 + 28 * abs(sin(Double(h) * 0.6)))
                }
            }
            .frame(height: 40, alignment: .bottom)
            ForEach(0..<3, id: \.self) { _ in block(width: nil, height: 18) }
            Spacer(minLength: 0)
        }
        .padding(14)
        .shimmer()
        .accessibilityLabel(Text("Loading today's screen time"))
    }

    private func block(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(palette.tint)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
