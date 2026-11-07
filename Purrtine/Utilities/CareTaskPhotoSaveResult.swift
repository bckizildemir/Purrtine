import Foundation

/// What `CareTaskPhotoWriter.save(_:)` wrote, and what it could not.
nonisolated struct CareTaskPhotoSaveResult: Sendable {
    /// The stored file names of the photos that were written, in the order they were given.
    var fileNames: [String] = []
    /// One error for each photo that was not written.
    var failures: [PhotoSaveError] = []
}
