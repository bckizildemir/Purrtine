import SwiftUI
import SwiftData

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.haptics) private var haptics
    @Environment(\.careTaskWriter) private var careTaskWriter
    
    @Query private var allCats: [Cat]
    @Query private var allCaregivers: [Caregiver]

    let task: CareTask
    
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
    @State private var assignToMe: Bool = true
    @State private var selectedCaregiver: Caregiver?
    
    // Scheduling
    @State private var startDate: Date = Date()
    @State private var selectedTime: Date = Date()
    @State private var hasDate: Bool = false
    @State private var hasTime: Bool = false
    @State private var frequency: CareTaskFrequency = .once
    @State private var frequencyInterval: Int = 1
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasEndDate: Bool = false
    @State private var customDays: Set<Int> = []
    @State private var showingCustomRepeatSheet = false
    @State private var repeatConfiguration: RepeatConfiguration = RepeatConfiguration()
    
    // Notifications
    @State private var enableReminder: Bool = true
    @State private var reminderMinutes: Int = 15
    
    // UI State
    @State private var isDatePickerExpanded: Bool = false
    @State private var isTimePickerExpanded: Bool = false
    @State private var isPopulatingFromTask: Bool = false
    @State private var initialSnapshot: [String]?

    // Save
    /// True from the first tap of the save button until the save ends or fails.
    ///
    /// Both reminder paths dismiss only after an `await`, so the button stays on screen while the
    /// save runs. Without this flag a second tap starts a second save.
    @State private var isSaving: Bool = false

    // Save failure
    @State private var isSaveErrorPresented: Bool = false
    @State private var isCancelReminderErrorPresented: Bool = false
    @State private var isScheduleReminderErrorPresented: Bool = false
    @State private var saveErrorDetail: String = ""

    // Focus Management
    enum Field: Hashable {
        case title
        case notes
    }
    @FocusState private var focusedField: Field?
    
    private var reminderOptions: [(value: Int, label: String)] {
        [
            (value: 0, label: String(localized: .reminderAtTime)),
            (value: 15, label: String(localized: .reminder15Minutes)),
            (value: 30, label: String(localized: .reminder30Minutes)),
            (value: 60, label: String(localized: .reminder1Hour)),
            (value: 1440, label: String(localized: .reminder1Day))
        ]
    }
    
    init(task: CareTask) {
        self.task = task
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Title and Notes Section
                    VStack(spacing: 0) {
                        titleSection
                        notesSection
                    }
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        dateSection
                        timeSection
                    }
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Main Options
                    VStack(spacing: 0) {
                        TaskEditCatsSection(
                            allCats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats,
                            showingCatSelector: $showingCatSelector,
                            horizontalSizeClass: horizontalSizeClass
                        )
                        CaregiverPickerSection(
                            additionalCaregivers: additionalCaregivers,
                            assignToMe: $assignToMe,
                            selectedCaregiver: $selectedCaregiver,
                            accessibilityIdentifier: "taskEdit.caregiverButton"
                        )
                        frequencySection
                        reminderSection
                        prioritySection
                        categorySection
                    }
                    .background(Theme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: .tasksEditTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                    .accessibilityIdentifier("taskEdit.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        saveChanges()
                    }
                    .disabled(!canSaveTask || isSaving)
                    .accessibilityIdentifier("taskEdit.saveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: .actionDone)) {
                        focusedField = nil
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showingCustomRepeatSheet) {
                CustomRepeatSheet(configuration: $repeatConfiguration) { configuration in
                    applyRepeatConfiguration(configuration)
                }
            }
        }
        .alert(String(localized: .errorDataSave), isPresented: $isSaveErrorPresented) { } message: {
            Text(saveErrorDetail)
        }
        .alert(String(localized: .errorReminderCancel), isPresented: $isCancelReminderErrorPresented) { } message: {
            Text(saveErrorDetail)
        }
        .alert(String(localized: .errorReminderSchedule), isPresented: $isScheduleReminderErrorPresented) { } message: {
            Text(saveErrorDetail)
        }
        // `isSaving` is part of the condition because the snapshot is re-baselined before the
        // notification hop: without it a swipe-dismiss mid-save would discard the failure alert.
        .interactiveDismissDisabled(hasUnsavedChanges || isSaving)
        .onAppear {
            // Populate once. A second `onAppear` would overwrite the user's edits with the
            // stored task and reset the baseline that `hasUnsavedChanges` compares against.
            guard initialSnapshot == nil else { return }

            isPopulatingFromTask = true
            populateFromTask()
            isDatePickerExpanded = false
            isTimePickerExpanded = false
            initialSnapshot = currentSnapshot
            Task { @MainActor in
                isPopulatingFromTask = false
            }
        }
        // Sync toggles and pickers
        .onChange(of: hasDate) { _, newValue in
            guard !isPopulatingFromTask else { return }
            // When the date toggle is turned off, also turn off everything that depends on it
            if !newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasTime = false
                    isTimePickerExpanded = false
                    isDatePickerExpanded = false
                }
            }
        }
        .onChange(of: hasTime) { _, newValue in
            guard !isPopulatingFromTask else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                if newValue {
                    // Time toggle turned on ➜ ensure date toggle is on but keep its picker collapsed
                    if !hasDate {
                        hasDate = true
                    }
                    isDatePickerExpanded = false     // do NOT open the date picker
                    isTimePickerExpanded = true      // make sure the time picker is visible
                } else {
                    // Time toggle turned off ➜ collapse its picker
                    isTimePickerExpanded = false
                }
            }
        }
    }
    
    // MARK: - Title Section
    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 0) {
            TextField(String(localized: .tasksEditTitlePlaceholder), text: $title)
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.clear)
                .accessibilityIdentifier("taskEdit.titleField")
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .notes
                }
        }
    }
    
    // MARK: - Notes Section
    @ViewBuilder
    private var notesSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)
            
            TextField(String(localized: .tasksEditNotesPlaceholder), text: $taskDescription, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.clear)
                .frame(minHeight: 56, alignment: .topLeading)
                .lineLimit(3...6)
                .accessibilityIdentifier("taskEdit.notesField")
                .focused($focusedField, equals: .notes)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
        }
    }
    
    // MARK: - Date Section
    @ViewBuilder
    private var dateSection: some View {
        VStack(spacing: 0) {
            RemindersOptionRow(
                icon: "calendar",
                iconColor: Theme.iconDate,
                title: String(localized: .tasksConfigDate),
                subtitle: hasDate ? startDate.taskDayLabel : nil,
                value: hasDate ? formatDate(startDate) : nil,
                hasToggle: true,
                isToggled: $hasDate
            ) {
                handleDateRowTap()
            }

            if hasDate && isDatePickerExpanded {
                DatePicker(
                    "",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Time Section
    @ViewBuilder
    private var timeSection: some View {
        VStack(spacing: 0) {
            RemindersOptionRow(
                icon: "clock.fill",
                iconColor: Theme.iconTime,
                title: String(localized: .tasksConfigTime),
                subtitle: hasTime ? dynamicTimeLabel(for: selectedTime) : nil,
                value: hasTime ? formatTime(selectedTime) : nil,
                hasToggle: true,
                isToggled: $hasTime
            ) {
                handleTimeRowTap()
            }

            // Kept always mounted (instead of inserted/removed via `if`) so its
            // intrinsic width is resolved once and never renegotiated mid-animation —
            // only height/opacity animate, so only this section moves, and it only
            // grows downward instead of also flashing wider.
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            // Fix height only: fixing both axes made the picker report its
            // ideal (wider-than-card) width, widening every section around it.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(height: isTimePickerVisible ? nil : 0, alignment: .top)
            .clipped()
            .opacity(isTimePickerVisible ? 1 : 0)
            .allowsHitTesting(isTimePickerVisible)
            .accessibilityHidden(!isTimePickerVisible)
        }
        .animation(.easeInOut(duration: 0.3), value: isTimePickerVisible)
    }

    private var isTimePickerVisible: Bool {
        hasTime && isTimePickerExpanded
    }

    // MARK: - Category Section
    @ViewBuilder
    private var categorySection: some View {
        Menu {
            ForEach(CareTaskCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                    iconName = category.iconName
                } label: {
                    HStack {
                        Image(systemName: category.iconName)
                        Text(category.displayName)
                        if selectedCategory == category {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SimpleOptionRow(
                icon: selectedCategory.iconName,
                iconColor: colorForCategory(selectedCategory),
                title: String(localized: .tasksConfigCategory),
                value: selectedCategory.displayName
            )
        }
    }
    
    // MARK: - Priority Section
    @ViewBuilder
    private var prioritySection: some View {
        Menu {
            ForEach(CareTaskPriority.allCases, id: \.self) { priority in
                Button {
                    selectedPriority = priority
                } label: {
                    HStack {
                        Text(priority.displayName)
                        if selectedPriority == priority {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SimpleOptionRow(
                icon: "exclamationmark",
                iconColor: Theme.iconPriority,
                title: String(localized: .tasksConfigPriority),
                value: selectedPriority.displayName
            )
        }
    }
    
    // MARK: - Caregiver Section
    private var additionalCaregivers: [Caregiver] {
        allCaregivers.filter { $0.localizationKey != CaregiverBootstrapper.defaultCaregiverLocalizationKey }
    }

    // MARK: - Frequency Section
    @ViewBuilder
    private var frequencySection: some View {
        Menu {
            ForEach(CareTaskFrequency.allCases, id: \.self) { freq in
                Button {
                    handleFrequencySelection(freq)
                } label: {
                    HStack {
                        Text(freq.displayName)
                        if frequency == freq {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SimpleOptionRow(
                icon: "repeat",
                iconColor: Theme.iconSchedule,
                title: String(localized: .tasksConfigRepeat),
                value: repeatSummaryText
            )
        }
    }
    
    // MARK: - Reminder Section
    @ViewBuilder
    private var reminderSection: some View {
        ReminderMenuRow(
            options: reminderOptions,
            selectedMinutes: $reminderMinutes,
            isEnabled: $enableReminder
        )
    }
    
    // MARK: - Helper Methods
    private func handleDateRowTap() {
        if hasDate {
            // Date toggle açıkken, picker'ı aç/kapat
            withAnimation(.easeInOut(duration: 0.3)) {
                isDatePickerExpanded.toggle()
                // Eğer date picker açılıyorsa, time picker'ı kapat
                if isDatePickerExpanded {
                    isTimePickerExpanded = false
                }
            }
        } else {
            // Date toggle kapalıyken, hiçbir şey yapma
            return
        }
    }
    
    private func handleTimeRowTap() {
        if hasTime {
            // Time toggle açıkken, picker'ı aç/kapat
            withAnimation(.easeInOut(duration: 0.3)) {
                isTimePickerExpanded.toggle()
                // Eğer time picker açılıyorsa, date picker'ı kapat
                if isTimePickerExpanded {
                    isDatePickerExpanded = false
                }
            }
        } else {
            // Time toggle kapalıyken, hiçbir şey yapma
            return
        }
    }
    
    private func dynamicTimeLabel(for date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .autoupdatingCurrent))
    }
    
    private var repeatSummaryText: String {
        switch frequency {
        case .once:
            return frequency.displayName
        default:
            let config = RepeatConfiguration.from(
                frequency: frequency,
                interval: frequencyInterval,
                customDays: customDays
            )
            return config.localizedSummary()
        }
    }
    
    private func handleFrequencySelection(_ freq: CareTaskFrequency) {
        if freq == .custom {
            presentCustomRepeatSheet()
            return
        }
        
        frequency = freq
        switch freq {
        case .once, .daily:
            frequencyInterval = 1
            customDays.removeAll()
        case .weekly:
            frequencyInterval = 1
        case .biweekly:
            frequencyInterval = 1
            customDays.removeAll()
        case .monthly:
            frequencyInterval = 1
            customDays.removeAll()
        case .custom:
            break
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
    
    // MARK: - Computed Properties
    private var canSaveTask: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (assignToAllCats || !selectedCats.isEmpty)
    }

    /// Serialized form state used to detect unsaved edits against the snapshot
    /// taken right after `populateFromTask()`.
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
            hasDate.description,
            hasTime.description,
            hasDate ? startDate.description : "",
            hasTime ? selectedTime.description : "",
            String(describing: frequency),
            String(frequencyInterval),
            hasEndDate ? endDate.description : "",
            customDays.sorted().map(String.init).joined(separator: ","),
            enableReminder.description,
            String(reminderMinutes)
        ]
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }
    
    // MARK: - Pre-populate from Task
    private func populateFromTask() {
        // Basic fields
        title = task.title
        taskDescription = task.taskDescription ?? ""
        selectedCategory = task.category
        selectedPriority = task.priority
        iconName = task.iconName
        
        // Cats
        if task.assignedCats.count == allCats.count && !allCats.isEmpty {
            assignToAllCats = true
            selectedCats = []
        } else {
            assignToAllCats = false
            selectedCats = Set(task.assignedCats)
        }

        // Caregiver - a non-default assignee maps to an explicit selection;
        // otherwise fall back to the "Myself" (default/primary) option.
        if let caregiver = task.assignedCaregiver,
           additionalCaregivers.contains(where: { $0.id == caregiver.id }) {
            assignToMe = false
            selectedCaregiver = caregiver
        } else {
            assignToMe = true
            selectedCaregiver = nil
        }

        // Schedule - get the primary active schedule
        if let primarySchedule = task.schedules.first(where: { $0.isActive }) ?? task.schedules.first {
            startDate = primarySchedule.scheduledDate
            hasDate = true
            
            if let scheduledTime = primarySchedule.scheduledTime {
                selectedTime = scheduledTime
                hasTime = true
            } else {
                hasTime = false
            }
            
            frequency = primarySchedule.frequency
            frequencyInterval = primarySchedule.frequencyInterval
            
            if let endDate = primarySchedule.endDate {
                self.endDate = endDate
                hasEndDate = true
            } else {
                hasEndDate = false
            }
            
            customDays = Set(primarySchedule.customDays ?? [])
            
            if let reminderMinutes = primarySchedule.reminderMinutes {
                self.reminderMinutes = reminderMinutes
                enableReminder = true
            } else {
                enableReminder = false
            }
        } else {
            // No schedule exists, use defaults
            hasDate = false
            hasTime = false
            frequency = .once
            hasEndDate = false
            enableReminder = false
        }
    }
    
    // MARK: - Save Changes Method
    private func saveChanges() {
        // The disabled button already blocks the second tap. This guard covers the frame between
        // the tap and the state update.
        guard isSaving == false else { return }
        isSaving = true

        let assignedCaregiver: Caregiver?
        if assignToMe {
            assignedCaregiver = allCaregivers.first(where: { $0.isPrimary }) ?? allCaregivers.first
        } else {
            assignedCaregiver = selectedCaregiver ?? task.assignedCaregiver
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
            customDays: frequency == .weekly && !customDays.isEmpty ? Array(customDays) : nil
        )

        do {
            try TaskFormPersistence.updateTask(task, from: draft, in: modelContext)
        } catch {
            presentSaveError(error)
            return
        }

        // `saveChangesAndDismiss` owns the dismiss: a failed reminder update has to stay on screen
        // long enough to raise its alert.
        saveChangesAndDismiss()
    }

    /// Raises the "not saved" alert. The sheet stays open, so the button must accept a retry.
    private func presentSaveError(_ error: any Error) {
        haptics.notify(.error)
        saveErrorDetail = error.localizedDescription
        isSaveErrorPresented = true
        isSaving = false
    }

    /// Commits the edits and brings this task's reminders in line with them, then dismisses.
    ///
    /// A failed reminder update is user-impacting either way: with the reminder on, the user is
    /// left with no reminders for a task they just asked to be reminded about; with it off, with
    /// reminders that still fire. So the sheet stays open and raises the matching alert instead of
    /// dismissing.
    private func saveChangesAndDismiss() {
        // Read the model before the hop, so the log line survives a dismiss.
        let taskTitle = task.title
        let isReminderEnabled = enableReminder

        Task {
            do {
                try await careTaskWriter.save(task, in: modelContext)
            } catch is CancellationError {
                // The edits are committed, and the next resync rebuilds the reminders from the
                // store, so there is no user-facing failure to report here.
            } catch let error as CareTaskRemindersOutOfSyncError {
                // The edits are committed. Re-baseline the snapshot: without this,
                // `hasUnsavedChanges` would still report the already-saved edits as unsaved, so the
                // dismiss button would warn about discarding work that is already on disk.
                initialSnapshot = currentSnapshot
                print("❌ Failed to update notifications for '\(taskTitle)': \(error.underlyingError)")
                haptics.notify(.error)
                saveErrorDetail = error.localizedDescription
                if isReminderEnabled {
                    isScheduleReminderErrorPresented = true
                } else {
                    isCancelReminderErrorPresented = true
                }
                // The sheet stays open, so the button must accept a retry.
                isSaving = false
                return
            } catch {
                presentSaveError(error)
                return
            }

            dismiss()
        }
    }
    
    private func colorForCategory(_ category: CareTaskCategory) -> Color {
        switch category {
        case .feeding: return .orange
        case .medication: return .red
        case .grooming: return .cyan
        case .health: return .pink
        case .exercise: return .green
        case .litter: return .brown
        case .vet: return .orange
        case .general: return .gray
        case .water: return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: .autoupdatingCurrent))
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .autoupdatingCurrent))
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        if let task = PreviewData.firstTask() {
            TaskEditView(task: task)
        }
    }
} 
#endif
