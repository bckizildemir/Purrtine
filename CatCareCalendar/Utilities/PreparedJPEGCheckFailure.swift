import Foundation

/// The check of `PhotoManager.isPreparedJPEG` that a photo failed. `savePreparedPhoto` names it in
/// the log when it re-encodes a `.prepared` photo.
nonisolated enum PreparedJPEGCheckFailure: Equatable, Sendable, CustomStringConvertible {
    /// Not one complete JPEG image with a readable, non-zero pixel size.
    case notASingleCompleteJPEG
    /// Larger than the pixel cap on its longest edge.
    case tooLarge(width: Int, height: Int)
    /// An EXIF orientation other than 1 (up).
    case notUpright(orientation: Int)
    /// GPS data in the image properties.
    case hasLocation

    var description: String {
        switch self {
        case .notASingleCompleteJPEG:
            "not a single complete JPEG"
        case .tooLarge(let width, let height):
            "too large: \(width) x \(height) pixels"
        case .notUpright(let orientation):
            "not upright: orientation \(orientation)"
        case .hasLocation:
            "has GPS data"
        }
    }
}
