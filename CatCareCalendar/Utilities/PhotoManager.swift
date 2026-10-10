import Foundation
import ImageIO
import os
import UIKit
import UniformTypeIdentifiers

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
    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Photos")

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

    /// Scales `image` down to `maxPixelSize` on its longest edge and encodes it once. The drawing
    /// applies the image orientation, so the JPEG is upright. `nil` when the image has no pixels or
    /// cannot be encoded.
    static func downsampledJPEGData(
        from image: UIImage,
        maxPixelSize: Int,
        compressionQuality: CGFloat = saveCompressionQuality
    ) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longestEdge = max(pixelWidth, pixelHeight)
        guard longestEdge > 0 else { return nil }
        let factor = min(1, CGFloat(maxPixelSize) / longestEdge)
        let targetSize = CGSize(
            width: max(1, (pixelWidth * factor).rounded()),
            height: max(1, (pixelHeight * factor).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    /// Whether `data` is already what `preparedJPEGData` makes: one complete, upright JPEG image no
    /// larger than `maxPixelSize` on its longest edge. Reads the header only; nothing is decoded.
    static func isPreparedJPEG(_ data: Data, maxPixelSize: Int) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return false
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return width > 0 && height > 0 && max(width, height) <= maxPixelSize && orientation == 1
    }

    /// Downsamples a picked photo off the caller's actor, to the size `savePhoto` stores, so that
    /// `savePhoto` can write it without a second decode and encode. `nil` when the data cannot be
    /// decoded.
    @concurrent
    static func preparedJPEGData(from data: Data) async -> Data? {
        downsampledJPEGData(from: data, maxPixelSize: photoMaxPixelSize)
    }

    // MARK: - Directory Management

    private func createPhotosDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Photos directory not created: \(String(describing: error), privacy: .public)")
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

    /// Writes `data` as a JPEG and returns the stored file name. Data that `preparedJPEGData`
    /// already made is written as it is; anything else is downsampled first. Every failure is
    /// logged here, so a caller only decides what the caregiver sees.
    func savePhoto(_ data: Data, for catId: UUID) throws -> String {
        if PhotoManager.isPreparedJPEG(data, maxPixelSize: PhotoManager.photoMaxPixelSize) {
            return try writeJPEG(data, for: catId)
        }
        guard let jpeg = PhotoManager.downsampledJPEGData(
            from: data,
            maxPixelSize: PhotoManager.photoMaxPixelSize
        ) else {
            Self.logger.error("Photo not saved: the image data cannot be decoded")
            throw PhotoSaveError.unreadableImage
        }
        return try writeJPEG(jpeg, for: catId)
    }

    func saveUIImage(_ image: UIImage, for catId: UUID) throws -> String {
        guard let jpeg = PhotoManager.downsampledJPEGData(
            from: image,
            maxPixelSize: PhotoManager.photoMaxPixelSize
        ) else {
            Self.logger.error("Photo not saved: the image cannot be encoded as a JPEG")
            throw PhotoSaveError.unreadableImage
        }
        return try writeJPEG(jpeg, for: catId)
    }

    /// Saves `photo` off the caller's actor: the decode, the encode and the disk write must not
    /// block the main actor.
    @concurrent
    func save(_ photo: PendingCatPhoto, for catId: UUID) async throws -> String {
        switch photo {
        case .data(let data):
            try savePhoto(data, for: catId)
        case .image(let image):
            try saveUIImage(image, for: catId)
        }
    }

    /// Creates the photos folder first: it is made once at launch, and a folder removed since then
    /// would otherwise fail every write.
    private func writeJPEG(_ data: Data, for catId: UUID) throws -> String {
        let fileName = "cat_\(catId.uuidString)_\(makeUUID().uuidString).jpg"
        let fileURL = photosDirectory.appending(path: fileName)
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            try data.write(to: fileURL)
            return fileName
        } catch {
            Self.logger.error("Photo not saved: \(String(describing: error), privacy: .public)")
            throw PhotoSaveError.writeFailed(error)
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
            Self.logger.error("Photo not deleted: \(String(describing: error), privacy: .public)")
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
            Self.logger.error("Cat photos not deleted: \(String(describing: error), privacy: .public)")
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
            Self.logger.error("Photo storage info not read: \(String(describing: error), privacy: .public)")
            return (totalPhotos: 0, totalSize: 0)
        }
    }
}
