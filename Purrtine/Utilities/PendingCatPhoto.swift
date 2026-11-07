import UIKit

/// A cat photo the caregiver picked or took that is not written to disk yet.
nonisolated enum PendingCatPhoto: Equatable, Sendable {
    /// A JPEG that `PhotoManager.preparedJPEGData` made, from a photo-library pick. It is written as
    /// it is. Only data the app prepared itself belongs here: nothing else may skip the re-encode.
    case prepared(Data)
    /// Any other encoded image data. It is always downsampled and re-encoded when it is saved, which
    /// drops its metadata (EXIF, IPTC, XMP, location).
    case data(Data)
    /// A camera capture, downsampled and encoded once when it is saved.
    case image(UIImage)
}
