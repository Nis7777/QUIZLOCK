import Foundation
import SwiftUI
import WidgetKit

/// Streaks & stats, milestones, difficulty progression, strict mode, lock schedules,
/// emergency unlocks, the daily puzzle and reminder notifications.
extension AppModel {

    // MARK: Stats

    /// Reloads stats, checks milestones, refreshes widgets and reminders.
    func statsChanged() {
        stats = StatsStore.load()
        if settings.onboardingComplete, milestone == nil, let m = stats.pendingMilestone() {
            milestone = m
        }
        WidgetCenter.shared.reloadAllTimelines()
        Reminders.reschedule(settings: settings, stats: stats)
        pushStatsToCloud()
    }

    func milestoneCelebrated() {
        if let m = milestone {
            StatsStore.update { s in
                // Celebrating 7 also covers 3, so smaller ones don't pop up later.
                for x in Stats.milestones where x <= m && !s.celebratedMilestones.contains(x) { s.celebratedMilestones.append(x) }
            }
        }
        milestone = nil
        stats = StatsStore.load()
    }

    var timeSavedTodayText: String { StatsStore.formatMinutes(stats.day(Date()).minutesSaved) }

    // MARK: Results & difficulty progression

    /// Records a finished round (unlock flow, practice, daily puzzle) and adapts difficulty:
    /// 5 quick solves in a row → offer the next level; 3 fails in a row → step down automatically.
    func recordResult(game: GameID, status: RoundStatus, startedAt: Date) {
        let key = game.rawValue
        switch status {
        case .solved:
            let quick = Date().timeIntervalSince(startedAt) < 60
            StatsStore.recordSolve(game: key)
            let updated = StatsStore.update { s in
                s.failStreak[key] = 0
                s.quickSolveStreak[key] = quick ? (s.quickSolveStreak[key] ?? 0) + 1 : 0
            }
            if (updated.quickSolveStreak[key] ?? 0) >= 5, nextDifficulty(for: game) != nil {
                StatsStore.update { $0.quickSolveStreak[key] = 0 }
                progressionOffer = game
            }
        case .failed:
            let updated = StatsStore.update { s in
                s.quickSolveStreak[key] = 0
                s.failStreak[key] = (s.failStreak[key] ?? 0) + 1
            }
            if (updated.failStreak[key] ?? 0) >= 3, let easier = previousDifficulty(for: game) {
                StatsStore.update { $0.failStreak[key] = 0 }
                setDifficulty(easier, for: game)
                showToast(String(localized: "We made \(game.localizedName) a bit easier: \(easier.localizedName)."))
            }
        case .playing:
            break
        }
        statsChanged()
    }

    func nextDifficulty(for game: GameID) -> Difficulty? {
        let levels = game.difficulties
        guard let i = levels.firstIndex(of: settings.difficulty(for: game)), i + 1 < levels.count else { return nil }
        // Only offer the step up from the entry levels (Quick/Easy → next).
        return i <= 1 ? levels[i + 1] : nil
    }

    func previousDifficulty(for game: GameID) -> Difficulty? {
        let levels = game.difficulties
        guard let i = levels.firstIndex(of: settings.difficulty(for: game)), i > 0 else { return nil }
        return levels[i - 1]
    }

    func acceptProgression() {
        if let game = progressionOffer, let next = nextDifficulty(for: game) {
            setDifficulty(next, for: game)
            showToast(String(localized: "\(game.localizedName) is now \(next.localizedName). Good luck!"))
        }
        progressionOffer = nil
    }

    func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if self.toast == text { withAnimation(.easeIn(duration: 0.2)) { self.toast = nil } }
        }
    }

    // MARK: Strict mode

    var isStrict: Bool { lock.isStrict() }

    /// Runs `action`, unless it weakens the locks while strict mode is on; then the user must
    /// first solve 3 hard puzzles (which also ends strict mode).
    func guardStrict(weakening: Bool, _ action: @escaping () -> Void) {
        if weakening && lock.isStrict() {
            Haptics.error()
            pendingStrictAction = action
            strictChallengeActive = true
        } else {
            action()
        }
    }

    func startStrictMode(hours: Int) {
        let until = Date().addingTimeInterval(TimeInterval(hours) * 3600)
        updateLock { $0.strictUntil = until }
        Haptics.success()
    }

    func strictChallengeCompleted() {
        updateLock { $0.strictUntil = nil }
        strictChallengeActive = false
        let action = pendingStrictAction
        pendingStrictAction = nil
        action?()
        showToast(String(localized: "Strict mode ended."))
    }

    func strictChallengeCancelled() {
        strictChallengeActive = false
        pendingStrictAction = nil
    }

    var strictUntilText: String {
        (lock.strictUntil ?? Date()).formatted(date: .omitted, time: .shortened)
    }

    // MARK: Lock schedule

    func setSchedule(_ schedule: LockSchedule?) {
        guardStrict(weakening: true) {
            self.updateLock { $0.schedule = schedule }
            self.screenTime.registerSchedule(schedule)
        }
    }

    // MARK: Emergency unlock

    var emergencyUnlocksLeft: Int { stats.emergencyUnlocksLeft() }

    /// 1 minute without a puzzle. Max 3 per week; breaks today's streak.
    func emergencyUnlock() {
        guard let session = unlockSession, emergencyUnlocksLeft > 0 else { return }
        let pending = session.pending
        let unlock = ActiveUnlock(itemKey: pending.itemKey, appToken: pending.appToken, webToken: pending.webToken,
                                  expiresAt: Date().addingTimeInterval(60))
        updateLock { state in
            state.activeUnlocks.removeAll { $0.itemKey == pending.itemKey }
            state.activeUnlocks.append(unlock)
        }
        screenTime.scheduleRelock(unlock)
        StatsStore.recordEmergency()
        SharedStore.pendingUnlock = nil
        SharedStore.save(nil as UnlockSession?, .unlockSession)
        statsChanged()
        let name = pending.appName ?? SharedStore.tokenNames[pending.itemKey] ?? String(localized: "your app")
        withAnimation(.easeInOut(duration: 0.3)) {
            unlockResult = UnlockResult(appName: name, duration: .minutes(1))
        }
    }

    // MARK: Daily puzzle

    var dailyGame: GameID { RoundProvider.dailyGame(for: Date()) }
    var dailySolvedToday: Bool { stats.day(Date()).dailyPuzzleSolved }

    func dailyPuzzleSolved(startedAt: Date) {
        StatsStore.recordDailyPuzzle()
        recordResult(game: dailyGame, status: .solved, startedAt: startedAt)
        Haptics.success()
    }

    // MARK: Reminders

    func setReminder(streak: Bool? = nil, weekly: Bool? = nil) {
        updateSettings { s in
            if let streak { s.streakReminderEnabled = streak }
            if let weekly { s.weeklySummaryEnabled = weekly }
        }
        Task {
            if streak == true || weekly == true { await requestNotificationPermission() }
            Reminders.reschedule(settings: settings, stats: stats)
        }
    }
}
