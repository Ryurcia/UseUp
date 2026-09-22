import SwiftUI
import RevenueCatUI

/// Renders whichever paywall is attached to `Offerings.current` in the RevenueCat dashboard —
/// not a hand-built screen. `onDismiss` fires both on close-button tap and after a successful
/// purchase (`PaywallView.onRequestedDismissal` covers both per RevenueCatUI's own docs).
struct UseUpPaywallView: View {
    @EnvironmentObject private var session: AppSession
    let onDismiss: () -> Void
    @ObservedObject private var subscriptions = RevenueCatManager.shared
    @State private var isPreparing = true

    var body: some View {
        Group {
            if let userId = session.currentUserId?.uuidString, subscriptions.identifiedUserId == userId {
                paywall
            } else {
                VStack(spacing: 20) {
                    if isPreparing {
                        ProgressView("Loading subscription…")
                    } else {
                        Text("Unable to load subscription.")
                        Button("Try Again") { Task { await prepareSubscription() } }
                    }
                    Button("Close", action: onDismiss)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: session.currentUserId) { await prepareSubscription() }
    }

    private func prepareSubscription() async {
        isPreparing = true
        if let userId = session.currentUserId {
            await subscriptions.logIn(userId: userId.uuidString)
        }
        guard !Task.isCancelled else { return }
        isPreparing = false
    }

    private var paywall: some View {
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
