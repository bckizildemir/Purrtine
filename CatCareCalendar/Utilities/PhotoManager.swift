import Foundation
import UIKit

/// Stateless apart from three immutable dependencies, so it is `Sendable`
/// rather than main-actor isolated: it does disk I/O and must stay off the
/// main actor.
nonisolated final class PhotoManager: Sendable {
    static let shared = PhotoManager()

    /// Longest-edge pixel cap applied to cat and task photos on save.
    static let photoMaxPixelSize = 2048
    /// Longest-edge pixel cap for caregiver avatars, which are only ever shown small.
    static let avatarMaxPixelSize = 512
    private static let saveCompressionQuality: CGFloat = 0.8

    private let photosDirectory: URL
    private let makeUUID: @Sendable () -> UUID

    init(
        photosDirectory: URL? = nil,
        makeUUID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.photosDirectory = photosDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appending(path: "CatPhotos", directoryHint: .isDirectory)
        self.makeUUID = makeUUID
        createPhotosDirectoryIfNeeded()
    }

    // MARK: - Downsample-on-save

    static func downsampledJPEGData(
        from data: Data,
        maxPixelSize: Int,
        compressionQuality: CGFloat = saveCompressionQuality
    ) -> Data? {
        guard let cgImage = DownsampledImageLoader.downsampledCGImage(
            from: data,
            maxPixelSize: maxPixelSize
        ) else {
            return UIImage(data: data)?.jpegData(compressionQuality: compressionQuality)
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
    }

    static func downsampledJPEGData(
        from image: UIImage,
        maxPixelSize: Int,
        compressionQuality: CGFloat = saveCompressionQuality
    ) -> Data? {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        return downsampledJPEGData(
            from: data,
            maxPixelSize: maxPixelSize,
            compressionQuality: compressionQuality
        )
    }

    // MARK: - Directory Management

    private func createPhotosDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create photos directory: \(error)")
        }
    }

    func absoluteURL(for fileName: String) -> URL? {
        resolvedURL(for: fileName)
    }

    func resolvedURL(for stored: String) -> URL? {
        guard stored.isEmpty == false else {
            return nil
        }

        let candidate: URL
        if stored.hasPrefix("/") {
            candidate = URL(filePath: stored)
        } else {
            guard URL(filePath: stored).lastPathComponent == stored else {
                return nil
            }
            candidate = photosDirectory.appending(path: stored)
        }

        let canonicalDirectory = photosDirectory.resolvingSymlinksInPath().standardizedFileURL
        let canonicalCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard canonicalCandidate != canonicalDirectory,
              canonicalCandidate.pathComponents.starts(with: canonicalDirectory.pathComponents) else {
            return nil
        }

        return candidate.standardizedFileURL
    }

    // MARK: - Photo Saving

    func savePhoto(_ data: Data, for catId: UUID) -> String? {
        guard let jpeg = PhotoManager.downsampledJPEGData(
            from: data,
            maxPixelSize: PhotoManager.photoMaxPixelSize
        ) else {
            return nil
        }
        return writeJPEG(jpeg, for: catId)
    }

    func saveUIImage(_ image: UIImage, for catId: UUID) -> String? {
        guard let jpeg = PhotoManager.downsampledJPEGData(
            from: image,
            maxPixelSize: PhotoManager.photoMaxPixelSize
        ) else {
            print("❌ Failed to convert UIImage to data")
            return nil
        }
        return writeJPEG(jpeg, for: catId)
    }

    private func writeJPEG(_ data: Data, for catId: UUID) -> String? {
        let fileName = "cat_\(catId.uuidString)_\(makeUUID().uuidString).jpg"
        let fileURL = photosDirectory.appending(path: fileName)
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("❌ Failed to save photo: \(error)")
            return nil
        }
    }

    // MARK: - Photo Loading

    func loadPhoto(from stored: String) -> UIImage? {
        guard let url = resolvedURL(for: stored),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    func getPhotoURL(from stored: String) -> URL? {
        guard let url = resolvedURL(for: stored),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    // MARK: - Photo Deletion

    func deletePhoto(at path: String) {
        guard let url = resolvedURL(for: path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("❌ Failed to delete photo at \(path): \(error)")
        }
    }

    func deleteAllPhotos(for catId: UUID) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: photosDirectory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
            let prefix = "cat_\(catId.uuidString)_"
            let catPhotos = contents.filter { url in
                let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                return isRegularFile
                    && url.pathExtension.lowercased() == "jpg"
                    && url.lastPathComponent.hasPrefix(prefix)
            }

            for photoURL in catPhotos {
                try FileManager.default.removeItem(at: photoURL)
            }
        } catch {
            print("❌ Failed to delete photos for cat \(catId): \(error)")
        }
    }

    // MARK: - Validation

    func isValidImageData(_ data: Data) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        return image.size.width > 0 && image.size.height > 0
    }

    // MARK: - Storage Info

    func getStorageInfo() -> (totalPhotos: Int, totalSize: Int64) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: photosDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            let totalSize = contents.compactMap { url in
                try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            }.reduce(0, +)

            return (totalPhotos: contents.count, totalSize: Int64(totalSize))
        } catch {
            print("❌ Failed to get storage info: \(error)")
            return (totalPhotos: 0, totalSize: 0)
        }
    }
}
