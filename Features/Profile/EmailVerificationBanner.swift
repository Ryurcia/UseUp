import SwiftUI
import PhosphorSwift

/// Persistent, non-dismissible nudge shown on the Profile screen (and mirrored in the Notifications
/// tab, see `NotificationListView`) until `session.isEmailVerified`. Tapping sends a fresh one-time
/// code to the user's own email and opens `OTPVerificationView` to enter it.
struct EmailVerificationBanner: View {
    @EnvironmentObject private var session: AppSession
    @State private var showVerificationSheet = false

    var body: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.envelope.regular
                .frame(width: 12, height: 12)
                .foregroundStyle(Sourdough.Ramp.onFilled)
                .frame(width: 24, height: 24)
                .background(Sourdough.Ramp.honey500)
                .clipShape(Circle())

            Text("Finish setting up your account — verify your email")
                .sourdoughTextStyle(.subhead, color: Sourdough.Ramp.honey700)
                .frame(maxWidth: .infinity, alignment: .leading)

            Ph.caretRight.bold
                .frame(width: 7, height: 12)
                .foregroundStyle(Sourdough.Ramp.honey500)
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Ramp.honey50)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.row, style: .continuous)
                .stroke(Sourdough.Ramp.honey200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await session.sendEmailVerificationCode() }
            showVerificationSheet = true
        }
        .sheet(isPresented: $showVerificationSheet) {
            OTPVerificationView(email: session.currentUserEmail ?? "")
                .environmentObject(session)
        }
    }
}
