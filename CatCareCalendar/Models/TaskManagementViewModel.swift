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
    var showingTaskTemplate: Bool = false
    var taskCreationRequest: TaskCreationRequest?
    
    // CareTask Actions
    var selectedCareTask: CareTask?
    
    // CareTask Completion
    var taskCompletionRequest: TaskCompletionRequest?

    /// A completion saved, but its reminders could not be updated. Drives the reminder warning alert.
    var isShowingReminderWarning = false

    /// A reminder warning from the completion sheet, held until the sheet has closed.
    private var hasPendingReminderWarning = false

    /// The last one-tap complete or delete that did not save. Kept after the alert closes, so the
    /// alert's text does not change while it animates away.
    private(set) var actionFailure: TaskActionFailure?

    /// Drives the alert for `actionFailure`.
    var isShowingActionFailure = false

    // YENİ: UI için işlenmiş ve hazır veriler
    var groupedTasks: [TaskListSection] = []
    var taskCounts: [CareTaskFilter: Int] = [:]
    
    private let notificationManager: NotificationManager
    private let taskWriter: any CareTaskWriting
    private var modelContext: ModelContext?
    private var allCareTasks: [CareTask] = []
    private let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "TaskManagement")

    init(
        notificationManager: NotificationManager = .shared,
        taskWriter: (any CareTaskWriting)? = nil
    ) {
        self.notificationManager = notificationManager
        self.taskWriter = taskWriter ?? CareTaskWriter(scheduler: notificationManager)
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
                    logStaleReminders(after: "Completed", task, staleError)
                    isShowingReminderWarning = true
                case .notSaved:
                    logger.error("Failed to complete task: \(error.localizedDescription)")
                    showActionFailure(.completionNotSaved)
                }
            }
        }
    }

    func completeCareTaskAndWait(
        _ task: CareTask,
        for cats: [Cat] = [],
        by caregiver: Caregiver?,
        completedForDate: Date? = nil,
        with notes: String? = nil,
        photos: [UIImage]? = nil
    ) async throws {
        guard let modelContext else { return }

        let photoURLs = photos.map(savePhotosToDocuments) ?? []
        try await taskWriter.complete(
            task,
            with: CareTaskCompletionInput(
                cats: cats,
                caregiver: caregiver,
                completedForDate: completedForDate,
                notes: notes,
                photoURLs: photoURLs
            ),
            in: modelContext
        )
        refreshTasks()
    }

    /// The view model has no store yet, so nothing can be saved.
    struct StoreUnavailableError: Error {}

    /// Saves a completion from the completion sheet and closes the sheet once the completion committed.
    ///
    /// Throws only when nothing was saved, so the sheet stays open with the user's input.
    func submitCompletion(
        of task: CareTask,
        for cats: [Cat] = [],
        by caregiver: Caregiver?,
        completedForDate: Date? = nil,
        with notes: String? = nil,
        photos: [UIImage]? = nil
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
                photos: photos
            )
        } catch {
            switch CareTaskWriteFailure(error) {
            case .cancelled:
                // The completion committed, and the next resync rebuilds the reminders from the store.
                break
            case .remindersStale(let staleError):
                // The completion committed. A retry would record it twice, so the sheet still closes,
                // and the warning shows once it has.
                logStaleReminders(after: "Completed", task, staleError)
                hasPendingReminderWarning = true
            case .notSaved:
                throw error
            }
        }
        dismissTaskCompletion()
    }

    /// Call when the completion sheet has closed. Shows the reminder warning its save left pending:
    /// an alert raised while the sheet is still on screen would not present.
    func taskCompletionSheetDidDismiss() {
        guard hasPendingReminderWarning else { return }
        hasPendingReminderWarning = false
        isShowingReminderWarning = true
    }

    private func logStaleReminders(
        after action: String,
        _ task: CareTask,
        _ error: CareTaskRemindersOutOfSyncError
    ) {
        logger.error(
            "\(action) '\(task.title)' but could not update its reminders: \(error.underlyingError.localizedDescription)"
        )
    }

    private func showActionFailure(_ failure: TaskActionFailure) {
        actionFailure = failure
        isShowingActionFailure = true
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
                    logStaleReminders(after: "Deleted", task, staleError)
                    isShowingReminderWarning = true
                case .notSaved:
                    // The writer keeps a failed delete staged, and the next successful save commits it,
                    // so the row stays removed.
                    logger.error("Failed to commit task delete: \(error.localizedDescription)")
                    showActionFailure(.deletePending)
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
    
    // MARK: - Photo Management
    private func savePhotosToDocuments(_ photos: [UIImage]) -> [String] {
        var savedPaths: [String] = []
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("CareTaskPhotos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        for (_, photo) in photos.enumerated() {
            let fileName = "task_photo_\(UUID().uuidString).jpg"
            let fileURL = photosDirectory.appendingPathComponent(fileName)
            
            // Downsample + encode once before writing.
            if let imageData = PhotoManager.downsampledJPEGData(from: photo, maxPixelSize: PhotoManager.photoMaxPixelSize) {
                do {
                    try imageData.write(to: fileURL)
                    savedPaths.append(fileURL.lastPathComponent) // Store relative path
                    print("✅ Photo saved: \(fileName)")
                } catch {
                    print("❌ Failed to save photo: \(error)")
                }
            }
        }

        return savedPaths
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
