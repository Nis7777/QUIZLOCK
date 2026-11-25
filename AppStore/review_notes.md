# App Review notes (paste into App Store Connect → App Review Information → Notes)

Lockie helps people block their own distracting apps. It uses Apple's Screen Time API with
**FamilyControls individual authorization** (`AuthorizationCenter.requestAuthorization(for: .individual)`),
so the person using the iPhone chooses which of *their own* apps to block. It is not a parental-control or
monitoring app. To temporarily unlock a blocked app, the user solves a short puzzle (chess, Sudoku, math
or a 5-letter word game).

**No login is needed and there are no accounts.** Everything runs on the device; progress (streaks,
stats, settings) syncs through the user's own iCloud key-value storage. The subscription is tied to the Apple ID
(Restore Purchases). Lockie requires a subscription. Onboarding and Screen Time setup are free, then the
Lockie Pro paywall appears (the yearly plan has a 7-day free trial). **No app is ever blocked without an active
subscription:** the locks only take effect once Lockie Pro or its free trial starts, and they are removed
automatically if it ends, so apps are never held locked to push a purchase. Please subscribe with a Sandbox
account to test.

## How to test (about 3 minutes)

1. Launch Lockie and go through onboarding (tap-only; typing your name is optional and can be skipped):
   tap **Get Started**, keep the 4 puzzles selected on **Which puzzles sound fun?** and tap **Continue**.
   **Here's how it works** plays by itself (or tap **Skip**). Answer the short questions.
2. On **Connect Lockie to Screen Time**, tap **Continue** and allow access in Apple's system sheet.
   Then tap **Continue** on the notifications screen and allow notifications.
3. On **Lock your apps.**, tap **Add Apps to Lock** and choose any app (for example Safari or News), then
   tap **Done** and **Continue**.
4. Choose an unlock time (for example **5 minutes**) and tap **Continue**. The Lockie Pro paywall
   appears. Start the free trial with your Sandbox account (no real money is charged). The locks turn on and you
   land on the dashboard.
5. Go to the Home Screen and open the app you chose. Lockie's block screen appears.
6. Tap **Solve to unlock**. The block screen changes to "Your puzzle is ready". Tap the "Your puzzle is ready 🧩" notification, or open Lockie. The puzzle
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

Subscription group **Lockie Pro**:

- `app.lockie.ios.pro.yearly`: 1 year, with a **7-day free trial** (introductory offer, new subscribers).
  Pre-selected on the paywall.
- `app.lockie.ios.pro.monthly`: 1 month, no trial.

Any active subscription in the group unlocks Lockie Pro (unlimited puzzle-earned unlocks and standalone puzzle
practice). Every paywall screen shows the price and billing period, the amount billed after the trial, "Auto-renews.
Cancel anytime in Settings.", **Restore Purchases**, **Terms of Use** and **Privacy Policy**. Because the app requires a subscription, the paywall
has no close button (there is no close button that doesn't close), and there are no discount pop-ups, countdowns
or "one-time" offers.
Prices, periods and the trial length are read from StoreKit. Restore Purchases is also in Settings → Support, and
subscribers see **Manage subscription** in Settings.

**Testing purchases:** sign in with a **Sandbox Apple Account** (Settings → Developer → Sandbox Apple Account on
the device, or when the purchase sheet asks) and buy any plan; no real money is charged and sandbox renewals are
accelerated.

## Privacy

- No accounts, analytics, advertising or tracking.
- Progress sync uses the user's own iCloud key-value storage (NSUbiquitousKeyValueStore); the developer has no
  access to it. Screen Time selections are never synced.
- Screen Time data is only accessed through Apple's on-device APIs and never leaves the device; the
  "Today" screen-time card is rendered by Apple's DeviceActivityReport extension on-device.
- Privacy Policy: https://nis7777.github.io/lockie/privacy.html
- Terms of Use: https://nis7777.github.io/lockie/terms.html

Chess puzzles come from the Lichess puzzle database (CC0).
