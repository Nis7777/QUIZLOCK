import Foundation
import Observation
import StoreKit
import UserNotifications

/// StoreKit 2 subscriptions (group "Lockie Pro"). Pro = an active, verified, non-revoked subscription in the group.
/// Prices, periods and the free trial always come from StoreKit; nothing here is hard-coded.
@Observable
@MainActor
final class Store {
    private(set) var yearly: Product?
    private(set) var monthly: Product?
    private(set) var yearlyOffer: Product?
    private(set) var isPurchasing = false
    /// The user can still get the yearly plan's introductory offer (free trial).
    private(set) var isEligibleForTrial = false
    /// Active subscription details (nil when not subscribed).
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    private(set) var willAutoRenew = true
    private(set) var isInTrial = false
    var lastError: String?

    /// Called whenever entitlement is (re)computed.
    @ObservationIgnored var onEntitlementChange: ((Bool) -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    static let productIDs = Brand.proProductIDs

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    enum LoadState { case loading, loaded, failed }
    private(set) var loadState: LoadState = .loading

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: Self.productIDs)
            yearly = products.first { $0.id == Brand.iapProYearly }
            monthly = products.first { $0.id == Brand.iapProMonthly }
            yearlyOffer = products.first { $0.id == Brand.iapProYearlyOffer }
            loadState = (yearly != nil && monthly != nil) ? .loaded : .failed
            await refreshTrialEligibility()
        } catch {
            loadState = .failed
        }
    }

    private func refreshTrialEligibility() async {
        guard let subscription = yearly?.subscription, subscription.introductoryOffer?.paymentMode == .freeTrial else {
            isEligibleForTrial = false
            return
        }
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }

    func refreshEntitlements() async {
        var active: Transaction?
        let now = Date()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  t.productType == .autoRenewable,
                  Self.productIDs.contains(t.productID),
                  t.revocationDate == nil,
                  (t.expirationDate ?? .distantFuture) > now else { continue }
            if (t.expirationDate ?? .distantFuture) > (active?.expirationDate ?? .distantPast) { active = t }
        }
        activeProductID = active?.productID
        expirationDate = active?.expirationDate
        isInTrial = active.map(Self.isIntroductory) ?? false
        willAutoRenew = await autoRenewStatus(for: active)
        await refreshTrialEligibility()
        TrialReminder.update(trialEndsAt: isInTrial && willAutoRenew ? expirationDate : nil)
        onEntitlementChange?(active != nil)
    }

    var isSubscribed: Bool { activeProductID != nil }

    private static func isIntroductory(_ t: Transaction) -> Bool {
        if #available(iOS 17.2, *) {
            return t.offer?.type == .introductory
        } else {
            return t.offerType == .introductory
        }
    }

    private func autoRenewStatus(for transaction: Transaction?) async -> Bool {
        guard let transaction, let product = [yearly, monthly, yearlyOffer].compactMap({ $0 }).first,
              let statuses = try? await product.subscription?.status else { return true }
        for status in statuses {
            guard case .verified(let t) = status.transaction, t.originalID == transaction.originalID,
                  case .verified(let info) = status.renewalInfo else { continue }
            return info.willAutoRenew
        }
        return true
    }

    @discardableResult
    func purchase(_ product: Product?) async -> Bool {
        guard let product else {
            lastError = String(localized: "The App Store isn't available right now. Please try again.")
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = String(localized: "The purchase couldn't be verified.")
                    return false
                }
                await transaction.finish()
                if Self.isIntroductory(transaction) {
                    // The trial timeline promises a reminder; ask for notifications now if we haven't yet.
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                }
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    /// Loads prices again if they're missing (e.g. the paywall opened while offline).
    func loadProductsIfNeeded() async {
        if yearly == nil || monthly == nil || loadState == .failed { await loadProducts() }
    }

    // MARK: Display helpers (all computed from StoreKit values)

    /// Length of the yearly plan's free trial in days, if it has one.
    var trialDays: Int? {
        guard let offer = yearly?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return Self.days(in: offer.period) * offer.periodCount
    }

    /// The free trial can be offered to this user right now.
    var showsTrial: Bool { isEligibleForTrial && trialDays != nil }

    /// "$39.99/year", "$9.99/month".
    func pricePerPeriod(_ product: Product?) -> String? {
        guard let product else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return Self.pricePerPeriod(product.displayPrice, period: period)
    }

    static func pricePerPeriod(_ price: String, period: Product.SubscriptionPeriod) -> String {
        switch (period.unit, period.value) {
        case (.year, 1): return String(localized: "\(price)/year")
        case (.month, 1): return String(localized: "\(price)/month")
        case (.week, 1): return String(localized: "\(price)/week")
        case (.day, 1): return String(localized: "\(price)/day")
        default: return String(localized: "\(price) every \(period.value) \(unitName(period.unit))")
        }
    }

    private static func unitName(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return String(localized: "days")
        case .week: return String(localized: "weeks")
        case .month: return String(localized: "months")
        case .year: return String(localized: "years")
        @unknown default: return ""
        }
    }

    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }

    private static func months(in period: Product.SubscriptionPeriod) -> Decimal {
        switch period.unit {
        case .year: return Decimal(period.value * 12)
        case .month: return Decimal(period.value)
        case .week: return Decimal(period.value) * 7 / 30
        case .day: return Decimal(period.value) / 30
        @unknown default: return 1
        }
    }

    /// The yearly price per month, e.g. "$3.33".
    var yearlyMonthlyEquivalent: String? {
        guard let yearly, let period = yearly.subscription?.subscriptionPeriod else { return nil }
        return (yearly.price / Self.months(in: period)).formatted(yearly.priceFormatStyle)
    }

    /// How much yearly saves over 12 months of monthly (67% with $39.99 vs $9.99).
    var yearlySavingsPercent: Int? {
        guard let yearly, let monthly,
              let yp = yearly.subscription?.subscriptionPeriod, let mp = monthly.subscription?.subscriptionPeriod else { return nil }
        let monthlyPerMonth = monthly.price / Self.months(in: mp)
        let yearlyPerMonth = yearly.price / Self.months(in: yp)
        return Self.percentOff(yearlyPerMonth, from: monthlyPerMonth)
    }

    /// Exit offer discount vs the regular yearly price (25% with $29.99 vs $39.99).
    var offerDiscountPercent: Int? {
        guard let yearly, let yearlyOffer else { return nil }
        return Self.percentOff(yearlyOffer.price, from: yearly.price)
    }

    static func percentOff(_ price: Decimal, from reference: Decimal) -> Int? {
        guard reference > 0, price < reference else { return nil }
        let ratio = NSDecimalNumber(decimal: price / reference).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }
}

/// The local "Your free trial ends in 2 days" notification (day 5 of a 7-day trial).
enum TrialReminder {
    static let id = "reminder.trialEnding"

    /// Schedules the reminder for `trialEndsAt − 2 days`, or removes it when `trialEndsAt` is nil.
    static func update(trialEndsAt: Date?, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        guard let end = trialEndsAt else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }
        let fire = end.addingTimeInterval(-Double(Brand.trialReminderDaysBeforeEnd) * 24 * 3600)
        guard fire > now else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your free trial ends in 2 days")
        content.body = String(localized: "You won't be charged if you cancel before then in Settings → Apple ID → Subscriptions.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSince(now)), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - Counting prices

/// A price as a number plus how to print any value on the way up to it ("$39.99/year").
struct CountingPrice {
    let value: Double
    let format: (Double) -> String
}

extension Store {
    /// For CountingText: the product's price and a formatter in its own currency (with "/year" etc.).
    func countingPrice(_ product: Product?, perPeriod: Bool = true) -> CountingPrice? {
        guard let product else { return nil }
        let style = product.priceFormatStyle
        let period = product.subscription?.subscriptionPeriod
        return CountingPrice(value: NSDecimalNumber(decimal: product.price).doubleValue) { value in
            let amount = Decimal(value).formatted(style)
            guard perPeriod, let period else { return amount }
            return Self.pricePerPeriod(amount, period: period)
        }
    }
}
