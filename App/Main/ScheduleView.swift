import SwiftUI

/// "Lock schedule": Always, or chosen hours on chosen days.
struct ScheduleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var custom = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            PushHeader(title: "Lock schedule", onBack: { dismiss() }) {
                PillButton(title: "Save") { save() }
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 10) {
                        ChoiceCard(title: "Always", symbol: "infinity", selected: !custom) { custom = false }
                        ChoiceCard(title: "On a schedule", symbol: "calendar.badge.clock", selected: custom) { custom = true }
                    }
                    if custom {
                        VStack(spacing: 0) {
                            DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
                                .appFont(17, .semibold)
                                .padding(.vertical, 8)
                            Divider()
                            DatePicker("To", selection: $end, displayedComponents: .hourAndMinute)
                                .appFont(17, .semibold)
                                .padding(.vertical, 8)
                        }
                        .tint(palette.accent)
                        .card()
                        Text("Days").appFont(17, .semibold).foregroundStyle(palette.textSecondary).padding(.horizontal, 6)
                        weekdayPicker
                        FooterText(text: "Locks are on during these hours. Outside them, your apps open normally. Times past midnight continue into the next day.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .screenBackground()
        .onAppear(perform: load)
        .animation(.selectionSpring, value: custom)
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let names = Calendar.current.standaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday
        let order = (0..<7).map { ((first - 1 + $0) % 7) + 1 }
        return HStack(spacing: 8) {
            ForEach(order, id: \.self) { day in
                let on = weekdays.contains(day)
                Button {
                    Haptics.tap()
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .appFont(16, .bold)
                        .foregroundStyle(on ? palette.onAccent : palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? palette.accent : palette.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[day - 1])
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let s = model.lock.schedule
        custom = s != nil
        let schedule = s ?? LockSchedule()
        start = date(minute: schedule.startMinute)
        end = date(minute: schedule.endMinute)
        weekdays = Set(schedule.weekdays)
    }

    private func save() {
        if custom {
            let schedule = LockSchedule(startMinute: minute(of: start), endMinute: minute(of: end),
                                        weekdays: weekdays.sorted())
            model.setSchedule(weekdays.isEmpty ? nil : schedule)
        } else {
            model.setSchedule(nil)
        }
        dismiss()
    }

    private func minute(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func date(minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }
}

extension LockSchedule {
    /// "09:00–17:00 · Mon, Tue, Wed, Thu, Fri"
    var summary: String {
        let names = Calendar.current.shortStandaloneWeekdaySymbols
        let days = weekdays.sorted().compactMap { (1...7).contains($0) ? names[$0 - 1] : nil }
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        let cal = Calendar.current
        let s = cal.date(bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0, of: Date()) ?? Date()
        let e = cal.date(bySettingHour: endMinute / 60, minute: endMinute % 60, second: 0, of: Date()) ?? Date()
        return "\(s.formatted(time))–\(e.formatted(time)) · " + days.formatted(.list(type: .and, width: .narrow))
    }
}
