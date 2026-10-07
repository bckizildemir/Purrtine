import SwiftUI
import SwiftData

/// Photo picker section component for cat forms.
/// Displays photo circle, placeholder, and add photo button.
struct PhotoPickerSection: View {
    @Binding var formData: CatFormData
    @Binding var hasChangedPhoto: Bool

    // For edit mode to show existing photos
    var existingCat: Cat?

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { formData.showingPhotoOptions = true }) {
                VStack(spacing: 12) {
                    photoCircle
                    addPhotoLabel
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Photo Circle
    @ViewBuilder
    private var photoCircle: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 140, height: 140)

            // Display photo based on priority: captured > selected > existing
            if let photoData = formData.photoData,
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
            } else if let cat = existingCat, cat.hasPhoto {
                DownsampledImage(url: photoURL(for: cat), targetPointSize: 140) {
                    defaultPhotoPlaceholder
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
            } else {
                placeholderCatIcon
            }

            // Edit indicator (show if any photo exists)
            if formData.hasPhoto || (existingCat?.hasPhoto ?? false) {
                editIndicator
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
        Text(formData.hasPhoto || (existingCat?.hasPhoto ?? false) ? .catAddPhotoEdit : .catAddPhotoAdd)
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
