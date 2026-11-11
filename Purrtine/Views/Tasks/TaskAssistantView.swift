import SwiftData
import SwiftUI

struct TaskAssistantView: View {
    let onOpenTask: (UUID) -> Void

    @Environment(\.haptics) private var haptics
    @Query(sort: \CareTask.updatedAt, order: .reverse) private var allCareTasks: [CareTask]
    @Query(sort: \Cat.name) private var allCats: [Cat]
    @Query private var allCaregivers: [Caregiver]
    @State private var navigationPath: [TaskAssistantDestination] = []
    @State private var viewModel = TaskAssistantViewModel()

    var body: some View {
        let quickActionChips = TaskAssistantQuickActionBuilder.chips(from: allCareTasks)

        NavigationStack(path: $navigationPath) {
            TaskAssistantWelcomeView(
                chips: quickActionChips,
                onStartChat: openChat,
                onSelectSuggestion: openSuggestion
            )
            .onAppear(perform: revalidateAssistantState)
            .navigationTitle(String(localized: .taskAssistantTitle))
            .navigationBarTitleDisplayMode(.inline)
            .minimizingNavigationBarOnScroll()
            .navigationDestination(for: TaskAssistantDestination.self) { destination in
                switch destination {
                case .chat:
                    TaskAssistantChatView(
                        viewModel: viewModel,
                        allCareTasks: allCareTasks,
                        allCats: allCats,
                        allCaregivers: allCaregivers,
                        quickActionChips: quickActionChips,
                        onOpenTask: onOpenTask,
                        onEndChat: endChat
                    )
                }
            }
        }
        .onChange(of: tasksChangeSignature) {
            revalidateAssistantState()
        }
    }

    /// Single change signal covering both membership changes and in-place edits, replacing two
    /// separate onChange handlers that each allocated an array and both fired for one change.
    private var tasksChangeSignature: [TaskChangeToken] {
        allCareTasks.map { TaskChangeToken(id: $0.id, updatedAt: $0.updatedAt) }
    }

    private func revalidateAssistantState() {
        viewModel.revalidatePendingActions(against: allCareTasks)
    }

    private func endChat() {
        viewModel.endChat()
        navigationPath.removeLast()
    }

    private func openChat() {
        haptics.impact(.light)
        navigationPath.append(.chat)
    }

    private func openSuggestion(_ suggestion: TaskAssistantSuggestion) {
        haptics.selection()
        viewModel.chooseSuggestion(suggestion)
        navigationPath.append(.chat)
    }
}

#if DEBUG
#Preview("Task Assistant") {
    PreviewHost(scenario: .standard) {
        TaskAssistantView { _ in }
    }
}
#endif
