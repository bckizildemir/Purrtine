import SwiftUI

struct NotificationPermissionView: View {
    @Environment(\.notificationManager) private var notificationManager
    @State private var isLoading = false
    @State private var permissionGranted = false

    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Spacer()
            
            // Notification Icon Animation
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Theme.label.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .scaleEffect(permissionGranted ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: permissionGranted)
                }
                
                VStack(spacing: 16) {
                    // Header
                    Text(.onboardingNotificationTitle)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 40)
                    
                    // Context
                    Text(.onboardingNotificationSubtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            OnboardingActionFooter {
                Button(action: { Task { await requestNotificationPermission() } }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isLoading ? String(localized: .onboardingNotificationRequestLoading) : String(localized: .onboardingNotificationRequestButton))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                }
                .accessibilityIdentifier("onboarding.notification.enableButton")
                .disabled(isLoading)
            } secondaryAction: {
                Button(action: onSkip) {
                    Text(.onboardingNotificationSkip)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("onboarding.notification.skipButton")
                .disabled(isLoading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() async {
        isLoading = true

        // Through the manager, so a grant reaches `requestFullReminderResync()` and the reminder resync.
        let granted = await notificationManager.requestPermission()

        isLoading = false
        permissionGranted = granted

        // Continue regardless of permission result
        try? await Task.sleep(for: .milliseconds(500))
        onContinue()
    }
}

#Preview {
    NotificationPermissionView(
        onContinue: { print("Continue") },
        onSkip: { print("Skip") }
    )
} 
