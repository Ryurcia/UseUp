import Foundation
import RevenueCat
import Supabase

enum SubscriptionTier: String {
    case free
    case premium
}

enum RevenueCatConstants {
    static let apiKey = "test_aEsRNMyezdCbMuWxrmIkUOgKIjC"
    static let entitlementID = "UseUp Pro"
    static let monthlyProductID = "monthly"
    static let yearlyProductID = "yearly"
}

@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isPremium = false
    @Published private(set) var currentOffering: Offering?

    private let client = SupabaseManager.client

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(
            with: .builder(withAPIKey: RevenueCatConstants.apiKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )

        Purchases.shared.delegate = self
    }

    // MARK: - User Identity

    func logIn(userId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            await updatePremiumState(from: customerInfo)
        } catch {
            // Non-critical — user stays on free tier
        }
    }

    func logOut() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            self.isPremium = false
        } catch {
            self.isPremium = false
        }
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            // Offerings unavailable
        }
    }

    // MARK: - Purchases

    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        await updatePremiumState(from: result.customerInfo)
        return result.customerInfo
    }

    func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        await updatePremiumState(from: customerInfo)
        return customerInfo
    }

    // MARK: - Entitlement Check

    func checkEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await updatePremiumState(from: customerInfo)
        } catch {
            // Keep current state on error
        }
    }

    // MARK: - Subscription Tier

    var subscriptionTier: SubscriptionTier {
        isPremium ? .premium : .free
    }

    // MARK: - Premium State + Supabase Sync

    private func updatePremiumState(from customerInfo: CustomerInfo) async {
        self.customerInfo = customerInfo
        let newPremium = customerInfo.entitlements[RevenueCatConstants.entitlementID]?.isActive == true
        let changed = newPremium != isPremium
        self.isPremium = newPremium

        // Sync to Supabase whenever the state changes
        if changed {
            await syncSubscriptionToSupabase(isPremium: newPremium)
        }
    }

    private func syncSubscriptionToSupabase(isPremium: Bool) async {
        guard let userId = try? await client.auth.session.user.id else { return }
        let type = isPremium ? "premium" : "free"
        do {
            try await client
                .from("profiles")
                .update(["subscription_type": type])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            // Non-critical — local state is still correct
        }
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await self.updatePremiumState(from: customerInfo)
        }
    }
}
