import XCTest

/// Captures the App Store screenshots. Run the "Screenshots" scheme on the **iPhone 16 Pro Max**
/// Simulator (6.9", 1320 × 2868 px). PNGs are written to AppStore/screenshots/<language>/
/// (that folder is the source of truth; the report attachments are only kept for failed runs).
final class ScreenshotTests: XCTestCase {
    private let screens: [(file: String, screen: String)] = [
        ("01-puzzles", "puzzles"),
        ("02-word", "word"),
        ("03-chess", "chess"),
        ("04-sudoku", "sudoku"),
        ("05-stats", "stats"),
        ("06-reality-check", "realityCheck"),
        ("07-pick-puzzles", "pickGames"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testScreenshotsEnglish() throws {
        try capture(language: "en", locale: "en_US")
    }

    @MainActor
    private func capture(language: String, locale: String) throws {
        let folder = Self.outputFolder.appendingPathComponent(language, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in screens {
            let app = XCUIApplication()
            app.launchArguments = ["-demoData", "-screen", item.screen,
                                   "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            // Let animations (board slides, chart, ring, counting numbers) settle.
            Thread.sleep(forTimeInterval: ["chess", "stats", "realityCheck"].contains(item.screen) ? 3.5 : 2.0)
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(language)-\(item.file)"
            add(attachment)
            let url = folder.appendingPathComponent("\(item.file).png")
            try shot.pngRepresentation.write(to: url)
            print("Saved \(url.path) (\(Int(shot.image.size.width * shot.image.scale))×\(Int(shot.image.size.height * shot.image.scale)))")
            app.terminate()
        }
    }

    /// <repo>/AppStore/screenshots (the Simulator can write to the Mac's file system).
    private static var outputFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AppStore/screenshots", isDirectory: true)
    }
}
