import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.notificationManager) private var notificationManager
    let onboardingManager = OnboardingManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    /// Built on first appearance, because its dependencies come from the environment.
    @State private var taskSetupModel: OnboardingTaskSetupModel?
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and page indicator
                OnboardingHeaderView(currentStep: currentStep, onBack: goBack)
                
                // Main content
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeView(onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = .notificationPermission
                                onboardingManager.currentStep = .notificationPermission
                            }
                        })
                        
                    case .notificationPermission:
                        NotificationPermissionView(
                            onContinue: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = .firstCatSetup
                                    onboardingManager.currentStep = .firstCatSetup
                                }
                            },
                            onSkip: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = .firstCatSetup
                                    onboardingManager.currentStep = .firstCatSetup
                                }
                            }
                        )
                        
                    case .firstCatSetup:
                        FirstCatSetupView(
                            onContinue: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = .taskSetup
                                    onboardingManager.currentStep = .taskSetup
                                }
                            },
                            onSkip: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = .taskSetup
                                    onboardingManager.currentStep = .taskSetup
                                }
                            }
                        )
                        
                    case .taskSetup:
                        if let taskSetupModel {
                            OnboardingTaskSetupStep(model: taskSetupModel)
                        } else {
                            // Only before the first `onAppear` builds the model; a Continue tap here does nothing.
                            TaskSetupView(onContinue: {})
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            currentStep = onboardingManager.currentStep
            if taskSetupModel == nil {
                taskSetupModel = OnboardingTaskSetupModel(
                    notificationManager: notificationManager,
                    taskWriter: careTaskWriter,
                    modelContext: modelContext,
                    onboardingManager: onboardingManager
                )
            }
        }
    }
    
    // MARK: - Navigation
    private func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                break // No back from welcome
            case .notificationPermission:
                currentStep = .welcome
                onboardingManager.currentStep = .welcome
            case .firstCatSetup:
                currentStep = .notificationPermission
                onboardingManager.currentStep = .notificationPermission
            case .taskSetup:
                currentStep = .firstCatSetup
                onboardingManager.currentStep = .firstCatSetup
            }
        }
    }
}

#if DEBUG
#Preview("Onboarding") {
    PreviewHost(scenario: .empty) {
        OnboardingView()
    }
}
#endif
