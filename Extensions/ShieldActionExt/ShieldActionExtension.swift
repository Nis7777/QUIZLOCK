import Foundation
import ManagedSettings
import UserNotifications

/// Handles the shield buttons. START PUZZLE records a pending unlock and posts a notification
/// (a shield extension can't open the host app directly); NOT NOW closes the app.
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
        // START PUZZLE starts the unlock; every other button (NOT NOW, or anything new) closes the app.
        if case .primaryButtonPressed = action {
            SharedStore.pendingUnlock = pending
            postNotification(appName: pending.appName) {
                completion(.defer)
            }
        } else {
            if case .secondaryButtonPressed = action {
                // NOT NOW: an unlock skipped. Counts toward "time saved" (skips × the unlock time).
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
        content.title = String(localized: "Tap to start your puzzle 🧩")
        content.body = String(localized: "Solve \(n) puzzles to unlock \(appName ?? String(localized: "your app"))")
        content.sound = .default
        content.userInfo = ["deeplink": Brand.unlockDeepLink.absoluteString]
        let request = UNNotificationRequest(identifier: "quizlock.unlock", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done() }
    }
}
