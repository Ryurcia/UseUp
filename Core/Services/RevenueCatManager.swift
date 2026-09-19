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
        let hasActiveEntitlement = !customerInfo.entitlements.active.isEmpty
        isPremium = hasActiveEntitlement

        // Supabase's profiles.subscription_type (synced via the RevenueCat webhook) is the
        // source of truth. This on-device check may only push session.isPremium UP — a fast
        // "yes" right after a fresh purchase, before the webhook + profile refetch land —
        // never DOWN. Right after logIn() identifies a user, RevenueCat's backend can still
        // be resolving their historical entitlements and briefly report none, which would
        // otherwise clobber a value Supabase had already correctly set.
        if hasActiveEntitlement {
            session?.isPremium = true
        }
    }
}

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await self.updatePremiumState(from: customerInfo)
        }
    }
}
