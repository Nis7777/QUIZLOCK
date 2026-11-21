import SwiftUI

/// Radio card with 5 minutes / 15 minutes / For Today / Custom ⊕.
struct DurationOptionsCard: View {
    let selection: UnlockDuration?
    let onSelect: (UnlockDuration) -> Void
    var leading: AnyView?
    @Environment(\.palette) private var palette
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 0) {
            if let leading {
                leading
                Divider().padding(.leading, 20)
            }
            ForEach(Array(UnlockDuration.presets.enumerated()), id: \.offset) { _, option in
                row(title: option.localizedLabel, selected: selection == option) { onSelect(option) }
                Divider().padding(.leading, 20)
            }
            Button {
                Haptics.tap()
                showCustom = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom")
                            .appFont(19, .semibold)
                            .foregroundStyle(palette.accent)
                        if let s = selection, s.isCustom {
                            Text(s.localizedLabel).appFont(15).foregroundStyle(palette.textSecondary)
                        }
                    }
                    Spacer()
                    if let s = selection, s.isCustom {
                        RadioMark(isSelected: true)
                    } else {
                        Image(systemName: "plus.circle")
                            .appFont(24)
                            .foregroundStyle(palette.accent)
                    }
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 66)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(initial: selection) { onSelect($0) }
                .presentationDetents([.height(420)])
                .presentationCornerRadius(28)
        }
    }

    private func row(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { action() }
        } label: {
            HStack {
                Text(title)
                    .appFont(19, .semibold)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                RadioMark(isSelected: selected)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Separate radio cards (onboarding S11 style).
struct DurationRadioCards: View {
    let selection: UnlockDuration
    let onSelect: (UnlockDuration) -> Void
    @Environment(\.palette) private var palette
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(UnlockDuration.presets.enumerated()), id: \.offset) { _, option in
                let selected = selection == option
                Button {
                    Haptics.tap()
                    withAnimation(.selectionSpring) { onSelect(option) }
                } label: {
                    HStack {
                        Text(option.localizedLabel).appFont(19, .semibold).foregroundStyle(palette.textPrimary)
                        Spacer()
                        RadioMark(isSelected: selected)
                    }
                    .padding(.horizontal, 22)
                    .frame(height: 66)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selected ? palette.accent.opacity(0.35) : palette.separator, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Button {
                Haptics.tap()
                showCustom = true
            } label: {
                HStack {
                    Text(selection.isCustom ? String(localized: "Custom · \(selection.localizedLabel)") : String(localized: "Custom"))
                        .appFont(19, .semibold)
                        .foregroundStyle(palette.accent)
                    Spacer()
                    if selection.isCustom {
                        RadioMark(isSelected: true)
                    } else {
                        Image(systemName: "plus.circle").appFont(24).foregroundStyle(palette.accent)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 66)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(selection.isCustom ? palette.accent.opacity(0.35) : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(initial: selection) { onSelect($0) }
                .presentationDetents([.height(420)])
                .presentationCornerRadius(28)
        }
    }
}

/// "Set unlock time" sheet with Cancel / Save pills and an hours + min wheel.
struct CustomDurationSheet: View {
    let initial: UnlockDuration?
    let onSave: (UnlockDuration) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var hours = 0
    @State private var minutes = 30

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PillButton(title: "Cancel", filled: false) { dismiss() }
                Spacer()
                Text("Set unlock time").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                Spacer()
                PillButton(title: "Save") {
                    let total = hours * 60 + minutes
                    if total > 0 { onSave(.custom(hours: hours, minutes: minutes)) }
                    dismiss()
                }
                .opacity(hours * 60 + minutes > 0 ? 1 : 0.4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            HStack(spacing: 0) {
                wheel(selection: $hours, range: 0..<24, unit: "hours")
                wheel(selection: $minutes, range: 0..<60, unit: "min")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            Spacer()
        }
        .screenBackground()
        .onAppear {
            switch initial {
            case .custom(let h, let m)?:
                hours = h
                minutes = m
            case .minutes(let m)?:
                hours = m / 60
                minutes = m % 60
            default:
                break
            }
        }
    }

    private func wheel(selection: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        HStack(spacing: 0) {
            Picker(unit, selection: selection) {
                ForEach(range, id: \.self) { v in
                    Text("\(v)").appFont(22).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            Text(LocalizedStringKey(unit))
                .appFont(19, .semibold)
                .foregroundStyle(palette.textPrimary)
                .frame(width: 64, alignment: .leading)
        }
    }
}
