import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the custom block screen for shielded apps, categories and websites.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let brand = UIColor(red: 0xFF / 255, green: 0x5A / 255, blue: 0x36 / 255, alpha: 1)
    private static let textPrimary = UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1)
    private static let textSecondary = UIColor(red: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        remember(application)
        return makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        remember(application)
        return makeConfiguration(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        if let token = webDomain.token { SharedStore.rememberName(webDomain.domain, forKey: TokenKey.key(token)) }
        return makeConfiguration(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        if let token = webDomain.token { SharedStore.rememberName(webDomain.domain, forKey: TokenKey.key(token)) }
        return makeConfiguration(name: webDomain.domain ?? category.localizedDisplayName)
    }

    private func remember(_ application: Application) {
        guard let token = application.token else { return }
        SharedStore.rememberName(application.localizedDisplayName, forKey: TokenKey.key(token))
    }

    private func makeConfiguration(name: String?) -> ShieldConfiguration {
        let appName = name ?? "This app"
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .white,
            icon: Self.shieldIcon,
            title: ShieldConfiguration.Label(text: "Solve a puzzle to unlock the app", color: Self.textPrimary),
            subtitle: ShieldConfiguration.Label(text: "\(appName) is locked by \(Brand.appName).\nTap START PUZZLE, then open \(Brand.appName).", color: Self.textSecondary),
            primaryButtonLabel: ShieldConfiguration.Label(text: "START PUZZLE", color: .white),
            primaryButtonBackgroundColor: Self.brand,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "NOT NOW", color: Self.textSecondary)
        )
    }

    /// Our puzzle-padlock artwork (`shield_icon`, copied from the app icon by Scripts/import_art.py),
    /// or a coral `lock.fill` if it's missing.
    private static let shieldIcon: UIImage? = {
        if let asset = UIImage(named: "shield_icon") {
            // Rounded like an app icon.
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
