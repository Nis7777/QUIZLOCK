# Submission checklist (for the App Store Connect account holder)

The Apple Developer account holder (your friend) does the steps marked **[Holder]**. With the **Admin**
role in App Store Connect you can do the rest.

## 1. Entitlements and identifiers (developer.apple.com)

- [x] **[Holder]** Request **Family Controls (Distribution)**: one request for the whole developer account
      (submitted 21 Nov 2026; it carries over to the Lockie IDs). Once approved it applies to every
      App ID with the Family Controls capability, which these targets need:
      https://developer.apple.com/contact/request/family-controls-distribution
  - `app.lockie.ios` (app)
  - `app.lockie.ios.ShieldConfiguration`
  - `app.lockie.ios.ShieldAction`
  - `app.lockie.ios.DeviceActivityMonitor`
  - `app.lockie.ios.ScreenTimeReport`
  - (The widget, `app.lockie.ios.Widgets`, doesn't use Family Controls.)
- [ ] Register all 6 **new** `app.lockie.ios…` bundle IDs (automatic signing in Xcode usually does this).
      Delete any App IDs or App Groups from before the rename: only the `lockie` ones are used.
- [ ] Register the App Group `group.app.lockie.ios` and enable it on all 6 App IDs.
- [ ] On `app.lockie.ios` and `app.lockie.ios.ShieldAction`, enable **Time Sensitive Notifications** (the
      "Tap to solve" notification uses it to get through Focus / Sleep; both entitlements files ask for it).
- [ ] On the main App ID `app.lockie.ios` **only**, enable **iCloud** (Key-value storage; no container
      needed). The app's entitlement `com.apple.developer.ubiquity-kvstore-identifier` is already in `project.yml`.
      In Xcode, **Signing & Capabilities** on the App target should then show **iCloud → Key-value storage**.
- [ ] In Xcode, set the Team on all 6 targets (or put the Team ID in `DEVELOPMENT_TEAM` in `project.yml`).

## 2. Agreements

- [ ] **[Holder]** Accept the **Paid Apps** agreement, and add bank and tax details (Agreements, Tax, and Banking).

## 3. App record (App Store Connect → Apps → +)

- [ ] Platform iOS, name and subtitle from `metadata.md`, bundle ID `app.lockie.ios`, SKU `lockie-001`.
- [ ] After creating it, copy the numeric **Apple ID** (App Information) into `Brand.appStoreID` in
      `Shared/Brand.swift`. "Rate Lockie" uses it.
- [ ] Category: **Productivity** (secondary: **Education**).
- [ ] Localization: **English (U.S.)** only, with the texts from `metadata.md`.
- [ ] Support URL: https://nis7777.github.io/lockie/
- [ ] Privacy Policy URL: https://nis7777.github.io/lockie/privacy.html
- [ ] Terms of Use: put https://nis7777.github.io/lockie/terms.html in the description (already there).

## 4. Subscriptions (App → Monetization → Subscriptions)

No accounts: the subscription is tied to the Apple ID, and progress syncs through iCloud.

- [ ] Create the subscription group **Lockie Pro** (group display name "Lockie Pro" in English).
- [ ] Create the 3 auto-renewable subscriptions in that group:

| Reference name | Product ID | Duration | Price (USA) | Introductory offer |
|---|---|---|---|---|
| Pro Yearly | `app.lockie.ios.pro.yearly` | 1 Year | $39.99 | **Free trial · 1 Week · New subscribers** |
| Pro Monthly | `app.lockie.ios.pro.monthly` | 1 Month | $9.99 | None |
| Pro Yearly Offer | `app.lockie.ios.pro.yearly.offer` | 1 Year | $29.99 | None |

- [ ] Prices: set the USA price, let Apple fill in the other countries. The app always shows the StoreKit price, and
      computes "Save 67%" (yearly vs 12 × monthly) and "25% off" (offer vs yearly) from the real prices.
- [ ] Display name + description for each, in English (e.g. "Lockie Pro Yearly" / "Unlimited
      unlocks, all 4 puzzle games and the daily puzzle").
- [ ] **Review screenshot** for each: the main paywall for Yearly and Monthly, the discount screen for the Offer.
- [ ] Only on Pro Yearly: **Introductory Offers → (+)** → **Free**, **1 Week**, **New subscribers**, all countries.
- [ ] Subscription levels: Yearly and Yearly Offer on the same level, Monthly below them.
- [ ] The first subscriptions must be submitted **with the app version** (step 8).
- [ ] Local testing needs no App Store Connect: `Products.storekit` (set on the App scheme's Run action) has the
      same 3 products, the group and the 7-day free trial. In Xcode use **Debug → StoreKit → Manage Transactions**
      to refund, expire or reset trial eligibility.
- [ ] Sandbox testing on a device: App Store Connect → **Users and Access → Sandbox → Test Accounts (+)**, then on the
      iPhone **Settings → Developer → Sandbox Apple Account**. Sandbox renewals are accelerated (1 year ≈ 1 hour,
      1 week trial ≈ 3 minutes), so the "trial ends in 2 days" reminder may be skipped there.

## 5. Privacy and age rating

- [ ] App Privacy: answer as in `privacy_labels.md` (**Data Not Collected**).
- [ ] Age Rating: answer as in `age_rating.md` (expected **4+**).

## 6. Build and upload

- [ ] In Xcode, set the destination to **Any iOS Device (arm64)**, then **Product → Archive** → Distribute
      App → App Store Connect → Upload.
- [ ] Increase **Build** (`CURRENT_PROJECT_VERSION`) for every upload.

## 7. TestFlight first

- [ ] Add yourself as an internal tester and install the build.
- [ ] Test on a real iPhone: onboarding (tap-only, paywall right after Turn On Locks, no close button), Screen Time permission, block screen, Solve to unlock → notification → puzzle → unlock → automatic
      re-lock, the 7-day trial, monthly and the
      offer (sandbox), Restore Purchases, Settings → Lockie Pro (Active · renews…, Manage subscription),
      iCloud restore on a second device ("Welcome back!"), Settings → Data → Reset all data, the lock
      schedule, strict mode and widgets.

## 8. Submit

- [ ] Screenshots: the 6.9" set from `AppStore/screenshots/` (run the Screenshots scheme first; it now also
      captures `07-pick-puzzles`). None of them may show the old pricing.
- [ ] Under **In-App Purchases and Subscriptions** on the version page, add all 3 subscriptions.
- [ ] Description ends with the Terms of Use (EULA) and Privacy Policy links (already in `metadata.md`), and the
      live pages at those URLs show the subscription terms (publish `docs/terms.html` and `docs/privacy.html`).
- [ ] App Review notes: paste `review_notes.md`.
- [ ] Submit for review.
