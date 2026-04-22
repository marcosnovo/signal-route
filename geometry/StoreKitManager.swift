import StoreKit
import Combine

// MARK: - StoreKitManager

/// Wraps StoreKit 2 for the single non-consumable product: full-access premium.
///
/// Responsibilities:
/// - Load the product and its localized price from the App Store.
/// - Drive a purchase or restore flow.
/// - Verify and finish every transaction.
/// - Sync `EntitlementStore.shared.isPremium` whenever a valid entitlement is found.
/// - Listen for background transaction updates (renewals, revocations, refunds).
@MainActor
final class StoreKitManager: ObservableObject {

    static let shared = StoreKitManager()

    // ── Product identifier ─────────────────────────────────────────────────
    static let productID = "com.marcosnovo.signalvoidgame.fullunlock"

    // ── Published state ────────────────────────────────────────────────────
    @Published private(set) var product:       Product?
    @Published private(set) var purchaseState: PurchaseState = .idle

    /// Simplified purchase-flow state exposed to the UI.
    enum PurchaseState: Equatable {
        case idle
        case loading        // fetching product or checking entitlements
        case purchasing     // App Store purchase sheet active
        case restoring      // AppStore.sync() in flight
        case success        // transaction verified, premium activated
        case failed(String) // localised error message
    }

    // Background task that listens for App Store transaction updates.
    private var transactionListenerTask: Task<Void, Never>?

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        transactionListenerTask = startTransactionListener()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Public API

    /// Fetch the product from App Store Connect. Safe to call multiple times.
    func loadProduct() async {
        guard product == nil else { return }
        purchaseState = .loading
        do {
            let products = try await Product.products(for: [Self.productID])
            product       = products.first
            purchaseState = .idle
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    /// Walk `Transaction.currentEntitlements` and activate premium if a valid
    /// transaction is found. Call at app launch to restore across reinstalls.
    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
    }

    /// Localized strings helper using the current language setting.
    private var S: AppStrings { AppStrings(lang: SettingsStore.shared.language) }

    /// Initiate a purchase for the full-access product.
    func purchase() async {
        guard let product else {
            purchaseState = .failed(S.purchaseProductMissing)
            return
        }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                // Awaiting parent/Ask-to-Buy approval — treat as idle for now.
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    /// Sync with the App Store and re-verify all existing entitlements.
    /// Use for the "Restore purchase" button.
    func restorePurchases() async {
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await checkEntitlements()
            // If premium was already active the state is now .success via handle(_:).
            // If nothing was found, report to the user.
            if purchaseState == .restoring {
                purchaseState = .failed(S.purchaseRestoreNone)
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    /// Reset state to idle (e.g. after the user dismisses an error alert).
    func clearState() {
        purchaseState = .idle
    }

    #if DEBUG
    /// Simulate a successful purchase without StoreKit (dev menu only).
    func simulatePurchaseSuccess() {
        EntitlementStore.shared.setPremium(true)
        purchaseState = .success
    }

    /// Simulate a failed purchase without StoreKit (dev menu only).
    func simulatePurchaseFailed() {
        purchaseState = .failed("Simulation: payment declined")
    }
    #endif

    // MARK: - Private

    /// Verify a transaction, finish it, and sync premium state.
    /// Handles activation (new purchase / restore) and revocation (refund / family removal).
    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
            guard transaction.productID == Self.productID else { return }
            if transaction.revocationDate == nil {
                // Valid entitlement — activate premium
                EntitlementStore.shared.setPremium(true)
                purchaseState = .success
                MonetizationAnalytics.shared.trackPurchaseSuccess()
            } else {
                // Revoked (refund, family sharing removed) — remove premium
                EntitlementStore.shared.setPremium(false)
                purchaseState = .idle
            }
        case .unverified:
            // Tampered or invalid — ignore silently.
            break
        }
    }

    /// Detached background task that processes incoming App Store transactions
    /// (renewals, deferred purchases, refunds) while the app is running.
    private func startTransactionListener() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }
}
