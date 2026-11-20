import SwiftUI
import UIKit

enum SettingsRoute: Hashable {
    case manageApps
    case unlockTime
    case appUnlockTime(String)
}

/// Settings tab (the dashboard).
struct SettingsTab: View {
    @Environment(AppModel.self) private var model
    @State private var path: [SettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SettingsView(path: $path)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: SettingsRoute.self) { route in
                    Group {
                        switch route {
                        case .manageApps:
                            ManageAppsView(path: $path)
                        case .unlockTime:
                            UnlockTimeView(itemKey: nil)
                        case .appUnlockTime(let key):
                            UnlockTimeView(itemKey: key)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                }
        }
    }
}

struct SettingsView: View {
    @Binding var path: [SettingsRoute]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var showPuzzlesPerUnlock = false
    @State private var showUnlockPuzzles = false
    @State private var link: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                TabHeader()
                if model.settings.showAllSetBanner {
                    allSetBanner.transition(.opacity.combined(with: .move(edge: .top)))
                }
                appLocksSection
                unlockRulesSection
                appearanceSection
                lifetimeCard
                analyticsSection
                adMeasurementSection
                footerCard
                if ScreenTimeService.isMock { simulatorTools }
            }
            .padding(.bottom, 120)
        }
        .screenBackground()
        .sheet(isPresented: $showPuzzlesPerUnlock) {
            PuzzlesPerUnlockSheet()
                .environment(model)
                .environment(\.palette, model.palette)
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showUnlockPuzzles) {
            UnlockPuzzlesSheet()
                .environment(model)
                .environment(\.palette, model.palette)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .safariSheet($link)
    }

    // MARK: Banner

    private var allSetBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            TogglePillsIcon(color: palette.accent, size: 26)
                .frame(width: 50, height: 50)
                .background(palette.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("You're all set").font(.system(size: 19, weight: .heavy)).foregroundStyle(palette.textPrimary)
                Text("Use these switches anytime to pause or resume a lock.")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Got it") {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.3)) { model.updateSettings { $0.showAllSetBanner = false } }
            }
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(palette.accentText)
        }
        .padding(18)
        .background(palette.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(palette.accent.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: App locks

    private var appLocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "App locks")
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable locks").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.textPrimary)
                    Text(model.lock.locksEnabled ? "All apps protected" : "Locks paused")
                        .font(.system(size: 15)).foregroundStyle(palette.textSecondary)
                }
                Spacer()
                PillToggle(isOn: model.lockBinding(\.locksEnabled), label: "Enable locks")
            }
            .card()
            .padding(.horizontal, 16)

            if !model.lockItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(model.lockItems.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 46) }
                        HStack {
                            LockItemLabel(item: item)
                            Spacer()
                            PillToggle(isOn: model.itemEnabledBinding(item.key), label: "Lock")
                        }
                        .padding(.vertical, 8)
                        .opacity(model.lock.locksEnabled ? 1 : 0.5)
                    }
                }
                .card()
                .padding(.horizontal, 16)
            }

            Button { path.append(.manageApps) } label: {
                InfoRow(icon: AnyView(Image(systemName: "slider.horizontal.3").font(.system(size: 20)).foregroundStyle(palette.accent)),
                        title: "Manage Apps to Lock", subtitle: "Add, remove, and set unlock times")
            }
            .buttonStyle(.plain)
            .card()
            .padding(.horizontal, 16)
        }
    }

    // MARK: Unlock rules

    private var unlockRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Unlock rules")
            VStack(spacing: 0) {
                Button { path.append(.unlockTime) } label: {
                    InfoRow(icon: AnyView(Image(systemName: "timer").font(.system(size: 22)).foregroundStyle(palette.accent)),
                            title: "Unlock time", subtitle: "Default time for each app", value: model.lock.defaultDuration.label)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { showPuzzlesPerUnlock = true } label: {
                    InfoRow(icon: AnyView(Image(systemName: "list.bullet.circle").font(.system(size: 22)).foregroundStyle(palette.accent)),
                            title: "Puzzles per unlock", subtitle: "Solved puzzles required", value: "\(model.lock.puzzlesPerUnlock)")
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { showUnlockPuzzles = true } label: {
                    InfoRow(icon: AnyView(Image(systemName: "shuffle").font(.system(size: 20)).foregroundStyle(palette.accent)),
                            title: "Unlock puzzles", subtitle: model.enabledGamesText,
                            value: "\(model.settings.enabledGames.count) selected")
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
            .padding(.horizontal, 16)
            FooterText(text: "Your puzzles take turns in a shuffled order.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Appearance")
            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeCard(theme: theme, selected: model.settings.theme == theme) {
                        Haptics.tap()
                        withAnimation(.selectionSpring) { model.updateSettings { $0.theme = theme } }
                    }
                }
            }
            .padding(.horizontal, 16)
            FooterText(text: "Puzzle boards keep their original colors.")
        }
    }

    // MARK: Lifetime

    private var lifetimeCard: some View {
        Button {
            if !model.settings.hasLifetime { model.presentPaywall(.settings) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.settings.hasLifetime ? "Lifetime Access · Active" : "Unlock Lifetime Access")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    if !model.settings.hasLifetime {
                        Text("\(model.settings.freeUnlocksRemaining) of \(Brand.freeUnlocks) free app unlocks remaining")
                            .font(.system(size: 15))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                Spacer()
                if !model.settings.hasLifetime {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundStyle(palette.accent)
                } else {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: Privacy

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Analytics")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Share app analytics").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.textPrimary)
                    Spacer()
                    PillToggle(isOn: model.settingsBinding(\.analyticsEnabled), label: "Share app analytics")
                }
                Text("Help improve \(Brand.appName) with anonymous analytics, including purchases, changes to your selected puzzles, and puzzle starts/completions during app unlocks. App identities, Screen Time reports, unlock times and typed answers stay on-device. Optional; turn off anytime.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
            .padding(.horizontal, 16)
            // TODO: analytics — no SDK is included. Read `model.settings.analyticsEnabled` before sending any event.
        }
    }

    private var adMeasurementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ad measurement")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Share ad measurement").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.textPrimary)
                    Spacer()
                    PillToggle(isOn: model.settingsBinding(\.adMeasurementEnabled), label: "Share ad measurement")
                }
                Text("Optionally share app opens and purchases to measure our ads. Protected apps, Screen Time activity and puzzle data are never included. Turning this off stops future events; it doesn't delete data already sent.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Manage Apple tracking permission") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accentText)
            }
            .card()
            .padding(.horizontal, 16)
        }
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                Button("Terms of Service") { link = Brand.termsURL }
                Button("Privacy Policy") { link = Brand.privacyURL }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(palette.accentText)
            Text(Brand.credits)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
            Text("\(Brand.appName) \(appVersion)")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
        }
        .card()
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: Simulator

    private var simulatorTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Simulator tools")
            Button {
                model.simulateShieldTap()
            } label: {
                InfoRow(icon: AnyView(Image(systemName: "hand.tap.fill").foregroundStyle(palette.accent)),
                        title: "Simulate START PUZZLE", subtitle: "Pretend a locked app's shield button was tapped")
            }
            .buttonStyle(.plain)
            .card()
            .padding(.horizontal, 16)
        }
    }
}

/// Appearance card with a mini drawing of the UI.
private struct ThemeCard: View {
    let theme: AppTheme
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                mini
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(palette.textPrimary)
                        Text(theme.subtitle).font(.system(size: 13)).foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    RadioMark(isSelected: selected)
                }
            }
            .padding(12)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? palette.accent : palette.separator, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title), \(theme.subtitle)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var mini: some View {
        let dark = theme == .dark
        let accent = Color.brand
        return VStack(alignment: .leading, spacing: 6) {
            Text(Brand.appName)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.brand)
            ForEach(0..<2, id: \.self) { _ in
                HStack {
                    Capsule().fill(dark ? Color.white.opacity(0.35) : Color(hex: 0xD8D8DD)).frame(width: 46, height: 6)
                    Spacer()
                    Capsule().fill(accent).frame(width: 20, height: 11)
                }
                .padding(6)
                .background(dark ? Color(hex: 0x1C1C1E) : Color.white, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dark ? Color.black : Color.appBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
