import SwiftUI

struct PreSignupOnboardingContainerView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var onboardingAnswers = OnboardingAnswers()
    @State private var currentStep = 0 // 0=Intro 1=Name 2=Struggle 3=Spend 4=Waste 5=Goal 6=PreferencesPreview 7=Dietary 8=RestrictionsAllergies 9=CookingSkill 10=SignUp

    private var progressStep: Int? {
        switch currentStep {
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 4
        case 5: return 5
        case 7: return 6
        case 8: return 7
        case 9: return 8
        default: return nil // Intro, PreferencesPreview, SignUp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let progressStep {
                OnboardingProgressBar(progress: Double(progressStep) / 8.0)
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
                    StruggleOnboardingView(onBack: { advance(to: 1) }, onContinue: { advance(to: 3) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 3:
                    SpendOnboardingView(onBack: { advance(to: 2) }, onContinue: { advance(to: 4) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 4:
                    WasteOnboardingView(onBack: { advance(to: 3) }, onContinue: { advance(to: 5) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 5:
                    GoalOnboardingView(onBack: { advance(to: 4) }, onContinue: { advance(to: 6) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 6:
                    PreferencesPreviewOnboardingView(
                        onBack: { advance(to: 5) },
                        onSkip: { advance(to: 10) },
                        onContinue: { advance(to: 7) }
                    )
                    .transition(.push(from: .trailing))
                case 7:
                    DietaryPreferenceOnboardingView(onBack: { advance(to: 6) }, onContinue: { advance(to: 8) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 8:
                    RestrictionsAllergiesOnboardingView(onBack: { advance(to: 7) }, onContinue: { advance(to: 9) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                case 9:
                    CookingSkillOnboardingView(onBack: { advance(to: 8) }, onContinue: { advance(to: 10) })
                        .environmentObject(onboardingAnswers)
                        .transition(.push(from: .trailing))
                default:
                    AuthView(onBack: { advance(to: 9) })
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
