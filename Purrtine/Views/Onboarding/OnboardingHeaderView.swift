import SwiftUI

struct OnboardingHeaderView: View {
    let currentStep: OnboardingStep
    let onBack: (() -> Void)?
    
    private var showBackButton: Bool {
        currentStep != .welcome
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button (invisible on welcome screen for alignment)
            if showBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
            } else {
                Spacer()
                    .frame(width: 44, height: 44)
            }

            // Onboarding progress
            PageIndicatorView(currentStep: currentStep)

            // Invisible spacer for symmetry
            Spacer()
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingHeaderView(currentStep: .welcome, onBack: nil)
        OnboardingHeaderView(currentStep: .notificationPermission, onBack: { print("Back") })
        OnboardingHeaderView(currentStep: .firstCatSetup, onBack: { print("Back") })
    }
    .background(Theme.background)
}
