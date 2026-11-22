import AppIntents
import RevenueCat
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

@main
struct LockieApp: App {
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
        // RevenueCat sees every purchase for its dashboard; Lockie still completes purchases itself
        // (StoreKit 2), so the paywall, trial and Pro logic work exactly as before.
        RevenueCatBridge.configure()
        // Decode Lockie's art off the main thread now, so no animation ever waits for a PNG.
        MascotArtCache.preload()
        NotificationArt.prepare()
        return true
    }
}

/// Opens the unlock flow when the "Your puzzle is ready" notification is tapped.
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

/// Writes Lockie's picture into the App Group once, for the "Tap to solve" notification's attachment.
enum NotificationArt {
    static func prepare() {
        DispatchQueue.global(qos: .utility).async {
            guard let url = PendingPuzzleNote.notificationArtURL,
                  !FileManager.default.fileExists(atPath: url.path),
                  let art = UIImage(named: MascotExpression.happy.assetName) else { return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let size = CGSize(width: 240, height: 240)
            let data = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
                art.draw(in: CGRect(origin: .zero, size: size))
            }
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - App Shortcut: "Solve my puzzle"

/// Opens Lockie straight into the waiting puzzle (Siri, Spotlight, the Shortcuts app, the Action button).
struct SolvePuzzleIntent: AppIntent {
    static var title: LocalizedStringResource = "Solve my puzzle"
    static var description = IntentDescription("Opens the puzzle that unlocks your app.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.handleDeepLink(Brand.unlockDeepLink)
        return .result()
    }
}

struct LockieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SolvePuzzleIntent(),
                    phrases: ["Solve my puzzle in \(.applicationName)", "Unlock with \(.applicationName)"],
                    shortTitle: "Solve my puzzle",
                    systemImageName: "puzzlepiece.fill")
    }
}

/// The only place that talks to RevenueCat (kept apart from Store.swift, whose StoreKit names would clash
/// with RevenueCat's). Lockie completes purchases itself with StoreKit 2; RevenueCat records them for its
/// dashboard (revenue, trials, conversions, churn). No accounts: RevenueCat only sees an anonymous ID.
enum RevenueCatBridge {
    static func configure() {
        RevenueCat.Purchases.logLevel = .warn
        RevenueCat.Purchases.configure(
            with: RevenueCat.Configuration.Builder(withAPIKey: Brand.revenueCatAPIKey)
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                .build())
    }

    /// After a successful StoreKit 2 purchase.
    static func record(_ result: StoreKit.Product.PurchaseResult) async {
        guard RevenueCat.Purchases.isConfigured else { return }
        _ = try? await RevenueCat.Purchases.shared.recordPurchase(result)
    }

    /// After Restore Purchases.
    static func syncRestore() async {
        guard RevenueCat.Purchases.isConfigured else { return }
        _ = try? await RevenueCat.Purchases.shared.syncPurchases()
    }
}
