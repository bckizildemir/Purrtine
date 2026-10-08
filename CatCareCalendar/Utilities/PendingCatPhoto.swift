import UIKit

/// A cat photo the caregiver picked or took that is not written to disk yet.
nonisolated enum PendingCatPhoto: Sendable {
    /// Encoded image data, from the photo library.
    case data(Data)
    /// A camera capture.
    case image(UIImage)
}
