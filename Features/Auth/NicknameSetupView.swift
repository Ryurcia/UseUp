import SwiftUI

struct NicknameSetupView: View {
    @EnvironmentObject private var session: AppSession
    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        NicknameOnboardingView(username: $username, displayName: $displayName) {
            Task { await session.completeNicknameOnboarding(nickname: username, displayName: displayName) }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { displayName = session.currentUserDisplayName ?? "" }
    }
}
