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
        switch action {
        case .primaryButtonPressed:
            SharedStore.pendingUnlock = pending
            postNotification(appName: pending.appName) {
                completion(.defer)
            }
        case .secondaryButtonPressed:
            completion(.close)
        @unknown default:
            completion(.close)
        }
    }

    private func postNotification(appName: String?, then done: @escaping () -> Void) {
        let n = max(1, SharedStore.lockState.puzzlesPerUnlock)
        let content = UNMutableNotificationContent()
        content.title = "Tap to start your puzzle 🔑"
        content.body = "Solve \(n) puzzle\(n == 1 ? "" : "s") to unlock \(appName ?? "your app")"
        content.sound = .default
        content.userInfo = ["deeplink": Brand.unlockDeepLink.absoluteString]
        let request = UNNotificationRequest(identifier: "quizlock.unlock", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done() }
    }
}
