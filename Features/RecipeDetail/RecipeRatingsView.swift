import SwiftUI
import PhosphorSwift

struct RecipeRatingsView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var blockError: String?

    private var reviews: [CommunityReview] {
        savedRecipesStore.communityReviews[recipe.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                Button {
                    dismiss()
                } label: {
                    Ph.caretLeft.regular
                        .frame(width: 17, height: 17)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DS.Spacing.space2)

                Text("Ratings")
                    .font(.custom("CalSans-Regular", size: 28))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                    .font(.custom("Satoshi Variable", size: 13))
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space4)

            if reviews.isEmpty {
                Spacer()
                VStack(spacing: DS.Spacing.space3) {
                    Ph.star.regular
                        .frame(width: 40, height: 40)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                    Text("No ratings yet")
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DS.Spacing.space3) {
                        ForEach(reviews) { review in
                            RatingRowView(
                                review: review,
                                isOwnReview: review.userId == session.currentUserId,
                                onReport: { category, description in
                                    Task {
                                        try? await savedRecipesStore.reportReview(
                                            review,
                                            recipeId: recipe.id,
                                            category: category,
                                            description: description
                                        )
                                    }
                                },
                                onBlock: {
                                    Task {
                                        do {
                                            try await savedRecipesStore.blockUser(review.userId)
                                        } catch {
                                            blockError = "Failed to block user. Please try again."
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.bottom, DS.Spacing.space8)
                }
            }
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: HideTabBarKey.self, value: true)
        .task {
            await savedRecipesStore.fetchCommunityReviews(for: recipe.id)
        }
        .alert("Block Error", isPresented: Binding(
            get: { blockError != nil },
            set: { if !$0 { blockError = nil } }
        )) {
            Button("OK") { blockError = nil }
        } message: {
            if let err = blockError { Text(err) }
        }
    }
}

// MARK: - Rating Row

private struct RatingRowView: View {
    let review: CommunityReview
    let isOwnReview: Bool
    let onReport: (String, String?) -> Void
    let onBlock: () -> Void

    @State private var avatarImage: UIImage?
    @State private var showReportSheet = false
    @State private var showBlockAlert = false

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.space3) {
            Group {
                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Ph.userCircle.fill
                        .frame(width: 36, height: 36)
                        .foregroundStyle(DS.ColorToken.accent)
                        .frame(width: 40, height: 40)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                HStack {
                    Text(review.nickname)
                        .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Spacer()
                    StarRatingView(rating: review.rating, size: 14)
                    if !isOwnReview {
                        Button {
                            showReportSheet = true
                        } label: {
                            Ph.flag.regular
                                .frame(width: 13, height: 13)
                                .foregroundStyle(DS.ColorToken.textTertiary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showBlockAlert = true
                        } label: {
                            Ph.prohibit.regular
                                .frame(width: 13, height: 13)
                                .foregroundStyle(DS.ColorToken.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let reviewText = review.review, !reviewText.isEmpty {
                    Text(reviewText)
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.space4)
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 0.5)
        )
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(subject: .review(nickname: review.nickname), onSubmit: onReport)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Block \(review.nickname)?", isPresented: $showBlockAlert) {
            Button("Block", role: .destructive) { onBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see recipes or reviews from this user anymore. You can unblock them anytime in Settings.")
        }
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let avatarPath = review.avatarPath, !avatarPath.isEmpty else { return }
        if let cached = AvatarCache.load(for: avatarPath),
           let image = UIImage(data: cached) {
            avatarImage = image
            return
        }
        do {
            let data = try await SupabaseManager.client.storage
                .from("profile-photos")
                .download(path: avatarPath)
            AvatarCache.save(data, for: avatarPath)
            avatarImage = UIImage(data: data)
        } catch {}
    }
}
