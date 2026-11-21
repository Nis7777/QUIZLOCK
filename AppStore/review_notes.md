# App Review notes (paste into App Store Connect → App Review Information → Notes)

QuizLock helps people block their own distracting apps. It uses Apple's Screen Time API with
**FamilyControls individual authorization** (`AuthorizationCenter.requestAuthorization(for: .individual)`),
so the person using the iPhone chooses which of *their own* apps to block. It is not a parental-control or
monitoring app. To temporarily unlock a blocked app, the user solves a short puzzle (chess, Sudoku, math
or a 5-letter word game).

**No login is needed.** Everything runs on the device. The first 5 unlocks are free, so you can test the
full flow without paying.

## How to test (about 3 minutes)

1. Launch QuizLock and go through onboarding: tap **Get Started**, pick any game and solve the practice
   puzzle, then continue.
2. On **Connect QuizLock to Screen Time**, tap **Continue** and allow access in Apple's system sheet.
3. On **Lock your apps.**, tap **Add Apps to Lock** and choose any app (for example Safari or News), then
   tap **Done** and **Continue**.
4. Choose an unlock time (for example **5 minutes**) and tap **Turn On Locks**. Allow notifications when
   asked. The paywall appears once; close it with the × at the top right.
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

## In-app purchases

- `com.dinismagina.quizlock.lifetime`: non-consumable, standard lifetime access.
- `com.dinismagina.quizlock.lifetime.discount`: non-consumable, launch-offer lifetime access.

Either one grants lifetime access (unlimited puzzle-earned unlocks and standalone puzzle practice).
There are no subscriptions. **Restore Purchases** is on both paywall screens and in Settings → Support.

## Privacy

- No accounts, analytics, advertising or tracking.
- Screen Time data is only accessed through Apple's on-device APIs and never leaves the device; the
  "Today" screen-time card is rendered by Apple's DeviceActivityReport extension on-device.
- Privacy Policy: https://nis7777.github.io/lockfeeddupe/privacy.html
- Terms of Use: https://nis7777.github.io/lockfeeddupe/terms.html

Chess puzzles come from the Lichess puzzle database (CC0).
