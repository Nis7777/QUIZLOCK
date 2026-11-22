import Foundation

/// Codable JSON persistence in the App Group `UserDefaults`, shared by the app and its extensions.
public enum SharedStore {
    public enum Key: String {
        case settings = "settings.v1"
        case lockState = "lockState.v1"
        case pendingUnlock = "pendingUnlock.v1"
        case unlockSession = "unlockSession.v1"
        case tokenNames = "tokenNames.v1"
        case tokenBundleIDs = "tokenBundleIDs.v1"
        case lastShieldedApp = "lastShieldedApp.v1"
        case usedWordAnswers = "usedWordAnswers.v1"
        case userProfile = "userProfile.v1"
        case stats = "stats.v1"
    }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: Brand.appGroup) ?? .standard
    }

    public static func load<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public static func save<T: Encodable>(_ value: T?, _ key: Key) {
        guard let value else {
            defaults.removeObject(forKey: key.rawValue)
            return
        }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    // MARK: Convenience

    public static var lockState: LockState {
        get { load(LockState.self, .lockState) ?? LockState() }
        set { save(newValue, .lockState) }
    }

    public static var pendingUnlock: PendingUnlock? {
        get { load(PendingUnlock.self, .pendingUnlock) }
        set { save(newValue, .pendingUnlock) }
    }

    /// Whether Lockie may post notifications, as last seen by the app (nil = not known yet).
    /// The shield reads it to tell people to open Lockie themselves when notifications are off.
    public static var notificationsAllowed: Bool? {
        get { defaults.object(forKey: "notificationsAllowed.v1") as? Bool }
        set { defaults.set(newValue, forKey: "notificationsAllowed.v1") }
    }

    /// Display names remembered by the shield configuration extension (token key → name).
    public static var tokenNames: [String: String] {
        get { load([String: String].self, .tokenNames) ?? [:] }
        set { save(newValue, .tokenNames) }
    }

    /// Bundle identifiers remembered by the shield configuration extension (token key → "com.burbn.instagram"),
    /// so after an unlock Lockie can open the app the person was trying to use.
    public static var tokenBundleIDs: [String: String] {
        get { load([String: String].self, .tokenBundleIDs) ?? [:] }
        set { save(newValue, .tokenBundleIDs) }
    }

    public static func rememberBundleID(_ bundleID: String?, forKey key: String) {
        guard let bundleID, !bundleID.isEmpty else { return }
        var ids = tokenBundleIDs
        guard ids[key] != bundleID else { return }
        ids[key] = bundleID
        tokenBundleIDs = ids
    }

    /// The app (or site) whose shield was drawn most recently, written by the shield configuration
    /// extension. When an app is locked through a category, "Solve to unlock" arrives as the category, so
    /// this is how Lockie still knows it was Instagram.
    public static var lastShieldedApp: ShieldedApp? {
        get { load(ShieldedApp.self, .lastShieldedApp) }
        set { save(newValue, .lastShieldedApp) }
    }

    public static func rememberName(_ name: String?, forKey key: String) {
        guard let name, !name.isEmpty else { return }
        var names = tokenNames
        guard names[key] != name else { return }
        names[key] = name
        tokenNames = names
    }
}

/// What the shield last showed: enough to open it again after an unlock.
public struct ShieldedApp: Codable, Equatable {
    public var name: String?
    public var bundleID: String?
    public var isWebsite: Bool
    public var at: Date

    public init(name: String?, bundleID: String?, isWebsite: Bool = false, at: Date = Date()) {
        self.name = name; self.bundleID = bundleID; self.isWebsite = isWebsite; self.at = at
    }

    /// Shown within the last `seconds`.
    public func isRecent(_ seconds: TimeInterval, now: Date = Date()) -> Bool { now.timeIntervalSince(at) < seconds }
}
