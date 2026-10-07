import SwiftData
import SwiftUI

// Type alias to resolve conflict with Swift's built-in Task
typealias CatTask = CatCareCalendar.CareTask

struct HistoryView: View {
  @Environment(\.navigationRouter) private var navigationRouter

  @Query private var allTasks: [CatTask]
  // Completions come straight from the store, already sorted newest-first, instead of faulting
  // every task's completions into memory and sorting them by hand on a background Task.
  @Query(sort: \CareTaskCompletion.completedAt, order: .reverse)
  private var allCompletions: [CareTaskCompletion]
  @State private var searchText = ""

  @Binding var selectedTab: AppTab

  private var scopedTask: CatTask? {
    guard let selectedHistoryTaskId = navigationRouter.selectedHistoryTaskId else { return nil }
    return allTasks.first { $0.id == selectedHistoryTaskId }
  }

  private func scopedCompletions(for scopedTask: CatTask?) -> [CareTaskCompletion] {
    guard let scopedTask else { return allCompletions }
    return allCompletions.filter { $0.task?.id == scopedTask.id }
  }

  var body: some View {
    // Derive once per render and reuse across the header, state, and list.
    let scopedTask = scopedTask
    let scopedCompletions = scopedCompletions(for: scopedTask)
    let filteredCompletions = HistoryPresentation.filteredCompletions(
      from: scopedCompletions,
      query: searchText
    )
    let presentationState = HistoryPresentation.state(
      taskCount: allTasks.count,
      completions: scopedCompletions,
      searchText: searchText,
      isTaskScoped: scopedTask != nil
    )

    return ZStack {
      Theme.backgroundGrouped.ignoresSafeArea()

      VStack(spacing: 16) {
        if let scopedTask {
          HistoryTaskScopeHeaderView(
            taskTitle: scopedTask.title,
            completionCountText: String(localized: .historyTaskScopeCount(Int32(scopedCompletions.count))),
            clearAction: clearTaskScope
          )
          .padding(.horizontal)
          .padding(.top)
        }

        switch presentationState {
        case .noTasks:
          emptyStateView
        case .noCompletions:
          noCompletionsStateView
        case .taskNoCompletions:
          taskNoCompletionsStateView
        case .searchEmpty:
          searchEmptyStateView
        case .content:
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(filteredCompletions) { completion in
                CompletionHistoryRow(completion: completion)
              }
            }
            .padding(.horizontal)
            .padding(.bottom)
          }
        }
      }
    }
    .navigationChromeTitle(
      semanticTitle: String(localized: .historyTitle),
      visualTitle: Text(.historyTitle),
      usesEditorToolbarRole: false
    )
    .searchable(text: $searchText)
    .accessibilityIdentifier("history.view")
  }

  private func clearTaskScope() {
    navigationRouter.selectedHistoryTaskId = nil
  }

  @ViewBuilder
  private var searchEmptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text(.tasksNoTasksFound)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)

      Text(.tasksNoTasksFilterDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("history.state.searchEmpty")
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text(.historyEmptyNoTasks)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text(.historyEmptyNoTasksDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        navigationRouter.selectedTab = .tasks
        navigationRouter.shouldTriggerAddTask = true
      } label: {
        Text(.historyEmptyCreateFirstTask)
          .font(.headline)
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.blue)
          .cornerRadius(12)
      }
      .accessibilityIdentifier("history.createFirstTaskButton")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("history.state.noTasks")
  }

  @ViewBuilder
  private var noCompletionsStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "clock.badge.questionmark")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text(.historyEmptyNoStats)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text(.historyEmptyNoStatsDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("history.state.noCompletions")
  }

  @ViewBuilder
  private var taskNoCompletionsStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "clock.badge.questionmark")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text(.historyTaskEmptyTitle)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text(.historyTaskEmptyDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("history.state.taskNoCompletions")
  }
}

struct CompletionHistoryRow: View {
  let completion: CareTaskCompletion

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: completion.task?.category.iconName ?? "circle.fill")
        .foregroundColor(statusColor)
        .font(.title3)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(completion.task?.title ?? String(localized: .taskUnknownTask))
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.primary)

        HStack(spacing: 4) {
          Text(completion.completedAt, format: .dateTime.day().month().year())
            .font(.caption)
            .foregroundStyle(.secondary)

          Text(verbatim: "•")
            .font(.caption)
            .foregroundStyle(.tertiary)

          Text(completion.completedAt, format: .dateTime.hour().minute())
            .font(.caption)
            .foregroundStyle(.secondary)

          if completion.cats.isEmpty == false {
            Text(verbatim: "•")
              .font(.caption)
              .foregroundStyle(.tertiary)

            Text(completion.cats.map(\.name).joined(separator: ", "))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .accessibilityIdentifier("history.row.\(completion.task?.title ?? "unknown")")
  }

  private var statusColor: Color {
    completion.wasOnTime ? .green : .orange
  }
}

#if DEBUG
#Preview {
  PreviewHost(scenario: .history) {
    NavigationStack {
      HistoryView(selectedTab: .constant(.tasks))
    }
  }
}
#endif
