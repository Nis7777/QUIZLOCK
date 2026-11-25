# Lockie: everything to put in App Store Connect

One file, in order. Copy each block into the field named in its heading. Version **1.0**, build **3** or
higher (Xcode → raise the build number before every upload).

---

## 1. Before you resubmit

- [ ] **Keep all 3 subscriptions in the submission**, including `app.lockie.ios.pro.yearly.offer` (the app shows
      it once, on a later visit). Its review screenshot is the offer screen.
- [ ] **Open these 3 links in a browser** and make sure each one loads (not a 404):
  - Privacy Policy: https://nis7777.github.io/lockie/privacy.html
  - Terms of Use: https://nis7777.github.io/lockie/terms.html
  - Support: https://nis7777.github.io/lockie/
- [ ] **Family Controls (Distribution)** is approved on the account, and in Xcode's Distribute App summary the
      app and its 4 Screen Time extensions all list `com.apple.developer.family-controls`.
- [ ] Upload the new build, then pick it on the 1.0 version page (Build section).

---

## 2. Reply to App Review (App Review → the rejection message → Reply)

> Thank you for the feedback. In this build we addressed guideline 5.6:
>
> - The paywall's close button now closes it immediately and takes you into the app. It no longer leads to a
>   discount screen, and there are no countdowns or "only shown once" claims.
> - The discounted yearly plan now appears only once, as its own screen, the next time the user opens the app
>   after closing the paywall. Its close button closes it.
> - No app is ever blocked without an active subscription: the locks only take effect after the user starts
>   Lockie Pro or its free trial, and they're removed automatically if the subscription ends. Without a
>   subscription the app clearly says the apps aren't locked yet.
> - The App Store rating prompt is no longer shown during onboarding; it's asked once, after the user has
>   earned a few unlocks.
> - Screens shown before Apple's permission prompts now use "Continue" and always lead to the system prompt.
>
> The updated review notes explain how to test, including how to see the offer. Thank you!

---

## 3. App Information

| Field | Value |
|---|---|
| Name | Lockie: Puzzle App Blocker |
| Subtitle | Solve a puzzle to unlock apps |
| Primary category | Productivity |
| Secondary category | Education |
| Content rights | Yes, it contains third-party content: chess puzzles from the Lichess database (CC0, public domain), and the icons of other apps (TikTok, Instagram…) shown in onboarding. |
| Privacy Policy URL | https://nis7777.github.io/lockie/privacy.html |

---

## 4. Version page (1.0): text fields

**Name** (30)
Lockie: Puzzle App Blocker

**Subtitle** (30)
Solve a puzzle to unlock apps

**Promotional text** (170)
Scroll less, think more. Lock distracting apps and earn a few minutes back by solving a chess, Sudoku, math or word puzzle. Start with a free trial.

**Keywords** (100)
screen time,app blocker,focus,brain training,chess,sudoku,word game,math,limit apps,detox,habit

**Description** (4000)
Lockie is an app blocker that makes you smarter. Pick the apps that steal your time, and Lockie locks them with Apple's Screen Time. Want back in? Solve a quick puzzle first.

LOCK THE APPS THAT DISTRACT YOU
Choose any apps, categories or websites. When you open one, Lockie's block screen appears instead. Tap Solve to unlock, solve the puzzle, and the app unlocks for the time you chose: 5 minutes, 15 minutes, for today, or a custom time. When the time is up, it locks again automatically.

FOUR REAL PUZZLES, NOT BUSYWORK
• Chess: real mate-in-one and mate-in-two puzzles from the Lichess database
• Sudoku: unique-solution grids, from a quick 6×6 to hard 9×9
• Math: quick mental math, percentages, algebra and more
• Word: guess the 5-letter word in six tries
Choose your difficulty, mix the games, and set how many puzzles each unlock needs.

BUILD A BETTER HABIT
• Streaks and stats: see your puzzles solved, unlocks skipped and time saved
• Today's puzzle: one featured puzzle a day to keep your streak alive
• Lock schedules: lock apps only during work, study or bedtime hours
• Strict mode: make locks harder to switch off when you need it most
• Widgets: your streak on the Home Screen and Lock Screen
• Gentle, opt-in reminders, never more than one a day

PRIVATE BY DESIGN
Lockie has no accounts, no ads and no tracking. Your Screen Time data stays on your iPhone: Apple shows it to you inside the app, and Lockie itself can't read or send it.

NEW PHONE? NO PROBLEM
Your progress syncs through your own iCloud, so your streak and stats come with you to a new iPhone. Use Restore Purchases to bring your subscription along.

PRICING
Lockie is free to download, and the daily puzzle, stats and streaks are free. Locking apps (and unlocking them with puzzles) and puzzle practice need Lockie Pro, an auto-renewable subscription:
• Lockie Pro Yearly: 1 year, with a 7-day free trial for new subscribers
• Lockie Pro Monthly: 1 month
Prices are shown in the app before you subscribe and may vary by country.

Payment is charged to your Apple ID when you confirm the purchase, or when the free trial ends. The subscription renews automatically unless you turn off auto-renew at least 24 hours before the end of the current period; renewal is charged within 24 hours before the period ends. Manage or cancel anytime in Settings → your name → Subscriptions. If you cancel during the free trial, you won't be charged.

Chess puzzles from the Lichess puzzle database (CC0).
Terms of Use: https://nis7777.github.io/lockie/terms.html
Privacy Policy: https://nis7777.github.io/lockie/privacy.html

**Support URL**
https://nis7777.github.io/lockie/

**Marketing URL** (optional)
https://nis7777.github.io/lockie/

**Copyright**
2026 Tomás Beja

---

## 5. App Review Information

- **Sign-in required:** No (no accounts).
- **Contact:** the account holder's name, phone and email.
- **Notes:** paste everything between the lines.

---

Lockie helps people block their own distracting apps. It uses Apple's Screen Time API with
**FamilyControls individual authorization** (`AuthorizationCenter.requestAuthorization(for: .individual)`),
so the person using the iPhone chooses which of *their own* apps to block. It is not a parental-control or
monitoring app. To temporarily unlock a blocked app, the user solves a short puzzle (chess, Sudoku, math
or a 5-letter word game).

**No login is needed and there are no accounts.** Everything runs on the device; progress (streaks,
stats, settings) syncs through the user's own iCloud key-value storage. The subscription is tied to the Apple ID
(Restore Purchases). Blocking apps needs a Lockie Pro subscription. Onboarding and Screen Time setup are free,
then the Lockie Pro paywall appears (the yearly plan has a 7-day free trial). Its **×** closes it straight away
and you can use the app without subscribing; the dashboard then says "Your apps aren't locked yet". **No app is
ever blocked without an active subscription:** the locks only take effect once Lockie Pro or its free trial
starts, and they are removed automatically if it ends, so apps are never held locked to push a purchase. Please
subscribe with a Sandbox account to test blocking.

## How to test (about 3 minutes)

1. Launch Lockie and tap **Get started**. Lockie (our mascot) introduces itself; typing a name is optional
   (**Skip**). A short chat follows: tap the reply bubbles, or tap **Skip chat** at the top right.
2. **How it works** shows 3 cards; tap **Continue**. Answer the short questions (tap an answer, then
   **Continue**), then tap **Continue** through the next few screens.
3. On **Let's lock your first apps**, tap **Continue** and allow access in Apple's system sheet. In
   Apple's app picker choose any app (for example Safari or News), tap **Done**, then **Continue**.
4. Choose an unlock time (for example **5 minutes**) and tap **Continue**. Tap **Continue** again and allow or decline
   notifications in Apple's alert, then tap **Continue** on the next screen.
5. Hold the round button to commit, then tap **Start my plan**. The Lockie Pro paywall appears. Start the free
   trial with your Sandbox account (no real money is charged). The locks turn on and you land on the dashboard.
6. Go to the Home Screen and open the app you chose. Lockie's block screen appears.
7. Tap **Solve to unlock**. The block screen changes to "Your puzzle is ready 🧩". Tap the notification, or open
   Lockie. Solve the puzzle: the app opens unlocked for the time you chose, and locks again when the time is up.

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
- `app.lockie.ios.pro.yearly.offer`: 1 year at a lower price, no trial. If someone closes the paywall without
  subscribing, this offer appears once, as its own screen, the next time they open Lockie (at least a minute
  later). It is never shown as a result of tapping ×, its own × closes it, and it has no countdown or urgency
  claims. To see it: close the paywall, wait a minute, leave Lockie and open it again.

Any active subscription in the group unlocks Lockie Pro: locking the chosen apps, unlocking them with puzzles,
and standalone puzzle practice. The daily puzzle, stats, streaks and widgets are free. Every paywall screen shows the price and billing period, the amount billed after the trial, "Auto-renews.
Cancel anytime in Settings.", **Restore Purchases**, **Terms of Use** and **Privacy Policy**, and a × that closes right away.
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

---

---

## 6. App Privacy (App Privacy → Edit)

Because of RevenueCat, the answer is **not** "Data Not Collected":

1. "Do you or your third-party partners collect data from this app?" → **Yes**
2. Data type: **Purchases → Purchase History**. Nothing else.
3. Purposes: **Analytics** and **App Functionality**.
4. Linked to the user's identity? → **No** (anonymous RevenueCat ID, no accounts).
5. Used for tracking? → **No**.

Everything else stays not collected (Screen Time data never leaves the iPhone; progress syncs through the user's
own iCloud, which counts as not collected).

---

## 7. Age Rating (App Information → Age Rating)

Expected result: **4+**.

| Question | Answer |
|---|---|
| Parental controls | **No.** Lockie uses FamilyControls *individual* authorization: people limit their own apps. It is not a parental-control app. |
| Age assurance | No |
| Unrestricted web access | **No.** The only web content is our own Terms and Privacy pages, shown in an in-app Safari sheet. |
| User-generated content | No |
| Messaging and chat | No |
| Advertising | No |
| Cartoon or fantasy violence | None |
| Realistic violence | None |
| Prolonged graphic or sadistic realistic violence | None |
| Profanity or crude humour | None |
| Mature or suggestive themes | None |
| Horror or fear themes | None |
| Medical or treatment information | None |
| Health or wellness topics | None (screen-time habits, not medical advice) |
| Alcohol, tobacco or drug use or references | None |
| Simulated gambling | None |
| Sexual content or nudity | None |
| Graphic sexual content and nudity | None |
| Contests | None |
| Gambling | No |
| Loot boxes | No |

---

## 8. Subscriptions (Monetization → Subscriptions)

**Subscription group:** Lockie Pro (display name "Lockie Pro", English).

| Reference name | Product ID | Duration | Price (USA) | Introductory offer | Display name | Description |
|---|---|---|---|---|---|---|
| Pro Yearly | `app.lockie.ios.pro.yearly` | 1 Year | $39.99 | Free trial, 1 Week, new subscribers | Lockie Pro Yearly | Lock distracting apps and unlock them with puzzles, plus puzzle practice |
| Pro Monthly | `app.lockie.ios.pro.monthly` | 1 Month | $9.99 | None | Lockie Pro Monthly | Lock distracting apps and unlock them with puzzles, plus puzzle practice |

- Review screenshot for each: a screenshot of the paywall with that plan selected.
- Both are submitted together with the app version.
- Pro Yearly Offer: `app.lockie.ios.pro.yearly.offer`, 1 Year, $29.99, no introductory offer, display name
  "Lockie Pro Yearly (Offer)", same description. Levels: Yearly and Yearly Offer on the same level, Monthly below.
  Its review screenshot is the offer screen.

---

## 9. Pricing, availability and export compliance

- **Price:** Free (the app is free to download; Lockie Pro is the subscription).
- **Availability:** all countries you want.
- **Encryption:** "Does your app use encryption?" → only standard HTTPS (exempt). The build already says
  `ITSAppUsesNonExemptEncryption = NO`, so App Store Connect shouldn't ask.
- **Devices:** iPhone only. (Apple still reviews it on an iPad, running the iPhone version.)
