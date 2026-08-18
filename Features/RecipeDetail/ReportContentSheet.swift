import SwiftUI
import PhosphorSwift

/// Report form shared by recipes and reviews — the two call sites only ever differed in title and
/// prompt copy, not layout or submission logic.
struct ReportContentSheet: View {
    enum Subject {
        case recipe(name: String)
        case review(nickname: String)

        var title: String {
            switch self {
            case .recipe: return "Report Recipe"
            case .review: return "Report Review"
            }
        }

        var prompt: String {
            switch self {
            case .recipe(let name):
                return "Why are you reporting \"\(name)\"? Our team will review it."
            case .review(let nickname):
                return "Why are you reporting \(nickname)'s review? Our team will review it."
            }
        }
    }

    let subject: Subject
    let onSubmit: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: ReportCategory? = nil
    @State private var description: String = ""
    @State private var isSubmitting = false

    private enum ReportCategory: String, CaseIterable {
        case spam, harassment, hate_speech, violence, self_harm, nudity

        var label: String {
            switch self {
            case .spam:        return "Spam"
            case .harassment:  return "Harassment"
            case .hate_speech: return "Hate Speech"
            case .violence:    return "Violence"
            case .self_harm:   return "Self-Harm"
            case .nudity:      return "Nudity"
            }
        }

        var icon: Ph {
            switch self {
            case .spam:        return .chatCircleDots
            case .harassment:  return .userCircleMinus
            case .hate_speech: return .handPalm
            case .violence:    return .warningOctagon
            case .self_harm:   return .heartBreak
            case .nudity:      return .eyeSlash
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.screenMargin)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        HStack {
                            Text(subject.title)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.title2)
                            Spacer()
                            Button("Cancel") { dismiss() }
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.subhead)
                                .buttonStyle(.plain)
                        }
                        Text(subject.prompt)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)

                    Menu {
                        ForEach(ReportCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Label {
                                    Text(category.label)
                                } icon: {
                                    category.icon.regular
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory?.label ?? "Select a category")
                                .foregroundStyle(selectedCategory != nil ? Sourdough.Colors.ink : Sourdough.Colors.faintInk)
                                .sourdoughTextStyle(.body)
                            Spacer()
                            Ph.caretDown.regular
                                .frame(width: 13, height: 13)
                                .foregroundStyle(Sourdough.Colors.faintInk)
                        }
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                        .frame(height: 48)
                        .background(Sourdough.Colors.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Additional details (optional)")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        TextField("Describe the issue…", text: $description, axis: .vertical)
                            .lineLimit(3...5)
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
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.screenMargin)
                }
            }

            Button {
                guard let category = selectedCategory, !isSubmitting else { return }
                isSubmitting = true
                onSubmit(category.rawValue, description.isEmpty ? nil : description)
                dismiss()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Submit Report")
                            .foregroundStyle(Sourdough.Colors.onDestructive)
                            .sourdoughTextStyle(.rowTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedCategory != nil ? Sourdough.Colors.destructive : Sourdough.Colors.destructive.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedCategory == nil || isSubmitting)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
    }
}
