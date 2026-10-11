import Foundation
import os
import UIKit

/// The one writer of task-completion photos, in `Documents/CareTaskPhotos`.
///
/// Built like `PhotoManager`: `Sendable` rather than main-actor isolated, because the encode and the
/// disk writes must stay off the main actor. Every failure is logged here, so a caller only decides
/// what the caregiver sees.
nonisolated final class CareTaskPhotoWriter: Sendable {
    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Photos")

    private let photosDirectory: URL
    private let makeUUID: @Sendable () -> UUID
    private let logFailure: @Sendable (String) -> Void

    init(
        photosDirectory: URL = .documentsDirectory.appending(path: "CareTaskPhotos", directoryHint: .isDirectory),
        makeUUID: @escaping @Sendable () -> UUID = { UUID() },
        logFailure: (@Sendable (String) -> Void)? = nil
    ) {
        self.photosDirectory = photosDirectory
        self.makeUUID = makeUUID
        self.logFailure = logFailure ?? { Self.logger.error("\($0, privacy: .public)") }
    }

    /// Saves each photo as a downsampled JPEG, off the caller's actor.
    ///
    /// A photo that cannot be saved does not stop the others: the result holds the file names that
    /// were written and an error for each photo that was not.
    @concurrent
    func save(_ photos: [UIImage]) async -> CareTaskPhotoSaveResult {
        var result = CareTaskPhotoSaveResult()
        for photo in photos {
            do {
                result.fileNames.append(try save(photo))
            } catch {
                result.failures.append(error)
            }
        }
        return result
    }

    /// Removes files this writer saved, for example after the completion that would own them was
    /// not saved. Runs off the caller's actor.
    @concurrent
    func delete(_ fileNames: [String]) async {
        for fileName in fileNames {
            guard URL(filePath: fileName).lastPathComponent == fileName else {
                logFailure("Task photo not deleted: '\(fileName)' is not a file name")
                continue
            }
            do {
                try FileManager.default.removeItem(at: photosDirectory.appending(path: fileName))
            } catch {
                logFailure("Task photo not deleted: \(String(describing: error))")
            }
        }
    }

    /// Creates the photos folder before each write, so a folder removed since the last write does not
    /// fail every later one.
    private func save(_ photo: UIImage) throws(PhotoSaveError) -> String {
        guard let jpeg = PhotoManager.renderedJPEGData(
            from: photo,
            maxPixelSize: PhotoManager.photoMaxPixelSize
        ) else {
            logFailure("Task photo not saved: the image cannot be encoded as a JPEG")
            throw .unreadableImage
        }
        let fileName = "task_photo_\(makeUUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            try jpeg.write(to: photosDirectory.appending(path: fileName))
            return fileName
        } catch {
            logFailure("Task photo not saved: \(String(describing: error))")
            throw .writeFailed(error)
        }
    }
}
