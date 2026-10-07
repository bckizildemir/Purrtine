import SwiftData
import SwiftUI

struct TaskAssistantChatView: View {
    @Bindable var viewModel: TaskAssistantViewModel
    let allCareTasks: [CareTask]
    let allCats: [Cat]
    let allCaregivers: [Caregiver]
    let quickActionChips: [TaskAssistantSuggestion]
    let onOpenTask: (UUID) -> Void
    let onEndChat: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.haptics) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresentingCloudConsent = false
    @State private var isAtBottom = true
    @State private var isComposerVisible = false
    @State private var scrollPosition = ScrollPosition()

    /// How close (in points) to the content's bottom edge still counts as "at the bottom".
    private static let bottomThreshold: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
                .opacity(isComposerVisible ? 1 : 0)
                .offset(y: reduceMotion || isComposerVisible ? 0 : 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: .taskAssistantTitle))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SheetDismissButton(action: onEndChat)
                    .accessibilityIdentifier("taskAssistant.endChatButton")
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .sheet(item: $viewModel.taskCompletionRequest, onDismiss: {
            viewModel.taskCompletionRequest = nil
        }) { request in
            TaskCompletionView(
                task: request.task,
                completedForDate: request.completedForDate,
                initialNotes: request.initialNotes,
                initialSelectedCats: request.initialSelectedCats
            ) { selectedCats, selectedCaregiver, notes, photos, completedForDate in
                Task {
                    await viewModel.completeDetailedTask(
                        task: request.task,
                        selectedCats: selectedCats,
                        selectedCaregiver: selectedCaregiver,
                        notes: notes,
                        photos: photos,
                        completedForDate: completedForDate,
                        in: modelContext
                    )
                }
            }
        }
        .onDisappear(perform: viewModel.stopDictation)
        .task {
            handleAppearance()
        }
        .sheet(isPresented: $isPresentingCloudConsent) {
            TaskAssistantCloudConsentView(
                onAllow: { respondToCloudConsent(granted: true) },
                onDecline: { respondToCloudConsent(granted: false) }
            )
        }
    }

    private func respondToCloudConsent(granted: Bool) {
        UserDefaults.standard.set(granted, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)
        isPresentingCloudConsent = false
    }

    private func handleAppearance() {
        isPresentingCloudConsent = !SettingsPreferences.hasAnsweredTaskAssistantCloudConsent(in: .standard)

        guard isComposerVisible == false else { return }
        if reduceMotion {
            isComposerVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                isComposerVisible = true
            }
        }
    }
}

private extension TaskAssistantChatView {
    var messageList: some View {
        ScrollView {
            // A plain VStack (not lazy): the assistant only ever holds a handful of chat
            // messages, so eager layout is cheap and keeps content-size reporting stable
            // for the scroll-to-bottom logic.
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.messages.isEmpty && viewModel.draftText.isEmpty {
                    TaskAssistantEmptyStateView(chips: quickActionChips) { suggestion in
                        haptics.selection()
                        viewModel.chooseSuggestion(suggestion)
                    }
                    .transition(.opacity)
                }

                ForEach(viewModel.messages) { message in
                    TaskAssistantMessageBubbleView(message: message)
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                if viewModel.isProcessing {
                    TaskAssistantTypingIndicatorView()
                        .transition(.opacity)
                }

                if let clarification = viewModel.pendingClarification {
                    clarificationCard(clarification)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let disambiguation = viewModel.pendingTaskDisambiguation {
                    taskDisambiguationCard(disambiguation)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let intentSelection = viewModel.pendingIntentSelection {
                    intentSelectionCard(intentSelection)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let confirmation = viewModel.pendingConfirmation {
                    confirmationCard(confirmation)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let session = viewModel.taskCreationSession {
                    taskCreationCard(session)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding()
            // Fill the width and pin content leading so the message column can never drift
            // horizontally — the chat scrolls only vertically.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.top)
        // Stick to the bottom as content grows and settles — a new message, the typing
        // indicator, or a clarification/confirmation card. This is a layout-level policy
        // (not a scroll command), so it lands past a card that is still animating in, which a
        // one-shot scrollTo fired during the same update cannot do.
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .animation(.default, value: viewModel.messages.count)
        .animation(.default, value: viewModel.isProcessing)
        .animation(.default, value: viewModel.pendingClarification == nil)
        .animation(.default, value: viewModel.pendingTaskDisambiguation == nil)
        .animation(.default, value: viewModel.pendingIntentSelection == nil)
        .animation(.default, value: viewModel.pendingConfirmation == nil)
        .animation(.default, value: viewModel.taskCreationSession == nil)
        .animation(.default, value: viewModel.draftText.isEmpty)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            // Drives the jump-to-latest chevron: within `bottomThreshold` of the content's
            // bottom edge (including any trailing card).
            geometry.visibleRect.maxY >= geometry.contentSize.height - Self.bottomThreshold
        } action: { _, newValue in
            isAtBottom = newValue
        }
        .onChange(of: viewModel.scrollToBottomToken) { _, _ in
            // The user just sent a message or picked a suggestion — bring them to the bottom
            // even if they'd scrolled up. When already at the bottom the follow above handles
            // it, so skip a competing animated scroll.
            if !isAtBottom {
                scrollToBottom()
            }
        }
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            // Accessibility + failure haptic only — scrolling is handled by the geometry
            // follow and the send token above. Guard on append so cancelling a card (which
            // removes the trailing bubble) doesn't re-announce an older message.
            guard newCount > oldCount, let last = viewModel.messages.last, last.role == .assistant else { return }
            if last.style == .failure {
                haptics.notify(.error)
            }
            AccessibilityNotification.Announcement(last.text).post()
        }
        .overlay(alignment: .bottomTrailing) {
            if !isAtBottom, !viewModel.messages.isEmpty {
                Button {
                    scrollToBottom()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.accent)
                        .background(Circle().fill(Theme.background))
                }
                .padding(12)
                .accessibilityLabel(String(localized: .taskAssistantJumpToLatest))
                .accessibilityIdentifier("taskAssistant.jumpToLatestButton")
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    /// One-shot animated scroll to the content's bottom edge — used by the jump-to-latest
    /// button and the send token (to bring a scrolled-up user down to their new message).
    /// Respects Reduce Motion. The continuous "stick to the bottom as content grows" behavior
    /// is handled at the layout level by `.defaultScrollAnchor(.bottom, for: .sizeChanges)`.
    private func scrollToBottom() {
        if reduceMotion {
            scrollPosition.scrollTo(edge: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
    }

    var composer: some View {
        VStack(spacing: 8) {
            // A neutral "Create a task" chip sits above the field, deliberately distinct from
            // the blue complete-chips up top so the two aren't confused. Hidden while a create
            // flow is already running.
            if viewModel.taskCreationSession == nil {
                HStack {
                    Button {
                        haptics.impact(.light)
                        viewModel.beginTaskCreation(cats: allCats)
                    } label: {
                        Label(String(localized: .taskAssistantCreateChip), systemImage: "plus.circle")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .disabled(viewModel.isProcessing)
                    .accessibilityIdentifier("taskAssistant.createTaskButton")

                    Spacer()
                }
            }

            composerField
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    /// Messages-style capsule input: Liquid Glass on iOS 26, material capsule earlier.
    @ViewBuilder
    var composerField: some View {
        let field = TextField(
            viewModel.isRecording
                ? String(localized: .taskAssistantListening)
                : String(localized: .taskAssistantInputPlaceholder),
            text: $viewModel.draftText,
            axis: .vertical
        )
        .lineLimit(1...4)
        .textInputAutocapitalization(.sentences)
        .submitLabel(.return)
        .disabled(viewModel.isProcessing)
        .padding(.leading, 16)
        .padding(.trailing, 46)
        .padding(.vertical, 9)

        Group {
            if #available(iOS 26.0, *) {
                field
                    .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                field
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
                    }
            }
        }
        .overlay(alignment: .trailing) {
            trailingComposerAccessory
                .padding(.trailing, 6)
        }
        .accessibilityIdentifier("taskAssistant.input")
    }

    private func submitDraft() {
        guard canSend else { return }
        haptics.impact(.light)
        viewModel.stopDictation()
        Task {
            await viewModel.sendCurrentDraft(tasks: allCareTasks)
        }
    }

    @ViewBuilder
    var trailingComposerAccessory: some View {
        if canSend {
            Button {
                submitDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel(String(localized: .taskAssistantSendButton))
            .accessibilityIdentifier("taskAssistant.sendButton")
        } else if viewModel.isRecording {
            Button {
                viewModel.stopDictation()
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative.reversing)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(String(localized: .taskAssistantStopButton))
            .accessibilityIdentifier("taskAssistant.stopButton")
        } else {
            Button {
                Task {
                    await viewModel.startDictation()
                }
            } label: {
                Image(systemName: "microphone.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .disabled(viewModel.isProcessing)
            .accessibilityLabel(String(localized: .taskAssistantMicButton))
            .accessibilityIdentifier("taskAssistant.micButton")
        }
    }

    var canSend: Bool {
        !viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isProcessing
    }

    func clarificationCard(_ clarification: TaskAssistantClarification) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(clarification.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            suggestionsList(clarification.suggestions)

            Button(String(localized: .actionCancel)) {
                viewModel.cancelPendingAction()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("taskAssistant.cancelClarificationButton")
        }
        .padding(14)
        // Grouped (not secondary) so the suggestion rows' `secondarySystemGroupedBackground`
        // surface reads as a distinct elevated card against this bubble in both appearances —
        // matching `backgroundSecondary` here made the fallback cards blend into the bubble.
        .background(Theme.backgroundGrouped)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    func suggestionsList(_ suggestions: [TaskAssistantSuggestion]) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                suggestionsStack(suggestions)
            }
        } else {
            suggestionsStack(suggestions)
        }
    }

    func suggestionsStack(_ suggestions: [TaskAssistantSuggestion]) -> some View {
        VStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
    }

    func suggestionRow(_ suggestion: TaskAssistantSuggestion) -> some View {
        let task = suggestion.task

        return Button {
            viewModel.chooseSuggestion(suggestion)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.iconName)
                    .foregroundStyle(task.isOverdue ? .red : .blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if task.assignedCatNames.isEmpty == false {
                            Text(task.assignedCatNames)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if task.dueDisplayText().isEmpty == false {
                            Text(verbatim: "•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(task.dueDisplayText())
                                .font(.caption)
                                .foregroundStyle(task.isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .taskCardSurface(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("taskAssistant.suggestion.\(suggestion.title)")
    }

    func taskDisambiguationCard(_ disambiguation: TaskAssistantTaskDisambiguation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(disambiguation.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(disambiguation.choices) { choice in
                taskChoiceRow(choice)
            }

            Button(String(localized: .actionCancel)) {
                viewModel.cancelPendingAction()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("taskAssistant.cancelTaskDisambiguationButton")
        }
        .padding(14)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func taskChoiceRow(_ choice: TaskAssistantTaskChoice) -> some View {
        let task = choice.task

        return Button {
            viewModel.chooseTaskChoice(choice)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.iconName)
                    .foregroundStyle(task.isOverdue ? .red : .blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if task.assignedCatNames.isEmpty == false {
                            Text(task.assignedCatNames)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if task.dueDisplayText().isEmpty == false {
                            Text(verbatim: "•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(task.dueDisplayText())
                                .font(.caption)
                                .foregroundStyle(task.isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("taskAssistant.taskChoice.\(task.title)")
    }

    func intentSelectionCard(_ selection: TaskAssistantIntentSelection) -> some View {
        let availableIntents = selection.availableIntents

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .taskAssistantIntentPrompt(selection.task.title)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            TaskAssistantFlowLayout(spacing: 8) {
                if availableIntents.contains(.open) {
                    Button(String(localized: .taskAssistantIntentOpen)) {
                        viewModel.chooseIntent(.open)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .accessibilityIdentifier("taskAssistant.intent.open")
                }

                if availableIntents.contains(.complete) {
                    Button(String(localized: .taskAssistantIntentComplete)) {
                        viewModel.chooseIntent(.complete)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .accessibilityIdentifier("taskAssistant.intent.complete")
                }

                if availableIntents.contains(.postpone) {
                    Button(String(localized: .taskAssistantIntentPostpone)) {
                        viewModel.chooseIntent(.postpone)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .accessibilityIdentifier("taskAssistant.intent.postpone")
                }
            }

            Button(String(localized: .actionCancel)) {
                viewModel.cancelPendingAction()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("taskAssistant.cancelIntentButton")
        }
        .padding(14)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func confirmationCard(_ confirmation: TaskAssistantConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(confirmation.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(confirmation.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(String(localized: .actionCancel)) {
                    viewModel.cancelPendingAction()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("taskAssistant.cancelConfirmationButton")

                Button(String(localized: .actionConfirm)) {
                    Task {
                        let outcome = await viewModel.confirmPendingAction(in: modelContext)
                        // Error haptic for a `.failure`-styled result is handled by the
                        // messages.last?.id watcher in messageList — avoid double-firing here.
                        if viewModel.messages.last?.style != .failure {
                            haptics.notify(.success)
                        }
                        guard case .openTask(let taskID) = outcome else { return }
                        onOpenTask(taskID)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                .accessibilityIdentifier("taskAssistant.confirmButton")
            }
        }
        .padding(14)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Create a task cards

private extension TaskAssistantChatView {
    /// The frequencies offered in the conversational flow (biweekly/custom are omitted to
    /// keep the choices tap-friendly).
    static let creationFrequencies: [CareTaskFrequency] = [.once, .daily, .weekly, .monthly]

    @ViewBuilder
    func taskCreationCard(_ session: TaskCreationSession) -> some View {
        switch session.step {
        case .name:
            // The question is a message bubble; the answer is typed in the composer.
            EmptyView()
        case .cats:
            creationCatsCard(session)
        case .category:
            creationCategoryCard()
        case .repeatFrequency:
            creationFrequencyCard()
        case .time:
            creationTimeCard()
        case .confirm:
            creationConfirmCard()
        }
    }

    func creationCatsCard(_ session: TaskCreationSession) -> some View {
        creationCardContainer {
            TaskAssistantFlowLayout(spacing: 8) {
                ForEach(allCats, id: \.id) { cat in
                    let isSelected = session.selectedCats.contains { $0.id == cat.id }
                    Button {
                        haptics.selection()
                        viewModel.toggleCreationCat(cat)
                    } label: {
                        Label(cat.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? Theme.accent : .gray)
                    .accessibilityIdentifier("taskAssistant.create.cat.\(cat.name)")
                }

                Button {
                    haptics.selection()
                    viewModel.selectAllCats(allCats)
                } label: {
                    Label(String(localized: .tasksConfigAllCats), systemImage: "pawprint.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .accessibilityIdentifier("taskAssistant.create.allCats")
            }

            Button(String(localized: .taskAssistantCreateContinue)) {
                haptics.selection()
                viewModel.confirmCreationCats()
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.selectedCats.isEmpty)
            .accessibilityIdentifier("taskAssistant.create.catsContinue")
        }
    }

    func creationCategoryCard() -> some View {
        creationCardContainer {
            TaskAssistantFlowLayout(spacing: 8) {
                ForEach(CareTaskCategory.allCases, id: \.self) { category in
                    Button {
                        haptics.selection()
                        viewModel.selectCreationCategory(category)
                    } label: {
                        Label(category.displayName, systemImage: category.iconName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .accessibilityIdentifier("taskAssistant.create.category.\(category.rawValue)")
                }
            }
        }
    }

    func creationFrequencyCard() -> some View {
        creationCardContainer {
            TaskAssistantFlowLayout(spacing: 8) {
                ForEach(Self.creationFrequencies, id: \.self) { frequency in
                    Button {
                        haptics.selection()
                        viewModel.selectCreationFrequency(frequency)
                    } label: {
                        Text(frequency.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .accessibilityIdentifier("taskAssistant.create.frequency.\(frequency.rawValue)")
                }
            }
        }
    }

    func creationTimeCard() -> some View {
        creationCardContainer {
            TaskAssistantFlowLayout(spacing: 8) {
                ForEach(TaskCreationTimeOption.allCases, id: \.self) { option in
                    Button {
                        haptics.selection()
                        viewModel.selectCreationTime(option)
                    } label: {
                        Text(creationTimeLabel(option))
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
        }
    }

    func creationConfirmCard() -> some View {
        creationCardContainer {
            Text(String(localized: .taskAssistantCreateConfirmTitle))
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                Button(String(localized: .actionCancel)) {
                    viewModel.cancelTaskCreation()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("taskAssistant.create.cancelButton")

                Button(String(localized: .taskAssistantCreateConfirmButton)) {
                    Task {
                        await viewModel.confirmTaskCreation(in: modelContext, existingCaregivers: allCaregivers)
                        if viewModel.messages.last?.style != .failure {
                            haptics.notify(.success)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                .accessibilityIdentifier("taskAssistant.create.confirmButton")
            }
        }
    }

    func creationCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func creationTimeLabel(_ option: TaskCreationTimeOption) -> String {
        switch option {
        case .morning: return String(localized: .taskAssistantCreateTimeMorning)
        case .noon: return String(localized: .taskAssistantCreateTimeNoon)
        case .evening: return String(localized: .taskAssistantCreateTimeEvening)
        case .none: return String(localized: .taskAssistantCreateTimeNone)
        }
    }
}

#if DEBUG
#Preview("Task Assistant Chat") {
    PreviewHost(scenario: .standard) {
        NavigationStack {
            TaskAssistantChatView(
                viewModel: TaskAssistantViewModel(),
                allCareTasks: [],
                allCats: [],
                allCaregivers: [],
                quickActionChips: [],
                onOpenTask: { _ in },
                onEndChat: {}
            )
        }
    }
}
#endif
