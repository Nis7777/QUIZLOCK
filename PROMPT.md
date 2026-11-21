You are building a native iOS app, ready for the App Store, in **Swift + SwiftUI**. It is a screen-time blocker: the user picks distracting apps, iOS blocks them using Apple's Screen Time API, and the user has to **solve a puzzle** to unlock them for a set time. There are 4 puzzle games: **Chess (mate puzzles), Sudoku, Math, and Word (a Wordle-style 5-letter word game)**. The screen flow and structure are **inspired by** an existing app (screenshots in `reference/`), but this app has its **own visual identity**: coral brand colour, a puzzle-padlock logo and a padlock mascot. Never copy the reference's logo, mascot, name, wordmark or exact art; follow the flow, information architecture and level of polish. Work autonomously. Make reasonable decisions without asking me, and stop only if something needs my Apple Developer account.

**Visual reference (inspiration only):** the folder `reference/` holds 40 screenshots of the app that inspired this one. Look at them to understand the flow, the layout ideas and the quality bar, then build **our own version** in our coral style. Don't reproduce their branding or artwork. Read `reference/README.md`. If this spec and a screenshot disagree, this spec wins.

## CONFIG (use these values everywhere and keep them in one `Brand.swift` file)

```
APP_NAME            = "QuizLock"                 // shown in UI wherever the spec says {APP_NAME}
APP_NAME_CAPS       = "QUIZLOCK"                 // small tracked label on puzzle screens
TAGLINE             = "Get smarter before scrolling"
BUNDLE_ID           = "com.dinismagina.quizlock"
APP_GROUP           = "group.com.dinismagina.quizlock"
SUPPORT_EMAIL       = "nismagina@gmail.com"
TERMS_URL           = "https://example.com/terms"
PRIVACY_URL         = "https://example.com/privacy"
IAP_PRO_YEARLY      = "com.dinismagina.quizlock.pro.yearly"         // $39.99/year, 7-day free trial (intro offer)
IAP_PRO_MONTHLY     = "com.dinismagina.quizlock.pro.monthly"        // $9.99/month, no trial
IAP_PRO_OFFER       = "com.dinismagina.quizlock.pro.yearly.offer"   // $29.99/year, exit offer only
// All three are auto-renewable subscriptions in the group "QuizLock Pro".
FREE_UNLOCKS        = 5
MIN_IOS             = 17.0
```

## 0. Project setup (do this first)

- Use **XcodeGen**: write a `project.yml` and generate the `.xcodeproj` with `xcodegen generate` (`brew install xcodegen` if it's missing). Don't hand-write a pbxproj.
- **4 targets**, all in the same App Group (`APP_GROUP`), all with the `com.apple.developer.family-controls` entitlement:
  1. `App`: the main SwiftUI app.
  2. `ShieldConfigurationExt`: a `ShieldConfigurationDataSource` that draws the custom block screen.
  3. `ShieldActionExt`: a `ShieldActionDelegate` that handles the shield buttons.
  4. `DeviceActivityMonitorExt`: a `DeviceActivityMonitor` that re-locks apps when an unlock window ends.
- Frameworks: FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity, StoreKit (StoreKit 2), UserNotifications.
- Add a **StoreKit Configuration file** (`Products.storekit`) with the 3 subscriptions (group "QuizLock Pro", 7-day free trial on yearly), and set it on the Run scheme so purchases work in Xcode without App Store Connect.
- Shared code (models, persistence, game engines, `ManagedSettingsStore` helpers) goes in a `Shared/` folder compiled into every target that needs it. Persist shared state as Codable JSON in the App Group `UserDefaults(suiteName:)`.
- Art: import every PNG from `ArtSource/` into `Assets.xcassets` using the file name as the asset name. `AppIcon.png` may not be exactly 1024×1024: resize it to 1024×1024 with `sips`, strip any alpha, and use it as the single-size App Icon. Also put a copy in the shield extension as `shield_icon`. If an image is missing, show a neutral rounded placeholder (a light grey fill with an SF Symbol). Never crash.
- Bundle the files in `Resources/` (`wordle_allowed.txt`, `wordle_answers.txt`, and `chess_puzzles.json`, which you'll generate in section 5) with the App target.
- Write a `README.md` with build-and-run steps, including signing, App Group and running on a physical device. Include a "Credits" line in the app's About section: "Chess puzzles from the Lichess puzzle database (CC0)."

## 1. Design system (our own identity)

- Colours:
  - `brand` **#FF5A36** coral (buttons, toggles, selected states, links, icons, the wordmark). Pressed/dark variant `brandDeep` #E4421F; for small text on white use `brandDeep` for contrast.
  - **Everywhere this spec says "red" or "pink", it means `brand` (coral) or `brandTint` (peach).** The only exception is error states (wrong answers, shakes, Sudoku conflicts), which use system red #FF3B30.
  - `bg` #F6F5F8 (every screen background)
  - `card` #FFFFFF
  - `textPrimary` #18181C
  - `textSecondary` ≈ #6E6E73
  - `correctGreenBg` #D3EFDA, with a green check (#34C759 family)
  - `darkCard` #13110F (dark preview cards)
  - `brandTint` = brand at 12–15% opacity (a soft peach) (icon tiles, "2 apps selected" pill, banner background)
  - Word game tiles: `wordGreen` #6AAA64, `wordYellow` #C9B458, `wordGrey` #787C7E
  - Chess board: light squares #E7E8C8, dark squares #65884E, last-move/destination highlight #F6F669 at 60%
- Type: SF Pro (system). Big titles are about 34–40pt **bold** with tight line spacing and centred. Section headers are about 17pt semibold in textSecondary. Rows are 17pt semibold title + 15pt textSecondary subtitle.
- The wordmark is the app name in SF Pro Rounded Black, in `brand`, with the small puzzle-padlock glyph (from `AppIcon` artwork, or a SwiftUI-drawn equivalent) before it. Use it left-aligned at the top of the tab screens and large and centred on the splash.
- Cards: white, corner radius 20–22, very soft shadow (black 4%, radius 12, y 4), 16pt inner padding, 16pt side margins.
- Primary button: full width, height 64, corner radius 18, brand, white 19pt **bold** text.
- Back button: 52pt white circle with a soft shadow and a black `chevron.left`, top left.
- Toggles: custom pill toggle. When on, a brand track with a white knob. When off, a light grey track.
- Radio rows: on the right, an empty grey ring or a filled brand circle with a white checkmark.
- Page dots: inactive is a 6pt grey dot, active is a 22×6 brand capsule. They animate between states.
- **Floating tab bar** (not the system TabView bar): a white capsule floating about 20pt above the bottom, with a soft shadow and 3 items:
  - **Settings**: a custom icon of two stacked toggle pills.
  - **Puzzles**: `puzzlepiece.fill`.
  - **Feedback**: two overlapping chat bubbles.
  - The selected item gets a light grey rounded-pill background with a brand icon and label. Unselected items are black.
- Haptics: light impact on taps, success notification haptic when a puzzle is solved, error haptic on a wrong answer or move.
- Support a **Dark theme** ("Dark · Black & coral": near-black background, white text, coral accents) chosen in Settings. Puzzle boards and tiles keep their own colours.

## 2. Onboarding flow (first launch only, in this order)

**S01 Splash**: bg colour. The wordmark is large and centred, TAGLINE sits under it in 20pt medium, and a small red activity spinner sits below. Hold for about 1.2s, then fade into S02.

**S02 Welcome carousel**: a swipeable pager with 4 preview cards. It auto-advances every ~3.5s. Each card plays a short self-solving animation. Under each card is the caption "Preview · Answers play automatically" in 13pt textSecondary. The header row of each card has a small icon + game name at the top left and a green check badge at the top right that pops in when the animation solves. The 4 cards are:
  1. **Math** (white card, `function` icon): "If 3x + 5 = 20, what is x?" in 30pt bold. Below is an answer field where "5" types in, then the field turns `correctGreenBg` with a check: "x = 5 ✓".
  2. **Word** (white card, `textformat.abc` icon): a 5×3 tile grid. The rows CRANE, SLANT and PLANT fill in one after another, with the tile **flip** animation revealing the colours. Compute the colours with the real scoring function against the answer PLANT. The last row is all green.
  3. **Sudoku** (darkCard, white text, `square.grid.3x3` icon): "Fill the last row" over a 9×9 board drawn in SwiftUI (cream cells, dark digits, thick box borders). The 4 empty cells in the bottom row fill in with red digits, then the row flashes green. Answer bar (dark green): "Row complete ✓".
  4. **Chess** (darkCard): "White to move. Mate in one." with an 8×8 board drawn in SwiftUI. The mating piece slides to its square, the square highlights yellow, and the answer bar reads e.g. "Rd8# · Checkmate ✓". Use the first easy mate-in-one from `chess_puzzles.json`.

  Under the pager: page dots, then 3 lines of centred text: "Lock your apps." (34 bold), "Solve a puzzle to unlock." (30 bold), "Scroll less." (36 bold, brand). Next is the primary button "Get Started". At the bottom, 14pt textSecondary: "By continuing, you agree to our **Terms of Service** and **Privacy Policy**". The two links are brand and open TERMS_URL and PRIVACY_URL in an in-app Safari sheet.

**S03 Try your first puzzle**: back button. Title "Try your first puzzle", subtitle "Pick a game. Just one quick round." Below, a 2×2 grid of tall white cards. Each card has a big red icon at the top left, a 22pt bold title at the bottom left and a grey subtitle:
  - Math: a red italic "f(x)" text icon; subtitle "Find the answer".
  - Word: a red "Abc" text icon; subtitle "Guess the word".
  - Sudoku: a red `square.grid.3x3.fill`; subtitle "Fill the grid".
  - Chess: a red checkerboard icon (a 4×4 red/white checker drawn in SwiftUI); subtitle "Mate in one".

  Tapping a card stores the game and goes to S04.

**S04 Here's how it works (animated, 3 beats, auto-plays)**: back button. Title "Here's how\n{APP_NAME} works". Below it is a **phone mockup** drawn in SwiftUI: a black rounded bezel, a Dynamic Island, a status bar reading "9:41", and a home indicator.
  - Beat 1: a home screen. The background is a soft lavender-to-peach gradient and shows today's date (e.g. "Thursday, September 17", using the real date). One row has 3 app icons: a generic "social" icon labelled "Instagram" with a tiny hourglass before the label, a Photos-style icon and a Camera-style icon. These are built from SF Symbols on coloured rounded squares. **Do not use real third-party logos.** Below are 2 rows of empty translucent icon tiles and a dock with Phone (green), Messages (green) and Safari (blue). Animate a tap on the social icon.
  - Beat 2: the phone screen turns white and shows the **shield preview**: a 72pt brand-coral circle with a white `lock.open.fill`, "Solve a puzzle to unlock the app" (bold, centred), a red rounded "START PUZZLE" button and a small grey "NOT NOW". Animate a tap on START PUZZLE.
  - Beat 3: the phone shows a scaled-down version of the game picked in S03 (same layout as S05). Caption under the phone: "Solve the puzzle to unlock the app" (22pt medium).

  Then the phone mockup **zooms and fades** into the full-screen S05.

**S05 Practice puzzle (full screen)**: this is the shared **puzzle screen chrome**, used again in the real unlock flow.
- Top: a small tracked label APP_NAME_CAPS in brand (12pt, letter-spacing 3). Under it the game name ("Math", "Word", "Sudoku", "Chess") in 17pt, with an × at the top right.
- A grey caps sub-label (e.g. "ALGEBRA", "5 LETTERS · 6 TRIES", "EASY", "MATE IN 1") and a green pill with a dot reading "Your turn".
- The game itself (section 5) fills the rest.
- "PRACTICE" in grey tracked caps at the bottom (onboarding/practice only).

The onboarding version of each game is deliberately easy:
- Math: one Easy question.
- Word: a common answer. If the user fails all 6 tries, reveal the word and continue anyway.
- Sudoku: a valid puzzle with only 4 empty cells.
- Chess: one easy mate-in-one.

On success go to S06.

**S06 You unlocked the app!**: back button. Title "You unlocked the app!" with a phone mockup underneath. At the top left of the mockup, a fake iOS breadcrumb reads "◀ Instagram". The centre has a 96pt pink circle with a red `lock.open.fill`. Below it: "Tap Instagram at the top left\nto return to your app." Auto-advance after 2s, or on tap.

**S07 Enjoy your feed.**: Title "Enjoy your feed.", subtitle "You've earned it!" A phone mockup shows a grey wireframe social feed: an "Instagram" header with heart and paper-plane icons, 2 posts made of an avatar circle, grey lines and a grey image placeholder with a `photo` icon, plus action icons and a bottom tab row. Primary button "Continue".

**S08 Take control of your screen time**: a 2-step page indicator at the top (step 1 active). A soft pink arc/semicircle fills the bottom 60% of the background. Illustration built in SwiftUI: two 150pt rounded squares overlapping and tilted (−8° and +10°). The first is white with a coral circle containing a white `puzzlepiece.fill`. The second is brand coral with a white `hourglass`. Title "Take control of\nyour screen time". Body: "Choose apps to limit distracting scrolling. Solve a puzzle to unlock them temporarily." Small print: "{APP_NAME} does not collect your Screen Time usage." Button "Continue".

**S09 Connect to Screen Time**: step 2 active. Title "Connect {APP_NAME}\nto Screen Time". Body: "To block the apps you choose, {APP_NAME} needs Screen Time permission." Small print as on S08. A grey label "Permission preview", then a **fake iOS alert** card: "“{APP_NAME}” Would Like to Access Screen Time", then "Providing “{APP_NAME}” access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites." It has a grey "Continue" pill with a pulsing **red outline ring** and a blue "Don't Allow" pill. Under the card, image `mascot_pointing` (our padlock mascot, about 200pt tall), positioned so it points up at the Continue pill. Primary button "Continue". On tap, dim the screen, change the button to a spinner plus "Requesting Access…", and call `AuthorizationCenter.shared.requestAuthorization(for: .individual)`. Apple then shows its real system sheets. On success go to S10. On failure show an alert explaining how to enable it and offer to retry.

**S10 Lock your apps.**: back button. Title "Lock your apps." Subtitle: "Select the apps that distract you the most, the ones you open on autopilot." Below is a **how-to mock** drawn in SwiftUI (no screenshot): a grey rounded panel with a "Done" pill, a white row "✓ [icon] Instagram — Social", a search field containing "Instagram", and a drawn keyboard. Caption "Add apps → Search → Select → Done".
  - Empty state card: a dashed-square icon, "No locks yet", "Choose an app to get started."
  - Selected state: a white card listing each selected app with its **real icon and name via `Label(token)`**, the subtitle "Ready to lock" and a red check on the right.
  - An outlined white button "+ Add Apps to Lock" (brand text) opens the system `FamilyActivityPicker`, bound to a `FamilyActivitySelection`.
  - Red text: "You can add apps later in Settings." (switch to "You can update this later in Settings." once apps are selected).
  - Primary "Continue".

**S11 Choose your puzzle reward**: a 3-step indicator. A 100pt pink rounded square holding a red timer icon (`timer`). Title "Choose your\npuzzle reward". Subtitle "Choose how long your apps stay unlocked after you solve a puzzle." Small print: "Your first 5 app unlocks are free. After that, unlimited unlocks and standalone puzzle practice need QuizLock Pro, an optional subscription." A pink pill reads "■ 2 apps selected", with the real count of apps + categories. Radio cards: **5 minutes**, **15 minutes** (default), **For Today**, and **Custom** in brand with a `plus.circle` icon. Custom opens a sheet titled "Set unlock time" with Cancel and Save pills and a wheel picker for hours (0–23) and min (0–59), styled like the iOS timer picker. Below the cards: "You can change your puzzle reward later in Settings." and a red "Change apps" link back to S10. Primary button "Turn On Locks ✓". On tap, apply the shield (section 4), request notification permission, and go to S12.

**S12 Paywall (once, right after onboarding)**: see section 6. Closing it lands on the dashboard with the "You're all set" banner.

## 3. Main app (floating tab bar: Settings · Puzzles · Feedback)

### Settings tab (the dashboard)
Scrolling list on bg, top to bottom:
- The wordmark at the top left.
- A **"You're all set" banner** shown only until dismissed. It has a pink background, a red toggle-pills icon tile, the bold title "You're all set", the text "Use these switches anytime to pause or resume a lock." and a red "Got it" at the top right.
- Section "App locks":
  - A card with a red `lock.fill`, "Enable locks", the subtitle "All apps protected" (or "Locks paused" when off) and a pill toggle. This is the master switch.
  - A card with one row per locked app or category: the real icon and name via `Label(token)` and a pill toggle each. Off means that app is temporarily removed from the shield.
  - A card row with a red sliders icon, "Manage Apps to Lock", "Add, remove, and set unlock times" and a chevron. It opens the **Manage apps** screen.
- Section "Unlock rules", one card with 3 rows:
  - Red timer icon, "Unlock time", "Default time for each app", trailing value "15 minutes". Opens **Unlock time**.
  - A red list icon, "Puzzles per unlock", "Solved puzzles required", trailing "1". Opens the **Puzzles per unlock** sheet.
  - Red `shuffle`, "Unlock puzzles", subtitle listing the enabled game names ("Chess, Word"), trailing "2 selected". Opens the **Unlock puzzles** sheet.
  - Footer: "Your puzzles take turns in a shuffled order."
- Section "Appearance": two side-by-side selectable cards, each with a mini drawing of the UI. "Classic · Light & coral" (selected: red border and red check) and "Dark · Black & white". Footer: "Puzzle boards keep their original colors."
- A "QuizLock Pro" card. Not subscribed: "X of 5 free unlocks left · Start free trial" and a chevron that opens the paywall. Subscribed: "Active · renews {date}" plus "Manage subscription" (`AppStore.showManageSubscriptions`).
- Section "Analytics": a card with "Share app analytics" and an off toggle. Body: "Help improve {APP_NAME} with anonymous analytics, including purchases, changes to your selected puzzles, and puzzle starts/completions during app unlocks. App identities, Screen Time reports, unlock times and typed answers stay on-device. Optional; turn off anytime." Only store the setting. Don't add any analytics SDK; leave a `// TODO: analytics` hook.
- Section "Ad measurement": a card with "Share ad measurement" and an off toggle. Body: "Optionally share app opens and purchases to measure our ads. Protected apps, Screen Time activity and puzzle data are never included. Turning this off stops future events; it doesn't delete data already sent." Then a red link "Manage Apple tracking permission" that opens the app's page in Settings. Store the setting only.
- A footer card with the "Terms of Service" and "Privacy Policy" links, plus the Credits line.

### Manage apps (push screen, title "Manage apps")
- Text: "Choose your apps and how long each stays unlocked after a puzzle."
- A full-width red "+ Add Apps" button that opens `FamilyActivityPicker`.
- A card row: "Default unlock time" / "15 minutes" with a chevron, opening Unlock time.
- "Your apps · N", then: "Apps use the default time unless you choose a different one below."
- One card per app with:
  - Top row: `Label(token)` and a red "⊖ Remove" on the right.
  - Divider.
  - Bottom row: "Unlock time" with "Default · 15 minutes ›" (or the override value). Tapping it opens the per-app override.

### Unlock time (push screen; Done pill at the top right)
- A radio card with 5 minutes / 15 minutes / For Today / Custom ⊕ (Custom opens the same wheel sheet).
- Footer: "The default for apps without an override. Changes apply the next time you earn an unlock; current unlocks keep their remaining time."
- **Per-app variant**: the app's `Label(token)` at the top, then a first row "Use default / 15 minutes" (checked by default), then the same options. Footer: "This overrides the default for this app. Current unlocks keep their remaining time."

### Puzzles per unlock (bottom sheet, medium detent, title centred, red "Done" pill)
- Text: "Puzzles you need to solve to unlock any app. One math answer, one word, one Sudoku grid or one chess puzzle each counts as one."
- A white card with "1 puzzle" (22pt bold) and a segmented −/+ stepper on the right, limited to 1–10.
- Footer: "Choose 1–10. Progress is saved if you leave. Changes apply to the next unlock."

### Unlock puzzles (bottom sheet)
- "N enabled", then 4 rows: game icon + name + current difficulty in grey + pill toggle.
- Footer: "Your puzzles take turns in a shuffled order."
- A large grey rounded button "+ More options" in brand text, which switches to the Puzzles tab.
- At least one game must stay enabled. Block turning off the last one and show a short hint.
- Default enabled: all 4.

### Puzzles tab
- Wordmark at the top.
- "Unlock puzzles 4" (grey count) with a red "Manage" on the right.
- "Your puzzles take turns in a shuffled order."
- Removable pink chips for the enabled games, e.g. "Chess ×".
- "All puzzles", then 4 large game cards, one per game:
  - A 115pt square cover image with radius 14 (`game_chess`, `game_sudoku`, `game_math`, `game_word`), the title (22 semibold), the description (grey) and the meta line.
  - Divider.
  - "Use for unlocks" with a pill toggle and a red "Try ›".
  - Cards in use get a 1.5pt brand border.
  - Titles, descriptions and meta lines:
    - **Chess**: "Find the checkmate." / "Mate in 1–2 · {count} puzzles"
    - **Sudoku**: "Fill the 9×9 grid." / "Endless · Unique solutions"
    - **Math**: "Quick mental math." / "Endless · Type your answer"
    - **Word**: "Guess the 5-letter word." / "6 tries · Real words only"
- Tapping the card body opens **Puzzle detail**:
  - A full-width hero image (radius 20), the title (34 bold), the description and the meta line.
  - A **Difficulty** segmented control (Easy / Medium / Hard; default Easy). For Sudoku it is Quick 6×6 / Easy / Medium / Hard.
  - An expandable red "How to play ⌄" section with short rules.
  - A pinned bottom bar holding "Use for unlocks" with its toggle and "Try ›".
- **Try** (practice mode) is free for the onboarding demo only. Otherwise it needs QuizLock Pro and opens the paywall if the user doesn't have it.

### Feedback tab
- A centred nav title "Feedback".
- Large title "Help improve {APP_NAME}", subtitle "Found a problem or have an idea? Send me a note."
- A white card:
  - "What's on your mind?"
  - A red menu picker "Suggestion ⌃⌄" (Suggestion / Bug report / Question / Other).
  - A divider.
  - A multiline `TextEditor` with the placeholder "Tell me what happened or what you'd like to see…".
  - Save the draft to UserDefaults as the user types.
- A full-width button "✉ Continue to email". It is grey and disabled while the text is empty and brand once there's text. It opens `MFMailComposeViewController`, prefilled with the subject "[{APP_NAME}] {type}", the body and the app version + iOS version, and falls back to a `mailto:` link.
- Note: "Your draft is saved on this device. You'll review and send from your email account, so I can reply."
- A card "Email me directly" with SUPPORT_EMAIL in red and "Copy email address" (with a copy icon), which copies the address and shows a "Copied" toast.

## 4. Screen Time engine (the core; make this rock solid)

- **Authorization**: `AuthorizationCenter.shared.requestAuthorization(for: .individual)`. Check the status on every launch. If authorization is revoked, show a full-screen "Reconnect Screen Time" state.
- **Selection**: store the `FamilyActivitySelection` (Codable) in the App Group. Also keep a per-app config of `ApplicationToken` → unlock-time override and enabled flag.
- **Locking**: a named `ManagedSettingsStore(named: .init("main"))`. Set `shield.applications` to the enabled app tokens and `shield.applicationCategories = .specific(enabledCategoryTokens)`. The master toggle off clears the shield. Per-app toggles add or remove single tokens.
- **Shield UI** (`ShieldConfigurationExt`): white background, our puzzle-padlock icon (bundle a copy of the app-icon artwork as `shield_icon`, or use `lock.fill` tinted coral), title "Solve a puzzle to unlock the app", subtitle "{app name} is locked by {APP_NAME}", a brand primary button with the label "START PUZZLE" and the secondary label "NOT NOW". Do this for applications, categories and web domains.
- **Shield action** (`ShieldActionExt`):
  - Primary: write the blocked token and a timestamp to the App Group as `pendingUnlock`. Then post an immediate local notification: "Tap to start your puzzle 🧩" / "Solve {N} puzzle(s) to unlock {app}", with the userInfo deep link `quizlock://unlock`. Return `.defer`. (A shield extension can't open the host app directly; the notification is how you get there.)
  - Secondary: return `.close`.
- **Unlock flow** (main app): opening via that notification or deep link, or launching while `pendingUnlock` is set, presents the full-screen **Unlock puzzle** (the S05 chrome without "PRACTICE", plus a progress line "1 of N").
  - It picks games round-robin, in shuffled order, from the enabled games at each game's chosen difficulty.
  - The user must solve **N puzzles** (Puzzles per unlock). Progress, including the half-finished puzzle state, persists if they leave.
  - On success:
    1. Check entitlement. If the user has no active QuizLock Pro subscription and `freeUnlocksUsed >= FREE_UNLOCKS`, show the "You've used your 5 free unlocks" card (which opens the paywall) instead of unlocking. Otherwise increment `freeUnlocksUsed` (unless Pro).
    2. Remove that token from the shield.
    3. Schedule the re-lock: `DeviceActivityCenter().startMonitoring(DeviceActivityName("unlock.<id>"), during: schedule)`. **DeviceActivity needs schedules of at least 15 minutes**, so for shorter unlocks set `intervalStart = now − (15min − duration)` and `intervalEnd = now + duration`. "For Today" ends at 23:59:59. Custom uses the chosen h/m.
    4. Show the S06-style screen "You unlocked the app!" with the open-lock icon and the line "Go back to {app} — it's unlocked for 15 minutes."
- **Re-lock** (`DeviceActivityMonitorExt.intervalDidEnd`): read the App Group, add the token back to the `main` store's shield, then stop monitoring that activity. Make this idempotent. Also, on every app launch, sweep for expired unlocks and re-shield them as a safety net.
- **Categories**: when a category was blocked, the shield action receives the app's `ApplicationToken`. Unlock it via `shield.applicationCategories = .specific(categories, except: [thatAppToken])`.
- Wrap all Screen Time calls so the app still runs (with mocked state) in the **Simulator**, where FamilyControls isn't available. Use a `#if targetEnvironment(simulator)` mock so I can click through every screen and play every game in the Simulator.

## 5. The 4 puzzle games

Build each game as a self-contained SwiftUI view with its own pure-Swift engine (no UI code in the engine), conforming to a shared protocol:

```swift
protocol PuzzleGame {
  var id: GameID { get }                 // .chess, .sudoku, .math, .word
  func makeRound(difficulty: Difficulty) async -> any PuzzleRound
}
// A round reports .solved or .failed (failed → serve a new round of the same game; it never counts)
```

Games pre-generate their next round in the background, so the unlock screen opens instantly.

### 5.1 Word (Wordle-style)
Never call it "Wordle" anywhere in the UI or metadata; Wordle is a New York Times trademark. Call it **Word**.
- **Dictionary rules (strict):**
  - A guess is accepted **only if it is exactly 5 letters A–Z AND appears in `Resources/wordle_allowed.txt`** (8,647 real English words, one lowercase word per line). Load both lists once into a `Set<String>`.
  - Fewer than 5 letters: shake the row and show the toast "Not enough letters".
  - Not in the list: shake the row and show the toast "Not in word list".
  - The keyboard only types A–Z, and the row stops at 5 letters.
  - Never accept random strings, names or abbreviations.
- **Answers** come only from `Resources/wordle_answers.txt` (2,203 common words, all also in the allowed list). Pick randomly without repeats until the list is exhausted, storing the used answers in the App Group.
- **UI:**
  - A 6×5 grid of 60pt square tiles (2pt light-grey border when empty, a darker border when filled, and a small "pop" scale when a letter is typed).
  - On Enter, reveal tiles left to right with a 3D **flip** (rotation3DEffect on X, 250ms each, staggered 100ms) into green, yellow or grey with white letters.
  - Below the grid is a **custom on-screen QWERTY keyboard**, not the system keyboard: 3 rows, ENTER and ⌫ on row 3, keys radius 6, light grey (#D3D6DA). Each key takes the best colour seen for that letter (green > yellow > grey).
  - Support a physical keyboard too (via `onKeyPress`).
- **Scoring (must handle duplicate letters correctly):** a two-pass algorithm. First mark exact matches green and count the remaining answer letters. Then mark yellow only while that letter's remaining count is above 0; everything else is grey.
- Win: the row bounces, then success. Lose after 6 guesses: show the toast with the answer in caps, mark the round failed, and serve a new word.
- Difficulty: Easy = 6 tries, Medium = 6 tries + hard mode (revealed hints must be used), Hard = 5 tries + hard mode.
- Unit tests:
  - Scoring cases: answer ABBEY with guess BABES; answer SPEED with guess EERIE; answer CRANE with guess CRANE.
  - "Not in word list" rejection, e.g. "abcde", "qwert" and "xyzzy".
  - Every answer is in the allowed set and is 5 lowercase letters.

### 5.2 Chess (mate puzzles, real data)
- **Data:** write `Scripts/build_chess_puzzles.py` and run it once now. It:
  - Downloads the **Lichess puzzle database** (CC0 license) from `https://database.lichess.org/lichess_db_puzzle.csv.zst` and decompresses it (python `zstandard`, or `brew install zstd`). The columns are `PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags,DailyDate`.
  - **Important:** `FEN` is the position *before* the opponent's move. The **first move in `Moves` (UCI) is the opponent's move**: apply it to get the position shown to the player. The rest alternates player move / opponent reply.
  - Keeps only puzzles whose Themes contain `mateIn1` or `mateIn2`, with `Popularity >= 85` and `NbPlays >= 500`.
  - Buckets them as Easy = mateIn1 with rating < 1300, Medium = mateIn1 at 1300–1800 or mateIn2 < 1500, Hard = mateIn2 ≥ 1500. Samples 300 per bucket.
  - Writes `Resources/chess_puzzles.json` with `[{id, fen, opponentFirstMove, solution:[uci...], rating, mateIn, difficulty}]`.
  - Don't commit the raw CSV.
- **Engine:** a small pure-Swift chess engine with FEN parsing, full legal move generation (castling, en passant, promotion), and check/checkmate detection.
- **UI:**
  - The board is drawn in SwiftUI, oriented from the player's side, with rank/file labels in the corners.
  - Pieces: draw them with the *filled* Unicode chess glyphs (♚♛♜♝♞♟) followed by the text variation selector U+FE0E so iOS doesn't render them as emoji, in the "Apple Symbols" font. Colour white pieces white with a 1.5pt dark outline and black pieces near-black.
  - When the round opens, animate the opponent's first move (slide 300ms + highlight).
  - Header text: "White to move. Mate in one." (or "Black to move. Mate in two.").
  - Tap a piece to show legal-move dots, then tap a destination. Drag-and-drop also works. Promotion shows a 4-piece picker.
- **Checking a move:**
  - Accept the move if it equals the expected solution move, **or if it is the player's final move and it delivers checkmate** (alternative mates count).
  - After a correct non-final move, auto-play the opponent's reply after 400ms.
  - A wrong move shakes, snaps back and uses one of 3 tries. After 3 misses, animate the solution and mark the round failed.
  - On success, the answer bar shows "{SAN}# · Checkmate ✓" in dark green.
- Unit tests: move generation perft for the start position to depth 3 (8,902) and for "Kiwipete" to depth 2 (2,039). Every bundled puzzle's solution must be legal and end in checkmate.

### 5.3 Sudoku
- **Generator:**
  - Fill a complete valid grid with randomized backtracking.
  - Remove cells in random symmetric pairs, keeping a removal only if a solver that stops at 2 solutions still finds exactly **one**.
  - Givens per difficulty: Quick (6×6, 2×3 boxes) ≈ 18 givens; Easy 9×9 = 40–45; Medium = 32–36; Hard = 26–30.
  - Generate off the main thread.
- **UI:**
  - A square board with thin 0.5pt cell lines and 2pt box lines. Givens are in bold textPrimary; the user's digits are in brand.
  - Highlights: the selected cell is pink (brandTint); its row, column and box are very light grey; every cell with the same digit is light pink.
  - **Conflicts** (a duplicate in a row, column or box) turn red immediately.
  - Below the board: a number pad 1–9 (large rounded keys; a digit's key fades out once all 9 are placed), plus Erase, a Notes toggle (pencil marks drawn as a small 3×3 sub-grid) and Hint (fills the selected or a random empty cell; max 3 per round).
  - Solved when every cell matches the solution: a cascade green flash across the board, then success. There is no fail state.
- Unit tests: 50 generated puzzles per difficulty each have exactly one solution and the right number of givens.

### 5.4 Math
- **Generator** (procedural, endless), with a topic sub-label:
  - Easy:
    - ARITHMETIC: 2-digit + and −, times tables up to 12, exact division.
    - PERCENT: 10%, 25% and 50% of round numbers.
  - Medium:
    - 3-digit ±, 2-digit × 1-digit, percentages like 15% of 80.
    - ALGEBRA: linear equations like 3x + 7 = 22 with integer answers.
    - ORDER OF OPERATIONS.
  - Hard: 2-digit × 2-digit, two-step equations, squares and roots, fractions to decimals.
  - Answers are always integers, or decimals with at most 2 places.
- **UI:**
  - The question in 34pt bold, centred, typeset nicely (×, ÷, −, superscripts).
  - A large answer field in a white card (60pt digits).
  - A **custom numeric keypad**: 1–9, ".", 0, "−", ⌫, and a full-width red "Check" button.
  - Correct: the field turns green with a check, then success.
  - Wrong: shake and red tint, the field clears, try again. After 3 wrong answers, show "Answer: {x}", mark the round failed and serve a new question.
- Unit tests: every generated question's stored answer matches an independent evaluation of its expression, for 1,000 samples per difficulty.

## 6. Paywall (StoreKit 2, auto-renewable subscriptions)

Subscription group "QuizLock Pro" with IAP_PRO_YEARLY (pre-selected, 7-day free trial for new subscribers), IAP_PRO_MONTHLY and IAP_PRO_OFFER.

**Main screen**: the mascot at the top, the headline ("Your plan is ready, {name}" after onboarding), two plan cards (Yearly with the badge "BEST VALUE · {yearly ÷ 12}/month · Save {x}%", and Monthly), 3 benefit rows with icons ("Unlimited unlocks", "All 4 puzzle games + daily puzzle", "Streaks, stats and widgets"), and, for the trial, a timeline "Today: full access" → "Day 5: we'll remind you" → "Day 7: you're billed {price}/year, cancel anytime before". The button reads "Start 7-day free trial" with "then {price}/year" under it, or "Subscribe for {price}/month" for monthly (and "Subscribe for {price}/year" when the user isn't eligible for the trial).

**Exit offer** (shown once, when the main paywall is closed): "{x}% off your first year" with IAP_PRO_OFFER's price.

Every screen shows the price and period, "Auto-renews. Cancel anytime in Settings.", Restore Purchases, Terms of Use, Privacy Policy and a visible ×. Prices, periods and the trial length come from StoreKit (`displayPrice`, `subscription.introductoryOffer`, `isEligibleForIntroOffer`); percentages are computed from the real prices. If products fail to load: "Couldn't load prices" + Retry. A local notification on day 5 of the trial says "Your free trial ends in 2 days".

Pro = an active subscription in the group: check `Transaction.currentEntitlements` on launch and listen to `Transaction.updates`.

## 7. Quality bar
- Support iPhone only, portrait only, iOS 17+. Use the system font with Dynamic Type where layouts allow. Add VoiceOver labels; the Sudoku and chess cells must read their contents.
- Code: MVVM with `@Observable`, one file per screen, no third-party packages in the app (the Python build script may use pip packages).
- Animate every transition between onboarding screens (push-style slide + fade). Spring animations for selections.
- Must **build with zero errors and warnings** for both the Simulator and a device. Run `xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` and fix everything until it passes, then run all the unit tests and fix any failures.
- When you finish, give me a checklist of what I still have to do by hand in Xcode or App Store Connect.
