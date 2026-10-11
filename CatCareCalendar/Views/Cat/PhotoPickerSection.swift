import SwiftUI
import SwiftData

/// Photo picker section component for cat forms.
/// Displays photo circle, placeholder, and add photo button.
/// Tapping the photo opens a menu of photo sources: camera, photo library, and remove.
struct PhotoPickerSection: View {
    @Binding var formData: CatFormData
    @Binding var hasChangedPhoto: Bool

    // For edit mode to show existing photos
    var existingCat: Cat?
    /// Loads the current photo-library pick again, after a failed load.
    let onRetryPhotoLoad: () -> Void
    /// Asks for camera permission, then opens the camera.
    let onTakePhoto: () -> Void
    /// Clears the photo the form shows.
    let onRemovePhoto: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Menu {
                if CameraPermissionHelper.isCameraAvailable {
                    Button(String(localized: .catAddCamera), systemImage: "camera", action: onTakePhoto)
                }
                Button(String(localized: .catAddPhotoLibrary), systemImage: "photo.on.rectangle") {
                    formData.isShowingPhotoLibrary = true
                }
                if hasAnyPhoto {
                    Button(
                        String(localized: .catAddRemovePhoto),
                        systemImage: "trash",
                        role: .destructive,
                        action: onRemovePhoto
                    )
                }
            } label: {
                VStack(spacing: 12) {
                    photoCircle
                    addPhotoLabel
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(hasAnyPhoto ? .catAddPhotoEdit : .catAddPhotoAdd))
            .accessibilityIdentifier("catForm.photoMenu")

            if let problem = formData.photoProblem {
                CatPhotoProblemMessage(
                    problem: problem,
                    onTryAgain: onRetryPhotoLoad,
                    onChooseAnother: chooseAnotherPhoto
                )
            }
        }
    }

    /// Clears the selection too, so picking the same photo again still starts a new load.
    private func chooseAnotherPhoto() {
        formData.photoProblem = nil
        formData.selectedPhoto = nil
        formData.isShowingPhotoLibrary = true
    }

    /// A removed photo stops counting at once, before Save deletes the stored file.
    private var hasAnyPhoto: Bool {
        formData.hasPhoto || hasStoredPhoto
    }

    private var hasStoredPhoto: Bool {
        !hasChangedPhoto && existingCat?.hasPhoto == true
    }

    // MARK: - Photo Circle
    @ViewBuilder
    private var photoCircle: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 140, height: 140)

            // Display photo based on priority: captured > selected > existing
            if let photoData = formData.preparedPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
            } else if let capturedImage = formData.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
            } else if let cat = existingCat, hasStoredPhoto {
                DownsampledImage(url: photoURL(for: cat), targetPointSize: 140) {
                    defaultPhotoPlaceholder
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
            } else {
                placeholderCatIcon
            }

            // Edit indicator (show if any photo exists)
            if hasAnyPhoto {
                editIndicator
            }

            if formData.isLoadingPhoto {
                Circle()
                    .fill(.black.opacity(0.35))
                    .frame(width: 140, height: 140)
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .accessibilityLabel(Text(.catPhotoLoading))
            }
        }
    }

    /// Resolved on-disk URL of the cat's first photo, preferring the stored file path and
    /// falling back to a legacy absolute-string URL.
    private func photoURL(for cat: Cat) -> URL? {
        if let photoPath = cat.firstPhotoPath,
           let photoURL = PhotoManager.shared.getPhotoURL(from: photoPath) {
            return photoURL
        }
        if let urlString = cat.firstPhotoURL {
            return URL(string: urlString)
        }
        return nil
    }

    // MARK: - Photo Placeholders
    @ViewBuilder
    private var placeholderCatIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.gray.opacity(0.20), .gray.opacity(0.06)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 140)
            Image(systemName: "cat.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
        }
    }

    @ViewBuilder
    private var defaultPhotoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(.catAddPhotoAdd)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Edit Indicator
    @ViewBuilder
    private var editIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "camera.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.blue))
            }
        }
        .frame(width: 140, height: 140)
    }

    // MARK: - Add Photo Label
    @ViewBuilder
    private var addPhotoLabel: some View {
        Text(hasAnyPhoto ? .catAddPhotoEdit : .catAddPhotoAdd)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 28)
            .background(
                Capsule()
                    .fill(Color(.systemGray3).opacity(0.7))
            )
    }
}
