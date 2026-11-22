import Foundation
import ManagedSettings
import UserNotifications
import WidgetKit

/// Handles the shield buttons. "Solve to unlock" records a pending unlock and posts a notification
/// (a shield extension can't open the host app directly); "Not now" closes the app.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let key = TokenKey.key(application)
        handle(action, pending: PendingUnlock(appToken: application, itemKey: key, appName: SharedStore.tokenNames[key]),
               completion: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let key = TokenKey.key(webDomain)
        handle(action, pending: PendingUnlock(webToken: webDomain, itemKey: key, appName: SharedStore.tokenNames[key]),
               completion: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let key = TokenKey.key(category)
        handle(action, pending: PendingUnlock(categoryToken: category, itemKey: key, appName: SharedStore.tokenNames[key]),
               completion: completionHandler)
    }

    private func handle(_ action: ShieldAction, pending: PendingUnlock,
                        completion: @escaping (ShieldActionResponse) -> Void) {
        // Not a `switch`: newer SDKs add ShieldAction cases, which would make a switch non-exhaustive.
        // Solve to unlock starts the unlock; every other button (Not now, or anything new) closes the app.
        // The "Your puzzle is ready" shield (shown right after Solve to unlock) has one button, Got it:
        // close the app so the user lands on the Home Screen with the notification on top.
        if let current = SharedStore.pendingUnlock, current.itemKey == pending.itemKey,
           Date().timeIntervalSince(current.createdAt) < Brand.shieldReadyWindow {
            completion(.close)
            return
        }
        if case .primaryButtonPressed = action {
            // Fill in which app this is from the shield that's on screen (a category tap carries no app).
            var pending = pending
            if let shown = SharedStore.lastShieldedApp, shown.isRecent(120) {
                if pending.appName == nil { pending.appName = shown.name }
                if pending.bundleID == nil { pending.bundleID = shown.bundleID }
            }
            if pending.bundleID == nil { pending.bundleID = SharedStore.tokenBundleIDs[pending.itemKey] }
            SharedStore.pendingUnlock = pending
            // Any route into Lockie in the next 5 minutes (notification, icon, widget, Spotlight,
            // Shortcuts) opens straight into this puzzle; the widget shows it too.
            PendingPuzzleNote.set(appName: pending.appName)
            WidgetCenter.shared.reloadAllTimelines()
            postNotification(appName: pending.appName) {
                // .defer keeps the shield up and redraws it in the "Your puzzle is ready" state.
                completion(.defer)
            }
        } else {
            if case .secondaryButtonPressed = action {
                // Not now: an unlock skipped. Counts toward "time saved" (skips × the unlock time).
                StatsStore.recordSkip(minutes: Self.unlockMinutes(SharedStore.lockState.duration(for: pending.itemKey)))
            }
            completion(.close)
        }
    }

    private static func unlockMinutes(_ d: UnlockDuration) -> Int {
        switch d {
        case .minutes(let m): return m
        case .forToday: return 60
        case .custom(let h, let m): return h * 60 + m
        }
    }

    /// "Tap to solve 🧩": Time Sensitive (breaks through Focus and Sleep when the person allows it),
    /// relevance 1.0 (top of the stack), with Lockie attached so it looks like ours, not a system alert.
    /// If notifications are off it simply isn't shown; the shield then tells them to open Lockie.
    private func postNotification(appName: String?, then done: @escaping () -> Void) {
        let n = max(1, SharedStore.lockState.puzzlesPerUnlock)
        let content = UNMutableNotificationContent()
        let target = appName ?? String(localized: "your app")
        content.title = String(localized: "Tap to solve 🧩")
        content.body = n == 1 ? String(localized: "\(target) unlocks as soon as you solve it.")
                              : String(localized: "Solve \(n) puzzles and \(target) unlocks.")
        content.sound = .default
        content.relevanceScore = 1.0
        content.threadIdentifier = "lockie.unlock"
        content.userInfo = ["deeplink": Brand.unlockDeepLink.absoluteString]
        if let attachment = Self.lockieAttachment() { content.attachments = [attachment] }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            // Time Sensitive when it's available and on; otherwise a normal notification, so it always shows.
            content.interruptionLevel = settings.timeSensitiveSetting == .enabled ? .timeSensitive : .active
            let request = UNNotificationRequest(identifier: "lockie.unlock", content: content, trigger: nil)
            center.add(request) { _ in done() }
        }
    }

    /// A copy of the App Group's Lockie picture (the system moves attachment files, so never the original).
    private static func lockieAttachment() -> UNNotificationAttachment? {
        guard let source = PendingPuzzleNote.notificationArtURL,
              FileManager.default.fileExists(atPath: source.path) else { return nil }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("lockie-\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: source, to: copy)
            return try UNNotificationAttachment(identifier: "lockie", url: copy, options: nil)
        } catch {
            return nil
        }
    }
}
