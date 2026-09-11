import Foundation
import RevenueCat

enum RevenueCatConstants {
    static let entitlementID = "UseUp Pro"
}

/// Configuration, identity, and entitlement-sync only — RevenueCatUI's `PaywallView` owns
/// offerings/purchase/restore directly now (see `Features/Paywall/UseUpPaywallView.swift`), so
/// this doesn't need the manual `fetchOfferings`/`purchase`/`restorePurchases` methods the
/// pre-dashboard-paywall version had.
@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var isPremium = false
    /// Set by `UseUp.swift` after `AppSession` is constructed — lets entitlement changes push
    /// straight into `session.isPremium` for instant on-device sync, same hybrid pattern as every
    /// prior purchase SDK integration here (Supabase `profiles.subscription_type`, updated
    /// server-side by `supabase/functions/revenuecat-webhook`, remains authoritative).
    weak var session: AppSession?

    private override init() {
        super.init()
    }

    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(
            with: .builder(withAPIKey: RevenueCatConfig.apiKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
        Purchases.shared.delegate = self
    }

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
            await updatePremiumState(from: customerInfo)
        } catch {
            isPremium = false
            session?.isPremium = false
        }
    }

    func checkEntitlements() async {
        if let customerInfo = try? await Purchases.shared.customerInfo() {
            await updatePremiumState(from: customerInfo)
        }
    }

    private func updatePremiumState(from customerInfo: CustomerInfo) async {
        // Any active entitlement counts — avoids breakage if the entitlement ID in the dashboard
        // doesn't exactly match RevenueCatConstants.entitlementID.
        isPremium = !customerInfo.entitlements.active.isEmpty
        session?.isPremium = isPremium
    }
}

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await self.updatePremiumState(from: customerInfo)
        }
    }
}
