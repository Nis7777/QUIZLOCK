import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

public extension ManagedSettingsStore.Name {
    static let main = Self("main")
}

/// Applies the shield from a `LockState`. Safe to call from the app and from every extension.
public enum ShieldController {
    /// Recomputes the whole shield. Idempotent.
    public static func apply(_ state: LockState, now: Date = Date()) {
        #if targetEnvironment(simulator)
        _ = state
        _ = now
        #else
        let store = ManagedSettingsStore(named: .main)
        guard state.locksEnabled else {
            store.clearAllSettings()
            return
        }
        let active = state.activeUnlocks.filter { $0.expiresAt > now }
        let unlockedApps = Set(active.compactMap(\.appToken))
        let unlockedWeb = Set(active.compactMap(\.webToken))

        let apps = state.selection.applicationTokens.filter { state.isEnabled(TokenKey.key($0)) && !unlockedApps.contains($0) }
        let categories = state.selection.categoryTokens.filter {
            let key = TokenKey.key($0)
            return state.isEnabled(key) && !state.isUnlocked(key, now: now)
        }
        let webs = state.selection.webDomainTokens.filter { state.isEnabled(TokenKey.key($0)) && !unlockedWeb.contains($0) }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: unlockedApps)
        store.shield.webDomains = webs.isEmpty ? nil : webs
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: unlockedWeb)
        #endif
    }

    public static func clear() {
        #if !targetEnvironment(simulator)
        ManagedSettingsStore(named: .main).clearAllSettings()
        #endif
    }

    /// Re-locks after an unlock window ends (called by the DeviceActivity monitor and by the app's sweep).
    /// Removes the given unlock plus anything already expired, saves, re-applies the shield. Idempotent.
    @discardableResult
    public static func relock(unlockID: String?, now: Date = Date()) -> [String] {
        var state = SharedStore.lockState
        let expired = state.activeUnlocks.filter { $0.id == unlockID || $0.expiresAt <= now.addingTimeInterval(1) }
        if !expired.isEmpty {
            let ids = Set(expired.map(\.id))
            state.activeUnlocks.removeAll { ids.contains($0.id) }
            SharedStore.lockState = state
        }
        apply(state, now: now)
        stopMonitoring(expired.map(\.activityName) + (unlockID.map { ["unlock.\($0)"] } ?? []))
        return expired.map(\.id)
    }

    public static func stopMonitoring(_ names: [String]) {
        #if !targetEnvironment(simulator)
        guard !names.isEmpty else { return }
        DeviceActivityCenter().stopMonitoring(names.map { DeviceActivityName($0) })
        #endif
    }
}
