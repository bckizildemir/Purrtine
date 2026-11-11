import SwiftUI

/// A fixed-height action area that keeps onboarding controls aligned across every step.
struct OnboardingActionFooter<PrimaryAction: View, SecondaryAction: View>: View {
    private let primaryAction: PrimaryAction
    private let secondaryAction: SecondaryAction

    init(
        @ViewBuilder primaryAction: () -> PrimaryAction,
        @ViewBuilder secondaryAction: () -> SecondaryAction = { Color.clear }
    ) {
        self.primaryAction = primaryAction()
        self.secondaryAction = secondaryAction()
    }

    var body: some View {
        VStack(spacing: 16) {
            primaryAction
                .frame(maxWidth: .infinity)

            secondaryAction
                .frame(height: 18)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .background(Theme.background)
    }
}
