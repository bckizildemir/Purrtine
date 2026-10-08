import Foundation

/// Why a photo could not be written to the photos folder.
nonisolated enum PhotoSaveError: Error {
    /// The data or image cannot be decoded and re-encoded as a JPEG.
    case unreadableImage
    /// The photos folder or the file could not be written, for example because the disk is full.
    case writeFailed(any Error)
}
