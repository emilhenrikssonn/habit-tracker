import Foundation
import StoreKit

/// The subscription: loads the two plans, buys and restores them, and tracks whether the person has access.
/// Apple handles payment; nothing about the purchase is stored or sent anywhere by the app.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    static let monthlyID = "com.emilhenriksson.habittracker.monthly"
    static let yearlyID = "com.emilhenriksson.habittracker.yearly"
    static let productIDs = [monthlyID, yearlyID]

    enum Access { case unknown, subscribed, notSubscribed }

    private(set) var access: Access = .unknown
    /// Monthly first, then yearly. Empty until loaded.
    private(set) var products: [Product] = []
    private(set) var loadFailed = false
    /// Whether the free trial still applies. A person only gets it once.
    private(set) var trialEligible = false

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SKIP_PAYWALL"] == "1" { access = .subscribed }
        #endif
        // Renewals, cancellations and purchases made outside the app arrive here.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshAccess()
            }
        }
    }

    func start() async {
        await refreshAccess()
        await loadProducts()
    }

    func loadProducts() async {
        loadFailed = false
        do {
            let loaded = try await Product.products(for: Store.productIDs)
            products = Store.productIDs.compactMap { id in loaded.first { $0.id == id } }
            loadFailed = products.isEmpty
            if let subscription = products.first?.subscription {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            loadFailed = true
        }
    }

    func refreshAccess() async {
        #if DEBUG
        if debugUnlocked { access = .subscribed; return }
        #endif
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Store.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        access = active ? .subscribed : .notSubscribed
    }

    /// Returns false when the person cancelled or the purchase is waiting for approval.
    func purchase(_ product: Product) async throws -> Bool {
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else { return false }
            await transaction.finish()
            await refreshAccess()
            return access == .subscribed
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshAccess()
    }

    #if DEBUG
    @ObservationIgnored private var debugUnlocked = ProcessInfo.processInfo.environment["SKIP_PAYWALL"] == "1"

    /// Debug builds only: get past the paywall without a purchase.
    func debugUnlock() {
        debugUnlocked = true
        access = .subscribed
    }
    #endif
}

extension Product {
    /// "month" or "year".
    var periodName: String {
        guard let unit = subscription?.subscriptionPeriod.unit else { return "" }
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }

    /// Length of the free trial, e.g. "1 week", or nil when there isn't one.
    var freeTrialLength: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        switch offer.period.unit {
        case .day: return n == 7 ? "1 week" : "\(n) \(n == 1 ? "day" : "days")"
        case .week: return "\(n) \(n == 1 ? "week" : "weeks")"
        case .month: return "\(n) \(n == 1 ? "month" : "months")"
        case .year: return "\(n) \(n == 1 ? "year" : "years")"
        @unknown default: return nil
        }
    }
}
