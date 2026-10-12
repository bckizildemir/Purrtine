import SwiftUI
import SwiftData
import PhotosUI

struct AddCaregiverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoadingPhoto = false
    @State private var model: AddCaregiverModel

    /// Called before the sheet closes when the caregiver saved but its photo did not. The presenter
    /// shows the note once this sheet has left: UIKit refuses to present an alert from a sheet that
    /// is closing, and an alert on this sheet would leave with it.
    let onAvatarNotSaved: () -> Void

    init(onAvatarNotSaved: @escaping () -> Void = {}) {
        self.onAvatarNotSaved = onAvatarNotSaved
        #if DEBUG
        // UI-test-only; see `AppLaunchConfiguration.failsCaregiverAvatarSave`.
        if AppLaunchConfiguration.current.failsCaregiverAvatarSave {
            _avatarImage = State(initialValue: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in })
            _model = State(initialValue: AddCaregiverModel(saveAvatar: { _ in
                throw PhotoSaveError.writeFailed(CocoaError(.fileWriteUnknown))
            }))
            return
        }
        #endif
        _model = State(initialValue: AddCaregiverModel())
    }

    private var hasUnsavedChanges: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || avatarImage != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Form {
                    Section {
                        avatarSection
                    }
                    
                    Section {
                        TextField(String(localized: .caregiverAddNamePlaceholder), text: $name)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.primary)
                    } header: {
                        Text(.caregiverAddDetailsSection)
                    } footer: {
                        Text(.caregiverAddNameFooter)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(model.isSaving)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: .caregiverAddTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                        .disabled(model.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if model.isSaving {
                        SheetSavingIndicator()
                    } else {
                        SheetConfirmButton {
                            Task { await saveCaregiver() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingPhoto)
                        .accessibilityIdentifier("addCaregiver.saveButton")
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges || model.isSaving)
        .alert(String(localized: .caregiverAddNotSaved), isPresented: $model.isShowingSaveFailure) {
            Button(String(localized: .actionOk)) { }
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            loadSelectedPhoto(newPhoto)
        }
    }
    
    @ViewBuilder
    private var avatarSection: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Avatar display
                ZStack {
                    if let avatarImage = avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    if isLoadingPhoto {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 100, height: 100)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
                
                // Photo picker button
                CaregiverPhotoPickerButton(
                    selection: $selectedPhoto,
                    hasPhoto: avatarImage != nil,
                    isLoading: isLoadingPhoto
                )
                
                if avatarImage != nil {
                    Button(String(localized: .caregiverAddPhotoRemove)) {
                        avatarImage = nil
                        selectedPhoto = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private func loadSelectedPhoto(_ photoItem: PhotosPickerItem?) {
        guard let photoItem = photoItem else { return }
        
        isLoadingPhoto = true
        
        Task {
            if let data = try? await photoItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.avatarImage = uiImage
                    self.isLoadingPhoto = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingPhoto = false
                }
            }
        }
    }
    
    /// A failed commit keeps the sheet open with the name and photo, and the model shows the alert.
    private func saveCaregiver() async {
        switch await model.save(name: name, avatar: avatarImage, in: modelContext) {
        case .saved:
            dismiss()
        case .savedWithoutAvatar:
            onAvatarNotSaved()
            dismiss()
        case nil:
            break
        }
    }
}

// MARK: - Preview
/// The caregiver photo picker and its label.
///
/// `PhotosPicker`'s label builder is a `@Sendable` closure, so reading the
/// presenting view's `@State` from inside it is a main-actor violation. Passing
/// the one value the label needs in as a plain `Bool` lets the closure capture
/// a `Sendable` stored property instead, with no annotation.
private struct CaregiverPhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool
    let isLoading: Bool

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                Text(hasPhoto ? .caregiverAddPhotoChange : .caregiverAddPhotoAdd)
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .clipShape(.rect(cornerRadius: 20))
        }
        .disabled(isLoading)
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .empty) {
        AddCaregiverView()
    }
} 
#endif
