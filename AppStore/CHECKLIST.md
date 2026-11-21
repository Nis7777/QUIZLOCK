# Submission checklist (for the App Store Connect account holder)

The Apple Developer account holder (your friend) does the steps marked **[Holder]**. With the **Admin**
role in App Store Connect you can do the rest.

## 1. Entitlements and identifiers (developer.apple.com)

- [ ] **[Holder]** Request **Family Controls (Distribution)** for **every** target that uses Screen Time.
      Submit the form once per bundle ID: https://developer.apple.com/contact/request/family-controls-distribution
  - `com.dinismagina.quizlock` (app)
  - `com.dinismagina.quizlock.ShieldConfiguration`
  - `com.dinismagina.quizlock.ShieldAction`
  - `com.dinismagina.quizlock.DeviceActivityMonitor`
  - `com.dinismagina.quizlock.ScreenTimeReport`
  - (The widget, `com.dinismagina.quizlock.Widgets`, doesn't use Family Controls.)
- [ ] Register all 6 bundle IDs (automatic signing in Xcode usually does this).
- [ ] Register the App Group `group.com.dinismagina.quizlock` and enable it on all 6 App IDs.
- [ ] In Xcode, set the Team on all 6 targets (or put the Team ID in `DEVELOPMENT_TEAM` in `project.yml`).

## 2. Agreements

- [ ] **[Holder]** Accept the **Paid Apps** agreement, and add bank and tax details (Agreements, Tax, and Banking).

## 3. App record (App Store Connect → Apps → +)

- [ ] Platform iOS, name and subtitle from `metadata.md`, bundle ID `com.dinismagina.quizlock`, SKU `quizlock-001`.
- [ ] After creating it, copy the numeric **Apple ID** (App Information) into `Brand.appStoreID` in
      `Shared/Brand.swift`. "Rate QuizLock" uses it.
- [ ] Category: **Productivity** (secondary: **Education**).
- [ ] Localizations: **English (U.S.)** and **Portuguese (Portugal)**, with the texts from `metadata.md`.
- [ ] Support URL: https://nis7777.github.io/lockfeeddupe/
- [ ] Privacy Policy URL: https://nis7777.github.io/lockfeeddupe/privacy.html
- [ ] Terms of Use: put https://nis7777.github.io/lockfeeddupe/terms.html in the description (already there).

## 4. In-app purchases (App → Monetization → In-App Purchases)

| Reference name | Product ID | Type | Price |
|---|---|---|---|
| Lifetime Access | `com.dinismagina.quizlock.lifetime` | Non-Consumable | $29.99 |
| Lifetime Access Discount | `com.dinismagina.quizlock.lifetime.discount` | Non-Consumable | $4.99 |

- [ ] Add a display name and description in English and Portuguese for each.
- [ ] Upload a **review screenshot** of the paywall for each (Screen A for the standard one, the
      "Launch offer" screen for the discount).
- [ ] Add both to the app version under **In-App Purchases and Subscriptions** before submitting.

## 5. Privacy and age rating

- [ ] App Privacy: answer as in `privacy_labels.md` (**Data Not Collected**).
- [ ] Age Rating: answer as in `age_rating.md` (expected **4+**).

## 6. Build and upload

- [ ] In Xcode, set the destination to **Any iOS Device (arm64)**, then **Product → Archive** → Distribute
      App → App Store Connect → Upload.
- [ ] Increase **Build** (`CURRENT_PROJECT_VERSION`) for every upload.

## 7. TestFlight first

- [ ] Add yourself as an internal tester and install the build.
- [ ] Test on a real iPhone: onboarding, Screen Time permission, block screen, START PUZZLE → notification
      → puzzle → unlock → automatic re-lock, both purchases (sandbox), Restore Purchases, the lock
      schedule, strict mode, widgets, and the Portuguese language (Settings → QuizLock → Language).

## 8. Submit

- [ ] Screenshots: the 6.9" set from `AppStore/screenshots/` (run the Screenshots scheme first).
- [ ] App Review notes: paste `review_notes.md`.
- [ ] Submit for review.
