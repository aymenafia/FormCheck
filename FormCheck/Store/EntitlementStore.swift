import Combine
import Foundation
import RevenueCat
import StoreKit

/// Subscription state, powered by RevenueCat (analytics, experiments,
/// remote offerings) with a StoreKit 2 safety net so anyone who subscribed
/// before RevenueCat was added is never locked out.
@MainActor
final class EntitlementStore: NSObject, ObservableObject {
    static let apiKey = "appl_HjSspQYwWMBEaRVzZFnPWAPxQBO"
    static let entitlementID = "pro"
    static let weeklyID = "formcheck.weekly"
    static let yearlyID = "formcheck.yearly"
    static let productIDs: Set<String> = [weeklyID, yearlyID]

    @Published private(set) var isSubscribed = false
    /// False until the first entitlement check answers — lets the UI avoid
    /// flashing the paywall at subscribers on cold launch.
    @Published private(set) var entitlementsLoaded = false
    @Published private(set) var packages: [Package] = []
    @Published private(set) var isLoadingProducts = false
    /// Set while the user is inside a free trial (drives the reminder copy).
    @Published private(set) var trialEndDate: Date?
    @Published var lastError: String?

    var annual: Package? { packages.first { $0.storeProduct.productIdentifier == Self.yearlyID } ?? packages.first { $0.packageType == .annual } }
    var weekly: Package? { packages.first { $0.storeProduct.productIdentifier == Self.weeklyID } ?? packages.first { $0.packageType == .weekly } }

    private var rcActive = false
    private var storeKitActive = false
    private var updatesTask: Task<Void, Never>?

    override init() {
        super.init()
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: Self.apiKey)
        }
        Purchases.shared.delegate = self

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlement()
            self?.entitlementsLoaded = true
            await self?.loadProducts()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Products

    func loadProducts() async {
        guard packages.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            packages = offerings.current?.availablePackages ?? []
        } catch {
            packages = [] // the paywall shows an inline "Try Again"
        }
    }

    // MARK: - Purchase / restore

    /// Returns true when the purchase unlocked Pro.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            if isSubscribed { await TrialReminder.requestPermissionIfTrial(endDate: trialEndDate) }
            return isSubscribed
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            await refreshStoreKit()
            if !isSubscribed { lastError = "No active subscription found to restore." }
        } catch {
            lastError = "Couldn't reach the App Store to restore. Check your connection and try again."
        }
    }

    func presentCodeRedemption() {
        Purchases.shared.presentCodeRedemptionSheet()
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        await refreshStoreKit()
        // Migrate pre-RevenueCat subscribers once, so RC's dashboard sees them.
        if storeKitActive && !rcActive && !UserDefaults.standard.bool(forKey: "rc.synced") {
            UserDefaults.standard.set(true, forKey: "rc.synced")
            if let info = try? await Purchases.shared.syncPurchases() { apply(info) }
        }
    }

    private func refreshStoreKit() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement,
               Self.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        storeKitActive = active
        isSubscribed = rcActive || storeKitActive
    }

    fileprivate func apply(_ info: CustomerInfo) {
        let ent = info.entitlements[Self.entitlementID]
        rcActive = ent?.isActive == true
        isSubscribed = rcActive || storeKitActive
        if let ent, ent.isActive, ent.periodType == .trial, ent.willRenew, let end = ent.expirationDate {
            trialEndDate = end
            TrialReminder.schedule(trialEnds: end)
        } else {
            trialEndDate = nil
            TrialReminder.cancel()
        }
    }
}

extension EntitlementStore: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in self.apply(customerInfo) }
    }
}

// MARK: - Package helpers

extension Package {
    /// Free-trial length in days, read from the real StoreKit intro offer so
    /// the paywall can never promise a trial the product doesn't have.
    var trialDays: Int? {
        guard let intro = storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let p = intro.subscriptionPeriod
        switch p.unit {
        case .day: return p.value
        case .week: return p.value * 7
        case .month: return p.value * 30
        case .year: return p.value * 365
        @unknown default: return p.value
        }
    }

    /// "week" / "month" / "year" from the real subscription period.
    var periodWord: String {
        switch storeProduct.subscriptionPeriod?.unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        default: return packageType == .annual ? "year" : "week"
        }
    }

    /// Yearly price expressed per week ("$0.77") for price anchoring.
    var perWeekPrice: String? {
        guard storeProduct.productIdentifier == EntitlementStore.yearlyID else { return nil }
        let weekly = storeProduct.price / 52
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = storeProduct.priceFormatter?.locale ?? .current
        return f.string(from: weekly as NSDecimalNumber)
    }
}
