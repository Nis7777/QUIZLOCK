import DeviceActivity
import FamilyControls
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let lockedApps = Self("Locked Apps")
}

/// "Today" card at the top of the dashboard: on-device Screen Time (rendered by the report extension),
/// streak and time saved, and a link to Stats.
struct TodayCard: View {
    let onOpenStats: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

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
    }

    @ViewBuilder
    private var screenTime: some View {
        if ScreenTimeService.isMock || !model.isAuthorized {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(ScreenTimeService.isMock ? "2h 41m" : "—"))
                    .appFont(34, .heavy, design: .rounded)
                    .foregroundStyle(palette.accent)
                Text(LocalizedStringKey(ScreenTimeService.isMock ? "screen time today (Simulator sample)" : "Connect Screen Time to see today's usage"))
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
            }
        } else if let all = filter(lockedOnly: false) {
            DeviceActivityReport(.totalActivity, filter: all)
                .frame(height: 64)
            if let locked = filter(lockedOnly: true), model.lock.selectedCount > 0 {
                DeviceActivityReport(.lockedApps, filter: locked)
                    .frame(height: 96)
            }
        }
    }

    private func filter(lockedOnly: Bool) -> DeviceActivityFilter? {
        guard let today = Calendar.current.dateInterval(of: .day, for: Date()) else { return nil }
        let selection = model.lock.selection
        return DeviceActivityFilter(
            segment: .daily(during: today),
            users: .all,
            devices: .init([.iPhone]),
            applications: lockedOnly ? selection.applicationTokens : [],
            categories: lockedOnly ? selection.categoryTokens : [],
            webDomains: lockedOnly ? selection.webDomainTokens : [])
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
