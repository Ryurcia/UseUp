import SwiftUI

struct CookingSkillOnboardingView: View {
    @EnvironmentObject private var session: AppSession
    let nickname: String
    let displayName: String

    @State private var selectedLevel: Int? = nil
    @State private var isLoading = false

    private let options: [(level: Int, label: String, icon: String)] = [
        (1, "I cook like I'm in college", "flame"),
        (2, "I can cook a decent meal", "frying.pan"),
        (3, "Just call me Gordon Ramsay", "star.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                    Text("How Well Do You Cook?")
                        .font(.custom("CalSans-Regular", size: 32))
                        .kerning(0)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.space6)

                    Text("We'll tailor recipe complexity to match your skills.")
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: DS.Spacing.space3) {
                        ForEach(options, id: \.level) { option in
                            let isSelected = selectedLevel == option.level
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedLevel = option.level
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.space3) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                                        .frame(width: 32)

                                    Text(option.label)
                                        .font(.custom("Satoshi Variable", size: 16).weight(.medium))
                                        .foregroundStyle(isSelected ? .white : DS.ColorToken.textPrimary)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.space4)
                                .padding(.vertical, DS.Spacing.space4)
                                .background(
                                    isSelected
                                        ? DS.ColorToken.primary
                                        : DS.ColorToken.bgSecondary
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? Color.clear
                                                : DS.ColorToken.borderDefault,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, DS.Spacing.space2)
                }
                .padding(.horizontal, DS.Spacing.space4)
            }

            VStack(spacing: DS.Spacing.space2) {
                Button {
                    completeOnboarding(level: selectedLevel ?? 1)
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
                .disabled(selectedLevel == nil || isLoading)
            }
            .padding(.horizontal, DS.Spacing.space4)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func completeOnboarding(level: Int) {
        Task {
            isLoading = true
            await session.updateCookingSkillLevel(level: level)
            await session.completeNicknameOnboarding(nickname: nickname, displayName: displayName)
            isLoading = false
        }
    }
}
