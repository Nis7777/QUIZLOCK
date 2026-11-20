import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the custom block screen for shielded apps, categories and websites.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let brandRed = UIColor(red: 0xD3 / 255, green: 0x25 / 255, blue: 0x1E / 255, alpha: 1)
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
            icon: Self.keyIcon,
            title: ShieldConfiguration.Label(text: "Solve a puzzle to unlock the app", color: Self.textPrimary),
            subtitle: ShieldConfiguration.Label(text: "\(appName) is locked by \(Brand.appName)", color: Self.textSecondary),
            primaryButtonLabel: ShieldConfiguration.Label(text: "START PUZZLE", color: .white),
            primaryButtonBackgroundColor: Self.brandRed,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "NOT NOW", color: Self.textSecondary)
        )
    }

    /// A red circle with a white key. Uses the `shield_key` asset if one is bundled.
    private static let keyIcon: UIImage? = {
        if let asset = UIImage(named: "shield_key") { return asset }
        let size = CGSize(width: 144, height: 144)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            brandRed.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .bold)
            if let key = UIImage(systemName: "key.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let rect = CGRect(x: (size.width - key.size.width) / 2, y: (size.height - key.size.height) / 2,
                                  width: key.size.width, height: key.size.height)
                key.draw(in: rect)
            }
        }
    }()
}
