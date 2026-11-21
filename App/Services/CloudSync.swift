import Foundation
import SwiftUI

/// iCloud key-value sync (NSUbiquitousKeyValueStore) so progress survives a new phone. No accounts:
/// it uses the user's own iCloud. Synced: stats (streaks, totals, daily puzzle history, best streak), enabled games,
/// difficulty per game, theme, unlock time + puzzles per unlock, onboarding completed, and the profile answers.
/// Never synced: Screen Time selections and tokens (they only work on the device that created them),
/// the subscription (StoreKit handles that per Apple ID) and device-only state.
/// With iCloud off, the store just keeps working locally.
@MainActor
final class CloudSync {
    enum Key: String, CaseIterable {
        case stats = "cloud.stats.v1"
        case settings = "cloud.settings.v1"
        case profile = "cloud.profile.v1"
    }

    /// The settings that travel between devices. The newest copy wins (`modifiedAt`).
    struct SyncedSettings: Codable, Equatable {
        var modifiedAt: Date
        var onboardingComplete: Bool
        var enabledGames: [GameID]
        var difficulties: [String: Difficulty]
        var theme: AppTheme
        var defaultDuration: UnlockDuration
        var puzzlesPerUnlock: Int

        init(modifiedAt: Date, settings: AppSettings, lock: LockState) {
            self.modifiedAt = modifiedAt
            onboardingComplete = settings.onboardingComplete
            enabledGames = settings.enabledGames
            difficulties = settings.difficulties
            theme = settings.theme
            defaultDuration = lock.defaultDuration
            puzzlesPerUnlock = lock.puzzlesPerUnlock
        }

        /// Same values, ignoring the timestamp.
        func sameValues(as other: SyncedSettings) -> Bool {
            var a = self, b = other
            a.modifiedAt = .distantPast
            b.modifiedAt = .distantPast
            return a == b
        }
    }

    struct SyncedProfile: Codable, Equatable {
        var modifiedAt: Date
        var profile: UserProfile
    }

    private var store: NSUbiquitousKeyValueStore { .default }
    private var observer: NSObjectProtocol?

    /// Off in UI tests so a test run never reads or overwrites real iCloud data.
    let isEnabled: Bool

    init() {
        #if DEBUG
        isEnabled = !DemoData.isFreshInstallTest && !DemoData.isEnabled
        #else
        isEnabled = true
        #endif
    }

    /// Starts listening for changes from other devices and asks iCloud for the latest values.
    func start(onRemoteChange: @escaping @MainActor () -> Void) {
        guard isEnabled, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { _ in
            Task { @MainActor in onRemoteChange() }
        }
        store.synchronize()
    }

    func read<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard isEnabled, let data = store.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func write<T: Encodable>(_ value: T, _ key: Key) {
        guard isEnabled, let data = try? JSONEncoder().encode(value) else { return }
        guard store.data(forKey: key.rawValue) != data else { return }
        store.set(data, forKey: key.rawValue)
    }

    /// "Reset all data": removes everything this app stored in iCloud.
    func removeAll() {
        for key in Key.allCases { store.removeObject(forKey: key.rawValue) }
        for key in store.dictionaryRepresentation.keys { store.removeObject(forKey: key) }
        store.synchronize()
    }

    // MARK: Local timestamps (when this device last changed its synced settings / profile)

    private enum LocalKey {
        static let settingsModifiedAt = "cloud.local.settingsModifiedAt"
        static let profileModifiedAt = "cloud.local.profileModifiedAt"
    }

    var localSettingsModifiedAt: Date? {
        get { SharedStore.defaults.object(forKey: LocalKey.settingsModifiedAt) as? Date }
        set { SharedStore.defaults.set(newValue, forKey: LocalKey.settingsModifiedAt) }
    }

    var localProfileModifiedAt: Date? {
        get { SharedStore.defaults.object(forKey: LocalKey.profileModifiedAt) as? Date }
        set { SharedStore.defaults.set(newValue, forKey: LocalKey.profileModifiedAt) }
    }
}

// MARK: - AppModel integration

extension AppModel {
    /// On launch and whenever another device changes iCloud: merge into the App Group store.
    /// Stats: per-day maximums (higher streak / totals win). Settings and profile: the newest copy wins,
    /// except "onboarding completed", which never goes back to false.
    func mergeFromCloud() {
        guard cloud.isEnabled else { return }
        let wasOnboarded = settings.onboardingComplete

        // Stats
        let localStats = StatsStore.load()
        if let remote = cloud.read(Stats.self, .stats) {
            let merged = localStats.merged(with: remote)
            if merged != localStats {
                StatsStore.save(merged)
                statsChanged()
            }
        }
        cloud.write(StatsStore.load(), .stats)

        // Settings
        if let remote = cloud.read(CloudSync.SyncedSettings.self, .settings) {
            if remote.modifiedAt > (cloud.localSettingsModifiedAt ?? .distantPast) {
                applyingCloudChange = true
                updateSettings { s in
                    s.enabledGames = remote.enabledGames.isEmpty ? s.enabledGames : remote.enabledGames
                    s.difficulties = remote.difficulties
                    s.theme = remote.theme
                    s.onboardingComplete = s.onboardingComplete || remote.onboardingComplete
                }
                updateLock(applyShield: settings.onboardingComplete) { l in
                    l.defaultDuration = remote.defaultDuration
                    l.puzzlesPerUnlock = max(1, min(10, remote.puzzlesPerUnlock))
                }
                applyingCloudChange = false
                cloud.localSettingsModifiedAt = remote.modifiedAt
            } else if remote.onboardingComplete, !settings.onboardingComplete {
                applyingCloudChange = true
                updateSettings { $0.onboardingComplete = true }
                applyingCloudChange = false
            }
        }

        // Profile
        if let remote = cloud.read(CloudSync.SyncedProfile.self, .profile),
           remote.modifiedAt > (cloud.localProfileModifiedAt ?? .distantPast) {
            applyingCloudChange = true
            updateProfile { $0 = remote.profile }
            applyingCloudChange = false
            cloud.localProfileModifiedAt = remote.modifiedAt
        }

        // A new phone with synced progress: skip onboarding and ask for the apps to lock again
        // (Screen Time selections can't move between devices).
        if !wasOnboarded, settings.onboardingComplete {
            restoreFromCloudOnNewDevice()
        } else if settings.onboardingComplete {
            // Make sure iCloud has this device's settings if it had none yet.
            if cloud.read(CloudSync.SyncedSettings.self, .settings) == nil { pushSettingsToCloud() }
            if cloud.read(CloudSync.SyncedProfile.self, .profile) == nil { pushProfileToCloud() }
        }
    }

    private func restoreFromCloudOnNewDevice() {
        updateSettings {
            $0.onboardingStep = nil
            $0.showAllSetBanner = false
        }
        // Nothing is locked yet on this phone; the user picks the apps again.
        updateLock(applyShield: false) { $0.locksEnabled = true }
        welcomeBack = true
        withAnimation(.easeInOut(duration: 0.35)) { phase = .main }
    }

    /// Called after a local change to a synced setting. Not during onboarding, so a new phone that's still
    /// being set up never overwrites the progress saved in iCloud before it has been restored.
    func pushSettingsToCloud() {
        guard cloud.isEnabled, !applyingCloudChange, settings.onboardingComplete else { return }
        let now = Date()
        cloud.localSettingsModifiedAt = now
        cloud.write(CloudSync.SyncedSettings(modifiedAt: now, settings: settings, lock: lock), .settings)
    }

    func pushProfileToCloud() {
        guard cloud.isEnabled, !applyingCloudChange, settings.onboardingComplete else { return }
        let now = Date()
        cloud.localProfileModifiedAt = now
        cloud.write(CloudSync.SyncedProfile(modifiedAt: now, profile: profile), .profile)
    }

    /// Stats only ever merge upwards, so they can be pushed anytime.
    func pushStatsToCloud() {
        guard cloud.isEnabled else { return }
        var stats = StatsStore.load()
        if let remote = cloud.read(Stats.self, .stats) { stats = stats.merged(with: remote) }
        cloud.write(stats, .stats)
    }

    /// True when a change between two settings values touches something that's synced.
    static func syncedSettingsChanged(_ a: AppSettings, _ b: AppSettings) -> Bool {
        a.onboardingComplete != b.onboardingComplete || a.enabledGames != b.enabledGames
            || a.difficulties != b.difficulties || a.theme != b.theme
    }
}
