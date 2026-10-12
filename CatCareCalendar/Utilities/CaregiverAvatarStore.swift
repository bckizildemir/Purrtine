import Foundation
import os
import UIKit

/// Writes caregiver avatars into the `CaregiverAvatars` folder in Documents.
///
/// Holds one immutable URL, so it is `Sendable` rather than main-actor isolated: `save` scales,
/// encodes and writes off the caller's actor, like `PhotoManager.save(_:for:)` does for cat photos.
nonisolated struct CaregiverAvatarStore: Sendable {
    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Photos")

    let directory: URL

    init(directory: URL = .documentsDirectory.appending(path: "CaregiverAvatars", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    /// Scales `image` to `PhotoManager.avatarMaxPixelSize`, encodes it once and writes it. Returns
    /// the file name, which is what `Caregiver.avatarURL` stores. Throws a `PhotoSaveError`.
    @concurrent
    func save(_ image: UIImage) async throws -> String {
        guard let jpeg = PhotoManager.renderedJPEGData(from: image, maxPixelSize: PhotoManager.avatarMaxPixelSize) else {
            Self.logger.error("Caregiver avatar not saved: the image cannot be encoded as a JPEG")
            throw PhotoSaveError.unreadableImage
        }

        let fileName = "caregiver_avatar_\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try jpeg.write(to: directory.appending(path: fileName))
            return fileName
        } catch {
            Self.logger.error("Caregiver avatar not saved: \(String(describing: error), privacy: .public)")
            throw PhotoSaveError.writeFailed(error)
        }
    }

    /// Removes an avatar this store wrote. `fileName` must be a bare file name, as `save` returns.
    func delete(_ fileName: String) {
        guard URL(filePath: fileName).lastPathComponent == fileName else { return }
        do {
            try FileManager.default.removeItem(at: directory.appending(path: fileName))
        } catch {
            Self.logger.error("Caregiver avatar not deleted: \(String(describing: error), privacy: .public)")
        }
    }
}
