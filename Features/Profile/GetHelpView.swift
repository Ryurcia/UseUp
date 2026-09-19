import SwiftUI
import PhosphorSwift

private enum GetHelpMailto {
    static let recipient = "hello@useupnow.com"

    static func url(subject: String) -> URL {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(recipient)?subject=\(encoded)")!
    }
}

struct GetHelpView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore

    @State private var feedbackKind: FeedbackSheet.Kind?
    @State private var submitError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                actionRow(icon: Ph.warning.regular, tint: Sourdough.Ramp.terracotta100, ink: Sourdough.Ramp.terracotta600,
                          label: "Report a Bug", first: true) {
                    feedbackKind = .bug
                }
                actionRow(icon: Ph.lightbulb.regular, tint: Sourdough.Ramp.honey100, ink: Sourdough.Ramp.honey700,
                          label: "Request a Feature", first: false) {
                    feedbackKind = .feature
                }
                linkRow(icon: Ph.envelope.regular, tint: Sourdough.Ramp.sage100, ink: Sourdough.Ramp.sage600,
                        label: "Contact Support", url: GetHelpMailto.url(subject: "Support — UseUp"), first: false)
            }
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
            .padding(Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Get Help")
        .preference(key: HideTabBarKey.self, value: true)
        .navigationDestination(item: $feedbackKind) { kind in
            FeedbackSheet(kind: kind) { title, description in
                Task {
                    do {
                        switch kind {
                        case .bug:
                            try await savedRecipesStore.reportBug(title: title, description: description)
                        case .feature:
                            try await savedRecipesStore.requestFeature(title: title, description: description)
                        }
                    } catch {
                        submitError = "Failed to submit. Please try again."
                    }
                }
            }
        }
        .reportErrorAlert($submitError)
    }

    @ViewBuilder
    private func rowContent(icon: Image, tint: Color, ink: Color, label: String, first: Bool) -> some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            icon
                .frame(width: 13, height: 13)
                .foregroundStyle(ink)
                .frame(width: 26, height: 26)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))
            Text(label).sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
            Spacer()
            Ph.caretRight.regular
                .frame(width: 9, height: 12)
                .foregroundStyle(Sourdough.Colors.faintInk)
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .padding(.vertical, Sourdough.Spacing.rowInternals)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(Sourdough.Colors.hairline).frame(height: 1)
                    .padding(.leading, 26 + Sourdough.Spacing.rowInternals * 2)
            }
        }
    }

    private func actionRow(icon: Image, tint: Color, ink: Color, label: String, first: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(icon: icon, tint: tint, ink: ink, label: label, first: first)
        }
        .buttonStyle(.plain)
    }

    private func linkRow(icon: Image, tint: Color, ink: Color, label: String, url: URL, first: Bool) -> some View {
        Link(destination: url) {
            rowContent(icon: icon, tint: tint, ink: ink, label: label, first: first)
        }
    }
}
