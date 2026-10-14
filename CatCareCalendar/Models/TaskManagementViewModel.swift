import OSLog
import SwiftUI
import SwiftData
import UserNotifications

struct TaskCreationRequest: Identifiable {
    let id = UUID()
    let template: CareTaskTemplate?
}

struct TaskCompletionRequest: Identifiable {
    let task: CareTask
    let completedForDate: Date?

    var id: UUID { task.id }
}

@MainActor
@Observable
final class TaskManagementViewModel {
    // State properties
    var selectedViewMode: CareTaskViewMode = .list {
        didSet {
            updateGroupedTasks()
        }
    }
    var selectedFilter: CareTaskFilter = .all {
        didSet {
            updateGroupedTasks()
        }
    }
    var searchText: String = "" {
        didSet {
            // Only the grouped list depends on filter/search; the per-filter badge counts
            // depend solely on the task set, so they are not recomputed on every keystroke.
            updateGroupedTasks()
        }
    }
    var selectedDate: Date = Date()
    var showingTaskTemplate: Bool = false {
        didSet {
            if showingTaskTemplate { sheetsOnScreen.insert(.taskTemplate) }
        }
    }
    var taskCreationRequest: TaskCreationRequest? {
        didSet {
            if taskCreationRequest != nil { sheetsOnScreen.insert(.taskCreation) }
        }
    }

    // CareTask Actions
    var selectedCareTask: CareTask? {
        didSet {
            if selectedCareTask != nil { sheetsOnScreen.insert(.taskEdit) }
        }
    }

    // CareTask Completion
    var taskCompletionRequest: TaskCompletionRequest? {
        didSet {
            if taskCompletionRequest != nil { sheetsOnScreen.insert(.taskCompletion) }
        }
    }

    /// A write saved, but its reminders could not be updated. Drives the reminder warning alert.
    var isShowingReminderWarning = false {
        didSet {
            if isShowingReminderWarning == false { showNextPendingAlertAfterAlertCloses() }
        }
    }

    /// The last one-tap complete or delete that did not save. Kept after the alert closes, so the
    /// alert's text does not change while it animates away.
    private(set) var actionFailure: TaskActionFailure?

    /// Drives the alert for `actionFailure`.
    var isShowingActionFailure = false {
        didSet {
            if isShowingActionFailure == false { showNextPendingAlertAfterAlertCloses() }
        }
    }

    /// The sheets this screen presents. An alert cannot present from the view under an open sheet.
    enum Sheet: Hashable {
        case taskTemplate
        case taskCreation
        case taskEdit
        case taskCompletion
        case addCat
    }

    /// Sheets from the moment they are requested until their dismiss callback: a sheet whose state
    /// was cleared is still on screen while it animates away. A sheet requested while another is up
    /// presents once that one closes (the template sheet hands over to the creation sheet this way),
    /// so every entry gets its dismiss callback.
    private var sheetsOnScreen: Set<Sheet> = []

    /// Alerts raised while a sheet or another alert was up, shown one at a time once nothing is.
    private var pendingActionFailures: [TaskActionFailure] = []
    private var hasPendingReminderWarning = false

    /// Shows the next pending alert once the closing alert's binding write has finished. Tests await it.
    @ObservationIgnored private(set) var nextAlertPresentation: Task<Void, Never>?

    // YENİ: UI için işlenmiş ve hazır veriler
    var groupedTasks: [TaskListSection] = []
    var taskCounts: [CareTaskFilter: Int] = [:]
    
    private let notificationManager: NotificationManager
    private let taskWriter: any CareTaskWriting
    private let photoWriter: CareTaskPhotoWriter
    private var modelContext: ModelContext?
    private var allCareTasks: [CareTask] = []
    private let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "TaskManagement")

    init(
        notificationManager: NotificationManager = .shared,
        taskWriter: (any CareTaskWriting)? = nil,
        photoWriter: CareTaskPhotoWriter = CareTaskPhotoWriter()
    ) {
        self.notificationManager = notificationManager
        self.taskWriter = taskWriter ?? CareTaskWriter(scheduler: notificationManager)
        self.photoWriter = photoWriter
    }

    func configure(with modelContext: ModelContext, tasks: [CareTask]) {
        self.modelContext = modelContext
        self.allCareTasks = tasks
        updateTasks()
    }

    // Recomputes both the grouped list and the per-filter counts. Use when the task set changes.
    @MainActor
    func updateTasks() {
        updateGroupedTasks()
        updateTaskCounts()
    }

    /// Recomputes only the grouped list (depends on the current filter + search text).
    @MainActor
    private func updateGroupedTasks() {
        self.groupedTasks = TaskListDerivation.groupedSections(
            from: allCareTasks,
            filter: selectedFilter,
            searchText: searchText
        )
    }

    /// Recomputes only the per-filter badge counts (depend solely on the task set).
    @MainActor
    private func updateTaskCounts() {
        self.taskCounts = TaskListDerivation.taskCounts(from: allCareTasks)
    }
    
    // MARK: - CareTask Actions
    @discardableResult
    func completeCareTask(
        _ task: CareTask,
        for cats: [Cat] = [],
        by caregiver: Caregiver?,
        completedForDate: Date? = nil,
        with notes: String? = nil,
        photos: [UIImage]? = nil
    ) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                try await completeCareTaskAndWait(
                    task,
                    for: cats,
                    by: caregiver,
                    completedForDate: completedForDate,
                    with: notes,
                    photos: photos
                )
            } catch {
                switch CareTaskWriteFailure(error) {
                case .cancelled:
                    break
                case .remindersStale(let staleError):
                    // The completion committed, so it counts as done; only the reminders are stale.
                    logStaleReminders(after: .completed, task, staleError)
                    raiseReminderWarning()
                case .notSaved:
                    logger.error("Failed to complete task: \(error.localizedDescription)")
                    raiseActionFailure(.completionNotSaved)
                }
            }
        }
    }

    /// Saves the photos, then commits the completion with them.
    ///
    /// With `.failCompletion`, a photo that cannot be saved throws its `PhotoSaveError` and nothing is
    /// committed. Photo files written by an attempt that commits nothing are deleted again.
    func completeCareTaskAndWait(
        _ task: CareTask,
        for cats: [Cat] = [],
        by caregiver: Caregiver?,
        completedForDate: Date? = nil,
        with notes: String? = nil,
        photos: [UIImage]? = nil,
        unsavedPhotos: UnsavedPhotoPolicy = .failCompletion
    ) async throws {
        guard let modelContext else { return }

        var savedPhotos = CareTaskPhotoSaveResult()
        if let photos, photos.isEmpty == false {
            savedPhotos = await photoWriter.save(photos)
        }
        if unsavedPhotos == .failCompletion, let failure = savedPhotos.failures.first {
            await photoWriter.delete(savedPhotos.fileNames)
            throw failure
        }

        do {
            try await taskWriter.complete(
                task,
                with: CareTaskCompletionInput(
                    cats: cats,
                    caregiver: caregiver,
                    completedForDate: completedForDate,
                    notes: notes,
                    photoURLs: savedPhotos.fileNames
                ),
                in: modelContext
            )
        } catch {
            // A cancelled or reminder-stale completion committed, and its photos belong to it.
            if case .notSaved = CareTaskWriteFailure(error) {
                await photoWriter.delete(savedPhotos.fileNames)
            }
            throw error
        }
        refreshTasks()
    }

    /// The view model has no store yet, so nothing can be saved.
    struct StoreUnavailableError: Error {}

    /// Saves a completion from the completion sheet and closes the sheet once the completion committed.
    ///
    /// Throws only when nothing was saved, so the sheet stays open with the user's input. A
    /// `PhotoSaveError` means a photo could not be saved while `unsavedPhotos` was `.failCompletion`.
    func submitCompletion(
        of task: CareTask,
        for cats: [Cat] = [],
        by caregiver: Caregiver?,
        completedForDate: Date? = nil,
        with notes: String? = nil,
        photos: [UIImage]? = nil,
        unsavedPhotos: UnsavedPhotoPolicy = .failCompletion
    ) async throws {
        // `completeCareTaskAndWait` returns quietly without a store; here that would close the sheet
        // with nothing saved.
        guard modelContext != nil else { throw StoreUnavailableError() }
        do {
            try await completeCareTaskAndWait(
                task,
                for: cats,
                by: caregiver,
                completedForDate: completedForDate,
                with: notes,
                photos: photos,
                unsavedPhotos: unsavedPhotos
            )
        } catch {
            switch CareTaskWriteFailure(error) {
            case .cancelled:
                // The completion committed, and the next resync rebuilds the reminders from the store.
                break
            case .remindersStale(let staleError):
                // The completion committed. A retry would record it twice, so the sheet still closes,
                // and the warning shows once it has.
                logStaleReminders(after: .completed, task, staleError)
                raiseReminderWarning()
            case .notSaved:
                throw error
            }
        }
        dismissTaskCompletion()
    }

    // MARK: - Alerts

    /// Call when the view presents the add-cat sheet, which is the view's own state.
    func addCatSheetWillPresent() {
        sheetsOnScreen.insert(.addCat)
    }

    /// Call from each sheet's dismiss callback. Shows an alert that waited for the sheet, once no
    /// sheet is left on screen.
    func sheetDidDismiss(_ sheet: Sheet) {
        // A sheet whose state was replaced rather than cleared is presented again.
        guard isRequested(sheet) == false else { return }
        sheetsOnScreen.remove(sheet)
        showNextPendingAlert()
    }

    private func isRequested(_ sheet: Sheet) -> Bool {
        switch sheet {
        case .taskTemplate: showingTaskTemplate
        case .taskCreation: taskCreationRequest != nil
        case .taskEdit: selectedCareTask != nil
        case .taskCompletion: taskCompletionRequest != nil
        case .addCat: false
        }
    }

    private func raiseReminderWarning() {
        hasPendingReminderWarning = true
        showNextPendingAlert()
    }

    private func raiseActionFailure(_ failure: TaskActionFailure) {
        // The same message twice in a row would say nothing new.
        if pendingActionFailures.last != failure {
            pendingActionFailures.append(failure)
        }
        showNextPendingAlert()
    }

    /// An alert closes inside the write of its own binding. Raising the next alert in that same write
    /// drops it when it uses the same alert (SwiftUI sees `true` before and after, so no change), and
    /// that flag then blocks every later alert. The next alert waits for the next main-actor turn.
    private func showNextPendingAlertAfterAlertCloses() {
        guard pendingActionFailures.isEmpty == false || hasPendingReminderWarning else { return }
        nextAlertPresentation = Task { [weak self] in
            self?.showNextPendingAlert()
        }
    }

    /// Shows one pending alert, the action failure first, when no sheet and no other alert is up.
    /// The rest stay pending until the shown alert closes.
    private func showNextPendingAlert() {
        guard sheetsOnScreen.isEmpty, isShowingActionFailure == false, isShowingReminderWarning == false else {
            return
        }
        if pendingActionFailures.isEmpty == false {
            actionFailure = pendingActionFailures.removeFirst()
            isShowingActionFailure = true
        } else if hasPendingReminderWarning {
            hasPendingReminderWarning = false
            isShowingReminderWarning = true
        }
    }

    /// The write that committed before its reminders went stale; the raw value opens the log line.
    private enum StaleRemindersAction: String {
        case completed = "Completed"
        case deleted = "Deleted"
    }

    private func logStaleReminders(
        after action: StaleRemindersAction,
        _ task: CareTask,
        _ error: CareTaskRemindersOutOfSyncError
    ) {
        let reason = error.underlyingError.localizedDescription
        logger.error("\(action.rawValue) '\(task.title)' but could not update its reminders: \(reason)")
    }

    @discardableResult
    func deleteCareTask(_ task: CareTask) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                try await deleteCareTaskAndWait(task)
            } catch {
                switch CareTaskWriteFailure(error) {
                case .cancelled:
                    break
                case .remindersStale(let staleError):
                    // The delete committed; only the reminders are stale.
                    logStaleReminders(after: .deleted, task, staleError)
                    raiseReminderWarning()
                case .notSaved:
                    // The writer keeps a failed delete staged, and the next successful save commits it,
                    // so the row stays removed.
                    logger.error("Failed to commit task delete: \(error.localizedDescription)")
                    raiseActionFailure(.deletePending)
                }
            }
        }
    }

    func deleteCareTaskAndWait(_ task: CareTask) async throws {
        guard let modelContext else { return }
        let taskId = task.id
        // Drop the row before the write: a failed commit leaves the delete staged, not undone.
        allCareTasks.removeAll { $0.id == taskId }
        refreshTasks()
        // A `CancellationError` also leaves the row removed. That is right only because
        // `CareTaskWriter.delete` commits before its first `await`; re-check it if the writer changes.
        try await taskWriter.delete(task, in: modelContext)
    }

    // MARK: - Notification Management
    func setupNotifications() async {
        // Check and request notification permissions
        await notificationManager.checkAuthorizationStatus()
        
        if notificationManager.authorizationStatus == .notDetermined {
            let granted = await notificationManager.requestPermission()
            print("✅ Notification permission granted: \(granted)")
        }
        
        #if DEBUG
        // Debug: Print pending notifications
        await notificationManager.printPendingNotifications()
        #endif
    }

    // MARK: - Presentation
    func presentTaskTemplateSelection() {
        showingTaskTemplate = true
    }

    func dismissTaskTemplateSelection() {
        showingTaskTemplate = false
    }

    func presentTaskCreation(template: CareTaskTemplate? = nil) {
        taskCreationRequest = TaskCreationRequest(template: template)
    }

    func dismissTaskCreation() {
        taskCreationRequest = nil
    }

    func presentTaskEdit(_ task: CareTask) {
        selectedCareTask = task
    }

    func dismissTaskEdit() {
        selectedCareTask = nil
    }

    func presentTaskCompletion(_ task: CareTask, completedForDate: Date? = nil) {
        taskCompletionRequest = TaskCompletionRequest(task: task, completedForDate: completedForDate)
    }

    func dismissTaskCompletion() {
        taskCompletionRequest = nil
    }

    @discardableResult
    func handleCompletionAction(for task: CareTask, completedForDate: Date? = nil) -> Bool {
        if task.assignedCats.count > 1 {
            presentTaskCompletion(task, completedForDate: completedForDate)
            return false
        }

        let cats = task.assignedCats.isEmpty ? [] : [task.assignedCats.first!]
        completeCareTask(task, for: cats, by: nil, completedForDate: completedForDate)
        return true
    }
    
    // MARK: - Navigation Handling
    func handleTaskNavigation(taskId: UUID, from allCareTasks: [CareTask]) {
        selectedViewMode = .list

        // Find the task in our list
        if let task = allCareTasks.first(where: { $0.id == taskId }) {
            presentTaskEdit(task)
            print("Found and navigating to care task: \(task.title)")
        } else {
            print("CareTask not found with ID: \(taskId)")
        }
    }
    
    // MARK: - Utility
    var dateRangeText: String {
        Date().formatted(
            .verbatim("\(day: .defaultDigits) \(month: .wide)", locale: .current, timeZone: .current, calendar: .current)
        )
    }

    private func refreshTasks() {
        updateTasks()
    }

    // MARK: - Test Helper Methods
    /// Test helper to verify that active tasks appear before completed tasks in grouped results
    func verifyTaskSorting() -> Bool {
        for section in groupedTasks {
            var foundCompletedTask = false
            for _ in section.tasks {
                let isActive = section.key != .completed
                if isActive == false {
                    foundCompletedTask = true
                } else if foundCompletedTask {
                    // Found an active task after a completed task - this is wrong
                    return false
                }
            }
        }
        return true
    }
} 
