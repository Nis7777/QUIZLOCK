import Foundation
import ManagedSettings
import UserNotifications

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
            SharedStore.pendingUnlock = pending
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

    private func postNotification(appName: String?, then done: @escaping () -> Void) {
        let n = max(1, SharedStore.lockState.puzzlesPerUnlock)
        let content = UNMutableNotificationContent()
        let target = appName ?? String(localized: "your app")
        content.title = String(localized: "Your puzzle is ready 🧩")
        content.body = n == 1 ? String(localized: "Tap to solve it and unlock \(target).")
                              : String(localized: "Tap to solve \(n) puzzles and unlock \(target).")
        content.sound = .default
        content.interruptionLevel = .active
        content.relevanceScore = 1
        content.userInfo = ["deeplink": Brand.unlockDeepLink.absoluteString]
        let request = UNNotificationRequest(identifier: "lockie.unlock", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done() }
    }
}
