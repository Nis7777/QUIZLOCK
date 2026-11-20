import Foundation
import FamilyControls
import ManagedSettings

/// How long an app stays unlocked after the puzzles are solved.
public enum UnlockDuration: Codable, Hashable, Sendable {
    case minutes(Int)
    case forToday
    case custom(hours: Int, minutes: Int)

    public static let presets: [UnlockDuration] = [.minutes(5), .minutes(15), .forToday]
    public static let `default`: UnlockDuration = .minutes(15)

    public var isCustom: Bool { if case .custom = self { return true } else { return false } }

    /// "15 minutes", "For Today", "1 hour 30 minutes".
    public var label: String {
        switch self {
        case .minutes(let m): return Self.describe(totalMinutes: m)
        case .forToday: return "For Today"
        case .custom(let h, let m): return Self.describe(totalMinutes: h * 60 + m)
        }
    }

    /// Used in sentences: "it's unlocked for 15 minutes" / "it's unlocked for today".
    public var sentenceLabel: String {
        if case .forToday = self { return "today" }
        return label
    }

    static func describe(totalMinutes: Int) -> String {
        let h = totalMinutes / 60, m = totalMinutes % 60
        func unit(_ n: Int, _ s: String) -> String { "\(n) \(s)\(n == 1 ? "" : "s")" }
        switch (h, m) {
        case (0, _): return unit(m, "minute")
        case (_, 0): return unit(h, "hour")
        default: return unit(h, "hour") + " " + unit(m, "minute")
        }
    }

    /// When an unlock that starts at `now` ends.
    public func endDate(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .minutes(let m):
            return now.addingTimeInterval(TimeInterval(max(1, m) * 60))
        case .custom(let h, let m):
            return now.addingTimeInterval(TimeInterval(max(1, h * 60 + m) * 60))
        case .forToday:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? now.addingTimeInterval(3600)
            return max(end, now.addingTimeInterval(60))
        }
    }
}

/// Per app / category / website settings, keyed by `TokenKey`.
public struct ItemConfig: Codable, Hashable, Sendable {
    public var enabled: Bool = true
    public var override: UnlockDuration?
    public init(enabled: Bool = true, override: UnlockDuration? = nil) {
        self.enabled = enabled
        self.override = override
    }
}

/// A temporary unlock earned by solving puzzles.
public struct ActiveUnlock: Codable, Hashable, Identifiable {
    public let id: String
    public let itemKey: String
    public let appToken: ApplicationToken?
    public let webToken: WebDomainToken?
    public let expiresAt: Date

    public init(id: String = UUID().uuidString, itemKey: String, appToken: ApplicationToken?, webToken: WebDomainToken?, expiresAt: Date) {
        self.id = id; self.itemKey = itemKey; self.appToken = appToken; self.webToken = webToken; self.expiresAt = expiresAt
    }

    public var activityName: String { "unlock.\(id)" }
}

/// Written by the shield action extension when the user taps START PUZZLE.
public struct PendingUnlock: Codable, Hashable {
    public var appToken: ApplicationToken?
    public var webToken: WebDomainToken?
    public var categoryToken: ActivityCategoryToken?
    public var itemKey: String
    public var appName: String?
    public var createdAt: Date

    public init(appToken: ApplicationToken? = nil, webToken: WebDomainToken? = nil, categoryToken: ActivityCategoryToken? = nil,
                itemKey: String, appName: String?, createdAt: Date = Date()) {
        self.appToken = appToken; self.webToken = webToken; self.categoryToken = categoryToken
        self.itemKey = itemKey; self.appName = appName; self.createdAt = createdAt
    }
}

/// Everything the extensions need to compute the shield.
public struct LockState: Codable {
    public var selection = FamilyActivitySelection()
    public var items: [String: ItemConfig] = [:]
    public var activeUnlocks: [ActiveUnlock] = []
    public var locksEnabled = true
    public var defaultDuration: UnlockDuration = .default
    public var puzzlesPerUnlock = 1
    /// Simulator only: fake app names used instead of real tokens.
    public var mockApps: [String] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selection = (try? c.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection)) ?? FamilyActivitySelection()
        items = (try? c.decodeIfPresent([String: ItemConfig].self, forKey: .items)) ?? [:]
        activeUnlocks = (try? c.decodeIfPresent([ActiveUnlock].self, forKey: .activeUnlocks)) ?? []
        locksEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .locksEnabled)) ?? true
        defaultDuration = (try? c.decodeIfPresent(UnlockDuration.self, forKey: .defaultDuration)) ?? .default
        puzzlesPerUnlock = (try? c.decodeIfPresent(Int.self, forKey: .puzzlesPerUnlock)) ?? 1
        mockApps = (try? c.decodeIfPresent([String].self, forKey: .mockApps)) ?? []
    }

    public func config(for key: String) -> ItemConfig { items[key] ?? ItemConfig() }
    public func isEnabled(_ key: String) -> Bool { config(for: key).enabled }
    public func duration(for key: String) -> UnlockDuration { config(for: key).override ?? defaultDuration }

    /// Number of apps + categories (+ websites) selected.
    public var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count + mockApps.count
    }

    public func isUnlocked(_ key: String, now: Date = Date()) -> Bool {
        activeUnlocks.contains { $0.itemKey == key && $0.expiresAt > now }
    }
}

/// Stable string keys for tokens (tokens are opaque Codable blobs).
public enum TokenKey {
    public static func key<T: Encodable>(_ token: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(token) else { return UUID().uuidString }
        return data.base64EncodedString()
    }

    public static func mock(_ name: String) -> String { "mock:" + name }
}
