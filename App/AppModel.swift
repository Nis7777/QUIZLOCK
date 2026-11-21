import Foundation
import Observation
import SwiftUI
import UserNotifications

enum MainTab: Hashable { case settings, puzzles, feedback }

enum PaywallReason { case onboarding, settings, unlockLimit, practice }

/// Result shown after an unlock is granted.
struct UnlockResult: Equatable {
    let appName: String
    let duration: UnlockDuration
}

/// Root state: settings, lock state, routing and the unlock flow.
@Observable
@MainActor
final class AppModel {
    static let shared = AppModel()

    enum Phase { case splash, onboarding, main }

    private(set) var settings: AppSettings
    private(set) var lock: LockState
    private(set) var profile: UserProfile
    var phase: Phase
    var selectedTab: MainTab = .settings

    /// Full-screen unlock flow (non-nil while presented).
    private(set) var unlockSession: UnlockSession?
    var unlockResult: UnlockResult?
    var awaitingEntitlementForUnlock = false

    var paywallReason: PaywallReason?

    // Retention (see AppModel+Retention.swift)
    var stats = StatsStore.load()
    var milestone: Int?
    var progressionOffer: GameID?
    var toast: String?
    var strictChallengeActive = false
    var dailyPuzzleOpen = false
    var showStats = false
    @ObservationIgnored var roundStartedAt = Date()
    @ObservationIgnored var pendingStrictAction: (() -> Void)?
    var practiceGame: GameID?
    var isAuthorized = true
    /// The user chose "Not Now" on the Reconnect screen (until the next launch).
    var reconnectSnoozed = false

    let screenTime = ScreenTimeService()
    let rounds = RoundProvider()
    let store = Store()
    @ObservationIgnored private var sweepTimer: Timer?
    /// Set when the user closes the unlock flow, so foregrounding doesn't immediately reopen it.
    @ObservationIgnored private var dismissedPendingDate: Date?

    private init() {
        settings = SharedStore.load(AppSettings.self, .settings) ?? AppSettings()
        lock = SharedStore.lockState
        profile = SharedStore.load(UserProfile.self, .userProfile) ?? UserProfile()
        unlockSession = nil
        phase = (SharedStore.load(AppSettings.self, .settings)?.onboardingComplete ?? false) ? .main : .splash
        store.onEntitlementChange = { [weak self] owned in
            guard let self else { return }
            if owned != self.settings.hasLifetime { self.updateSettings { $0.hasLifetime = owned } }
            if owned, self.awaitingEntitlementForUnlock {
                self.awaitingEntitlementForUnlock = false
                self.paywallReason = nil
                self.grantUnlock()
            }
        }
    }

    var palette: Palette { Palette.forTheme(settings.theme) }

    // MARK: Lifecycle

    func bootstrap() {
        store.start()
        refreshFromStore()
        if settings.onboardingComplete {
            phase = .main
            resumeUnlockIfNeeded()
        }
        warmUpRounds()
        if settings.onboardingComplete { screenTime.registerSchedule(lock.schedule) }
        sweepTimer?.invalidate()
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in AppModel.shared.sweepExpiredUnlocks() }
        }
    }

    /// Called on launch and whenever the app becomes active.
    func refreshFromStore() {
        lock = SharedStore.lockState
        StatsStore.recordActive()
        statsChanged()
        isAuthorized = screenTime.isAuthorized(simulatorFlag: settings.simulatorAuthorized)
        sweepExpiredUnlocks(reapply: true)
        Task { await refreshNotificationStatus() }
        if settings.onboardingComplete, phase == .main {
            resumeUnlockIfNeeded()
        }
    }

    /// Safety net: re-shield anything whose unlock window has ended.
    func sweepExpiredUnlocks(reapply: Bool = false) {
        let now = Date()
        let expired = lock.activeUnlocks.filter { $0.expiresAt <= now }
        if !expired.isEmpty {
            ShieldController.relock(unlockID: nil, now: now)
            lock = SharedStore.lockState
        } else if reapply, settings.onboardingComplete {
            screenTime.apply(lock)
        }
    }

    private func warmUpRounds() {
        for game in settings.enabledGames {
            rounds.prefetch(game, difficulty: settings.difficulty(for: game))
        }
    }

    // MARK: Mutations

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        guard s != settings else { return }
        settings = s
        SharedStore.save(settings, .settings)
    }

    func updateLock(applyShield: Bool = true, _ change: (inout LockState) -> Void) {
        var l = SharedStore.lockState   // start from disk: extensions may have changed it
        l.selection = lock.selection
        l.items = lock.items
        l.mockApps = lock.mockApps
        l.locksEnabled = lock.locksEnabled
        l.defaultDuration = lock.defaultDuration
        l.puzzlesPerUnlock = lock.puzzlesPerUnlock
        change(&l)
        lock = l
        SharedStore.lockState = l
        if applyShield, settings.onboardingComplete || phase != .onboarding {
            screenTime.apply(l)
        }
    }

    func updateProfile(_ change: (inout UserProfile) -> Void) {
        var p = profile
        change(&p)
        guard p != profile else { return }
        profile = p
        SharedStore.save(profile, .userProfile)
    }

    /// Pre-fills the later setup screens from the personalised plan.
    func applyPlan() {
        let plan = profile
        updateLock(applyShield: false) { $0.defaultDuration = plan.suggestedDuration }
        updateSettings { $0.enabledGames = plan.suggestedGames }
    }

    func settingsBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { value in self.updateSettings { $0[keyPath: keyPath] = value } })
    }

    func lockBinding<T>(_ keyPath: WritableKeyPath<LockState, T>) -> Binding<T> {
        Binding(get: { self.lock[keyPath: keyPath] },
                set: { value in self.updateLock { $0[keyPath: keyPath] = value } })
    }

    var lockItems: [LockItem] { LockItem.items(from: lock) }

    func itemEnabledBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { self.lock.isEnabled(key) },
                set: { value in
                    self.guardStrict(weakening: !value) {
                        self.updateLock { $0.items[key, default: ItemConfig()].enabled = value }
                    }
                })
    }

    /// Master "Enable locks" switch (strict mode blocks turning it off).
    var locksEnabledBinding: Binding<Bool> {
        Binding(get: { self.lock.locksEnabled },
                set: { value in
                    self.guardStrict(weakening: !value) { self.updateLock { $0.locksEnabled = value } }
                })
    }

    func setOverride(_ duration: UnlockDuration?, for key: String) {
        updateLock { $0.items[key, default: ItemConfig()].override = duration }
    }

    func remove(_ item: LockItem) {
        guardStrict(weakening: true) { self.performRemove(item) }
    }

    private func performRemove(_ item: LockItem) {
        updateLock { state in
            switch item.kind {
            case .app(let t): state.selection.applicationTokens.remove(t)
            case .category(let t): state.selection.categoryTokens.remove(t)
            case .web(let t): state.selection.webDomainTokens.remove(t)
            case .mock(let name): state.mockApps.removeAll { $0 == name }
            }
            state.items[item.key] = nil
        }
    }

    /// Enables/disables a game for unlocks. At least one must stay enabled. Returns false if blocked.
    @discardableResult
    func setGame(_ game: GameID, enabled: Bool) -> Bool {
        if !enabled, settings.enabledGames == [game] { return false }
        updateSettings { s in
            if enabled {
                if !s.enabledGames.contains(game) {
                    s.enabledGames.append(game)
                    s.enabledGames.sort { (GameID.allCases.firstIndex(of: $0) ?? 0) < (GameID.allCases.firstIndex(of: $1) ?? 0) }
                }
            } else {
                s.enabledGames.removeAll { $0 == game }
            }
        }
        if enabled { rounds.prefetch(game, difficulty: settings.difficulty(for: game)) }
        return true
    }

    func setDifficulty(_ d: Difficulty, for game: GameID) {
        updateSettings { $0.difficulties[game.rawValue] = d }
        rounds.prefetch(game, difficulty: d)
    }

    // MARK: Onboarding

    /// "Turn On Locks" (S11): applies the shield right away.
    func turnOnLocksFromOnboarding() {
        updateLock(applyShield: false) { $0.locksEnabled = true }
        screenTime.apply(lock)
    }

    func finishOnboarding() {
        updateSettings {
            $0.onboardingComplete = true
            $0.showAllSetBanner = true
            $0.onboardingStep = nil
        }
        updateLock { $0.locksEnabled = true }
        paywallReason = .onboarding
        withAnimation(.easeInOut(duration: 0.35)) { phase = .main }
    }

    /// True when the user declined notifications (Settings then explains how to turn them on).
    var notificationsDenied = false

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshNotificationStatus()
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    // MARK: Authorization

    func requestScreenTimeAuthorization() async -> Bool {
        do {
            try await screenTime.requestAuthorization()
            if ScreenTimeService.isMock { updateSettings { $0.simulatorAuthorized = true } }
            isAuthorized = true
            return true
        } catch {
            isAuthorized = screenTime.isAuthorized(simulatorFlag: settings.simulatorAuthorized)
            return isAuthorized
        }
    }

    // MARK: Paywall & practice

    func presentPaywall(_ reason: PaywallReason) { paywallReason = reason }

    func closePaywall() {
        let reason = paywallReason
        paywallReason = nil
        if reason == .unlockLimit, !settings.hasLifetime {
            awaitingEntitlementForUnlock = false
        }
    }

    func tryPractice(_ game: GameID) {
        if settings.hasLifetime {
            practiceGame = game
        } else {
            presentPaywall(.practice)
        }
    }

    // MARK: Unlock flow

    func handleDeepLink(_ url: URL) {
        guard url.scheme == Brand.urlScheme else { return }
        if url.host == "unlock" { resumeUnlockIfNeeded(userInitiated: true) }
    }

    /// Opens the unlock flow if there's a saved session or a pending unlock from the shield.
    func resumeUnlockIfNeeded(userInitiated: Bool = false) {
        guard settings.onboardingComplete, unlockSession == nil else { return }
        if !userInitiated, let dismissed = dismissedPendingDate,
           (SharedStore.pendingUnlock?.createdAt ?? dismissed) <= dismissed {
            return
        }
        dismissedPendingDate = nil
        if let saved = SharedStore.load(UnlockSession.self, .unlockSession) {
            if let pending = SharedStore.pendingUnlock, pending.itemKey != saved.pending.itemKey {
                startSession(for: pending)
            } else {
                unlockSession = saved
                if saved.current == nil { Task { await loadRoundForSession() } }
            }
            return
        }
        if let pending = SharedStore.pendingUnlock {
            startSession(for: pending)
        }
    }

    private func startSession(for pending: PendingUnlock) {
        let order = settings.enabledGames.shuffled()
        let session = UnlockSession(pending: pending, required: max(1, min(10, lock.puzzlesPerUnlock)),
                                    order: order.isEmpty ? [.math] : order)
        unlockSession = session
        saveSession()
        Task { await loadRoundForSession() }
    }

    /// Simulator only: pretend a shielded app's START PUZZLE was tapped.
    func simulateShieldTap() {
        let item = lockItems.first
        let name: String
        switch item?.kind {
        case .mock(let n): name = n
        default: name = "Social"
        }
        SharedStore.pendingUnlock = PendingUnlock(itemKey: item?.key ?? TokenKey.mock(name), appName: name)
        SharedStore.save(nil as UnlockSession?, .unlockSession)
        unlockSession = nil
        resumeUnlockIfNeeded(userInitiated: true)
    }

    private func saveSession() {
        SharedStore.save(unlockSession, .unlockSession)
    }

    func loadRoundForSession() async {
        guard let session = unlockSession else { return }
        let game = session.currentGame
        let round = await rounds.nextRound(game, difficulty: settings.difficulty(for: game))
        guard unlockSession != nil else { return }
        unlockSession?.current = round
        roundStartedAt = Date()
        saveSession()
    }

    /// Persists the half-finished puzzle.
    func sessionRoundUpdated(_ round: AnyRound) {
        guard unlockSession != nil else { return }
        unlockSession?.current = round
        saveSession()
    }

    func sessionRoundFinished(_ status: RoundStatus) {
        guard var session = unlockSession else { return }
        recordResult(game: session.current?.game ?? session.currentGame, status: status, startedAt: roundStartedAt)
        session.current = nil
        switch status {
        case .solved:
            session.solved += 1
            if session.solved >= session.required {
                unlockSession = session
                saveSession()
                completeUnlock()
                return
            }
            session.orderIndex += 1
            if session.orderIndex >= session.order.count {
                session.orderIndex = 0
                session.order.shuffle()
            }
        case .failed, .playing:
            break // a failed round never counts; serve a new round of the same game
        }
        unlockSession = session
        saveSession()
        Task { await loadRoundForSession() }
    }

    func closeUnlockFlow() {
        // Progress stays saved; the pending unlock remains so the user can come back
        // (tapping the notification or the shield again reopens it).
        if let session = unlockSession { dismissedPendingDate = session.pending.createdAt }
        unlockSession = nil
        unlockResult = nil
    }

    private func completeUnlock() {
        if !settings.hasLifetime && settings.freeUnlocksUsed >= Brand.freeUnlocks {
            awaitingEntitlementForUnlock = true
            paywallReason = .unlockLimit
            return
        }
        grantUnlock()
    }

    private func grantUnlock() {
        guard let session = unlockSession else { return }
        let pending = session.pending
        if !settings.hasLifetime { updateSettings { $0.freeUnlocksUsed += 1 } }
        let duration = lock.duration(for: pending.itemKey)
        let unlock = ActiveUnlock(itemKey: pending.itemKey, appToken: pending.appToken, webToken: pending.webToken,
                                  expiresAt: duration.endDate(from: Date()))
        updateLock { state in
            state.activeUnlocks.removeAll { $0.itemKey == pending.itemKey }
            state.activeUnlocks.append(unlock)
        }
        StatsStore.recordUnlockEarned()
        statsChanged()
        screenTime.scheduleRelock(unlock)
        SharedStore.pendingUnlock = nil
        SharedStore.save(nil as UnlockSession?, .unlockSession)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["quizlock.unlock"])
        let name = pending.appName ?? SharedStore.tokenNames[pending.itemKey] ?? String(localized: "your app")
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.3)) {
            unlockResult = UnlockResult(appName: name, duration: duration)
        }
    }

    func finishUnlockResult() {
        unlockResult = nil
        unlockSession = nil
    }

    // MARK: Text helpers

    var selectedCountText: String {
        String(localized: "\(lock.selectedCount) apps selected")
    }

    var enabledGamesText: String {
        settings.enabledGames.map(\.localizedName).formatted(.list(type: .and))
    }
}
