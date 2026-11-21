import XCTest

/// Taps through the whole first-launch onboarding on a fresh install (Simulator, Screen Time mocked) and checks:
/// - "Which puzzles sound fun?" has the 4 games pre-selected and nothing to play,
/// - "Here's how it works" plays by itself and can be skipped,
/// - every screen is tap-only (the name question is skipped),
/// - the paywall ("Your plan is ready") comes right after "Turn On Locks" and can be closed,
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

        // Splash → Welcome
        tap(app.buttons["Get Started"], timeout: 8)

        // Which puzzles sound fun? (all 4 pre-selected)
        XCTAssertTrue(app.staticTexts["Which puzzles sound fun?"].waitForExistence(timeout: 5))
        for game in ["chess", "sudoku", "math", "word"] {
            let card = app.buttons["onboarding.game.\(game)"]
            XCTAssertTrue(card.exists, "\(game) card missing")
            XCTAssertTrue(card.isSelected, "\(game) should be pre-selected")
        }
        tap(app.buttons["onboarding.continue"])

        // Here's how it works: auto-plays; Skip at the top right.
        tap(app.buttons["onboarding.skip"], timeout: 5)

        // Name (optional): Skip.
        tap(app.buttons["Skip"], timeout: 5)

        // Single-choice questions auto-advance; multi-select ones have Continue.
        tapFirstChoice()                       // age
        tapFirstChoice()                       // daily screen time
        tapFirstChoice(); tapContinue()        // time-wasters (multi)
        tapFirstChoice()                       // goal
        tapFirstChoice(); tapContinue()        // feelings (multi)
        tapFirstChoice()                       // when

        // Calculating → reality check → plan
        tap(app.buttons["Show my plan"], timeout: 10)
        tap(app.buttons["Use this plan"], timeout: 5)

        // Commitment: press and hold.
        let hold = app.buttons["Hold to commit"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        hold.press(forDuration: 2.0)
        tapContinue()

        // Rating screen
        tapContinue()

        // Screen Time intro → connect (mocked in the Simulator) → notifications explainer
        tapContinue()
        tapContinue()
        tapContinue(timeout: 8)
        allowSystemAlertIfShown()

        // Lock apps → Turn On Locks
        tapContinue(timeout: 8)
        tap(app.buttons["Turn On Locks"], timeout: 5)

        // Paywall right after Turn On Locks.
        let title = app.staticTexts["paywall.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(title.label.hasPrefix("Your plan is ready"))
        XCTAssertLessThan(Date().timeIntervalSince(start), 90, "Launch → paywall should take under 90 seconds")
        XCTAssertTrue(app.staticTexts["Auto-renews. Cancel anytime in Settings."].exists)
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)
        XCTAssertTrue(app.buttons["Terms of Use"].exists)
        XCTAssertTrue(app.buttons["Privacy Policy"].exists)

        // Close → exit offer (once, only if StoreKit prices loaded) → dashboard.
        tap(app.buttons["paywall.close"])
        if app.staticTexts["paywall.offer.title"].waitForExistence(timeout: 3) {
            XCTAssertTrue(app.staticTexts["Auto-renews. Cancel anytime in Settings."].exists)
            tap(app.buttons["paywall.close"])
        }
        let proCard = app.buttons["settings.proCard"]
        XCTAssertTrue(proCard.waitForExistence(timeout: 8))
        scrollUntilHittable(proCard)
        // Nothing was paid: all 5 free unlocks are still there.
        let freeUnlocks = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "5 of 5 free unlocks left")).firstMatch
        XCTAssertTrue(freeUnlocks.exists)

        // The exit offer shows only once: reopening the paywall and closing it goes straight back.
        tap(proCard)
        XCTAssertTrue(app.staticTexts["paywall.title"].waitForExistence(timeout: 5))
        tap(app.buttons["paywall.close"])
        XCTAssertFalse(app.staticTexts["paywall.offer.title"].waitForExistence(timeout: 2))
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
