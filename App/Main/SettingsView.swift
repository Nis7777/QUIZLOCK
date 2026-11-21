import StoreKit
import MessageUI
import SwiftUI
import UIKit

enum SettingsRoute: Hashable {
    case manageApps
    case unlockTime
    case appUnlockTime(String)
    case stats
    case schedule
}

/// Settings tab (the dashboard).
struct SettingsTab: View {
    @Environment(AppModel.self) private var model
    @State private var path: [SettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SettingsView(path: $path)
                .onAppear(perform: openStatsIfRequested)
                .onChange(of: model.showStats) { _, _ in openStatsIfRequested() }
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
                        case .stats:
                            StatsView()
                        case .schedule:
                            ScheduleView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                }
        }
    }
}

extension SettingsTab {
    private func openStatsIfRequested() {
        guard model.showStats else { return }
        model.showStats = false
        path = [.stats]
    }
}

struct SettingsView: View {
    @Binding var path: [SettingsRoute]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPuzzlesPerUnlock = false
    @State private var showStrictSheet = false
    @State private var showUnlockPuzzles = false
    @State private var link: URL?
    @State private var showMail = false
    @State private var restoreMessage: String?
    @State private var showManageSubscriptions = false
    @State private var showResetSheet = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                TabHeader()
                if model.settings.showAllSetBanner {
                    allSetBanner.transition(.opacity.combined(with: .move(edge: .top)))
                }
                if model.isStrict { strictBanner }
                TodayCard(onOpenStats: { path.append(.stats) })
                appLocksSection
                unlockRulesSection
                remindersSection
                appearanceSection
                if model.notificationsDenied { notificationsOffCard }
                proCard
                dataSection
                supportSection
                // No "Analytics" / "Ad measurement" sections: the app has no analytics or ads code and its
                // App Privacy label is "Data Not Collected". If you add an SDK later, bring the sections back
                // (see git history), call it only when the setting is on, and update the policy and label.
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
        .sheet(isPresented: $showStrictSheet) {
            StrictModeSheet()
                .environment(model)
                .environment(\.palette, model.palette)
                .presentationDetents([.medium, .large])
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
        .sheet(isPresented: $showMail) {
            MailComposer(recipient: Brand.supportEmail, subject: "[\(Brand.appName)] Support",
                         body: "\n\n—\n\(Brand.appName) \(appVersion) · iOS \(UIDevice.current.systemVersion)") { showMail = false }
                .ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .sheet(isPresented: $showResetSheet) {
            ResetDataSheet {
                showResetSheet = false
                model.guardStrict(weakening: true) { model.resetAllData() }
            } onCancel: {
                showResetSheet = false
            }
            .environment(\.palette, model.palette)
            .presentationDetents([.medium])
            .presentationCornerRadius(28)
        }
        .alert("Restore Purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: Strict mode

    private var strictBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").appFont(22).foregroundStyle(.white).accessibilityHidden(true)
            Text("Strict mode on until \(model.strictUntilText)")
                .appFont(17, .bold)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(16)
        .background(Color.brand, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Reminders")
            VStack(spacing: 0) {
                reminderRow(title: "Evening streak reminder", subtitle: "At 20:00 if you haven't solved a puzzle",
                            isOn: Binding(get: { model.settings.streakReminderEnabled },
                                          set: { model.setReminder(streak: $0) }))
                Divider().padding(.leading, 4)
                reminderRow(title: "Weekly summary", subtitle: "Sundays: how much time you saved",
                            isOn: Binding(get: { model.settings.weeklySummaryEnabled },
                                          set: { model.setReminder(weekly: $0) }))
            }
            .card()
            .padding(.horizontal, 16)
            FooterText(text: String(localized: "Local notifications only, never more than one a day."))
        }
    }

    private func reminderRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                Text(subtitle).appFont(15).foregroundStyle(palette.textSecondary)
            }
            Spacer()
            PillToggle(isOn: isOn)
        }
        .padding(.vertical, 6)
    }

    // MARK: Notifications off

    private var notificationsOffCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .appFont(20)
                .foregroundStyle(palette.accent)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications are off").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                Text("Turn them on in Settings so START PUZZLE can take you straight to your puzzle. Without them, open \(Brand.appName) after tapping START PUZZLE.")
                    .appFont(15)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .appFont(15, .semibold)
                .foregroundStyle(palette.accentText)
                .tapTarget()
            }
        }
        .card()
        .padding(.horizontal, 16)
    }

    // MARK: Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Data")
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "icloud.fill")
                        .appFont(20)
                        .foregroundStyle(palette.accent)
                        .frame(width: 34)
                        .accessibilityHidden(true)
                    Text("\(Brand.appName) has no accounts. Your subscription is tied to your Apple ID (use Restore Purchases on a new phone). Progress syncs with your iCloud.")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                Button {
                    Haptics.tap()
                    showResetSheet = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "trash")
                            .appFont(20)
                            .frame(width: 34)
                            .accessibilityHidden(true)
                        Text("Reset all data").appFont(17, .semibold)
                        Spacer()
                    }
                    .foregroundStyle(Color.errorRed)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.resetAllData")
            }
            .card()
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    // MARK: Support

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Support")
            VStack(spacing: 0) {
                Button { restore() } label: {
                    InfoRow(icon: AnyView(Image(systemName: "arrow.clockwise.circle").appFont(22).foregroundStyle(palette.accent)),
                            title: "Restore Purchases", subtitle: "Subscribed on another device?")
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { contactSupport() } label: {
                    InfoRow(icon: AnyView(Image(systemName: "envelope").appFont(20).foregroundStyle(palette.accent)),
                            title: "Contact support", subtitle: Brand.supportEmail)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button {
                    if let url = Brand.reviewURL { openURL(url) }
                } label: {
                    InfoRow(icon: AnyView(Image(systemName: "star").appFont(20).foregroundStyle(palette.accent)),
                            title: "Rate \(Brand.appName)", subtitle: "It really helps")
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
            .padding(.horizontal, 16)
        }
    }

    private func restore() {
        Task {
            await model.store.restore()
            restoreMessage = model.settings.isPro
                ? String(localized: "\(Brand.subscriptionGroupName) is active. Thank you!")
                : String(localized: "No active subscription was found for this Apple ID.")
        }
    }

    private func contactSupport() {
        if MFMailComposeViewController.canSendMail() {
            showMail = true
        } else {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = Brand.supportEmail
            components.queryItems = [URLQueryItem(name: "subject", value: "[\(Brand.appName)] Support")]
            if let url = components.url { openURL(url) }
        }
    }

    // MARK: Banner

    private var allSetBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            TogglePillsIcon(color: palette.accent, size: 26)
                .frame(width: 50, height: 50)
                .background(palette.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("You're all set").appFont(19, .heavy).foregroundStyle(palette.textPrimary)
                Text("Use these switches anytime to pause or resume a lock.")
                    .appFont(16)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Got it") {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.3)) { model.updateSettings { $0.showAllSetBanner = false } }
            }
            .appFont(16, .heavy)
            .foregroundStyle(palette.accentText)
            .tapTarget()
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
                    .appFont(22)
                    .foregroundStyle(palette.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable locks").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                    Text(LocalizedStringKey(model.lock.locksEnabled ? "All apps protected" : "Locks paused"))
                        .appFont(15).foregroundStyle(palette.textSecondary)
                }
                Spacer()
                PillToggle(isOn: model.locksEnabledBinding, label: "Enable locks")
            }
            .card()
            .padding(.horizontal, 16)

            if model.lockItems.isEmpty {
                MascotEmptyState(title: "No apps locked yet",
                                 message: "Tap Manage Apps to Lock to choose the apps that distract you most.")
                    .padding(.horizontal, 16)
            } else {
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
                InfoRow(icon: AnyView(Image(systemName: "slider.horizontal.3").appFont(20).foregroundStyle(palette.accent)),
                        title: "Manage Apps to Lock", subtitle: "Add, remove, and set unlock times")
            }
            .buttonStyle(.plain)
            .card()
            .padding(.horizontal, 16)

            Button {
                if !model.isStrict { showStrictSheet = true }
            } label: {
                InfoRow(icon: AnyView(Image(systemName: "lock.shield").appFont(20).foregroundStyle(palette.accent)),
                        title: "Strict mode",
                        subtitle: model.isStrict ? String(localized: "On until \(model.strictUntilText)")
                                                 : String(localized: "Make locks harder to turn off"),
                        showsChevron: !model.isStrict)
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
                    InfoRow(icon: AnyView(Image(systemName: "timer").appFont(22).foregroundStyle(palette.accent)),
                            title: "Unlock time", subtitle: "Default time for each app", value: model.lock.defaultDuration.localizedLabel)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { showPuzzlesPerUnlock = true } label: {
                    InfoRow(icon: AnyView(Image(systemName: "list.bullet.circle").appFont(22).foregroundStyle(palette.accent)),
                            title: "Puzzles per unlock", subtitle: "Solved puzzles required", value: "\(model.lock.puzzlesPerUnlock)")
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { showUnlockPuzzles = true } label: {
                    InfoRow(icon: AnyView(Image(systemName: "shuffle").appFont(20).foregroundStyle(palette.accent)),
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

    // MARK: QuizLock Pro

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if !model.settings.isPro { model.presentPaywall(.settings) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .appFont(22)
                        .foregroundStyle(palette.accent)
                        .frame(width: 34)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: Brand.subscriptionGroupName)
                            .appFont(17, .semibold)
                            .foregroundStyle(palette.textPrimary)
                        Text(proSubtitle)
                            .appFont(15)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if model.settings.isPro {
                        Image(systemName: "checkmark.seal.fill").appFont(20).foregroundStyle(palette.accent)
                    } else {
                        Image(systemName: "chevron.right").appFont(16, .bold).foregroundStyle(palette.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.proCard")
            if model.settings.isPro {
                Divider()
                Button("Manage subscription") { showManageSubscriptions = true }
                    .appFont(16, .semibold)
                    .foregroundStyle(palette.accentText)
                    .tapTarget()
            }
        }
        .card()
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    /// Not subscribed: "3 of 5 free unlocks left · Start free trial". Subscribed: "Active · renews 21 Nov 2027".
    private var proSubtitle: String {
        let store = model.store
        if model.settings.isPro {
            guard let date = store.expirationDate?.formatted(date: .abbreviated, time: .omitted) else {
                return String(localized: "Active")
            }
            return store.willAutoRenew ? String(localized: "Active · renews \(date)")
                                       : String(localized: "Active · ends \(date)")
        }
        let left = String(localized: "\(model.settings.freeUnlocksRemaining) of \(Brand.freeUnlocks) free unlocks left")
        let action = store.showsTrial ? String(localized: "Start free trial") : String(localized: "See plans")
        return left + " · " + action
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                Button("Terms of Use") { link = Brand.termsURL }.tapTarget()
                Button("Privacy Policy") { link = Brand.privacyURL }.tapTarget()
            }
            .appFont(15, .semibold)
            .foregroundStyle(palette.accentText)
            Text(LocalizedStringKey(Brand.credits))
                .appFont(13)
                .foregroundStyle(palette.textSecondary)
            Text("\(Brand.appName) \(appVersion)")
                .appFont(13)
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
                        Text(LocalizedStringKey(theme.title)).appFont(16, .semibold).foregroundStyle(palette.textPrimary)
                        Text(LocalizedStringKey(theme.subtitle)).appFont(13).foregroundStyle(palette.textSecondary)
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
                .appFont(11, .black, design: .rounded)
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

/// Confirmation for "Reset all data".
private struct ResetDataSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .appFont(40, .semibold)
                .foregroundStyle(Color.errorRed)
                .padding(.top, 28)
                .accessibilityHidden(true)
            Text("Reset all data?")
                .appFont(24, .bold)
                .foregroundStyle(palette.textPrimary)
            Text("This removes your locks, settings, stats and streaks from this device and iCloud. Your subscription isn't affected.")
                .appFont(16)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
            Button(role: .destructive, action: onConfirm) {
                Text("Reset all data")
                    .appFont(19, .bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.errorRed, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("settings.resetConfirm")
            Button("Cancel", action: onCancel)
                .appFont(17, .semibold)
                .foregroundStyle(palette.accentText)
                .tapTarget()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
    }
}
