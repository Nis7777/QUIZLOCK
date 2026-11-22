# Lockie v2: App Store compliance, longer onboarding, retention

Work through the parts below in order. Keep the existing design system (coral #FF5A36, our 3D art, the floating tab bar). Every new screen must look like it belongs to the current app. Commit after each part with a clear message, and push.

---

## PART A: App Store compliance (do this first)

1. **Remove features that don't work.** Apple rejects apps with non-functional settings (Guideline 2.1). The "Share app analytics" and "Share ad measurement" toggles do nothing because there's no SDK, so remove both sections, along with the "Manage Apple tracking permission" link. Don't request App Tracking Transparency anywhere, and make sure there's no `NSUserTrackingUsageDescription`.
2. **Privacy manifest.** Add `PrivacyInfo.xcprivacy` to the app and to every extension:
   - Declare the UserDefaults required-reason API: CA92.1 for the app's own data, and 1C8F.1 for the App Group suite.
   - `NSPrivacyTracking = false`, no tracking domains, collected data types empty.
3. **No third-party trademarks in our UI.** In the onboarding phone mockups, replace "Instagram" with a generic "Social" label and generic icons, and change "Tap Instagram at the top left" to "Tap the app at the top left". The real app names shown via `Label(token)` are fine.
4. **Paywall:**
   - Screen A needs a visible close (×) button at the top right.
   - Show the price and billing period, "Auto-renews. Cancel anytime in Settings.", Restore Purchases, Terms of Use and Privacy Policy on **every** paywall screen.
   - The exit-offer screen must not claim a fake original price: the struck-through price is the real, purchasable yearly plan, and the % is computed from the two StoreKit prices. No timers, countdowns or fake scarcity.
   - If StoreKit products fail to load, show "Couldn't load prices. Try again" with a retry button. Never show placeholder prices.
5. **Permissions UX.** Before each system prompt, show our own explainer screen with a single Continue. Do this for Screen Time and for notifications (copy below). If the user denies, the app must still work and must explain how to enable the permission later.
6. **Settings additions:**
   - "Restore Purchases".
   - "Contact support" (mail).
   - "Rate Lockie" (opens `itms-apps://itunes.apple.com/app/idAPP_ID?action=write-review`, with APP_ID as a constant in Brand.swift).
   - App version and build at the bottom.
7. **Accessibility pass:**
   - Dynamic Type on all text, minimum 44pt tap targets, VoiceOver labels on every icon button and game cell.
   - Respect Reduce Motion: no auto-rotating starburst, and use simple fades for animations.
8. **Robustness:**
   - No force-unwraps on URLs, assets or StoreKit.
   - No crash when Screen Time authorization is revoked mid-session.
   - Works offline; everything is local.
9. **App Review notes.** Create `AppStore/review_notes.md` explaining:
   - The app uses the FamilyControls *individual* authorization to let users block their own distracting apps.
   - Step-by-step how a reviewer can test it: complete onboarding, pick any app, open it, see the shield, tap START PUZZLE, solve it, and the app unlocks.
   - No login is needed, and the 5 free unlocks let the reviewer test the full flow without paying.

---

## PART B: Longer, high-converting onboarding (personalised quiz flow)

Insert these screens **between** the current "Try your first puzzle" / "Enjoy your feed" part and "Take control of your screen time". Use the same visual style:
- A thin coral progress bar at the top that fills as the user advances (not dots).
- Big bold titles, white answer cards that turn coral-outlined with a check when selected.
- One question per screen.
- Auto-advance 0.3s after a single-choice tap.
- Haptics on every tap.

Store all answers in a `UserProfile` model (App Group, Codable). Use them later for personalisation.

1. **Name:** "What should we call you?" A text field with an optional Skip. Use the name in later titles ("Nice to meet you, Dinis").
2. **Age range:** Under 18 / 18–24 / 25–34 / 35–44 / 45+.
3. **Daily screen time:** "How much time do you spend on your phone each day?" 1–2h / 3–4h / 5–6h / 7h+ / "I don't know". If they pick "I don't know", show a hint: "Check Settings → Screen Time". Optionally, in Part C, read the real value from the DeviceActivityReport.
4. **Biggest time-waster:** a multi-select grid of generic categories with SF Symbols: Short videos, Social media, Games, News, Messaging, Shopping, YouTube-style videos, Other. Use a Continue button.
5. **Main goal:** Focus on studies or work / Sleep better / Be more present / Learn something every day / Break the doom-scrolling habit.
6. **How scrolling makes you feel:** multi-select: Drained, Anxious, Bored, Guilty, Fine actually.
7. **When it happens most:** Morning in bed / At work or class / Evenings / Late at night.
8. **Calculating screen** (2.5s, animated): a circular coral progress ring with the steps "Analysing your answers", "Calculating your screen time", "Building your plan", each ticking off.
9. **The reality check:**
   - Big number: "You're on track to spend **X years** of your life on your phone."
   - Compute X = (dailyHours / 24) × (80 − midpoint of the age range), rounded to 1 decimal. Use midpoints 1.5 / 3.5 / 5.5 / 7.5 hours for the screen-time ranges, and 4h for "I don't know".
   - Show a simple bar comparing that number with "with Lockie", calculated as 50% less, plus a small footnote: "Estimate based on your answers."
10. **Your plan:** a personalised summary card:
    - The name.
    - The goal.
    - The suggested apps to lock (from the categories they picked).
    - The suggested default unlock time (15 min; 5 min if they picked "Break the doom-scrolling habit").
    - The suggested puzzle mix (more Math and Word if their goal is learning).
    - Pre-fill these choices in the later setup screens.
11. **Commitment:** "Make a promise to yourself", showing the goal in their words. A large coral circle button labelled "Hold to commit": the user holds it for 1.5s while a ring fills, with continuous haptics, then confetti.
12. **Rating request:** "Help us grow" with a simple screen that has the mascot and a "Continue" button. On tap, call `SKStoreReviewController`/`requestReview` once. **Never** gate anything on rating, never ask for 5 stars, and never show fake reviews or testimonials.

Then continue with the existing flow: Take control → Connect Screen Time (permission explainer) → Lock your apps → Choose your reward → **Notifications explainer** ("Get a gentle nudge when it's time to focus. We'll never spam you.", then the system prompt) → Paywall → Dashboard.

Remember the onboarding position, so killing the app mid-onboarding resumes where the user left off.

---

## PART C: Features that make it a winner (retention)

1. **Real Screen Time stats (on-device):**
   - Add a 5th target, a `DeviceActivityReportExtension`, that shows today's total screen time and the top locked apps' usage in a "Today" card at the top of the Settings/dashboard tab.
   - The data never leaves the device. This is Apple's design; mention it in the UI.
2. **Streaks and stats:**
   - Track the daily streak (consecutive days with at least one puzzle solved or zero unlocks).
   - Track puzzles solved per game, unlocks earned, unlocks *skipped* (opened the shield and tapped NOT NOW), and estimated time saved (skipped unlocks × the default unlock time).
   - Add a **Stats** screen (reachable from the dashboard) with a streak flame, weekly bar chart (Swift Charts, coral bars) and per-game totals.
   - Celebrate milestones (3, 7, 30 days) with a full-screen mascot + confetti moment.
3. **Widgets (WidgetKit):**
   - Small home-screen widget: streak + "time saved today".
   - Lock-screen accessory widget: streak number with a puzzle-piece symbol.
   - Read the data from the App Group.
4. **Lock schedules:** in Manage Apps, add "Lock schedule": Always (default), or chosen hours and days (e.g. 9:00–17:00 weekdays), using `DeviceActivitySchedule` + the monitor extension.
5. **Strict mode (optional toggle):**
   - The user can't disable locks or remove apps for the next 1/4/24 hours without solving 3 hard puzzles.
   - Shows a coral "Strict mode on until 18:00" banner.
6. **Daily puzzle:** one featured puzzle per day on the Puzzles tab ("Today's puzzle"). Solving it keeps the streak alive and has its own small celebration.
7. **Difficulty progression:** after 5 quick solves in a row in a game, offer "Ready for Medium?". After repeated fails, step the difficulty back down automatically.
8. **Emergency unlock:** a small "Emergency unlock" link on the unlock screen. It grants 1 minute without a puzzle, limited to 3 per week, and counts against the streak.
9. **Notifications (local only, opt-in):**
   - An evening streak reminder if no puzzle was solved today.
   - A weekly summary every Sunday ("You saved 2h 40m this week 🧩").
   - Max 1 per day, and each can be toggled in Settings.

---

## PART D: Polish

- App-wide confetti + haptic success moments (solve, unlock, streak).
- Empty states with the mascot (no apps locked, no stats yet).
- A launch screen matching the splash (peach background + wordmark), so there's no white flash.
- Make sure nothing overlaps on iPhone SE (small) and iPhone 16 Pro Max (large). Check both in previews.
- Dark theme check on every new screen.

---

## PART E: App Store submission package (generate files in `AppStore/`)

1. `metadata.md`:
   - App name (max 30 chars), subtitle (30), promotional text (170), description (4000) and keywords (100, comma-separated, no spaces after the commas, no competitor names).
   - Write it for "screen time blocker / app blocker / focus / brain training".
2. `privacy_labels.md`: what to answer in App Store Connect's App Privacy questionnaire. The expected answer is "Data Not Collected", but say what changes if the feedback email counts.
3. `age_rating.md`: the suggested questionnaire answers.
4. **Screenshots:**
   - Write an XCUITest (`ScreenshotTests`) that launches with a `-demoData` flag (fake stats, a 12-day streak, sample locked apps in simulator mock mode).
   - It captures 6 screens: Puzzles tab, Word game mid-play, Chess puzzle, Sudoku, Stats/streak, and the reality-check onboarding screen.
   - Save them as PNGs into `AppStore/screenshots/`, sized for the 6.9" display (1320×2868).
   - Then write `AppStore/screenshot_captions.md` with a short punchy caption for each (e.g. "Solve a puzzle to unlock your apps").
5. `review_notes.md` (from Part A).
6. `CHECKLIST.md`: the manual steps for the App Store Connect account holder:
   - Request the Family Controls (Distribution) entitlement for the app and **every** extension bundle ID.
   - Register the bundle IDs and the App Group.
   - Create the two in-app purchases with the exact product IDs from Brand.swift, plus their review screenshots.
   - Fill in the privacy labels, age rating, support URL (the GitHub Pages index) and privacy URL.
   - Upload via Xcode Archive, then use TestFlight first.

When everything is done, give me a short summary: what's new, what I must test on a real iPhone, and anything you couldn't do.
