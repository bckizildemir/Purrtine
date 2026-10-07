import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Spacer()
            
            // Hero Element - Cat Silhouette
            VStack(spacing: 24) {
                Image(systemName: "cat.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.background)
                    .background(
                        Circle()
                            .fill(.primary)
                            .frame(width: 120, height: 120)
                    )
                
                VStack(spacing: 16) {
                    // Primary Text
                    Text(.onboardingWelcomeTitle)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Secondary Text
                    Text(.onboardingWelcomeSubtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            OnboardingActionFooter {
                Button(action: onContinue) {
                    Text(.onboardingWelcomeButton)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.blue)
                        )
                }
                .accessibilityIdentifier("onboarding.welcome.continueButton")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    WelcomeView {
        print("Continue tapped")
    }
} 
