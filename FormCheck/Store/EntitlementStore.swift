import Combine
import Foundation
import StoreKit

/// StoreKit 2 subscription state — no SDK dependency, no server.
/// Product IDs must match App Store Connect (and Products.storekit for local testing).
@MainActor
final class EntitlementStore: ObservableObject {
    static let weeklyID = "formcheck.weekly"
    static let yearlyID = "formcheck.yearly"
    static let productIDs: Set<String> = [weeklyID, yearlyID]

    @Published private(set) var isSubscribed = false
    /// False until the first entitlement check answers — lets the UI avoid
    /// flashing the paywall at subscribers on cold launch.
    @Published private(set) var entitlementsLoaded = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published var lastError: String?

    var weekly: Product? { products.first { $0.id == Self.weeklyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlement()
                }
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlement()
            self?.entitlementsLoaded = true
            await self?.loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        // A load failure surfaces via the paywall's inline "Try Again" (products
        // stay empty) — no alert, to avoid double-messaging the same problem.
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                // Charged, but StoreKit couldn't verify (tampered device). Don't
                // grant access silently — tell the user so they aren't stranded.
                lastError = "Your purchase couldn't be verified. If you were charged, tap Restore or contact support."
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return // user backed out of the sign-in — say nothing
        } catch {
            // A genuine reachability problem, not "no subscription".
            lastError = "Couldn't reach the App Store to restore. Check your connection and try again."
            return
        }
        await refreshEntitlement()
        if !isSubscribed {
            lastError = "No active subscription found to restore."
        }
    }

    private func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

}
