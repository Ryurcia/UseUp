import Foundation
import RevenueCat

enum RevenueCatConstants {
    static let entitlementID = "useup_pro"
}

/// Configuration, identity, and entitlement-sync only — RevenueCatUI's `PaywallView` owns
/// offerings/purchase/restore directly now (see `Features/Paywall/UseUpPaywallView.swift`), so
/// this doesn't need the manual `fetchOfferings`/`purchase`/`restorePurchases` methods the
/// pre-dashboard-paywall version had.
@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var isPremium = false
    @Published private(set) var identifiedUserId: String?
    private var identityTask: Task<Void, Never>?
    private var requestedUserId: String?
    private var identityToken = UUID()
    /// Set by `UseUp.swift` after `AppSession` is constructed — lets entitlement changes push
    /// straight into `session.isPremium` for instant on-device sync, same hybrid pattern as every
    /// prior purchase SDK integration here (Supabase `profiles.subscription_type`, updated
    /// server-side by `supabase/functions/revenuecat-webhook`, remains authoritative).
    weak var session: AppSession?

    private override init() {
        super.init()
    }

    func configure() {
        // Unconditional (not just Debug) while the app is still TestFlight-only — RevenueCat's
        // own SDK logging (network calls, logIn/purchase outcomes) is otherwise silently
        // discarded on Release-configuration builds, which is exactly where it's needed most.
        // Dial back to `.warn` before public launch.
        Purchases.logLevel = .debug
        Purchases.configure(
            with: .builder(withAPIKey: RevenueCatConfig.apiKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
        Purchases.shared.delegate = self
    }

    func logIn(userId: String) async {
        guard session?.currentUserId?.uuidString == userId else { return }
        if let identityTask, requestedUserId == userId {
            await identityTask.value
            return
        }
        if identifiedUserId == userId, identityTask == nil { return }
        let previous = identityTask
        let token = UUID()
        identityToken = token
        requestedUserId = userId
        identifiedUserId = nil
        isPremium = false
        // Identity transitions are serialized even if a caller disappears or signs out mid-login.
        let task = Task {
            await previous?.value
            guard identityToken == token, session?.currentUserId?.uuidString == userId else { return }
            do {
                let (customerInfo, _) = try await Purchases.shared.logIn(userId)
                guard identityToken == token, session?.currentUserId?.uuidString == userId else { return }
                identifiedUserId = userId
                await updatePremiumState(from: customerInfo)
            } catch {
                // Leave identity unresolved so the paywall can offer a retry.
            }
        }
        identityTask = task
        await task.value
        if identityToken == token { identityTask = nil }
    }

    func logOut() async {
        guard session?.currentUserId == nil else { return }
        let previous = identityTask
        let token = UUID()
        identityToken = token
        requestedUserId = nil
        identifiedUserId = nil
        isPremium = false
        let task = Task {
            await previous?.value
            guard identityToken == token, session?.currentUserId == nil else { return }
            _ = try? await Purchases.shared.logOut()
        }
        identityTask = task
        await task.value
        if identityToken == token { identityTask = nil }
    }

    func checkEntitlements() async {
        guard let userId = session?.currentUserId?.uuidString else { return }
        await logIn(userId: userId)
        guard identifiedUserId == userId else { return }
        if let customerInfo = try? await Purchases.shared.customerInfo(),
           identifiedUserId == userId, session?.currentUserId?.uuidString == userId {
            await updatePremiumState(from: customerInfo)
        }
    }

    private func updatePremiumState(from customerInfo: CustomerInfo) async {
        guard let identifiedUserId,
              identifiedUserId == session?.currentUserId?.uuidString,
              Purchases.shared.appUserID == identifiedUserId else { return }
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
