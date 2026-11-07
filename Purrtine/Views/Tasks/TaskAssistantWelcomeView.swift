import SwiftUI

struct TaskAssistantWelcomeView: View {
    let chips: [TaskAssistantSuggestion]
    let onStartChat: () -> Void
    let onSelectSuggestion: (TaskAssistantSuggestion) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TaskAssistantEmptyStateView(
                    chips: chips,
                    accessibilityIdentifier: "taskAssistant.welcome",
                    onSelectChip: onSelectSuggestion
                )

                Button(
                    String(localized: .taskAssistantStartChat),
                    systemImage: "message.fill",
                    action: onStartChat
                )
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("taskAssistant.startChatButton")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .defaultScrollAnchor(.center)
        .addingFloatingTabBarScrollClearance()
        .background(Theme.background.ignoresSafeArea())
        .extendingUnderFloatingTabBar()
    }
}

#if DEBUG
#Preview("Task Assistant Welcome") {
    NavigationStack {
        TaskAssistantWelcomeView(
            chips: [],
            onStartChat: {},
            onSelectSuggestion: { _ in }
        )
        .navigationTitle(String(localized: .taskAssistantTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
