# App Privacy questionnaire (App Store Connect → App Privacy)

## Answer: **Data Not Collected**

"Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**

Why that's accurate:

| What the app touches | Where it goes | Counts as "collected"? |
|---|---|---|
| Screen Time selections (opaque Apple tokens), unlock times, lock schedule | Stays on the device (App Group) | No |
| Screen Time usage ("Today" card) | Rendered by Apple's DeviceActivityReport extension on-device; the app can't read it | No |
| Puzzle progress, stats, streaks, onboarding answers (name, age range, goals) | Stays on the device (and the user's own iCloud, below) | No |
| Purchases (Lockie Pro subscription) | Handled by Apple (StoreKit); the app only learns whether a subscription is active and when it renews | No |
| Progress synced with iCloud (streaks, stats, settings, onboarding answers) | The user's own iCloud key-value storage, managed by Apple; the developer can't access it | No |
| Notifications | Local only, scheduled on the device | No |
| Analytics, ads, tracking SDKs | None in the app | No |

Also confirm:
- **Tracking:** No. There's no App Tracking Transparency prompt and no `NSUserTrackingUsageDescription`.
- **Privacy manifest:** every target ships `PrivacyInfo.xcprivacy` with `NSPrivacyTracking = false`, no
  collected data types, and the UserDefaults reasons CA92.1 / 1C8F.1.

## What changes if the feedback email counts

The Feedback tab opens **your own** email app (or a `mailto:` link), prefilled with the message, the app
version and the iOS version. The user reviews and sends it themselves, so the app never transmits it.
Apple's guidance treats data that people send you in their own email as outside the app, so **Data Not
Collected** stays correct.

If you decide to be extra conservative (or later add an in-app form that sends feedback to a server),
declare instead:

- **Contact Info → Email Address**: purpose *App Functionality* (to reply); **linked to the user**; not used for tracking.
- **User Content → Customer Support / Other User Content**: purpose *App Functionality*; linked to the user; not used for tracking.
- **Diagnostics → Other Diagnostic Data** (app and iOS version): purpose *App Functionality*; linked to the user; not used for tracking.

Keep the Privacy Policy in sync if you change anything: https://nis7777.github.io/lockie/privacy.html
