import SwiftUI
import UIKit
import UserNotifications

@main
struct QuizLockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.palette, model.palette)
                .preferredColorScheme(model.settings.theme == .dark ? .dark : .light)
                .tint(model.palette.accent)
                // Dynamic Type is supported up to a size where every screen still fits.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .onOpenURL { model.handleDeepLink($0) }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

/// Opens the unlock flow when the "Tap to start your puzzle" notification is tapped.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo["deeplink"] as? String
        let url = URL(string: link ?? "") ?? Brand.unlockDeepLink
        Task { @MainActor in
            AppModel.shared.handleDeepLink(url)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
