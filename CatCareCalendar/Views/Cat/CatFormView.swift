import SwiftUI
import SwiftData
import PhotosUI
import os

/// Unified form view for creating and editing cats.
/// Supports onboarding, add, and edit modes with adaptive UI.
struct CatFormView: View {
    let mode: CatFormMode
    let onDelete: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.reportCatDeletionFailure) private var reportCatDeletionFailure

    // MARK: - Form State
    @State private var formData: CatFormData
    @State private var hasChangedPhoto = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionFailureHandoff = CatDeletionFailureHandoff()

    // MARK: - Focus State
    @FocusState private var focusedField: CatFormData.Field?

    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "CatForm")

    // MARK: - Initialization
    init(mode: CatFormMode, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onDelete = onDelete

        // Initialize form data based on mode
        switch mode {
        case .onboarding:
            _formData = State(initialValue: CatFormData(from: OnboardingManager.shared.tempCatData))
        case .add:
            _formData = State(initialValue: CatFormData())
        case .edit(let cat):
            _formData = State(initialValue: CatFormData(from: cat))
        }
    }

    // MARK: - Computed Properties
    private var navigationTitle: String {
        switch mode {
        case .onboarding:
            return "" // No title for onboarding
        case .add:
            return String(localized: .catAddTitle)
        case .edit:
            return String(localized: .catEditTitle)
        }
    }

    private var existingCat: Cat? {
        switch mode {
        case .onboarding, .add:
            return nil
        case .edit(let cat):
            return cat
        }
    }

    private var isSaveEnabled: Bool {
        switch mode {
        case .onboarding:
            return formData.isNameValid && !formData.isLoadingPhoto
        case .add:
            return formData.isNameValid && !formData.isLoading && !formData.isLoadingPhoto
        case .edit(let cat):
            return formData.isNameValid && !formData.isLoading && !formData.isLoadingPhoto
                && (formData.hasChanges(comparedTo: cat) || hasChangedPhoto)
        }
    }

    private var hasUnsavedChanges: Bool {
        switch mode {
        case .onboarding:
            return false
        case .add:
            return !formData.name.isEmpty
                || formData.gender != .unknown
                || formData.ageValue != nil
                || !formData.breed.isEmpty
                || !formData.weight.isEmpty
                || !formData.medicalNotes.isEmpty
                || !formData.medicalConditions.isEmpty
                || formData.hasPhoto
        case .edit(let cat):
            return formData.hasChanges(comparedTo: cat) || hasChangedPhoto
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Main content in NavigationStack (only for add/edit modes)
            if case .onboarding = mode {
                mainContent
            } else {
                NavigationStack {
                    mainContent
                        .navigationTitle(navigationTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                                .accessibilityIdentifier("catForm.cancelButton")
                            }

                            ToolbarItem(placement: .confirmationAction) {
                                SheetConfirmButton {
                                    focusedField = nil // Commit any active text field edits
                                    saveCat()
                                }
                                .disabled(!isSaveEnabled)
                                .accessibilityIdentifier("catForm.saveButton")
                            }
                        }
                }
            }

            // Onboarding bottom buttons
            if case .onboarding(_, let onSkip) = mode {
                OnboardingActionFooter {
                    Button(action: {
                        focusedField = nil // Commit any active text field edits
                        saveCat()
                    }) {
                        Text(.onboardingFirstCatContinue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSaveEnabled ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isSaveEnabled ? Color.blue : Color.gray.opacity(0.3))
                            )
                    }
                    .accessibilityIdentifier("onboarding.firstCat.continueButton")
                    .disabled(!isSaveEnabled)
                } secondaryAction: {
                    Button(action: onSkip) {
                        Text(.onboardingFirstCatSkip)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("onboarding.firstCat.skipButton")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .sheet(isPresented: $formData.showingPhotoOptions) {
            photoOptionsSheet
        }
        .alert(String(localized: .catEditDeleteConfirmationTitle), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: .actionCancel), role: .cancel) { }
            Button(String(localized: .actionDelete), role: .destructive) {
                deleteCat()
            }
        } message: {
            // Guarded on `modelContext`: SwiftUI can re-evaluate this closure during a body pass
            // after `deleteCat()` has removed `cat` from the store, and reading a property on an
            // invalidated `@Model` traps.
            if case .edit(let cat) = mode, cat.modelContext != nil {
                Text(.catEditDeleteConfirmationMessage(cat.name))
            }
        }
        .fullScreenCover(isPresented: $formData.showingCamera) {
            CameraCaptureFlowView(image: $formData.capturedImage, isPresented: $formData.showingCamera)
        }
        .alert(String(localized: .catAddCameraPermissionTitle), isPresented: $formData.showingCameraPermissionAlert) {
            Button(String(localized: .catAddSettings)) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button(String(localized: .actionCancel), role: .cancel) { }
        } message: {
            Text(.catAddCameraPermissionMessage)
        }
        .alert(String(localized: .catPhotoNotSavedTitle), isPresented: $formData.showingPhotoNotSavedAlert) {
            Button(String(localized: .catPhotoTryAgain)) {
                saveCat()
            }
            .keyboardShortcut(.defaultAction)
            Button(String(localized: .catPhotoSaveWithout)) {
                saveCat(includingPhoto: false)
            }
            Button(String(localized: .actionCancel), role: .cancel) { }
        } message: {
            Text(.catPhotoNotSavedMessage)
        }
        .onAppear {
            deletionFailureHandoff.screenDidAppear()
        }
        .onDisappear {
            deletionFailureHandoff.screenDidLeave()
        }
        .onChange(of: formData.selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .onChange(of: formData.capturedImage) { _, newValue in
            if newValue != nil {
                formData.preparedPhotoData = nil // Clear the picked photo when camera image is captured
                discardPhotoPick()
                hasChangedPhoto = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (only for onboarding)
                if case .onboarding = mode {
                    onboardingHeader
                }

                // Photo Section
                PhotoPickerSection(
                    formData: $formData,
                    hasChangedPhoto: $hasChangedPhoto,
                    existingCat: existingCat,
                    onRetryPhotoLoad: { loadSelectedPhoto(formData.selectedPhoto) }
                )

                // Essential Fields
                if case .onboarding = mode {
                    EssentialFieldsSection(formData: $formData, focusedField: $focusedField, showsAgeAndGender: false)
                } else {
                    EssentialFieldsSection(formData: $formData, focusedField: $focusedField)
                }

                // Advanced Section (not shown in onboarding)
                if case .onboarding = mode {
                    // Skip advanced section for onboarding
                } else {
                    AdvancedFieldsSection(formData: $formData, focusedField: $focusedField)
                }

                // Delete Section (only for edit mode)
                if case .edit = mode {
                    deleteSection
                }

                // Bottom spacing for onboarding buttons
                if case .onboarding = mode {
                    Spacer().frame(height: 120)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
    }

    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        switch mode {
        case .onboarding:
            Theme.background
        case .add, .edit:
            Color(.systemGroupedBackground)
        }
    }

    // MARK: - Onboarding Header
    @ViewBuilder
    private var onboardingHeader: some View {
        VStack(spacing: 16) {
            Text(.onboardingFirstCatTitle)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(.onboardingFirstCatSubtitle)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Delete Section
    @ViewBuilder
    private var deleteSection: some View {
        Button(String(localized: .catEditDeleteCat)) {
            showingDeleteConfirmation = true
        }
        .font(.headline)
        .foregroundStyle(.red)
        .accessibilityIdentifier("catForm.deleteButton")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .buttonStyle(.plain)
        .tintedActionChip(tint: .red)
        .padding(.top, 20)
    }

    // MARK: - Photo Options Sheet
    @ViewBuilder
    private var photoOptionsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if case .onboarding = mode {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 12) {
                            onboardingPhotoActions
                        }
                    } else {
                        onboardingPhotoActions
                    }
                } else {
                    Text(.catAddPhotoSelect)
                        .font(.headline)
                        .padding(.top)

                    VStack(spacing: 16) {
                        // Photo Library
                        PhotosPicker(selection: $formData.selectedPhoto, matching: .images) {
                            Label(String(localized: .catAddPhotoGallery), systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .onChange(of: formData.selectedPhoto) { _, _ in
                            formData.showingPhotoOptions = false
                        }

                        // Camera
                        cameraButton

                    // Remove Photo (if exists)
                    if formData.hasPhoto || (existingCat?.hasPhoto ?? false) {
                        removePhotoButton
                    }
                    }
                    .padding()
                }

                if case .onboarding = mode {
                    Spacer(minLength: 0)
                } else {
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton {
                        formData.showingPhotoOptions = false
                    }
                }
            }
        }
        .presentationDetents(photoOptionsSheetDetents)
    }

    private var onboardingPhotoActions: some View {
        HStack(spacing: 12) {
            cameraButton
            photoPickerButton
        }
        .padding(.horizontal)
    }

    private var photoOptionsSheetDetents: Set<PresentationDetent> {
        if case .onboarding = mode {
            return [.height(230)]
        }
        return [.medium]
    }

    @ViewBuilder
    private var cameraButton: some View {
        Button(action: {
            formData.showingPhotoOptions = false
            openCamera()
        }) {
            if case .onboarding = mode {
                OnboardingPhotoActionLabel(
                    title: String(localized: .catAddCamera),
                    systemImage: "camera.fill",
                    tint: .green
                )
                .tintedActionChip(tint: .green)
            } else {
                Label(String(localized: .catAddCamera), systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(12)
            }
        }
        .buttonStyle(.plain)
        .disabled(!CameraPermissionHelper.isCameraAvailable)
    }

    @ViewBuilder
    private var photoPickerButton: some View {
        PhotosPicker(selection: $formData.selectedPhoto, matching: .images) {
            OnboardingPhotoActionLabel(
                title: String(localized: .catAddPhotoGallery),
                systemImage: "photo.fill",
                tint: .blue
            )
        }
        .buttonStyle(.plain)
        .tintedActionChip(tint: .blue)
        .onChange(of: formData.selectedPhoto) { _, _ in
            formData.showingPhotoOptions = false
        }
    }

    @ViewBuilder
    private var removePhotoButton: some View {
        Button(action: {
            formData.preparedPhotoData = nil
            formData.capturedImage = nil
            discardPhotoPick()
            hasChangedPhoto = true
            formData.showingPhotoOptions = false
        }) {
            Label(String(localized: .catAddRemovePhoto), systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red.opacity(0.1))
                .foregroundStyle(.red)
                .cornerRadius(12)
        }
    }

    // MARK: - Actions
    /// Forgets the photo-library pick, so a load still running for it is dropped when it ends
    /// instead of overwriting the photo the caregiver chose since.
    private func discardPhotoPick() {
        formData.selectedPhoto = nil
        formData.isLoadingPhoto = false
        formData.photoProblem = nil
    }

    /// Loads and downsamples a photo-library pick. Save and Continue stay disabled until it ends.
    /// A failed pick keeps the photo the form already had and shows why under the photo circle.
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        formData.isLoadingPhoto = true
        formData.photoProblem = nil

        Task {
            let outcome = await CatPhotoIntake.prepare {
                try await item.loadTransferable(type: Data.self)
            }
            // A newer pick replaced this one while it loaded; that load reports instead.
            guard formData.selectedPhoto == item else { return }
            formData.isLoadingPhoto = false

            switch outcome {
            case .ready(let data):
                formData.preparedPhotoData = data
                formData.capturedImage = nil // Clear captured image when gallery photo is selected
                formData.showingPhotoOptions = false
                hasChangedPhoto = true
            case .loadFailed:
                formData.photoProblem = .loadFailed
            case .unusable:
                formData.photoProblem = .unusable
            }
        }
    }

    private func openCamera() {
        Task {
            let granted = await CameraPermissionHelper.checkCameraPermission()
            if granted {
                formData.showingCamera = true
            } else {
                formData.showingCameraPermissionAlert = true
            }
        }
    }

    /// `includingPhoto: false` is the "Save without photo" choice: Add Cat saves no photo, and Edit
    /// Cat saves the other edits and keeps the cat's current photo.
    private func saveCat(includingPhoto: Bool = true) {
        formData.isLoading = true

        switch mode {
        case .onboarding(let onContinue, _):
            // Save to onboarding manager
            OnboardingManager.shared.tempCatData.name = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
            // Kept as it is: a camera photo is encoded once, off the main actor, when onboarding saves.
            OnboardingManager.shared.tempCatData.photo = formData.pendingPhoto
            onContinue()

        case .add:
            Task { await saveNewCat(includingPhoto: includingPhoto) }

        case .edit(let cat):
            Task { await saveExistingCat(cat, includingPhoto: includingPhoto) }
        }
    }

    private func saveNewCat(includingPhoto: Bool) async {
        do {
            _ = try await CatFormSaver().add(
                formData.detailsForNewCat,
                photo: includingPhoto ? formData.pendingPhoto : nil,
                in: modelContext
            )
            haptics.impact(.medium)
            dismiss()
        } catch {
            handleSaveFailure(error)
        }
    }

    private func saveExistingCat(_ cat: Cat, includingPhoto: Bool) async {
        let photoChange = formData.editPhotoChange(hasChangedPhoto: hasChangedPhoto, includingPhoto: includingPhoto)

        do {
            try await CatFormSaver().update(
                cat,
                with: formData.detailsForEditedCat,
                photo: photoChange,
                in: modelContext
            )
            // Pending reminders carry the cat names they were scheduled with, so the rename only
            // reaches them through a reschedule. Refreshed unconditionally rather than gated on a
            // name comparison: this wiring is the one part of the fix a unit test cannot reach, and
            // re-handing a saved cat's tasks to the scheduler is cheap and idempotent.
            await CatReminderRefreshService(taskWriter: careTaskWriter)
                .refreshReminders(forTasksOf: cat, in: modelContext)
            formData.isLoading = false
            dismiss()
        } catch {
            handleSaveFailure(error)
        }
    }

    /// The form stays open with everything entered. A photo that could not be written asks the
    /// caregiver what to do; a failed commit was already taken back out of the context.
    private func handleSaveFailure(_ error: any Error) {
        formData.isLoading = false
        if error is PhotoSaveError {
            formData.showingPhotoNotSavedAlert = true
        } else {
            Self.logger.error("Cat not saved: \(String(describing: error), privacy: .public)")
        }
    }

    /// A failed delete still closes the form: the cat is gone either way (#19). The failure goes
    /// to `CatsTabView`, which outlives this sheet and shows the note, once this sheet has left:
    /// UIKit refuses to present the alert while the sheet is still on screen. Opened from a cat card,
    /// the sheet can leave before the delete finishes, because the card leaves with the cat (#31).
    private func deleteCat() {
        guard case .edit(let cat) = mode else { return }
        let catName = cat.name
        let deletionFailureHandoff = deletionFailureHandoff
        let reportCatDeletionFailure = reportCatDeletionFailure
        Task {
            var failure: CatDeletionFailure?
            do {
                try await CatDeletionService(taskWriter: careTaskWriter).delete(cat, from: modelContext)
            } catch {
                failure = CatDeletionFailure(error: error, catName: catName)
                if failure != nil {
                    haptics.notify(.error)
                }
            }
            deletionFailureHandoff.deleteDidFinish(with: failure, reporting: reportCatDeletionFailure)
            onDelete?()
            dismiss()
        }
    }
}

private struct OnboardingPhotoActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 84)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private extension View {
    @ViewBuilder
    func tintedActionChip(tint: Color) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.22)).interactive(), in: .rect(cornerRadius: 22))
        } else {
            self.background(.regularMaterial, in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(tint.opacity(0.25))
                }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Cat Form") {
    PreviewHost(scenario: .standard) {
        if let cat = PreviewData.firstCat() {
            CatFormView(mode: .edit(cat: cat))
        }
    }
}
#endif
