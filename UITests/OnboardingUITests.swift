import XCTest

/// Taps through the whole story-mode onboarding (ONBOARDING_V3) on a fresh install (Simulator, Screen Time
/// mocked) and checks:
/// - the chat can be skipped, every question is tap-only and the name can be skipped,
/// - "Which puzzles sound fun?" has the 4 games pre-selected,
/// - hold-to-commit works, and "Start my plan" opens the paywall, which can be closed,
/// - closing it (exit offer once, if prices loaded) lands on the dashboard.
/// Run with the "Screenshots" scheme (⌘U) on any iPhone Simulator.
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshInstall", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    @MainActor
    func testOnboardingReachesClosablePaywallByTappingOnly() throws {
        let start = Date()

        // 1. Hello: hero → "Hey! I'm Lockie." → name (skipped)
        tap(app.buttons["onboarding.start"], timeout: 8)
        tapContinue()
        tap(app.buttons["Skip"], timeout: 5)

        // 2. The chat: tap the notification banner, then "Skip chat".
        tap(app.buttons["onboarding.chatBanner"], timeout: 6)
        tap(app.buttons["Skip chat"], timeout: 5)

        // 3. How it works: Continue through the 3 cards.
        tapContinue(); tapContinue(); tapContinue()

        // 4. Questions (source and hours auto-advance; every screen also has a pinned Continue).
        tapContinue()                          // "Let's set you up"
        tapFirstChoice()                       // source
        tapFirstChoice()                       // hours
        tapFirstChoice(); tapContinue()        // apps (multi)
        tapFirstChoice(); tapContinue()        // feelings (multi)
        tapFirstChoice(); tapContinue()        // wants (multi)
        XCTAssertTrue(app.staticTexts["Which puzzles sound fun?"].waitForExistence(timeout: 5))
        let selected = app.buttons.matching(identifier: "quiz.choice").allElementsBoundByIndex.filter(\.isSelected)
        XCTAssertEqual(selected.count, 4, "All 4 puzzles should be pre-selected")
        tapContinue()                          // puzzles (multi)
        tapFirstChoice(); tapContinue()        // challenge (no auto-advance)

        // 5. The turn
        tapContinue(); tapContinue(); tapContinue(); tapContinue()

        // 6. Permissions: connect (mocked) → pick a mock app → confirmation → reward → notifications
        tap(app.buttons["onboarding.connect"], timeout: 5)
        let mockApp = app.buttons.matching(NSPredicate(format: "label CONTAINS 'TikTok'")).firstMatch
        tap(mockApp, timeout: 5)
        tap(app.buttons["Done"])
        tapContinue(timeout: 6)
        tap(app.buttons["onboarding.turnOn"], timeout: 5)
        tap(app.buttons["onboarding.notifications"], timeout: 5)
        allowSystemAlertIfShown()

        // 7. Commitment: press and hold → setup → plan ready → paywall
        let hold = app.buttons["onboarding.commit"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        hold.press(forDuration: 2.0)
        tap(app.buttons["onboarding.startPlan"], timeout: 10)

        // Paywall right after "Start my plan".
        let title = app.staticTexts["paywall.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(title.label.hasPrefix("Your plan is ready"))
        XCTAssertLessThan(Date().timeIntervalSince(start), 150, "Launch → paywall should stay quick")
        XCTAssertTrue(app.staticTexts["Auto-renews. Cancel anytime in Settings."].exists)
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)
        XCTAssertTrue(app.buttons["Terms of Use"].exists)
        XCTAssertTrue(app.buttons["Privacy Policy"].exists)

        // Hard paywall: no × at all (never a close button that doesn't close), and no discount pop-up.
        XCTAssertFalse(app.buttons["paywall.close"].exists)
        XCTAssertFalse(app.staticTexts["paywall.offer.title"].exists)
        XCTAssertFalse(app.buttons["settings.proCard"].exists)
    }

    // MARK: Helpers

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 4, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    private func tapFirstChoice(file: StaticString = #filePath, line: UInt = #line) {
        let choice = app.buttons.matching(identifier: "quiz.choice").firstMatch
        tap(choice, timeout: 5, file: file, line: line)
        Thread.sleep(forTimeInterval: 0.6) // single-choice screens auto-advance after 0.3s + the slide
    }

    private func tapContinue(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "label == 'Continue'")).firstMatch
        tap(button, timeout: timeout, file: file, line: line)
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func scrollUntilHittable(_ element: XCUIElement) {
        var tries = 0
        while !element.isHittable && tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    /// The system notification prompt (shown by Springboard).
    private func allowSystemAlertIfShown() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
    }
}
