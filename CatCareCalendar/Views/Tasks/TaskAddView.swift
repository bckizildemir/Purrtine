import SwiftUI
import SwiftData

struct TaskAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query private var allCats: [Cat]
    @Query private var allCaregivers: [Caregiver]

    let template: CareTaskTemplate?
    let titlePlaceholder: String?

    // Basic Information
    @State private var title: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedCategory: CareTaskCategory = .general
    @State private var selectedPriority: CareTaskPriority = .medium
    @State private var iconName: String = "circle"

    // Cat Assignment
    @State private var selectedCats: Set<Cat> = []
    @State private var assignToAllCats: Bool = false
    @State private var showingCatSelector: Bool = false

    // Caregiver Assignment
    @State private var selectedCaregiver: Caregiver?
    @State private var assignToMe: Bool = true

    // Scheduling
    @State private var startDate: Date = .now
    @State private var selectedTime: Date = .now
    @State private var hasTime: Bool = false
    @State private var frequency: CareTaskFrequency = .once
    @State private var frequencyInterval: Int = 1
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var hasEndDate: Bool = false
    @State private var customDays: Set<Int> = []
    @State private var showingCustomRepeatSheet = false
    @State private var repeatConfiguration: RepeatConfiguration = RepeatConfiguration()

    // Notifications
    @State private var enableReminder: Bool = true
    @State private var reminderMinutes: Int = 0

    // Custom Fields (from template)
    @State private var customFieldValues: [String: String] = [:]

    // Feeding Customization State
    @State private var showingFeedingDetailsSheet: Bool = false
    @State private var feedingDraft = FeedingDetailsDraft()

    // UI State
    @State private var isDatePickerExpanded: Bool = false
    @State private var isTimePickerExpanded: Bool = false
    @State private var initialSnapshot: [String]?

    // Validation State
    @State private var showTitleError: Bool = false
    @State private var showCatError: Bool = false
    @State private var catErrorResetTask: Task<Void, Never>?

    // Save
    /// True from the first tap of the save button until the save ends or fails.
    ///
    /// The reminder path dismisses only after an `await`, so the button stays on screen while the
    /// schedule runs. Without this flag a second tap creates a second task.
    @State private var isSaving: Bool = false

    // Save failure
    @State private var isSaveErrorPresented: Bool = false
    @State private var isScheduleReminderErrorPresented: Bool = false
    @State private var saveErrorDetail: String = ""

    @FocusState private var focusedField: TaskAddField?

    private var reminderOptions: [(value: Int, label: String)] {
        [
            (value: 0, label: String(localized: .reminderAtTime)),
            (value: 15, label: String(localized: .reminder15Minutes)),
            (value: 30, label: String(localized: .reminder30Minutes)),
            (value: 60, label: String(localized: .reminder1Hour)),
            (value: 1440, label: String(localized: .reminder1Day))
        ]
    }

    init(template: CareTaskTemplate?, titlePlaceholder: String? = nil, preselectedCat: Cat? = nil) {
        self.template = template
        self.titlePlaceholder = titlePlaceholder

        if let preselectedCat {
            _selectedCats = State(initialValue: [preselectedCat])
        }

        // Initialize with template values
        if let template {
            _title = State(initialValue: template.title)
            _taskDescription = State(initialValue: template.description)
            _selectedCategory = State(initialValue: template.category)
            _selectedPriority = State(initialValue: template.priority)
            _iconName = State(initialValue: template.iconName)
            _frequency = State(initialValue: template.defaultFrequency)
            _reminderMinutes = State(initialValue: template.defaultReminderMinutes ?? 0)
            _enableReminder = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Title and Notes Section
                    VStack(spacing: 0) {
                        TaskAddTitleSection(
                            title: $title,
                            placeholder: titlePlaceholder ?? String(localized: .tasksConfigNewReminder),
                            errorMessage: titleErrorMessage,
                            focusedField: $focusedField,
                            onTitleChange: handleTitleChange
                        )
                        TaskAddNotesSection(text: $taskDescription, focusedField: $focusedField)
                    }
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Date & Time Section
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(.tasksConfigDateAndTime)

                        VStack(spacing: 0) {
                            TaskAddDateSection(
                                startDate: $startDate,
                                isExpanded: isDatePickerExpanded,
                                onTap: toggleDatePicker
                            )
                            TaskAddTimeSection(
                                selectedTime: $selectedTime,
                                hasTime: $hasTime,
                                isPickerExpanded: isTimePickerExpanded,
                                onTap: toggleTimePicker
                            )
                        }
                        .background(Theme.backgroundSecondary)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Repeat Section
                    TaskAddFrequencySection(
                        selectedFrequency: frequency,
                        summary: repeatSummaryText,
                        onSelect: handleFrequencySelection
                    )
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Main Options
                    VStack(spacing: 0) {
                        TaskAddCatsSection(
                            allCats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats,
                            showingCatSelector: $showingCatSelector,
                            showCatError: showCatError,
                            horizontalSizeClass: horizontalSizeClass,
                            onCatSelectionChange: handleCatSelectionChange,
                            onAssignAllChange: handleAssignAllChange
                        )
                        CaregiverPickerSection(
                            additionalCaregivers: additionalCaregivers,
                            assignToMe: $assignToMe,
                            selectedCaregiver: $selectedCaregiver,
                            accessibilityIdentifier: "taskAdd.caregiverButton"
                        )
                        ReminderMenuRow(
                            options: reminderOptions,
                            selectedMinutes: $reminderMinutes,
                            isEnabled: $enableReminder
                        )
                        if let template, template.customFields.isEmpty == false {
                            TaskAddCustomFieldsSection(template: template, values: customFieldValues)
                        }
                    }
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Task Details Section
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(.tasksConfigTaskDetails)

                        VStack(spacing: 0) {
                            TaskAddPrioritySection(
                                selectedPriority: selectedPriority,
                                onSelect: handlePrioritySelection
                            )
                            TaskAddCategorySection(
                                selectedCategory: selectedCategory,
                                iconColor: colorForCategory(selectedCategory),
                                onSelect: handleCategorySelection
                            )
                            feedingDetailsRow
                        }
                        .background(Theme.backgroundSecondary)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: .tasksConfigAddTask))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                        .accessibilityIdentifier("taskAdd.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(action: createTask)
                        .disabled(isSaving)
                        .accessibilityIdentifier("taskAdd.saveButton")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: .actionDone)) {
                        focusedField = nil
                    }
                    .bold()
                }
            }
        }
        .sheet(isPresented: $showingFeedingDetailsSheet) {
            FeedingDetailsSheet(draft: $feedingDraft, onSave: applyFeedingSelections)
        }
        .sheet(isPresented: $showingCustomRepeatSheet) {
            CustomRepeatSheet(configuration: $repeatConfiguration, onSave: applyRepeatConfiguration)
        }
        .alert(String(localized: .errorDataSave), isPresented: $isSaveErrorPresented) { } message: {
            Text(saveErrorDetail)
        }
        .alert(String(localized: .errorReminderSchedule), isPresented: $isScheduleReminderErrorPresented) {
            // The task is already saved, so acknowledging the reminder failure closes the sheet.
            Button(String(localized: .actionOk)) { dismiss() }
        } message: {
            Text(saveErrorDetail)
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onAppear {
            if initialSnapshot == nil {
                initialSnapshot = currentSnapshot
            }
        }
        .onDisappear {
            catErrorResetTask?.cancel()
        }
        // Sync toggles and pickers
        .onChange(of: hasTime) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                if newValue {
                    // Time toggle turned on ➜ collapse date picker and show time picker
                    isDatePickerExpanded = false
                    isTimePickerExpanded = true
                } else {
                    // Time toggle turned off ➜ collapse its picker
                    isTimePickerExpanded = false
                }
            }
        }
    }

    private func sectionHeader(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var feedingDetailsRow: some View {
        if let template, let keys = FeedingFieldSupport.keys(for: template) {
            TaskAddFeedingDetailsRow(
                portionValue: customFieldValues[keys.portion],
                foodTypeValue: customFieldValues[keys.foodType],
                iconColor: colorForCategory(.feeding)
            ) {
                prepareFeedingSheet(with: template, keys: keys)
                showingFeedingDetailsSheet = true
            }
        }
    }

    private var additionalCaregivers: [Caregiver] {
        allCaregivers.filter { $0.localizationKey != CaregiverBootstrapper.defaultCaregiverLocalizationKey }
    }

    // MARK: - Selection Handlers

    private func toggleDatePicker() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDatePickerExpanded.toggle()
            if isDatePickerExpanded {
                isTimePickerExpanded = false
            }
        }
    }

    private func toggleTimePicker() {
        // The row is inert while the time toggle is off, because the picker has no meaning then.
        guard hasTime else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isTimePickerExpanded.toggle()
            if isTimePickerExpanded {
                isDatePickerExpanded = false
            }
        }
    }

    private func handleTitleChange(_ newValue: String) {
        guard showTitleError,
              newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            showTitleError = false
        }
    }

    private func handleCategorySelection(_ category: CareTaskCategory) {
        selectedCategory = category
        iconName = category.iconName
    }

    private func handlePrioritySelection(_ priority: CareTaskPriority) {
        selectedPriority = priority
    }

    private func handleFrequencySelection(_ freq: CareTaskFrequency) {
        if freq == .custom {
            presentCustomRepeatSheet()
            return
        }

        frequency = freq
        switch freq {
        case .once, .daily, .biweekly, .monthly:
            frequencyInterval = 1
            customDays.removeAll()
        case .weekly:
            frequencyInterval = 1
        case .custom:
            break
        }
    }

    private func handleCatSelectionChange(_ newValue: Set<Cat>) {
        guard newValue.isEmpty == false, showCatError else { return }
        clearCatError()
    }

    private func handleAssignAllChange(_ newValue: Bool) {
        guard newValue, showCatError else { return }
        clearCatError()
    }

    private func clearCatError() {
        catErrorResetTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            showCatError = false
        }
    }

    // MARK: - Repeat Configuration

    private var repeatSummaryText: String {
        switch frequency {
        case .once:
            frequency.displayName
        default:
            RepeatConfiguration.from(
                frequency: frequency,
                interval: frequencyInterval,
                customDays: customDays
            )
            .localizedSummary()
        }
    }

    private func presentCustomRepeatSheet() {
        repeatConfiguration = RepeatConfiguration.from(
            frequency: frequency,
            interval: frequencyInterval,
            customDays: customDays
        )
        showingCustomRepeatSheet = true
    }

    private func applyRepeatConfiguration(_ configuration: RepeatConfiguration) {
        let resolved = configuration.resolvedFrequency()
        frequency = resolved.frequency
        frequencyInterval = resolved.interval
        if let days = resolved.customDays {
            customDays = Set(days)
        } else {
            customDays.removeAll()
        }
    }

    // MARK: - Feeding Helpers

    private func prepareFeedingSheet(with template: CareTaskTemplate, keys: (portion: String, foodType: String)) {
        var draft = FeedingDetailsDraft()
        draft.portionFieldKey = keys.portion
        draft.foodTypeFieldKey = keys.foodType

        let portionField = template.customFields.first { $0.key == keys.portion }
        draft.portionFieldTitle = portionField?.name ?? String(localized: .templateMorningFeedingFieldPortionName)
        draft.portionFieldPlaceholder = portionField?.placeholder
            ?? String(localized: .templateMorningFeedingFieldPortionPlaceholder)

        let foodField = template.customFields.first { $0.key == keys.foodType }
        draft.foodFieldTitle = foodField?.name ?? String(localized: .templateMorningFeedingFieldFoodTypeName)
        draft.foodFieldPlaceholder = foodField?.placeholder
            ?? String(localized: .templateMorningFeedingFieldFoodTypePlaceholder)
        draft.foodTypeOptions = foodField?.options ?? []

        if let storedPortion = customFieldValues[keys.portion],
           let decoded = FeedingFieldSupport.decodePortion(storedPortion) {
            draft.portionAmount = decoded.amount
            draft.portionUnit = decoded.unit
        }

        draft.foodType = customFieldValues[keys.foodType]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        feedingDraft = draft
    }

    private func applyFeedingSelections() {
        guard let portionKey = feedingDraft.portionFieldKey,
              let foodKey = feedingDraft.foodTypeFieldKey else {
            return
        }

        customFieldValues[portionKey] = FeedingFieldSupport.encodePortion(
            amount: feedingDraft.portionAmount,
            unit: feedingDraft.portionUnit
        )
        customFieldValues[foodKey] = feedingDraft.foodType.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Computed Properties

    /// Serialized form state used to detect unsaved edits against the snapshot
    /// taken when the sheet first appears.
    private var currentSnapshot: [String] {
        [
            title,
            taskDescription,
            String(describing: selectedCategory),
            String(describing: selectedPriority),
            assignToAllCats.description,
            selectedCats.map { $0.id.uuidString }.sorted().joined(separator: ","),
            assignToMe.description,
            selectedCaregiver?.id.uuidString ?? "",
            startDate.description,
            hasTime.description,
            hasTime ? selectedTime.description : "",
            String(describing: frequency),
            String(frequencyInterval),
            hasEndDate ? endDate.description : "",
            customDays.sorted().map(String.init).joined(separator: ","),
            enableReminder.description,
            String(reminderMinutes),
            customFieldValues.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        ]
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }

    private var titleErrorMessage: String? {
        guard showTitleError else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: .tasksConfigTitleRequired) : nil
    }

    private func colorForCategory(_ category: CareTaskCategory) -> Color {
        switch category {
        case .feeding: .orange
        case .medication: .red
        case .grooming: .cyan
        case .health: .pink
        case .exercise: .green
        case .litter: .brown
        case .vet: .orange
        case .general: .gray
        case .water: .blue
        }
    }

    // MARK: - Create Task Method

    private func createTask() {
        // The disabled button already blocks the second tap. This guard covers the frame between
        // the tap and the state update.
        guard isSaving == false else { return }

        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasNoCats = allCats.isEmpty
        let isCatsNotSelected = hasNoCats == false && assignToAllCats == false && selectedCats.isEmpty

        if isTitleEmpty || hasNoCats || isCatsNotSelected {
            haptics.notify(.error)

            if isTitleEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTitleError = true
                }
            }

            if hasNoCats || isCatsNotSelected {
                showCatErrorBriefly()
            }

            return
        }

        let assignedCaregiver: Caregiver?
        if assignToMe {
            assignedCaregiver = allCaregivers.first { $0.isPrimary } ?? allCaregivers.first
        } else {
            assignedCaregiver = selectedCaregiver ?? allCaregivers.first
        }

        let draft = TaskFormDraft(
            title: title,
            taskDescription: taskDescription,
            category: selectedCategory,
            iconName: iconName,
            priority: selectedPriority,
            assignedCats: assignToAllCats ? allCats : Array(selectedCats),
            assignedCaregiver: assignedCaregiver,
            scheduledDate: startDate,
            scheduledTime: hasTime ? selectedTime : nil,
            frequency: frequency,
            frequencyInterval: frequencyInterval,
            endDate: hasEndDate ? endDate : nil,
            reminderMinutes: enableReminder ? reminderMinutes : nil,
            customDays: frequency == .weekly && customDays.isEmpty == false ? Array(customDays) : nil
        )

        // Set only after validation passes: the early return above must leave the button usable.
        isSaving = true

        let task: CareTask
        do {
            task = try TaskFormPersistence.createTask(
                from: draft,
                in: modelContext,
                existingCaregivers: allCaregivers,
                defaultCaregiverName: String(localized: .tasksConfigMyself),
                defaultCaregiverLocalizationKey: CaregiverBootstrapper.defaultCaregiverLocalizationKey
            )
        } catch {
            presentSaveError(error)
            return
        }

        // `saveTaskAndDismiss` owns the dismiss: a failed reminder schedule has to stay on screen
        // long enough to raise its alert.
        saveTaskAndDismiss(task)
    }

    /// Raises the "not saved" alert. The sheet stays open, so the button must accept a retry.
    private func presentSaveError(_ error: any Error) {
        haptics.notify(.error)
        saveErrorDetail = error.localizedDescription
        isSaveErrorPresented = true
        isSaving = false
    }

    /// Shows the cat-selection error, then hides it again after one second.
    ///
    /// The previous reset is cancelled first, so repeated Save taps cannot clear the error early.
    private func showCatErrorBriefly() {
        catErrorResetTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCatError = true
        }

        catErrorResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.3)) {
                showCatError = false
            }
        }
    }

    /// Commits the new task and its reminders, then dismisses.
    ///
    /// A failed schedule leaves the user with no reminders for a task they just asked to be
    /// reminded about, so it is user-impacting: the sheet stays open and raises an alert instead of
    /// dismissing. The task itself is already saved by then.
    private func saveTaskAndDismiss(_ task: CareTask) {
        let taskTitle = task.title

        Task {
            do {
                try await careTaskWriter.save(task, in: modelContext)
            } catch is CancellationError {
                // The task is saved, and the next resync rebuilds the reminders from the store, so
                // there is no user-facing failure to report here.
            } catch let error as CareTaskRemindersOutOfSyncError {
                print("❌ Failed to schedule notifications for '\(taskTitle)': \(error.underlyingError)")
                haptics.notify(.error)
                saveErrorDetail = error.localizedDescription
                isScheduleReminderErrorPresented = true
                // `isSaving` deliberately stays true, unlike the edit sheet's retry. The task is
                // already created and `TaskFormPersistence.createTask` is not idempotent, so a
                // second tap would add a duplicate. The alert dismisses the sheet instead.
                return
            } catch {
                presentSaveError(error)
                return
            }

            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        TaskAddView(template: CareTaskTemplateManager.shared.allTemplates.first)
    }
}
#endif
