import SwiftUI

struct FeedbackSheet: View {
    enum Kind: Identifiable {
        case bug
        case feature

        var id: Self { self }

        var title: String {
            switch self {
            case .bug: return "Report a Bug"
            case .feature: return "Request a Feature"
            }
        }

        var prompt: String {
            switch self {
            case .bug: return "What went wrong? The more detail, the faster we can fix it."
            case .feature: return "What would you like to see? We read every one of these."
            }
        }

        var titlePlaceholder: String {
            switch self {
            case .bug: return "Short summary of the bug"
            case .feature: return "Short summary of the idea"
            }
        }

        var descriptionPlaceholder: String {
            switch self {
            case .bug: return "Describe what happened…"
            case .feature: return "Describe what you'd like…"
            }
        }
    }

    let kind: Kind
    let onSubmit: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                    Text(kind.prompt)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Title")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                        TextField(kind.titlePlaceholder, text: $title)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.body)
                            .padding(Sourdough.Spacing.rowInternals)
                            .background(Sourdough.Colors.sunken)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Description")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                        TextField(kind.descriptionPlaceholder, text: $description, axis: .vertical)
                            .lineLimit(6...12)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.body)
                            .padding(Sourdough.Spacing.rowInternals)
                            .background(Sourdough.Colors.sunken)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                    }
                }
                .padding(Sourdough.Spacing.screenMargin)
            }

            Button {
                guard canSubmit, !isSubmitting else { return }
                isSubmitting = true
                onSubmit(
                    title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismiss()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Submit")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSubmit ? Sourdough.Colors.action : Sourdough.Colors.action.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .preference(key: HideTabBarKey.self, value: true)
    }
}
