import SwiftUI
import PhotosUI
import SwiftData

// MARK: - Task Completion View
struct TaskCompletionView: View {
    let task: CareTask
    let completedForDate: Date?
    let initialNotes: String?
    let initialSelectedCats: [Cat]
    /// Saves the completion. Throws only when nothing was saved; the sheet then stays open with the
    /// user's input. The caller closes the sheet on success.
    let onComplete: @MainActor ([Cat], Caregiver?, String?, [UIImage]?, Date?) async throws -> Void

    @State private var submission = TaskCompletionSubmission()
    @State private var selectedCats: Set<Cat> = []
    @State private var selectedCaregiver: Caregiver?
    @State private var notes: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var isLoadingPhotos = false
    @State private var initialSnapshot: [String]?
    @State private var showingPhotoSourceDialog = false
    @State private var showingLibraryPicker = false
    @State private var pendingLibraryItem: PhotosPickerItem?
    @State private var showingCropView = false
    @State private var pendingCropImage: UIImage?
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var showingCameraPermissionAlert = false
    @Query private var caregivers: [Caregiver]

    private static let maxPhotoCount = 5

    @Environment(\.dismiss) private var dismiss

    /// Serialized form state used to detect unsaved edits against the snapshot
    /// taken after the initial preselection.
    private var currentSnapshot: [String] {
        [
            notes,
            selectedCats.map { $0.id.uuidString }.sorted().joined(separator: ","),
            selectedCaregiver?.id.uuidString ?? "",
            String(selectedImages.count)
        ]
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }

    init(
        task: CareTask,
        completedForDate: Date?,
        initialNotes: String? = nil,
        initialSelectedCats: [Cat] = [],
        onComplete: @escaping @MainActor ([Cat], Caregiver?, String?, [UIImage]?, Date?) async throws -> Void
    ) {
        self.task = task
        self.completedForDate = completedForDate
        self.initialNotes = initialNotes
        self.initialSelectedCats = initialSelectedCats
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                catSelectionSection
                caregiverSelectionSection
                notesSection
                photoSelectionSection
            }
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .navigationTitle(String(localized: .taskCompletionTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if submission.isSaving {
                        SheetSavingIndicator()
                    } else {
                        completeButton
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges || submission.isSaving)
        .onAppear {
            preselectCats()
            preselectDefaultCaregiver()
            initialSnapshot = currentSnapshot
        }
        .confirmationDialog(String(localized: .catAddPhotoSelect), isPresented: $showingPhotoSourceDialog, titleVisibility: .visible) {
            Button(String(localized: .catAddPhotoGallery)) {
                showingLibraryPicker = true
            }
            if CameraPermissionHelper.isCameraAvailable {
                Button(String(localized: .catAddCamera)) {
                    openCamera()
                }
            }
            Button(String(localized: .actionCancel), role: .cancel) {}
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $pendingLibraryItem, matching: .images)
        .onChange(of: pendingLibraryItem) { _, newItem in
            loadPendingLibraryItem(newItem)
        }
        .fullScreenCover(isPresented: $showingCropView, onDismiss: { pendingCropImage = nil }) {
            if let pendingCropImage {
                PhotoCropView(
                    image: pendingCropImage,
                    onRetake: { showingCropView = false },
                    onUse: { cropped in
                        addImage(cropped)
                        showingCropView = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureFlowView(image: $capturedImage, isPresented: $showingCamera)
        }
        .onChange(of: capturedImage) { _, newValue in
            if let newValue {
                addImage(newValue)
                capturedImage = nil
            }
        }
        .alert(String(localized: .catAddCameraPermissionTitle), isPresented: $showingCameraPermissionAlert) {
            Button(String(localized: .catAddSettings)) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button(String(localized: .actionCancel), role: .cancel) {}
        } message: {
            Text(.catAddCameraPermissionMessage)
        }
        .alert(String(localized: .errorDataSave), isPresented: $submission.isShowingFailure) { } message: {
            Text(submission.failureMessage)
        }
        .disabled(isLoadingPhotos || submission.isSaving)
    }
}

// MARK: - View Components
private extension TaskCompletionView {
    @ViewBuilder
    var catSelectionSection: some View {
        Section {
            if task.assignedCats.isEmpty {
                emptyCatsMessage
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(.taskCompletionCatQuestion)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button(action: handleSelectAllTapped) {
                            Text(selectAllButtonTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(selectAllButtonColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectAllButtonColor.opacity(0.12))
                                .clipShape(Capsule())
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("taskCompletionSelectAllButton")
                    }
                    
                    ForEach(task.assignedCats) { cat in
                        MultipleCatSelectionRow(
                            cat: cat,
                            isSelected: selectedCats.contains(cat)
                        ) {
                            if selectedCats.contains(cat) {
                                selectedCats.remove(cat)
                            } else {
                                selectedCats.insert(cat)
                            }
                        }
                    }
                    
                    if !selectedCats.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(String(localized: .taskCompletionSelectedCount(Int32(selectedCats.count))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    private var hasSelectedAllAssignedCats: Bool {
        !task.assignedCats.isEmpty && task.assignedCats.allSatisfy { selectedCats.contains($0) }
    }

    private var selectAllButtonTitle: String {
        hasSelectedAllAssignedCats ? String(localized: .taskCompletionClearAll) : String(localized: .taskCompletionSelectAll)
    }

    private var selectAllButtonColor: Color {
        hasSelectedAllAssignedCats ? .orange : .blue
    }

    private func handleSelectAllTapped() {
        if hasSelectedAllAssignedCats {
            selectedCats.removeAll()
        } else {
            selectedCats = Set(task.assignedCats)
        }
    }

    @ViewBuilder
var caregiverSelectionSection: some View {
    Section(String(localized: .taskCompletionCaregiverSection)) {
        if caregivers.isEmpty {
            Text(.taskCompletionNoCaregivers)
                .foregroundStyle(.secondary)
        } else {
                ForEach(caregivers) { caregiver in
                    CaregiverSelectionRow(
                        caregiver: caregiver,
                        isSelected: selectedCaregiver?.id == caregiver.id
                    ) {
                        selectedCaregiver = caregiver
                    }
                }
            }
        }
    }
    
@ViewBuilder
var notesSection: some View {
    Section(String(localized: .taskCompletionNotesLabel)) {
        TextField(String(localized: .taskCompletionNotesPlaceholder), text: $notes, axis: .vertical)
            .lineLimit(3...6)
    }
}
    
    @ViewBuilder
    var photoSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(.taskCompletionPhotosLabel)
                        .font(.headline)
                    
                    Spacer()

                    Button(action: { showingPhotoSourceDialog = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                            Text(.actionAdd)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingPhotos || selectedImages.count >= Self.maxPhotoCount)
                    .accessibilityIdentifier("taskCompletionAddPhotoButton")
                }
                
                    if isLoadingPhotos {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(.taskCompletionPhotosLoading)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !selectedImages.isEmpty {
                        photoGridView
                    } else {
                        Text(.taskCompletionPhotosHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
    
    @ViewBuilder
    var photoGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        removePhoto(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(4)
                }
            }
        }
    }
    
var emptyCatsMessage: some View {
    Text(.taskCompletionNoCatAssigned)
        .foregroundStyle(.secondary)
}

var cancelButton: some View {
    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
}

var completeButton: some View {
    SheetConfirmButton(action: submitCompletion)
        .disabled(isLoadingPhotos || selectedCaregiver == nil || selectedCats.isEmpty)
    }
}

// MARK: - Helper Methods
private extension TaskCompletionView {
    func submitCompletion() {
        let cats = Array(selectedCats)
        let caregiver = selectedCaregiver
        let notesToSend = notes.isEmpty ? nil : notes
        let photosToSend = selectedImages.isEmpty ? nil : selectedImages
        // Unstructured on purpose: the sheet closes on success, and the save must not be cancelled
        // with it. The commit is synchronous, so a late cancellation already counts as saved.
        Task {
            await submission.submit {
                try await onComplete(cats, caregiver, notesToSend, photosToSend, completedForDate)
            }
        }
    }

    func preselectCats() {
        if !initialSelectedCats.isEmpty {
            selectedCats = Set(initialSelectedCats)
            return
        }

        // Eğer görevde tek kedi varsa otomatik seç
        if task.assignedCats.count == 1 {
            selectedCats = Set(task.assignedCats)
        }
        // Birden fazla kedi varsa kullanıcının seçmesini bekle
    }
    
    func preselectDefaultCaregiver() {
        if notes.isEmpty, let initialNotes, !initialNotes.isEmpty {
            notes = initialNotes
        }

        // Öncelik sırası:
        // 1. Görevin atanmış bakıcısı
        // 2. Birincil bakıcı
        // 3. Tek bakıcı varsa o
        if let assignedCaregiver = task.assignedCaregiver {
            selectedCaregiver = assignedCaregiver
        } else if let primary = caregivers.first(where: { $0.isPrimary }) {
            selectedCaregiver = primary
        } else if caregivers.count == 1 {
            selectedCaregiver = caregivers.first
        }
    }
    
    func loadPendingLibraryItem(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isLoadingPhotos = true

        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            // Decode off the main actor (the enclosing view is @MainActor, so a plain Task would
            // decode on main).
            let uiImage = await Task.detached { data.flatMap { UIImage(data: $0) } }.value

            pendingLibraryItem = nil
            isLoadingPhotos = false
            if let uiImage {
                pendingCropImage = uiImage
                showingCropView = true
            }
        }
    }

    func openCamera() {
        Task {
            let granted = await CameraPermissionHelper.checkCameraPermission()
            if granted {
                showingCamera = true
            } else {
                showingCameraPermissionAlert = true
            }
        }
    }

    func addImage(_ image: UIImage) {
        guard selectedImages.count < Self.maxPhotoCount else { return }
        selectedImages.append(image)
    }

    func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }
}

// MARK: - Multiple Cat Selection Row Component
struct MultipleCatSelectionRow: View {
    let cat: Cat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Cat image
            DownsampledImage(url: catImageURL, targetPointSize: 40) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Cat info
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let breed = cat.breed, !breed.isEmpty {
                    Text(breed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .green : .gray)
                .font(.title3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1)
        )
    }
    
    private var catImageURL: URL? {
        guard let urlString = cat.firstPhotoURL, !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
}

#if DEBUG
#Preview("Task Completion") {
    PreviewHost(scenario: .standard) {
        if let task = PreviewData.firstTask() {
            TaskCompletionView(task: task, completedForDate: .now) { _, _, _, _, _ in }
        }
    }
}
#endif
