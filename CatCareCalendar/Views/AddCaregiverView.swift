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
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: .caregiverAddTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        saveCaregiver()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingPhoto)
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
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
    
    private func saveCaregiver() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Save avatar image if exists
        var avatarURL: String?
        if let avatarImage = avatarImage {
            avatarURL = saveAvatarImage(avatarImage)
        }
        
        // Create new caregiver
        let newCaregiver = Caregiver(
            name: trimmedName,
            avatarURL: avatarURL
        )
        
        modelContext.insert(newCaregiver)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to save caregiver: \(error)")
        }
    }
    
    private func saveAvatarImage(_ image: UIImage) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let avatarsDirectory = documentsPath.appendingPathComponent("CaregiverAvatars")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
        
        let fileName = "caregiver_avatar_\(UUID().uuidString).jpg"
        let fileURL = avatarsDirectory.appendingPathComponent(fileName)
        
        // Scale down to avatar size and encode once before writing.
        if let imageData = PhotoManager.renderedJPEGData(
            from: image,
            maxPixelSize: PhotoManager.avatarMaxPixelSize
        ) {
            do {
                try imageData.write(to: fileURL)
                return fileURL.lastPathComponent // Store relative path
            } catch {
                print("❌ Failed to save avatar: \(error)")
            }
        }

        return nil
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
