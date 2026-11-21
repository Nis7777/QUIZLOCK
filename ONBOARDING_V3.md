# QuizLock onboarding v3: "story mode" (premium, chat-driven)

Rebuild the onboarding as a **story told by our mascot**, in the spirit of motion_reference/ but with OUR copy and OUR brand. Apply MOTION.md everywhere. All copy below is final unless marked otherwise; {name} = the user's name.

The mascot's name is **Lockie** (the coral puzzle-padlock).

## 0. Assets & components

### Mascot expressions
Load these from Assets; if one is missing, fall back to `mascot_pointing`:
- `mascot_wave`
- `mascot_happy`
- `mascot_worried`
- `mascot_sad`
- `mascot_thinking`
- `mascot_clipboard` (holding a clipboard/checklist)
- `mascot_celebrate` (arms up, confetti)
- `mascot_calm` (eyes closed, meditating)
- `mascot_pointing` (exists)

Every time the mascot changes expression, cross-fade with a tiny squash-and-stretch: scale 0.92 → 1.04 → 1.0 with Motion.bouncy, plus a light haptic. It always has its idle breathing loop.

### `ChunkyButton`
- A coral fill (#FF5A36) with a 5pt darker bottom edge (#D9431F) giving a 3D look, corner radius 18, height 60, white 18pt bold text.
- On press, the face moves down 4pt and the edge shrinks (Motion.snappy) + a light haptic.
- Disabled: coral at 35% opacity, no edge, no press.
- Use it for EVERY primary button in onboarding and on the paywall.

### `ChatView` (for the chat chapter)
- **Header:** a back chevron, a small mascot avatar circle, "Lockie" (bold) and a green dot + "Online".
- **Lockie's bubbles:** left-aligned, light grey (#EFEFF2), dark text, radius 18. They appear one at a time:
  - First a typing bubble with 3 bouncing dots for 0.6–1.1s (depending on message length).
  - Then the message pops in (scale 0.9 → 1, opacity, Motion.snappy) with a soft haptic.
  - Auto-scroll to the bottom with animation.
- **Emphasis styles inside bubbles:** a coral bold number (`**290**`-style), and a red line for hard truths (`!!text!!`) using #FF3B30.
- **Reply chips:** after a group of messages, a small grey caption "Tap to answer" appears, then 1–3 reply chips slide up from the right, staggered.
  - The chips are right-aligned, with a peach background (brandTint) and coral text.
  - Tapping one turns it into the user's sent bubble (coral fill, white text, right-aligned) with a `matchedGeometryEffect` from chip to bubble; the other chips fade out.
  - Then Lockie continues.
- **Rich bubble:** an "app icon grid" bubble with the real icons of TikTok, YouTube, Instagram, X, Facebook, Threads, Reddit and Snapchat (`BrandAppIcon`: white glyph from simple-icons on the brand-coloured rounded square).

### Other components
- **`ChoiceCard`** (single and multi select): white, radius 16, 1pt light border, emoji or SF Symbol on the left, title, and a radio circle on the right. Selected = 2pt coral border, peach fill, filled coral radio with a check (Motion.bouncy) + a selection haptic. Multi-select screens are grouped under small grey section headers.
- **Back button:** a coral arrow at the top left on all non-chat screens. No progress bar during the chat chapter; a thin coral progress bar for the question chapter.

## 1. Chapter 1: Hello (3 screens)
1. **Splash/hero:**
   - A peach-to-coral gradient sky background with soft clouds drawn in SwiftUI, and `mascot_wave` big in the centre.
   - "QuizLock" wordmark in white, with the line "The app blocker that makes you smarter" under it.
   - ChunkyButton (white with a coral label): "Get started".
   - Fine print: Terms · Privacy.
   - NO fake ratings or user counts. Only show real App Store numbers later, and leave a hidden slot for them.
2. **"Hey! I'm Lockie."** `mascot_wave` waves. After 1s, small grey text fades in: "(the little voice telling you to put the phone down)". Then Continue.
3. **"What should I call you?"** A large underlined text field that auto-focuses, with the keyboard up. ChunkyButton "Continue" (disabled until 1+ letter) and a "Skip" text link.

## 2. Chapter 2: The chat (one ChatView screen)
First a transition screen: "{name}, we need to talk." with `mascot_worried`. Then a fake iOS notification banner slides down from the top: an avatar + "Lockie: hey {name}, got a sec?" + "now". Below it: "↑ Lockie sent you a message, tap it". Tapping the banner opens the ChatView with a zoom-from-banner transition.

**Chat script** (Lockie's bubbles; ⟶ = the reply chips; after the user taps, continue):
1. "hey {name} 👋"
2. "quick question"
3. "how many times did you open your phone today without even thinking?"
   ⟶ "too many" / "don't ask" / "i'm fine actually"
4. If "i'm fine actually": "respect. but let's check anyway 😏". Otherwise: "yeah… same story for most people"
5. "it goes like this:"
6. "you unlock your phone"
7. "you open one app 'for a second'"
8. "40 minutes disappear"
9. "and you feel kinda empty after"
   ⟶ "ok that's me" / "stop exposing me"
10. "it's not your fault tho"
11. [app icon grid bubble]
12. "these apps are built by **thousands** of engineers"
13. "their whole job is keeping you scrolling"
14. !!willpower vs a billion-dollar algorithm?!!
15. "not a fair fight"
    ⟶ "so what do i do" / "that's unfair"
16. "that's where i come in 🧩"
17. "i lock the apps that steal your time"
18. "want back in? solve a quick puzzle first"
19. "chess, sudoku, math or a word game"
20. "by the time you've solved it, you usually don't even want the app anymore"
21. "and even if you do, your brain got a workout first 💪"
    ⟶ "wait that's smart" / "show me"
22. "let me show you how it works"
    ⟶ "let's go"

Then go to Chapter 3 with a page-curl-free cross-fade.

**Timing:** typing time = clamp(0.45 + chars × 0.018, 0.6, 1.4)s, and 0.25s between consecutive bubbles. A "Skip chat" link sits at the top right of the chat header for impatient users and jumps to Chapter 3.

## 3. Chapter 3: How it works (3 swipeable cards, auto-advance 3.5s, plus ChunkyButton "Continue")
Each card is a phone-mockup illustration drawn in SwiftUI with a big title + subtitle below:
1. **"Your apps get locked"**: generic app icons slide into a phone and a coral padlock clicks shut over them (`symbolEffect(.bounce)` + a haptic). Subtitle: "Pick the apps that steal your time."
2. **"Solve to unlock"**: the shield appears, and a mini Sudoku/Word puzzle solves itself. Subtitle: "A quick puzzle stands between you and the scroll."
3. **"Earn your scroll"**: the lock opens, a timer ring counts down 15:00, then the lock closes again. Subtitle: "Unlocked for a few minutes. Then it locks again."

## 4. Chapter 4: Getting to know you (questions; progress bar visible)
Open with a transition screen: `mascot_clipboard` + "Let's set you up, {name}!" + "I'll ask a few quick questions to build your plan." + Continue.

1. **"Where did you hear about us?"** (single choice): TikTok, Instagram, YouTube, App Store, Friend, Other. TikTok, Instagram, YouTube and App Store use their real icons (`BrandAppIcon`); Friend and Other use SF Symbols. Store it for attribution.
2. **"How many hours do you spend scrolling each day?"** Subtitle "Don't worry about the exact number, just a best guess." Options: Less than 2h, 2–4h, 4–6h, 6–8h, More than 8h.
3. **"Which apps eat most of your time?"** (multi): Short videos, Social feeds, YouTube-style videos, Games, News, Messaging, Shopping, Other.
4. **"How do you feel after scrolling?"** (multi, emoji): 😞 Guilty, 😶 Empty, 😰 Anxious, ⏳ Like I'm wasting my life, 🪫 Low energy, 🌫️ Foggy, 🙂 Fine actually.
5. **"What do you want more of?"** (multi, grouped):
   - **Mind:** Reading, Learning, Focus at work/school
   - **Body:** Sleep, Exercise, Time outside
   - **Life:** Friends & family, Creativity, Calm
6. **"Which puzzles sound fun?"** (multi, all pre-selected): Chess ♟️, Sudoku 🔢, Math ➗, Word 🔤. This sets the enabled games.
7. **"How hard should unlocking be?"** (single):
   - "Chill: 1 easy puzzle"
   - "Balanced: 1 medium puzzle" (default)
   - "Tough: 2 puzzles"
   - "Monk mode: 3 hard puzzles"

   This sets the puzzles per unlock and the difficulty.

## 5. Chapter 5: The turn (emotional payoff)
1. **"Don't worry, {name}. That's about to change."** with `mascot_happy`.
2. **Reality check:** "At this rate, you'll spend **X years** of your life scrolling." Use the formula from PROMPT_V2. The number counts up, `mascot_sad`.
3. **"With QuizLock, you could get back Y years."** (Y = 50% of X.) The number counts up in coral, `mascot_celebrate`, with light confetti.
4. **Projection chart:** "Less scrolling, more living". A simple illustrative 30-day line chart (Swift Charts): a coral "Scrolling" line trending down and a green "Living" line trending up, drawing themselves in (trim animation). Small footnote: "Illustration based on your goals." Never claim it as user data or study results.

## 6. Chapter 6: Permissions (mascot-guided)
1. **Screen Time:**
   - "Let's lock your first apps" with `mascot_pointing`.
   - A card with an Apple logo: "Your data stays on your iPhone. Protected by Apple's Screen Time privacy."
   - ChunkyButton "Connect Screen Time" → the system prompt → the app picker → a confirmation with the selected app icons popping in staggered.
   - Then "Choose your reward" (unlock time, existing screen).
2. **Notifications:**
   - "I'll send you gentle reminders to keep your streak alive" with `mascot_pointing`, placed so it points at where the system alert appears.
   - ChunkyButton "Allow notifications" → the system prompt.
   - "Not now" link.
3. **Rating:**
   - "Help more people unlock their time" with `mascot_celebrate` and confetti.
   - ChunkyButton "Continue" → requestReview once.
   - NO fake reviews, NO fake rating numbers.

## 7. Chapter 7: Commitment (cinematic)
1. **"Are you ready to take your time back, {name}?"** with `mascot_thinking`. At the bottom: "Hold your finger on the button to commit" and a coral circular button with a tap icon (SF Symbol `hand.tap.fill`; never use the Touch ID / Face ID glyphs for non-biometric actions).
   - **While holding:** the screen fills with a coral circle expanding from the button (a radial reveal tied to hold progress over 1.6s), with continuous haptics ramping up and the mascot growing slightly.
   - **Release early:** it springs back.
   - **Complete:** a heavy haptic, and the whole screen becomes solid coral.
2. **Full coral screen** (white text):
   - "You're about to…" fades in, then "Unlock" types itself letter by letter (with a tick haptic per letter), then "(verb)" fades in.
   - Then a paragraph fades in line by line: "To earn your scroll. You solve a puzzle, your brain wakes up, and the app gets a little less powerful every time."
   - Then the white ChunkyButton "Let's go".
3. **Setup screen:**
   - A large semicircle arc progress (coral) around `mascot_calm`, with the title "Setting up QuizLock…".
   - 3 steps tick off one by one: "Analysing your answers", "Building your plan", "Locking in your puzzles".
   - Each turns into a coral check circle with `symbolEffect(.bounce)` + a haptic. About 3s in total.
4. **Plan ready:**
   - A coral gradient sky with clouds and `mascot_celebrate` + confetti.
   - Big white text: "In 4 weeks, you won't recognise your screen time, {name}." (Use the US spelling "recognize" in en-US.)
   - A white card with a check: "Your personalised plan is ready", then 3 rows built from their answers: locked categories, daily puzzle mix, unlock time.
   - ChunkyButton (white with a coral label): "Start my plan" → the paywall.

## 8. Rules
- Every screen uses MOTION.md (stagger in, springs, haptics). Every primary button is a ChunkyButton.
- The total flow must still be quick. Chat skippable, questions tap-only, and launch → paywall in about 2–3 minutes of tapping.
- Persist progress, so killing the app resumes at the same chapter and step.
- No fake social proof anywhere (no invented ratings, user counts, testimonials or study claims).
- Respect Reduce Motion (no typing animation delays; show messages instantly with fades).
