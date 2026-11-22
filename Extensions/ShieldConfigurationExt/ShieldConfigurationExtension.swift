import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the custom block screen for shielded apps, categories and websites (all three use the same
/// `makeConfiguration`, so they always look identical).
///
/// Light and dark each get their own on-brand palette (warm cream, or deep dark with an orange tint)
/// over a thin system material. Text contrast on the background (WCAG 2.1):
/// - light: title #18181C ≈ 17:1, subtitle #3D2C28 ≈ 12:1, "Not now" #6B4A43 ≈ 7:1;
/// - dark: title white ≈ 18:1, subtitle white 85% ≈ 12:1, "Not now" white 65% ≈ 7:1;
/// - button: white on #D83A18 ≈ 4.6:1 (AA for normal text; the brand coral #FF5A36 is only 3.2:1).
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private struct Palette {
        let blur: UIBlurEffect.Style
        let background: UIColor
        let title: UIColor
        let subtitle: UIColor
        let secondary: UIColor
    }

    private static let light = Palette(
        blur: .systemUltraThinMaterialLight,
        background: UIColor(red: 0xFF / 255, green: 0xF4 / 255, blue: 0xEE / 255, alpha: 0.94),
        title: UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1),
        subtitle: UIColor(red: 0x3D / 255, green: 0x2C / 255, blue: 0x28 / 255, alpha: 1),
        secondary: UIColor(red: 0x6B / 255, green: 0x4A / 255, blue: 0x43 / 255, alpha: 1))

    private static let dark = Palette(
        blur: .systemUltraThinMaterialDark,
        background: UIColor(red: 0x1E / 255, green: 0x14 / 255, blue: 0x11 / 255, alpha: 0.94),
        title: .white,
        subtitle: UIColor.white.withAlphaComponent(0.85),
        secondary: UIColor.white.withAlphaComponent(0.65))

    /// Brand orange, deepened just enough for white text to pass WCAG AA.
    private static let button = UIColor(red: 0xD8 / 255, green: 0x3A / 255, blue: 0x18 / 255, alpha: 1)

    private var palette: Palette {
        UITraitCollection.current.userInterfaceStyle == .dark ? Self.dark : Self.light
    }

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
        let key = TokenKey.key(token)
        SharedStore.rememberName(application.localizedDisplayName, forKey: key)
        // So that, once unlocked, Lockie can open this app straight away.
        SharedStore.rememberBundleID(application.bundleIdentifier, forKey: key)
    }

    /// Two states:
    /// - Locked: "Instagram is locked 🔒" + what it takes, [Solve to unlock] / [Not now].
    /// - Puzzle ready (after Solve to unlock; the shield is redrawn after `.defer`): where the puzzle is,
    ///   [Got it]. If notifications are off, it says to open Lockie, so nobody is left waiting for a
    ///   notification that will never come.
    private func makeConfiguration(name: String?, keys: [String?]) -> ShieldConfiguration {
        let p = palette
        let appName = name ?? String(localized: "This app")
        let itemKeys = keys.compactMap { $0 }
        let notificationsOff = SharedStore.notificationsAllowed == false
        if let pending = SharedStore.pendingUnlock, itemKeys.contains(pending.itemKey),
           Date().timeIntervalSince(pending.createdAt) < Brand.shieldReadyWindow {
            let subtitle = notificationsOff
                ? String(localized: "Open \(Brand.appName) to solve your puzzle. \(appName) unlocks as soon as you solve it.")
                : String(localized: "Tap the \(Brand.appName) notification, or open \(Brand.appName). \(appName) unlocks as soon as you solve it.")
            return ShieldConfiguration(
                backgroundBlurStyle: p.blur,
                backgroundColor: p.background,
                icon: Self.readyIcon,
                title: ShieldConfiguration.Label(text: String(localized: "Your puzzle is ready 🧩"), color: p.title),
                subtitle: ShieldConfiguration.Label(text: subtitle, color: p.subtitle),
                primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Got it"), color: .white),
                primaryButtonBackgroundColor: Self.button
            )
        }
        let state = SharedStore.lockState
        let n = max(1, state.puzzlesPerUnlock)
        let duration = itemKeys.first.map { state.duration(for: $0) } ?? state.defaultDuration
        let subtitle: String
        if case .forToday = duration {
            subtitle = n == 1 ? String(localized: "Solve 1 quick puzzle to use it for the rest of today")
                              : String(localized: "Solve \(n) quick puzzles to use it for the rest of today")
        } else {
            subtitle = n == 1 ? String(localized: "Solve 1 quick puzzle to earn \(duration.sentenceLabel)")
                              : String(localized: "Solve \(n) quick puzzles to earn \(duration.sentenceLabel)")
        }
        return ShieldConfiguration(
            backgroundBlurStyle: p.blur,
            backgroundColor: p.background,
            icon: Self.lockedIcon,
            title: ShieldConfiguration.Label(text: String(localized: "\(appName) is locked 🔒"), color: p.title),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: p.subtitle),
            primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Solve to unlock"), color: .white),
            primaryButtonBackgroundColor: Self.button,
            secondaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Not now"), color: p.secondary)
        )
    }

    // Lockie himself on the block screen's own background (iOS draws the icon as a still image).
    /// "Instagram is locked": Lockie with his clipboard, checking you against your plan.
    private static let lockedIcon: UIImage? = UIImage(named: "shield_locked") ?? fallbackIcon
    /// "Your puzzle is ready": Lockie pointing up at the notification that just arrived.
    private static let readyIcon: UIImage? = UIImage(named: "shield_ready") ?? fallbackIcon

    /// The app icon artwork as a rounded tile, or a coral `lock.fill` if that's missing too.
    private static let fallbackIcon: UIImage? = {
        let brand = UIColor(red: 0xFF / 255, green: 0x5A / 255, blue: 0x36 / 255, alpha: 1)
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
