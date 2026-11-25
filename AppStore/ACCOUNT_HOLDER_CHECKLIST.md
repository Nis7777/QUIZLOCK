# 📱 App Store setup for the account holder

*Every step needs the paid Apple Developer account login. Go in order and tick each box.*

> **Old IDs:** delete any App IDs or App Groups from before the rename to Lockie under
> Identifiers. Only the `lockie` IDs below are used. The Screen Time request (step 6) is for the whole
> account, so it doesn't need sending again.

## PART 1: Do first (the slow approval starts here)

### ☐ 1. Add the developer to the team
1. Go to **appstoreconnect.apple.com → Users and Access → (+)**.
2. Enter the developer's Apple ID email.
3. Tick the roles **Developer** and **App Manager** → **Invite**.
4. The developer accepts the email invite.

### ☐ 2. Accept the paid apps contract
1. App Store Connect → **Business** (Agreements, Tax, and Banking).
2. **Paid Apps Agreement → View and Agree to Terms**.
3. Add the **bank account** and complete the **tax forms**.
4. Wait until the status says **Active**. Subscriptions won't work, even in testing, before that.

### ☐ 3. Join the Small Business Program
Go to developer.apple.com/app-store/small-business-program → **Enroll**. Apple then takes 15% instead of 30%.

### ☐ 4. Create the App Group
1. Go to developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers → (+)**.
2. Choose **App Groups → Continue**.
3. Description: `Lockie Group`. Identifier: `group.app.lockie.ios` → **Register**.

### ☐ 5. Register the 6 bundle IDs
For each one: **Identifiers → (+) → App IDs → App → Continue**, choose **Explicit**, paste the Bundle ID, tick the capabilities shown, then **Continue → Register**.

| # | Bundle ID (copy exactly) | Description | Family Controls | App Groups |
|---|---|---|---|---|
| 1 | `app.lockie.ios` | Lockie App | ✅ | ✅ |
| 2 | `app.lockie.ios.ShieldConfiguration` | Lockie Shield | ✅ | ✅ |
| 3 | `app.lockie.ios.ShieldAction` | Lockie Shield Action | ✅ | ✅ |
| 4 | `app.lockie.ios.DeviceActivityMonitor` | Lockie Monitor | ✅ | ✅ |
| 5 | `app.lockie.ios.ScreenTimeReport` | Lockie Report | ✅ | ✅ |
| 6 | `app.lockie.ios.Widgets` | Lockie Widgets | ❌ | ✅ |

On `app.lockie.ios` **and** `app.lockie.ios.ShieldAction`, also tick **Time Sensitive Notifications** (it lets
"Tap to solve 🧩" through Focus and Sleep).

On the main app ID (`app.lockie.ios`) **only**, also tick **iCloud** (it's used for key-value storage, which syncs streaks and stats; no container needed).

After registering each one, open it → next to **App Groups** click **Configure** → tick `group.app.lockie.ios` → **Save**.

⚠️ **Never change these IDs after step 7.** Once the app is created in App Store Connect with
`app.lockie.ios`, that bundle ID belongs to the app for good.

### ☐ 6. Request the Screen Time permission (the slow one) ✅ submitted 21 Nov 2026
1. While logged in as the Account Holder, go to **developer.apple.com/contact/request/family-controls-distribution**.
2. It's **one request for the whole developer account** (not per bundle ID). Check the details and click **Get Entitlement**. It then shows "Reviewing submission".
3. Wait for Apple's email (days to a few weeks). Once approved, "Family Controls (Development)" on the App IDs becomes Distribution; nothing needs re-registering.
4. Meanwhile, continue with Part 2. Development builds from Xcode already work on a real iPhone.

## PART 2: Do while waiting for approval

### ☐ 7. Create the app
1. App Store Connect → **Apps → (+) → New App**.
2. Platform **iOS**, Name **Lockie**, Primary language **English (U.S.)**.
3. Bundle ID `app.lockie.ios`, SKU `lockie-001`, User Access **Full Access** → **Create**.
4. Open **App Information**, copy the **Apple ID** number, and send it to the developer (it goes into the app's "Rate" button).

### ☐ 8. Create the subscription group
1. In the app → **Monetization → Subscriptions → Create** a subscription group.
2. Reference name: **Lockie Pro**.
3. Add a group localization: English (U.S.), display name **Lockie Pro**.

### ☐ 9. Create the 2 subscriptions inside that group

| Reference name | Product ID (copy exactly) | Duration | Price (USA) | Introductory offer |
|---|---|---|---|---|
| Pro Yearly | `app.lockie.ios.pro.yearly` | 1 Year | $39.99 | Free · 1 Week · New subscribers |
| Pro Monthly | `app.lockie.ios.pro.monthly` | 1 Month | $9.99 | None |

For each subscription:
1. **Subscription Prices → Add pricing**: set the USA price and let Apple fill in the other countries automatically.
2. **Localization** (English U.S.): a display name (e.g. "Yearly") and a short description (e.g. "Unlimited unlocks and all puzzles").
3. **Review Information**: upload a screenshot of the paywall.
4. Only on **Pro Yearly**: **Introductory Offers → (+)**, type **Free**, duration **1 Week**, eligibility **New subscribers**, all countries.

### ☐ 10. Fill in the app information
- **Privacy Policy URL:** https://nis7777.github.io/lockie/privacy.html
- **Support URL:** https://nis7777.github.io/lockie/
- **Terms of Use:** add the line `Terms of Use: https://nis7777.github.io/lockie/terms.html` at the end of the description. Apple requires it for subscriptions.
- **Category:** Primary **Productivity**, Secondary **Education**.
- **App Privacy:** **Data Not Collected** (answers in `AppStore/privacy_labels.md`).
- **Age Rating:** answer using `AppStore/age_rating.md`.
- **Pricing and Availability:** price **Free**, all countries.

### ☐ 11. Add the store listing
Copy from `AppStore/metadata.md`: name, subtitle, promotional text, description and keywords (English). Upload the 6.9" screenshots from `AppStore/screenshots/`.

## PART 3: Once the Screen Time approval arrives

### ☐ 12. Upload a build
1. In Xcode, set **Team** to the account holder's team on all targets → **Product → Archive**.
2. **Distribute App → App Store Connect → Upload**.

### ☐ 13. Test with TestFlight
1. App Store Connect → **TestFlight**, then add internal testers.
2. On a real iPhone, test:
   - locking an app
   - the block screen
   - solving a puzzle and getting the unlock
   - the app locking again when the time runs out
   - starting the 7-day trial (sandbox, so no real money)
   - Restore Purchases

### ☐ 14. Submit for review
1. Open the version page → **Build** → select the build.
2. Under **In-App Purchases and Subscriptions**, tick both subscriptions (Yearly and Monthly). The first subscriptions must go in together with the app.
3. **App Review Information**: no sign-in required. Paste the notes from `AppStore/review_notes.md`. Add a contact name, phone and email.
4. **Add for Review → Submit for Review.** 🎉
