# QuizLock

**Get smarter before scrolling.** QuizLock blocks the apps you choose with Apple's Screen Time API. To unlock one for a while, you solve a puzzle: **Chess** (mate-in-1/2 from Lichess), **Sudoku**, **Math** or **Word** (a 5-letter word game).

`reference/` has 40 screenshots of the app that inspired this one. They're for flow and structure only; our app has its own coral brand.

Swift + SwiftUI, iOS 17+, iPhone only, portrait. No third-party packages.

## Project layout

| Path | What's there |
|---|---|
| `project.yml` | XcodeGen spec. **The `.xcodeproj` is generated from it.** |
| `App/` | The main app: `Design/` (colours, components), `Onboarding/` (S01–S11), `Main/` (tabs and settings screens), `Puzzles/` (game views and unlock flow), `Paywall/`, `Services/` (Screen Time, StoreKit, rounds), `Assets.xcassets` |
| `Shared/` | Compiled into every target. `Brand.swift` holds every brand/config value. `Engine/` holds the pure-Swift game engines; `ScreenTime/` holds models, the App Group store and the shield logic |
| `Extensions/` | `ShieldConfigurationExt` (block screen), `ShieldActionExt` (START PUZZLE / NOT NOW), `DeviceActivityMonitorExt` (re-locks when an unlock ends) |
| `Resources/` | `wordle_allowed.txt`, `wordle_answers.txt`, `chess_puzzles.json` (bundled with the app) |
| `Tests/` | Unit tests for the 4 engines |
| `Scripts/` | `build_chess_puzzles.py`, `import_art.py`, `test_engines_linux.sh` |
| `Products.storekit` | Local StoreKit config with both lifetime products (set on the Run scheme) |

## Build and run

1. Install XcodeGen once, then generate the project. Re-run it whenever `project.yml` changes or you add or remove files.
   ```bash
   brew install xcodegen
   ```
   ```bash
   xcodegen generate
   ```
2. Optional: add your art to `ArtSource/` (see `ArtSource/PUT_IMAGES_HERE.md`), then import it into the asset catalog. Missing images show a grey placeholder. Until you add `AppIcon.png`, the app uses a generated placeholder icon.
   ```bash
   python3 Scripts/import_art.py
   ```
3. Open `QuizLock.xcodeproj` and pick the **App** scheme.
4. **Simulator:** press ▶. FamilyControls doesn't work in the Simulator, so the app runs with a mock instead. Authorization always succeeds, the app picker shows fake apps, and **Settings → Simulator tools → Simulate START PUZZLE** opens the real unlock flow. You can click through every screen and play every game.
5. Tests: **⌘U**, or:
   ```bash
   xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
   ```
   The engine tests also run without Xcode (macOS or Linux):
   ```bash
   Scripts/test_engines_linux.sh
   ```

## Running on a physical iPhone (needed for real blocking)

1. **Signing:** in Xcode, select each of the 4 targets (`App`, `ShieldConfigurationExt`, `ShieldActionExt`, `DeviceActivityMonitorExt`). Under *Signing & Capabilities*, set your **Team**. To make it stick across `xcodegen generate`, put your Team ID in `DEVELOPMENT_TEAM` in `project.yml`.
2. **App Group:** all 4 targets use `group.com.dinismagina.quizlock`. With automatic signing, Xcode registers it for you. If it doesn't, create it under Certificates, Identifiers & Profiles → App Groups and enable it on all 4 App IDs.
3. **Family Controls:** the `com.apple.developer.family-controls` entitlement works in development builds on your own devices. Distributing through TestFlight or the App Store needs Apple's **Family Controls (Distribution)** approval, which you request at developer.apple.com/contact/request/family-controls-distribution for **each** of the 4 bundle IDs:
   - `com.dinismagina.quizlock`
   - `com.dinismagina.quizlock.ShieldConfiguration`
   - `com.dinismagina.quizlock.ShieldAction`
   - `com.dinismagina.quizlock.DeviceActivityMonitor`
4. Run on the device and allow Screen Time access (Face ID or passcode). Pick apps, then open one: the QuizLock shield appears. Tap **START PUZZLE**, then tap the notification to solve your puzzle.

## How unlocking works

1. The shield's **START PUZZLE** writes `pendingUnlock` to the App Group and posts a local notification. A shield extension can't open its host app, so the notification is how you get there; it carries the deep link `quizlock://unlock`.
2. The app opens the unlock flow. Progress, including a half-finished puzzle, is saved if you leave.
3. On success, the app removes that app from the `main` `ManagedSettingsStore` shield. For apps blocked through a category, it uses `.specific(categories, except: [app])` instead. It then schedules a `DeviceActivity` interval `unlock.<id>`. Intervals must be at least 15 minutes, so shorter unlocks start in the past.
4. `DeviceActivityMonitorExt.intervalDidEnd` puts the app back under the shield. Every app launch and foreground also sweeps for expired unlocks as a safety net.

## Chess puzzles

`Resources/chess_puzzles.json` (900 puzzles, 300 per difficulty) is generated from the Lichess puzzle database (CC0). To rebuild it:

```bash
python3 -m venv .venv && .venv/bin/pip install zstandard chess
```
```bash
.venv/bin/python Scripts/build_chess_puzzles.py
```

The raw download is git-ignored.

Credits: Chess puzzles from the Lichess puzzle database (CC0).
