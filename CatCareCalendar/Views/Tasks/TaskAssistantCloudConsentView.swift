import SwiftUI

/// Shown once, the first time the task assistant is opened. Lets the user decide
/// whether unresolved requests may be sent to the cloud interpretation tier. The
/// choice can be revisited later from Settings > Task Assistant.
struct TaskAssistantCloudConsentView: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
                .padding(.top, 24)

            Text(.taskAssistantCloudConsentTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(.taskAssistantCloudConsentMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            // Side-by-side, primary action trailing — matches HIG's two-choice
            // system alerts rather than two stacked, equally weighted buttons.
            HStack(spacing: 12) {
                Button(String(localized: .taskAssistantCloudConsentDecline), action: onDecline)
                    .buttonStyle(.bordered)
                    .tint(Theme.labelSecondary)

                Button(String(localized: .taskAssistantCloudConsentAllow), action: onAllow)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(300)])
        .interactiveDismissDisabled()
        .accessibilityIdentifier("taskAssistant.cloudConsent")
    }
}
