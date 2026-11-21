# App Review notes (paste into App Store Connect → App Review Information → Notes)

QuizLock helps people block their own distracting apps. It uses Apple's Screen Time API with
**FamilyControls individual authorization** (`AuthorizationCenter.requestAuthorization(for: .individual)`),
so the person using the iPhone chooses which of *their own* apps to block. It is not a parental-control or
monitoring app. To temporarily unlock a blocked app, the user solves a short puzzle (chess, Sudoku, math
or a 5-letter word game).

**No login is needed and there are no accounts.** Everything runs on the device; progress (streaks,
stats, settings) syncs through the user's own iCloud key-value storage. The subscription is tied to the Apple ID
(Restore Purchases). The first 5 unlocks are free, so you can test the full flow without paying, and Screen Time
setup and app use are never blocked behind payment before those 5 free unlocks are used.

## How to test (about 3 minutes)

1. Launch QuizLock and go through onboarding (tap-only; typing your name is optional and can be skipped):
   tap **Get Started**, keep the 4 puzzles selected on **Which puzzles sound fun?** and tap **Continue**.
   **Here's how it works** plays by itself (or tap **Skip**). Answer the short questions.
2. On **Connect QuizLock to Screen Time**, tap **Continue** and allow access in Apple's system sheet.
   Then tap **Continue** on the notifications screen and allow notifications.
3. On **Lock your apps.**, tap **Add Apps to Lock** and choose any app (for example Safari or News), then
   tap **Done** and **Continue**.
4. Choose an unlock time (for example **5 minutes**) and tap **Turn On Locks**. The QuizLock Pro paywall
   appears; it's optional. Close it with the **×** at the top right. A discount screen appears (only the first time);
   close it with the **×** too. You land on the dashboard with 5 free unlocks.
5. Go to the Home Screen and open the app you chose. QuizLock's block screen appears.
6. Tap **START PUZZLE**. Tap the "Tap to start your puzzle 🧩" notification, or open QuizLock. The puzzle
   opens.
7. Solve the puzzle. The app is unlocked for the time you chose, and it locks again automatically when
   the time is up.

If you decline Screen Time access or notifications, the app keeps working and explains how to turn them
on later (Settings tab).

Optional features you may see:
- **Lock schedule** (Settings → Manage Apps to Lock → Lock schedule): locks apply only during chosen hours.
- **Strict mode** (Settings): for 1/4/24 hours, turning locks off requires solving 3 hard puzzles.
- **Emergency unlock** (link on the puzzle screen): 1 minute without a puzzle, 3 per week.
- **Reminders** (Settings): opt-in local notifications, at most one per day.
- **Settings → Data**: explains that there are no accounts, and **Reset all data** deletes the locks, settings,
  stats and streaks from the device and iCloud (the subscription isn't affected) and returns to onboarding.

## In-app purchases (auto-renewable subscriptions)

Subscription group **QuizLock Pro**:

- `com.dinismagina.quizlock.pro.yearly`: 1 year, with a **7-day free trial** (introductory offer, new subscribers).
  Pre-selected on the paywall.
- `com.dinismagina.quizlock.pro.monthly`: 1 month, no trial.
- `com.dinismagina.quizlock.pro.yearly.offer`: 1 year at a lower price, no trial. Shown only once, on the
  discount screen that appears after the main paywall is closed.

Any active subscription in the group unlocks QuizLock Pro (unlimited puzzle-earned unlocks and standalone puzzle
practice). Every paywall screen shows the price and billing period, the amount billed after the trial, "Auto-renews.
Cancel anytime in Settings.", **Restore Purchases**, **Terms of Use**, **Privacy Policy** and a visible close button.
Prices, periods and the trial length are read from StoreKit. Restore Purchases is also in Settings → Support, and
subscribers see **Manage subscription** in Settings.

**Testing purchases:** sign in with a **Sandbox Apple Account** (Settings → Developer → Sandbox Apple Account on
the device, or when the purchase sheet asks) and buy any plan; no real money is charged and sandbox renewals are
accelerated. To see the paywall again after closing it: Settings tab → **QuizLock Pro** card. To reach the
"You've used your 5 free unlocks" screen, earn 5 unlocks (one solved puzzle each by default).

## Privacy

- No accounts, analytics, advertising or tracking.
- Progress sync uses the user's own iCloud key-value storage (NSUbiquitousKeyValueStore); the developer has no
  access to it. Screen Time selections are never synced.
- Screen Time data is only accessed through Apple's on-device APIs and never leaves the device; the
  "Today" screen-time card is rendered by Apple's DeviceActivityReport extension on-device.
- Privacy Policy: https://nis7777.github.io/QUIZLOCK/privacy.html
- Terms of Use: https://nis7777.github.io/QUIZLOCK/terms.html

Chess puzzles come from the Lichess puzzle database (CC0).
