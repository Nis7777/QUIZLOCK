import Foundation
import Observation
import StoreKit

/// StoreKit 2 lifetime purchases (two non-consumables; either grants lifetime access).
@Observable
@MainActor
final class Store {
    private(set) var standard: Product?
    private(set) var promo: Product?
    private(set) var isPurchasing = false
    var lastError: String?

    /// Called whenever entitlement is (re)computed.
    @ObservationIgnored var onEntitlementChange: ((Bool) -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    static let productIDs = [Brand.iapLifetimeStandard, Brand.iapLifetimePromo]

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
            standard = products.first { $0.id == Brand.iapLifetimeStandard }
            promo = products.first { $0.id == Brand.iapLifetimePromo }
            loadState = (standard != nil && promo != nil) ? .loaded : .failed
        } catch {
            loadState = .failed
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                owned = true
            }
        }
        onEntitlementChange?(owned)
    }

    @discardableResult
    func purchase(_ product: Product?) async -> Bool {
        guard let product else {
            lastError = "The App Store isn't available right now. Please try again."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "The purchase couldn't be verified."
                    return false
                }
                await transaction.finish()
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

    // MARK: Display helpers

    var standardPrice: String? { standard?.displayPrice }
    var promoPrice: String? { promo?.displayPrice }

    /// Discount computed from the two real StoreKit prices (never hard-coded). Nil until both load.
    var discountPercent: Int? {
        guard let std = standard, let pro = promo, std.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: pro.price / std.price).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }

    /// Loads prices again if they're missing (e.g. the paywall opened while offline).
    func loadProductsIfNeeded() async {
        if standard == nil || promo == nil || loadState == .failed { await loadProducts() }
    }
}
