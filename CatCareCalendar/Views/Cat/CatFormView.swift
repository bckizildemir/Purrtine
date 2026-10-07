import SwiftUI
import SwiftData
import PhotosUI

/// Unified form view for creating and editing cats.
/// Supports onboarding, add, and edit modes with adaptive UI.
struct CatFormView: View {
    let mode: CatFormMode
    let onDelete: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.careTaskWriter) private var careTaskWriter

    // MARK: - Form State
    @State private var formData: CatFormData
    @State private var hasChangedPhoto = false
    @State private var showingDeleteConfirmation = false

    // MARK: - Focus State
    @FocusState private var focusedField: CatFormData.Field?

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
            return formData.isNameValid
        case .add:
            return formData.isNameValid && !formData.isLoading
        case .edit(let cat):
            return formData.isNameValid && !formData.isLoading && (formData.hasChanges(comparedTo: cat) || hasChangedPhoto)
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
                            .foregroundColor(formData.isNameValid ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(formData.isNameValid ? Color.blue : Color.gray.opacity(0.3))
                            )
                    }
                    .accessibilityIdentifier("onboarding.firstCat.continueButton")
                    .disabled(!formData.isNameValid)
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
        .onChange(of: formData.selectedPhoto) { _, newValue in
            loadSelectedPhoto(newValue)
        }
        .onChange(of: formData.capturedImage) { _, newValue in
            if newValue != nil {
                formData.photoData = nil // Clear photo data when camera image is captured
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
                PhotoPickerSection(formData: $formData, hasChangedPhoto: $hasChangedPhoto, existingCat: existingCat)

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
            formData.photoData = nil
            formData.capturedImage = nil
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
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Downsample at ingestion (off the main actor) so we hold and later persist a
                    // bounded-size image instead of the full-resolution original.
                    let downsampled = await Task.detached {
                        PhotoManager.downsampledJPEGData(from: data, maxPixelSize: PhotoManager.photoMaxPixelSize)
                    }.value
                    formData.photoData = downsampled ?? data
                    hasChangedPhoto = true
                    formData.capturedImage = nil // Clear captured image when gallery photo is selected
                    formData.showingPhotoOptions = false
                }
            } catch {
                print("Failed to load photo: \(error)")
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

    private func saveCat() {
        formData.isLoading = true

        switch mode {
        case .onboarding(let onContinue, _):
            // Save to onboarding manager
            OnboardingManager.shared.tempCatData.name = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let photoData = formData.photoData {
                OnboardingManager.shared.tempCatData.photoData = photoData
            } else if let capturedImage = formData.capturedImage {
                OnboardingManager.shared.tempCatData.photoData = capturedImage.jpegData(compressionQuality: 0.8)
            }
            onContinue()

        case .add:
            Task { await saveNewCat() }

        case .edit(let cat):
            Task { await saveExistingCat(cat) }
        }
    }

    private func saveNewCat() async {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBreed = formData.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = formData.medicalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let conditions = trimmedNotes.isEmpty ? [] :
            formData.medicalConditions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let catId = UUID()
        let ageInMonths = AgeUtils.months(from: formData.ageValue, unit: formData.ageUnit)

        // Persist the photo off the main actor (decode/encode/disk write) — keep only the
        // SwiftData mutation on the main actor below.
        let savedPhotoFileName = await savePhotoOffMainActor(for: catId)

        let photoURLs = savedPhotoFileName != nil ? [savedPhotoFileName!] : []
        let newCat = Cat(
            name: trimmedName,
            photoURLs: photoURLs,
            age: ageInMonths,
            gender: formData.gender,
            breed: trimmedBreed.isEmpty ? nil : trimmedBreed,
            weight: formData.weightValue,
            weightUnit: formData.weightUnit,
            medicalNotes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            medicalConditions: conditions
        )

        newCat.id = catId
        modelContext.insert(newCat)

        do {
            try modelContext.save()
            haptics.impact(.medium)
            dismiss()
        } catch {
            print("Error saving cat: \(error)")
            formData.isLoading = false
        }
    }

    /// Writes the pending photo (downsample + encode + disk write) on a background task and returns
    /// the saved file name. Nothing here touches SwiftData, so it is safe off the main actor.
    private func savePhotoOffMainActor(for catId: UUID) async -> String? {
        let photoData = formData.photoData
        let capturedImage = formData.capturedImage
        return await Task.detached {
            if let photoData {
                return PhotoManager.shared.savePhoto(photoData, for: catId)
            }
            if let capturedImage {
                return PhotoManager.shared.saveUIImage(capturedImage, for: catId)
            }
            return nil
        }.value
    }

    private func saveExistingCat(_ cat: Cat) async {
        // Update cat properties
        cat.name = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        cat.gender = formData.gender
        let validatedAge = AgeUtils.validateAge(formData.ageValue)
        cat.age = AgeUtils.months(from: validatedAge, unit: formData.ageUnit)
        cat.breed = formData.breed.isEmpty ? nil : formData.breed
        cat.weight = formData.weightValue
        cat.weightUnit = formData.weightUnit
        cat.medicalNotes = formData.medicalNotes.isEmpty ? nil : formData.medicalNotes
        cat.medicalConditions = formData.medicalConditions
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        cat.updatedAt = Date()

        // Handle photo updates
        if hasChangedPhoto {
            // Delete old photos (cheap file removal — safe to keep on the main actor).
            for oldPhotoFileName in cat.photoURLs {
                PhotoManager.shared.deletePhoto(at: oldPhotoFileName)
            }

            // Save the new photo off the main actor.
            let newPhotoFileName = await savePhotoOffMainActor(for: cat.id)

            cat.photoURLs.removeAll()
            if let newPhotoFileName {
                cat.photoURLs.append(newPhotoFileName)
            }
        }

        do {
            try modelContext.save()
            // Pending reminders carry the cat names they were scheduled with, so the rename only
            // reaches them through a reschedule. Refreshed unconditionally rather than gated on a
            // name comparison: this wiring is the one part of the fix a unit test cannot reach, and
            // re-handing a saved cat's tasks to the scheduler is cheap and idempotent.
            await CatReminderRefreshService(taskWriter: careTaskWriter)
                .refreshReminders(forTasksOf: cat, in: modelContext)
            formData.isLoading = false
            dismiss()
        } catch {
            print("Failed to save cat: \(error)")
            formData.isLoading = false
        }
    }

    private func deleteCat() {
        if case .edit(let cat) = mode {
            Task {
                do {
                    try await CatDeletionService(taskWriter: careTaskWriter).delete(cat, from: modelContext)
                    onDelete?()
                    dismiss()
                } catch {
                    print("Failed to delete cat: \(error)")
                }
            }
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
