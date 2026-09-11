import SwiftUI

struct PreSignupOnboardingContainerView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var onboardingAnswers = OnboardingAnswers()
    // 0=Intro 1=Name 2=Struggle 3=Spend 4=SpendReveal 5=GroceryBudget 6=Waste 7=WasteReveal
    // 8=SavingsPitch 9=Goal 10=PreferencesPreview 11=Dietary 12=RestrictionsAllergies 13=CookingSkill 14=SignUp
    @State private var currentStep = 0

    private var progressStep: Int? {
        switch currentStep {
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 5: return 4
        case 6: return 5
        case 9: return 6
        case 11: return 7
        case 12: return 8
        case 13: return 9
        default: return nil // Intro, SpendReveal, WasteReveal, SavingsPitch, PreferencesPreview, SignUp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let progressStep {
                OnboardingProgressBar(progress: Double(progressStep) / 9.0)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.rowInternals)
            }

            Group {
                switch currentStep {
                case 0:
                    IntroOnboardingView(onBack: { dismiss() }, onContinue: { advance(to: 1) })
                        .transition(.push(from: .trailing))
                case 1:
                    NameOnboardingView(onBack: { advance(to: 0) }, onContinue: { advance(to: 2) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 2:
                    StruggleOnboardingView(onContinue: { advance(to: 3) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 3:
                    SpendOnboardingView(onContinue: { advance(to: 4) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 4:
                    SpendRevealView(onContinue: { advance(to: 5) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 5:
                    GroceryBudgetOnboardingView(onContinue: { advance(to: 6) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 6:
                    WasteOnboardingView(onContinue: { advance(to: 7) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 7:
                    WasteRevealView(onContinue: { advance(to: 8) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 8:
                    SavingsPitchView(onContinue: { advance(to: 9) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 9:
                    GoalOnboardingView(onContinue: { advance(to: 10) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 10:
                    PreferencesPreviewOnboardingView(
                        onBack: { advance(to: 9) },
                        onSkip: { advance(to: 14) },
                        onContinue: { advance(to: 11) }
                    )
                    .transition(.push(from: .trailing))
                case 11:
                    DietaryPreferenceOnboardingView(onContinue: { advance(to: 12) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 12:
                    RestrictionsAllergiesOnboardingView(onContinue: { advance(to: 13) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 13:
                    CookingSkillOnboardingView(onContinue: { advance(to: 14) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                default:
                    AuthView(onBack: { advance(to: 13) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                }
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(session.preferredColorScheme)
    }

    private func advance(to step: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = step }
    }
}
