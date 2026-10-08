import SwiftUI

/// Says, under the photo circle, why the last picked photo was not used, and offers a way on.
/// The message is announced to VoiceOver when it appears, because it is not an alert.
struct CatPhotoProblemMessage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let problem: CatFormData.PhotoProblem
    let onTryAgain: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        let buttonLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        VStack(spacing: 8) {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)

            buttonLayout {
                if problem == .loadFailed {
                    Button(String(localized: .catPhotoTryAgain), action: onTryAgain)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("catForm.photoProblem.tryAgainButton")
                }
                Button(String(localized: .catPhotoChooseAnother), action: onChooseAnother)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("catForm.photoProblem.chooseAnotherButton")
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: problem) {
            // High priority: the message often appears while the photo picker is closing, and the
            // focus change that follows would cut off a default-priority announcement.
            var announcement = AttributedString(String(localized: message))
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private var message: LocalizedStringResource {
        switch problem {
        case .loadFailed:
            .catPhotoLoadFailed
        case .unusable:
            .catPhotoUnusable
        }
    }
}
