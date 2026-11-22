import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the custom block screen for shielded apps, categories and websites.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let brand = UIColor(red: 0xFF / 255, green: 0x5A / 255, blue: 0x36 / 255, alpha: 1)
    private static let textPrimary = UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1)
    /// The soft coral brand tint (#F7E1DF) used across the app, instead of plain white.
    private static let background = UIColor(red: 0xF7 / 255, green: 0xE1 / 255, blue: 0xDF / 255, alpha: 1)
    private static let textSecondary = UIColor(red: 0x5C / 255, green: 0x4A / 255, blue: 0x48 / 255, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        remember(application)
        return makeConfiguration(name: application.localizedDisplayName, keys: [application.token.map(TokenKey.key)])
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        remember(application)
        return makeConfiguration(name: application.localizedDisplayName ?? category.localizedDisplayName,
                                 keys: [application.token.map(TokenKey.key), category.token.map(TokenKey.key)])
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        if let token = webDomain.token { SharedStore.rememberName(webDomain.domain, forKey: TokenKey.key(token)) }
        return makeConfiguration(name: webDomain.domain, keys: [webDomain.token.map(TokenKey.key)])
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        if let token = webDomain.token { SharedStore.rememberName(webDomain.domain, forKey: TokenKey.key(token)) }
        return makeConfiguration(name: webDomain.domain ?? category.localizedDisplayName,
                                 keys: [webDomain.token.map(TokenKey.key), category.token.map(TokenKey.key)])
    }

    private func remember(_ application: Application) {
        guard let token = application.token else { return }
        SharedStore.rememberName(application.localizedDisplayName, forKey: TokenKey.key(token))
    }

    /// Two states:
    /// - Locked: "Instagram is locked" + what it takes to open it, [Solve to unlock] / [Not now].
    /// - Puzzle ready (after Solve to unlock was tapped; the shield is redrawn after `.defer`):
    ///   tells the user exactly where the puzzle is (the notification, or the Lockie app), [Got it].
    private func makeConfiguration(name: String?, keys: [String?]) -> ShieldConfiguration {
        let appName = name ?? String(localized: "This app")
        let itemKeys = keys.compactMap { $0 }
        if let pending = SharedStore.pendingUnlock, itemKeys.contains(pending.itemKey),
           Date().timeIntervalSince(pending.createdAt) < Brand.shieldReadyWindow {
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
                backgroundColor: Self.background,
                icon: Self.readyIcon,
                title: ShieldConfiguration.Label(text: String(localized: "Your puzzle is ready"), color: Self.textPrimary),
                subtitle: ShieldConfiguration.Label(
                    text: String(localized: "Tap the \(Brand.appName) notification, or open \(Brand.appName) from your Home Screen. \(appName) opens as soon as you solve it."),
                    color: Self.textSecondary),
                primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Got it"), color: .white),
                primaryButtonBackgroundColor: Self.brand
            )
        }
        let state = SharedStore.lockState
        let n = max(1, state.puzzlesPerUnlock)
        let duration = itemKeys.first.map { state.duration(for: $0) } ?? state.defaultDuration
        let puzzles = n == 1 ? String(localized: "1 quick puzzle") : String(localized: "\(n) quick puzzles")
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: Self.background,
            icon: Self.lockedIcon,
            title: ShieldConfiguration.Label(text: String(localized: "\(appName) is locked"), color: Self.textPrimary),
            subtitle: ShieldConfiguration.Label(
                text: String(localized: "Solve \(puzzles) in \(Brand.appName) to use it for \(duration.sentenceLabel)."),
                color: Self.textSecondary),
            primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Solve to unlock"), color: .white),
            primaryButtonBackgroundColor: Self.brand,
            secondaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Not now"), color: Self.textSecondary)
        )
    }

    // Lockie himself on the block screen's own background (iOS draws the icon as a still image).
    /// "Instagram is locked": Lockie with his clipboard, checking you against your plan.
    private static let lockedIcon: UIImage? = UIImage(named: "shield_locked") ?? fallbackIcon
    /// "Your puzzle is ready": Lockie pointing up at the notification that just arrived.
    private static let readyIcon: UIImage? = UIImage(named: "shield_ready") ?? fallbackIcon

    /// The app icon artwork as a rounded tile, or a coral `lock.fill` if that's missing too.
    private static let fallbackIcon: UIImage? = {
        if let asset = UIImage(named: "shield_icon") {
            let size = CGSize(width: 180, height: 180)
            return UIGraphicsImageRenderer(size: size).image { _ in
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 40).addClip()
                asset.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        let config = UIImage.SymbolConfiguration(pointSize: 96, weight: .semibold)
        return UIImage(systemName: "lock.fill", withConfiguration: config)?
            .withTintColor(brand, renderingMode: .alwaysOriginal)
    }()
}
