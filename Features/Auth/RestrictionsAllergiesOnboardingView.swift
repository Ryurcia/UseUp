import SwiftUI

struct RestrictionsAllergiesOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void

    @State private var selectedRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    @State private var selectedAllergies: Set<AllergyType> = []
    @State private var showOtherField = false
    @State private var otherAllergyText = ""
    @FocusState private var isOtherFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                        Text("Allergies & Restrictions")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.display)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Sourdough.Spacing.betweenBlocks)

                        Text("We'll steer clear of these when generating recipes. You can always change this later.")
                            .sourdoughTextStyle(.body)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals), GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)],
                            spacing: Sourdough.Spacing.rowInternals
                        ) {
                            ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                                let isSelected = selectedRestrictions.contains(restriction)
                                OnboardingOptionCard(label: restriction.rawValue, isSelected: isSelected) {
                                    if isSelected { selectedRestrictions.remove(restriction) }
                                    else { selectedRestrictions.insert(restriction) }
                                }
                            }
                        }
                        .padding(.top, Sourdough.Spacing.insideChip)

                        Text("Allergies")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Sourdough.Spacing.insideChip)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals), GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)],
                            spacing: Sourdough.Spacing.rowInternals
                        ) {
                            ForEach(AllergyType.allCases) { allergy in
                                let isSelected = selectedAllergies.contains(allergy)
                                OnboardingOptionCard(label: allergy.rawValue, isSelected: isSelected) {
                                    if isSelected { selectedAllergies.remove(allergy) }
                                    else { selectedAllergies.insert(allergy) }
                                }
                            }

                            OnboardingOptionCard(label: "Other", isSelected: showOtherField) {
                                showOtherField.toggle()
                                if showOtherField {
                                    isOtherFieldFocused = true
                                    DispatchQueue.main.async {
                                        withAnimation { scrollProxy.scrollTo("otherAllergyField", anchor: .bottom) }
                                    }
                                } else {
                                    otherAllergyText = ""
                                    isOtherFieldFocused = false
                                }
                            }
                        }
                        .padding(.top, Sourdough.Spacing.insideChip)

                        if showOtherField {
                            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                                TextField("e.g. shellfish, sesame", text: $otherAllergyText)
                                    .focused($isOtherFieldFocused)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.body)
                                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                    .frame(height: 52)
                                    .background(Sourdough.Colors.sunken)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                            .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                                Text("Separate multiple allergies with commas")
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .sourdoughTextStyle(.caption)
                                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            }
                            .padding(.bottom, Sourdough.Spacing.betweenBlocks)
                            .id("otherAllergyField")
                        }
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.betweenBlocks)
                }
            }

            Button {
                onboardingAnswers.restrictions = selectedRestrictions
                onboardingAnswers.allergies = selectedAllergies
                onboardingAnswers.customAllergyText = otherAllergyText.trimmingCharacters(in: .whitespacesAndNewlines)
                onContinue()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear {
            selectedRestrictions = onboardingAnswers.restrictions
            selectedAllergies = onboardingAnswers.allergies
            otherAllergyText = onboardingAnswers.customAllergyText
            showOtherField = !onboardingAnswers.customAllergyText.isEmpty
        }
    }
}
