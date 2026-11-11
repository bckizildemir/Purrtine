import SwiftUI

/// A row that shows one caregiver and marks the caregiver that the user selected.
struct CaregiverSelectionRow: View {
    let caregiver: Caregiver
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                CaregiverAvatar(caregiver: caregiver)

                Text(caregiver.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.label)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The avatar image of a caregiver, or a placeholder when the caregiver has no photo.
private struct CaregiverAvatar: View {
    let caregiver: Caregiver

    @ScaledMetric(relativeTo: .headline) private var size = 40

    var body: some View {
        if let urlString = caregiver.avatarURL, urlString.isEmpty == false {
            DownsampledImage(url: avatarURL(for: urlString), targetPointSize: size) {
                Circle().fill(Theme.fill)
            }
            .frame(width: size, height: size)
            .clipShape(.circle)
        } else {
            Circle()
                .fill(Theme.fill)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func avatarURL(for fileName: String) -> URL {
        URL.documentsDirectory
            .appending(path: "CaregiverAvatars")
            .appending(path: fileName)
    }
}
