# App Store setup for the account holder

Every step needs the paid Apple Developer account login. Go in order and tick each step off as you finish it.

## PART 1: Do first (the slow approval starts here)

### 1. Add Dinis to the team
1. Go to **appstoreconnect.apple.com → Users and Access → (+)**.
2. Enter Dinis's Apple ID email.
3. Tick the roles **Developer** and **App Manager** → **Invite**.
4. Dinis accepts the email invite.

### 2. Accept the Paid Apps agreement
1. App Store Connect → **Business** (Agreements, Tax, and Banking).
2. **Paid Apps Agreement → View and Agree to Terms**.
3. Add the **bank account** and complete the **tax forms**.
4. Wait until the status says **Active**. Subscriptions won't work, even in sandbox testing, before that.

### 3. Join the Small Business Program
Go to **developer.apple.com/app-store/small-business-program → Enroll**. Apple then takes 15% instead of 30%.

### 4. Create the App Group
1. Go to **developer.apple.com/account → Certificates, Identifiers & Profiles → Identifiers → (+)**.
2. Choose **App Groups → Continue**.
3. Description: `QuizLock Group`. Identifier: `group.com.dinismagina.quizlock` → **Register**.

### 5. Register the 6 bundle IDs
For each one: **Identifiers → (+) → App IDs → App → Continue**, choose **Explicit**, paste the Bundle ID, tick the capabilities shown, then **Continue → Register**.

| # | Bundle ID (copy exactly) | Description | Family Controls | App Groups | iCloud |
|---|---|---|---|---|---|
| 1 | `com.dinismagina.quizlock` | QuizLock App | Yes | Yes | Yes |
| 2 | `com.dinismagina.quizlock.ShieldConfiguration` | QuizLock Shield | Yes | Yes | No |
| 3 | `com.dinismagina.quizlock.ShieldAction` | QuizLock Shield Action | Yes | Yes | No |
| 4 | `com.dinismagina.quizlock.DeviceActivityMonitor` | QuizLock Monitor | Yes | Yes | No |
| 5 | `com.dinismagina.quizlock.ScreenTimeReport` | QuizLock Report | Yes | Yes | No |
| 6 | `com.dinismagina.quizlock.Widgets` | QuizLock Widgets | No | Yes | No |

iCloud on the main app is only used for key-value storage (it syncs streaks and stats), so no iCloud container is needed.

After registering each one, open it → next to **App Groups** click **Configure** → tick `group.com.dinismagina.quizlock` → **Save**.

**Never change these IDs after this step.** Apple's approval is tied to them.

### 6. Request the Screen Time permission (the slow one)
1. While logged in, go to **developer.apple.com/contact/request/family-controls-distribution**.
2. Submit **one request for each of the 5 IDs with Family Controls = Yes** (rows 1–5; the widget doesn't need it).
3. Paste this as the description:

> QuizLock is a self-control app that helps people reduce compulsive scrolling. Users choose their own distracting apps using FamilyActivityPicker with individual authorization (.individual), and the app blocks them with ManagedSettings shields. To unlock an app for a short, user-chosen time, the user solves a quick puzzle (chess, Sudoku, math or word game). DeviceActivity re-applies the block when the time ends. All Screen Time data, app tokens and settings stay on the device. Nothing is sent to a server, there are no accounts and no tracking. It is for adults managing their own phone use, not for monitoring others.

4. **Screenshot each form before you press submit.** Apple sends no confirmation.
5. When the approval email arrives, check whether it says **team** (it covers future apps too) or lists specific IDs, and tell Dinis.

## PART 2: Do while waiting for approval

### 7. Create the app
1. App Store Connect → **Apps → (+) → New App**.
2. Platform **iOS**, Name **QuizLock: Puzzle App Blocker**, Primary language **English (U.S.)**.
3. Bundle ID `com.dinismagina.quizlock`, SKU `quizlock001`, User Access **Full Access** → **Create**.
4. Open **App Information**, copy the **Apple ID** number, and send it to Dinis (it goes into the app's "Rate" button).

### 8. Create the subscription group
1. In the app → **Monetization → Subscriptions → Create** a subscription group.
2. Reference name: **QuizLock Pro**.
3. Add group localizations: English (U.S.) and Portuguese (Portugal), display name **QuizLock Pro** for both.

### 9. Create the 3 subscriptions inside that group

| Reference name | Product ID (copy exactly) | Duration | Price (USA) | Level | Introductory offer |
|---|---|---|---|---|---|
| Pro Yearly | `com.dinismagina.quizlock.pro.yearly` | 1 Year | $39.99 | 1 | Free, 1 Week |
| Pro Yearly Offer | `com.dinismagina.quizlock.pro.yearly.offer` | 1 Year | $29.99 | 1 | None |
| Pro Monthly | `com.dinismagina.quizlock.pro.monthly` | 1 Month | $9.99 | 2 | None |

For each subscription:
1. **Subscription Prices → Add Subscription Price**: set the USA price and let Apple fill in the other countries automatically.
2. **Localization**: add English (U.S.) and Portuguese (Portugal), each with a display name (e.g. "Yearly" / "Anual") and a short description (e.g. "Unlimited unlocks and all puzzles" / "Desbloqueios ilimitados e todos os puzzles").
3. **Review Information**: upload a screenshot of the paywall (Dinis will send it).
4. Only on **Pro Yearly**: **Subscription Prices → Set Up Introductory Offer**, all countries, type **Free**, duration **1 Week**. Apple automatically limits it to people who have never subscribed to the group.

Then, on the subscription group page, check the levels match the table: both yearly plans on level 1, monthly on level 2 (drag to reorder if needed).

### 10. Fill in the app information
- **Privacy Policy URL:** https://nis7777.github.io/lockfeeddupe/privacy.html
- **Support URL:** https://nis7777.github.io/lockfeeddupe/
- **Terms of Use:** the description already ends with `Terms of Use: https://nis7777.github.io/lockfeeddupe/terms.html`. Apple requires it for subscriptions, so don't remove it.
- Open all three links in a browser first and make sure they load. If any is a 404, tell Dinis before submitting.
- **Category:** Primary **Productivity**, Secondary **Education**.
- **App Privacy:** **Data Not Collected** (answers in `AppStore/privacy_labels.md`).
- **Age Rating:** answer using `AppStore/age_rating.md`.
- **Pricing and Availability:** price **Free**, all countries.

### 11. Add the store listing
1. Copy from `AppStore/metadata.md`: name, subtitle, promotional text, description and keywords for **English (U.S.)**.
2. Use the language menu at the top right of the version page to add **Portuguese (Portugal)** and paste the Portuguese section of the same file.
3. Upload the 6.9" iPhone screenshots for each language from `AppStore/screenshots/en/` and `AppStore/screenshots/pt-PT/`. Dinis generates these first; the folders are empty until then.

## PART 3: Once the Screen Time approval arrives

### 12. Upload a build
1. In Xcode, set **Team** to the account holder's team on all targets → **Product → Archive**.
2. **Distribute App → App Store Connect → Upload**.

### 13. Test with TestFlight
1. App Store Connect → **TestFlight**, then add Dinis and yourself as internal testers.
2. On a real iPhone, test:
   - locking an app
   - the block screen
   - solving a puzzle and getting the unlock
   - the app locking again when the time runs out
   - starting the 7-day trial (sandbox, so no real money)
   - Restore Purchases

### 14. Submit for review
1. Open the version page → **Build** → select the build.
2. Under **In-App Purchases and Subscriptions**, tick all 3 subscriptions. The first subscriptions must go in together with the app.
3. **App Review Information**: no sign-in required. Paste the notes from `AppStore/review_notes.md`. Add a contact name, phone and email.
4. **Add for Review**, then **Submit for Review**.
