import SwiftUI

struct TaskAssistantMessageBubbleView: View {
    @Environment(\.openURL) private var openURL

    let message: TaskAssistantMessage

    private var isFromUser: Bool { message.role == .user }

    var body: some View {
        // Align with a frame + fixed opposite-side inset rather than a `Spacer`. A `Spacer`'s
        // width animates, so any keyboard-driven relayout slid the bubble leading→trailing
        // ("shake"); frame alignment keeps the row horizontally stable.
        bubble
            .padding(isFromUser ? .leading : .trailing, 40)
            .frame(maxWidth: .infinity, alignment: isFromUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var bubble: some View {
        if message.role == .user, #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: .rect(cornerRadius: 18, style: .continuous))
        } else {
            content
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var content: some View {
        // First-line alignment keeps the failure icon beside the message, not centred on the button.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if message.style == .failure {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(textColor)

                if message.offersOpenSettings {
                    Button(String(localized: .onboardingTaskSetupReminderRowOpenSettings), action: openSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityHint(Text(.taskAssistantOpenSettingsHint))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Theme.accent.opacity(0.9)
        case .assistant:
            return message.style == .failure ? Color.red.opacity(0.12) : Theme.backgroundSecondary
        }
    }

    private var textColor: Color {
        message.role == .assistant ? Color.primary : Color.white
    }
}
