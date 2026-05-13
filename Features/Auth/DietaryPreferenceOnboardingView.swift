import SwiftUI

struct DietaryPreferenceOnboardingView: View {
    @EnvironmentObject private var session: AppSession
    let nickname: String
    let displayName: String
    var onContinue: (() -> Void)?

    @State private var selectedDiet: GenerationOptions.DietType = .any
    @State private var selectedRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                    Text("What's Your Diet?")
                        .font(.custom("CalSans-Regular", size: 32))
                        .kerning(0)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.space6)

                    Text("We'll use this as your default when generating recipes. You can always change it later.")
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietType.allCases) { dietType in
                            Button {
                                selectedDiet = dietType
                            } label: {
                                Text(dietType.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(
                                        selectedDiet == dietType ? .white : DS.ColorToken.textSecondary
                                    )
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(
                                        selectedDiet == dietType
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedDiet == dietType
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, DS.Spacing.space2)

                    Text("Any Restrictions?")
                        .font(.custom("CalSans-Regular", size: 20))
                        .kerning(0)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.space2)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                            let isSelected = selectedRestrictions.contains(restriction)
                            Button {
                                if isSelected {
                                    selectedRestrictions.remove(restriction)
                                } else {
                                    selectedRestrictions.insert(restriction)
                                }
                            } label: {
                                Text(restriction.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(
                                        isSelected ? .white : DS.ColorToken.textSecondary
                                    )
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(
                                        isSelected
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.space4)
            }

            // Pinned bottom buttons
            VStack(spacing: DS.Spacing.space2) {
                Button {
                    completeOnboarding(diet: selectedDiet)
                } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
                .disabled(isLoading)
            }
            .padding(.horizontal, DS.Spacing.space4)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func completeOnboarding(diet: GenerationOptions.DietType) {
        Task {
            isLoading = true
            await session.updateDietaryPreference(dietType: diet)
            await session.updateDietaryRestrictions(restrictions: selectedRestrictions)
            isLoading = false
            if let onContinue {
                onContinue()
            } else {
                await session.completeNicknameOnboarding(nickname: nickname, displayName: displayName)
            }
        }
    }
}
