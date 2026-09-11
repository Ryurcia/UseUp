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
    }
}
