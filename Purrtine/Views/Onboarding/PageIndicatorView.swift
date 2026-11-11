import SwiftUI

struct PageIndicatorView: View {
    let currentStep: OnboardingStep
    let totalSteps: Int = OnboardingStep.allCases.count
    
    private var currentIndex: Int {
        OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    private var progress: Double {
        Double(currentIndex + 1) / Double(totalSteps)
    }

    @State private var trackWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.fill)
                .frame(height: 4)

            Capsule()
                .fill(Theme.accent)
                .frame(width: max(trackWidth * progress, 4), height: 4)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(currentStep.title))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    VStack(spacing: 20) {
        PageIndicatorView(currentStep: .welcome)
        PageIndicatorView(currentStep: .notificationPermission)
        PageIndicatorView(currentStep: .firstCatSetup)
        PageIndicatorView(currentStep: .taskSetup)
    }
    .frame(width: 240)
    .padding()
    .background(Theme.background)
}
