import SwiftData
import SwiftUI
import UserNotifications

/// Per-task fingerprint used to detect task-set changes (membership or in-place edits) with a
/// single SwiftUI `onChange`. Shared by the task and assistant screens.
struct TaskChangeToken: Equatable {
  let id: UUID
  let updatedAt: Date
}

struct TaskManagementView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.haptics) private var haptics
  @Environment(\.navigationRouter) private var navigationRouter
  @AppStorage(TaskViewPreference.defaultTaskViewKey) private var defaultTaskViewRawValue = CareTaskViewMode.list.rawValue

  @Query private var allCareTasks: [CareTask]
  @Query private var allCats: [Cat]

  @Binding var selectedTaskId: UUID?
  @Binding var selectedTaskFilter: CareTaskFilter?

  @State private var viewModel = TaskManagementViewModel()
  @State private var showingAddCat = false
  @State private var hasAppliedDefaultTaskView = false
  @State private var calendarViewportHeight: CGFloat = 0

  init(
    selectedTaskId: Binding<UUID?> = .constant(nil),
    selectedTaskFilter: Binding<CareTaskFilter?> = .constant(nil)
  ) {
    self._selectedTaskId = selectedTaskId
    self._selectedTaskFilter = selectedTaskFilter
  }

  /// Lightweight fingerprint of the task set that changes on add/remove (id set) or in-place
  /// edit (updatedAt), so a single `onChange` can drive re-derivation.
  private var tasksChangeSignature: [TaskChangeToken] {
    allCareTasks.map { TaskChangeToken(id: $0.id, updatedAt: $0.updatedAt) }
  }

  var body: some View {
    NavigationStack {
      navigationContent
    }
    .searchable(text: $viewModel.searchText, prompt: String(localized: .tasksSearchPlaceholder))
    .task {
      guard !AppLaunchConfiguration.current.skipsNotificationSetup else { return }
      await viewModel.setupNotifications()
    }
    .onChange(of: selectedTaskId) { _, _ in
      consumeIfPresent(&selectedTaskId) { taskId in
        viewModel.handleTaskNavigation(taskId: taskId, from: allCareTasks)
      }
    }
    .onChange(of: navigationRouter.shouldTriggerAddTask) { _, _ in
      consumeIfTrue(&navigationRouter.shouldTriggerAddTask) {
        viewModel.presentTaskCreation()
      }
    }
    .onChange(of: selectedTaskFilter) { _, newFilter in
      if let filter = newFilter {
        viewModel.selectedFilter = filter
        viewModel.selectedViewMode = .list
        selectedTaskFilter = nil
      }
    }
    .onAppear {
      applyInitialPresentationState()
      viewModel.configure(with: modelContext, tasks: allCareTasks)
      // Cold-tab open: when the Tasks tab hasn't been mounted yet (e.g. the assistant
      // in its own tab requests opening a task, or `-launch-route addTask` sets its flag
      // before this view mounts), the pending selection/flag is already set at mount time,
      // so `.onChange` never observes a change and the sheet wouldn't present. Consume any
      // pending state here so the first appearance still reacts; `.onChange` continues to
      // cover the already-mounted case.
      consumeIfPresent(&selectedTaskId) { taskId in
        viewModel.handleTaskNavigation(taskId: taskId, from: allCareTasks)
      }
      consumeIfTrue(&navigationRouter.shouldTriggerAddTask) {
        viewModel.presentTaskCreation()
      }
    }
    // Single change signal covering both membership changes (add/remove) and in-place edits
    // (updatedAt). Previously two separate onChange handlers could both fire for one change,
    // running the full derivation twice.
    .onChange(of: tasksChangeSignature) { _, _ in
      viewModel.configure(with: modelContext, tasks: allCareTasks)
    }
    // Every sheet reports its dismissal: an alert raised while a sheet is up waits for it to close.
    .sheet(isPresented: $viewModel.showingTaskTemplate, onDismiss: { viewModel.sheetDidDismiss(.taskTemplate) }) {
      TaskTemplateSelectionView { template in
        viewModel.presentTaskCreation(template: template)
        viewModel.dismissTaskTemplateSelection()
      }
    }
    .sheet(item: $viewModel.taskCreationRequest, onDismiss: { viewModel.sheetDidDismiss(.taskCreation) }) { request in
      TaskAddView(template: request.template)
    }
    .sheet(item: $viewModel.selectedCareTask, onDismiss: { viewModel.sheetDidDismiss(.taskEdit) }) { task in
      TaskEditView(task: task)
    }
    .sheet(
      item: $viewModel.taskCompletionRequest,
      onDismiss: { viewModel.sheetDidDismiss(.taskCompletion) }
    ) { request in
      TaskCompletionView(task: request.task, completedForDate: request.completedForDate) {
        selectedCats, selectedCaregiver, notes, photos, completedForDate, unsavedPhotos in
        try await viewModel.submitCompletion(
          of: request.task,
          for: selectedCats,
          by: selectedCaregiver,
          completedForDate: completedForDate,
          with: notes,
          photos: photos,
          unsavedPhotos: unsavedPhotos
        )
        haptics.impact(.medium)
      }
    }
    .sheet(isPresented: $showingAddCat, onDismiss: { viewModel.sheetDidDismiss(.addCat) }) {
      AddCatView()
    }
    // Covers the list and the calendar: both complete through the view model. The completion
    // stands, so the alert only acknowledges the stale reminders and offers no retry.
    .alert(String(localized: .errorReminderSchedule), isPresented: $viewModel.isShowingReminderWarning) {
      Button(String(localized: .actionOk)) {}
    }
    // A one-tap complete or a delete from the list or the calendar that did not save.
    .alert(
      viewModel.actionFailure?.title ?? "",
      isPresented: $viewModel.isShowingActionFailure,
      presenting: viewModel.actionFailure
    ) { _ in
      Button(String(localized: .actionOk)) {}
    } message: { failure in
      Text(failure.message)
    }
    .accessibilityIdentifier("taskManagement.view")
  }

  private var navigationContent: some View {
    mainContentView
      .navigationChromeTitle(
        semanticTitle: String(localized: .tasksTitle),
        visualTitle: Text(.tasksTitle)
      )
      .minimizingNavigationBarOnScroll()
      .toolbar {
        if !allCats.isEmpty {
          if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
              viewModeToggleButton
            }
            Backport.ToolbarSpacer(placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
              addMenuButton
            }
          } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
              viewModeToggleButton
              addMenuButton
            }
          }
        }
      }
  }

  @ViewBuilder
  private var mainContentView: some View {
    VStack {
      if allCats.isEmpty {
        emptyStateView
      } else {
        VStack(spacing: 2) {
          if viewModel.selectedViewMode == .list {
            TaskFilterSection(
              filters: CareTaskFilter.allCases,
              selectedFilter: viewModel.selectedFilter,
              getTaskCount: { filter in
                viewModel.taskCounts[filter] ?? 0
              },
              onFilterSelected: { filter in
                viewModel.selectedFilter = filter
              }
            )
            .padding(.top, 2)
          }

          if viewModel.selectedViewMode == .list {
            if viewModel.groupedTasks.isEmpty {
              ScrollView {
                filterEmptyView
              }
            } else {
              listView
                .padding(.bottom, 2)
            }
          } else {
            calendarView
          }
        }
      }
    }
    .background {
      Theme.backgroundGrouped.ignoresSafeArea()
    }
    .extendingUnderFloatingTabBar()
  }

  private var viewModeToggleButton: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.3)) {
        viewModel.selectedViewMode = viewModel.selectedViewMode == .list ? .calendar : .list
      }
    } label: {
      Label(
        String(localized: .tasksViewMode),
        systemImage: viewModel.selectedViewMode == .list ? "calendar" : "list.bullet"
      )
      .labelStyle(.iconOnly)
      .foregroundStyle(.blue)
    }
    .accessibilityLabel(String(localized: .tasksViewMode))
    .accessibilityIdentifier("taskManagement.viewModeButton")
  }

  private var addMenuButton: some View {
    Menu {
      Button {
        viewModel.presentTaskTemplateSelection()
      } label: {
        Label(String(localized: .tasksTemplateTask), systemImage: "list.bullet.rectangle")
      }
      .accessibilityIdentifier("taskManagement.templateTaskButton")

      Button {
        viewModel.presentTaskCreation()
      } label: {
        Label(String(localized: .tasksCustomTask), systemImage: "pencil.circle")
      }
      .accessibilityIdentifier("taskManagement.customTaskButton")
    } label: {
      Label(String(localized: .actionAdd), systemImage: "plus")
        .labelStyle(.iconOnly)
        .foregroundStyle(.blue)
    }
    .accessibilityIdentifier("taskManagement.addMenuButton")
  }

  @ViewBuilder
  private var calendarView: some View {
    ScrollView {
      TaskCalendarView(
        tasks: viewModel.groupedTasks.flatMap(\.tasks),
        selectedDate: $viewModel.selectedDate,
        viewModel: viewModel
      )
      // ScrollView sizes content to its ideal height, so the day panel
      // needs an explicit minimum to reach the bottom on short task lists.
      .frame(minHeight: calendarViewportHeight, alignment: .top)
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.height
    } action: { height in
      calendarViewportHeight = height
    }
    .accessibilityIdentifier("taskManagement.calendar")
  }

  @ViewBuilder
  private var listView: some View {
    List {
      ForEach(viewModel.groupedTasks) { section in
        Section {
          ForEach(section.tasks) { task in
            TaskRow(task: task) {
              handleTaskTap(task)
            } onComplete: {
              handleTaskCompletion(task)
            } onDelete: {
              viewModel.deleteCareTask(task)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
          }
        } header: {
          Text(section.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 8)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(.clear)
    .addingFloatingTabBarScrollClearance()
    .accessibilityIdentifier("taskManagement.list")
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 32) {
      VStack(spacing: 16) {
        Image(systemName: "cat.circle.fill")
          .font(.system(size: 80, weight: .light))
          .foregroundStyle(.secondary)

        VStack(spacing: 8) {
          Text(.catsNoCatsTitle)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)

          Text(.catsNoCatsDescription)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
        }
      }

      Button(action: presentAddCat) {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
          Text(.catsAddFirstCat)
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(height: 50)
        .frame(maxWidth: 280)
        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var filterEmptyView: some View {
    Group {
      if !viewModel.searchText.isEmpty {
        ContentUnavailableView.search
      } else {
        VStack(spacing: 16) {
          Spacer()
          Image(systemName: "exclamationmark.magnifyingglass")
            .font(.system(size: 50))
            .foregroundColor(.gray)
          Text(.tasksNoTasksFound)
            .font(.title2)
            .fontWeight(.semibold)
          Text(.tasksNoTasksFilterDescription)
            .font(.subheadline)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
          Spacer()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Shared "already-set-at-mount" shape for one-shot optional navigation state: run
  /// `action` with the value if present, then clear it.
  private func consumeIfPresent<Value>(_ value: inout Value?, action: (Value) -> Void) {
    guard let unwrapped = value else { return }
    action(unwrapped)
    value = nil
  }

  /// Same shape as `consumeIfPresent` for one-shot boolean navigation flags.
  private func consumeIfTrue(_ flag: inout Bool, action: () -> Void) {
    guard flag else { return }
    action()
    flag = false
  }

  private func applyInitialPresentationState() {
    if !hasAppliedDefaultTaskView {
      viewModel.selectedViewMode = TaskViewPreference.resolvedViewMode(from: defaultTaskViewRawValue)
      hasAppliedDefaultTaskView = true
    }
  }

  private func presentAddCat() {
    viewModel.addCatSheetWillPresent()
    showingAddCat = true
  }

  private func handleTaskTap(_ task: CareTask) {
    viewModel.presentTaskEdit(task)
  }

  private func handleTaskCompletion(_ task: CareTask, completedForDate: Date? = nil) {
    if viewModel.handleCompletionAction(for: task, completedForDate: completedForDate) {
      haptics.impact(.medium)
    }
  }
}

#if DEBUG
#Preview("Task Management") {
  PreviewHost(scenario: .standard) {
    TaskManagementView(
      selectedTaskId: .constant(nil),
      selectedTaskFilter: .constant(nil)
    )
  }
}
#endif
