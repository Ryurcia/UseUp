import SwiftUI
import RevenueCatUI

/// Renders whichever paywall is attached to `Offerings.current` in the RevenueCat dashboard —
/// not a hand-built screen. `onDismiss` fires both on close-button tap and after a successful
/// purchase (`PaywallView.onRequestedDismissal` covers both per RevenueCatUI's own docs).
struct UseUpPaywallView: View {
    @EnvironmentObject private var session: AppSession
    let onDismiss: () -> Void

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onRequestedDismissal {
                onDismiss()
            }
            .onPurchaseCompleted { customerInfo in
                session.isPremium = !customerInfo.entitlements.active.isEmpty
            }
            .onRestoreCompleted { customerInfo in
                session.isPremium = !customerInfo.entitlements.active.isEmpty
            }
            .onPurchaseFailure { _ in
                // Backstop for a stale local "not premium" gate re-showing the paywall for an
                // account that already owns the entitlement (StoreKit surfaces its own
                // already-subscribed alert in that case) — re-check and self-dismiss instead of
                // leaving the user stuck with no way out.
                Task {
                    await RevenueCatManager.shared.checkEntitlements()
                    if RevenueCatManager.shared.isPremium {
                        session.isPremium = true
                        onDismiss()
                    }
                }
            }
    }
}
