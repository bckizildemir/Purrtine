import UIKit

/// A cat photo the caregiver picked or took that is not written to disk yet.
nonisolated enum PendingCatPhoto: Equatable, Sendable {
    /// Encoded image data, from the photo library. Data that `PhotoManager.preparedJPEGData` made
    /// at pick time is written as it is; other data is downsampled when it is saved.
    case data(Data)
    /// A camera capture, downsampled and encoded once when it is saved.
    case image(UIImage)
}
