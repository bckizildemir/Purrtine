import Foundation
import CoreImage
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import CatCareCalendar

@Suite
struct PhotoManagerTests {
    @Test
    func relativeAndLegacyAbsolutePathsResolveWithoutTraversal() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let legacyURL = fixture.directory.appending(path: "legacy.jpg")

        #expect(fixture.sut.resolvedURL(for: "cat.jpg") == fixture.directory.appending(path: "cat.jpg"))
        #expect(fixture.sut.resolvedURL(for: legacyURL.path) == legacyURL)
    }

    @Test(arguments: [
        "",
        ".",
        "..",
        "../outside.jpg",
        "nested/photo.jpg"
    ])
    func malformedRelativePathsAreRejected(_ stored: String) throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        #expect(fixture.sut.resolvedURL(for: stored) == nil)
    }

    @Test
    func externalAbsoluteAndTraversalPathsCannotBeLoadedOrDeleted() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let externalURL = fixture.directory
            .deletingLastPathComponent()
            .appending(path: "external-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: externalURL) }
        try makeImageData(width: 16, height: 16).write(to: externalURL)
        let traversalPath = fixture.directory
            .appending(path: "..")
            .appending(path: externalURL.lastPathComponent)
            .path

        for stored in [externalURL.path, traversalPath] {
            #expect(fixture.sut.resolvedURL(for: stored) == nil)
            #expect(fixture.sut.getPhotoURL(from: stored) == nil)
            #expect(fixture.sut.loadPhoto(from: stored) == nil)
            fixture.sut.deletePhoto(at: stored)
            #expect(FileManager.default.fileExists(atPath: externalURL.path))
        }
    }

    @Test
    func symlinkEscapeCannotBeResolvedLoadedOrDeleted() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let externalURL = fixture.directory
            .deletingLastPathComponent()
            .appending(path: "external-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: externalURL) }
        try makeImageData(width: 16, height: 16).write(to: externalURL)
        let symlinkURL = fixture.directory.appending(path: "linked.jpg")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: externalURL)

        #expect(fixture.sut.resolvedURL(for: symlinkURL.lastPathComponent) == nil)
        #expect(fixture.sut.getPhotoURL(from: symlinkURL.lastPathComponent) == nil)
        #expect(fixture.sut.loadPhoto(from: symlinkURL.lastPathComponent) == nil)
        fixture.sut.deletePhoto(at: symlinkURL.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: externalURL.path))
        #expect(FileManager.default.fileExists(atPath: symlinkURL.path))
    }

    @Test
    func savedPhotoUsesOwnedFilenameAndRelativeDeletionRemovesIt() throws {
        let generatedId = UUID()
        let catId = UUID()
        let fixture = try makeFixture(makeUUID: { generatedId })
        defer { fixture.cleanup() }
        let data = try makeImageData(width: 16, height: 16)

        let stored = try fixture.sut.savePhoto(data, for: catId)
        let expected = "cat_\(catId.uuidString)_\(generatedId.uuidString).jpg"
        let savedURL = fixture.directory.appending(path: expected)

        #expect(stored == expected)
        #expect(FileManager.default.fileExists(atPath: savedURL.path))
        #expect(try Data(contentsOf: savedURL).count <= 1_000_000)
        #expect(fixture.sut.loadPhoto(from: stored) != nil)

        fixture.sut.deletePhoto(at: stored)
        #expect(FileManager.default.fileExists(atPath: savedURL.path) == false)
    }

    @Test
    func invalidImageDataThrowsUnreadableImageAndWritesNothing() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let error = try #require(throws: PhotoSaveError.self) {
            try fixture.sut.savePhoto(Data("not an image".utf8), for: UUID())
        }

        guard case .unreadableImage = error else {
            Issue.record("Expected unreadableImage, got \(error)")
            return
        }
        #expect(fixture.sut.getStorageInfo().totalPhotos == 0)
    }

    @Test
    func aDirectoryThatCannotBeCreatedThrowsWriteFailed() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        // A regular file where the photos folder should be: neither the folder nor the photo can be written.
        let blocker = fixture.directory.appending(path: "blocker")
        try Data([1]).write(to: blocker)
        let sut = PhotoManager(photosDirectory: blocker)

        let error = try #require(throws: PhotoSaveError.self) {
            try sut.savePhoto(try makeImageData(width: 16, height: 16), for: UUID())
        }

        guard case .writeFailed = error else {
            Issue.record("Expected writeFailed, got \(error)")
            return
        }
    }

    @Test
    func aDirectoryThatCannotBeWrittenToThrowsWriteFailed() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let fileManager = FileManager.default
        try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: fixture.directory.path)
        defer { try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.directory.path) }

        let error = try #require(throws: PhotoSaveError.self) {
            try fixture.sut.savePhoto(try makeImageData(width: 16, height: 16), for: UUID())
        }

        guard case .writeFailed = error else {
            Issue.record("Expected writeFailed, got \(error)")
            return
        }
    }

    @Test
    func aMissingPhotosDirectoryIsCreatedAgainBeforeTheWrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try FileManager.default.removeItem(at: fixture.directory)

        let stored = try fixture.sut.savePhoto(try makeImageData(width: 16, height: 16), for: UUID())

        #expect(fixture.sut.getPhotoURL(from: stored) != nil)
    }

    @Test
    func largeImageIsDownsampledToTheConfiguredPixelLimit() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let data = try makeNoiseImageData()

        let storedPath = try fixture.sut.savePhoto(data, for: UUID())
        let savedImage = try #require(fixture.sut.loadPhoto(from: storedPath))

        #expect(max(savedImage.size.width, savedImage.size.height) <= CGFloat(PhotoManager.photoMaxPixelSize))
    }

    /// A photo-library pick is downsampled and encoded once, by `CatPhotoIntake`; saving it must not
    /// decode and compress it a second time.
    @Test
    func preparedJPEGDataIsWrittenWithoutReEncoding() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        // Noise, not a flat colour: a flat image can come out of a second encode byte for byte.
        let prepared = try #require(await PhotoManager.preparedJPEGData(from: try makeNoiseImageData()))

        let stored = try await fixture.sut.save(.prepared(prepared), for: UUID())

        let url = try #require(fixture.sut.getPhotoURL(from: stored))
        #expect(try Data(contentsOf: url) == prepared)
    }

    /// Only data the app prepared itself is written as it is. Plain data that only looks prepared
    /// (small, upright, one JPEG image, no location) is re-encoded, which drops its EXIF, IPTC and
    /// XMP metadata.
    @Test
    func plainJPEGDataWithMetadataIsReEncodedWithoutIt() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let jpeg = try makeJPEGWithMetadata()
        let source = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let sourceProperties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let sourceExif = try #require(sourceProperties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        let sourceIPTC = try #require(sourceProperties[kCGImagePropertyIPTCDictionary] as? [CFString: Any])
        try #require(sourceExif[kCGImagePropertyExifLensMake] as? String == "Test Lens Maker")
        try #require(sourceIPTC[kCGImagePropertyIPTCCity] as? String == "Istanbul")
        try #require(xmpTagValue(of: source) == "Purrtine Test")
        try #require(PhotoManager.isPreparedJPEG(jpeg, maxPixelSize: PhotoManager.photoMaxPixelSize))

        let stored = try fixture.sut.savePhoto(jpeg, for: UUID())

        let url = try #require(fixture.sut.getPhotoURL(from: stored))
        let saved = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(saved, 0, nil) as? [CFString: Any])
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifLensMake] == nil)
        #expect(exif[kCGImagePropertyExifUserComment] == nil)
        #expect(properties[kCGImagePropertyIPTCDictionary] == nil)
        #expect(xmpTagValue(of: saved) == nil)
    }

    /// Onboarding can hand over a full-size camera JPEG; it must still be capped on save.
    @Test
    func aJPEGLargerThanThePixelLimitIsStillDownsampled() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let image = try #require(UIImage(data: try makeImageData(width: 2_600, height: 1_300)))
        let jpeg = try #require(image.jpegData(compressionQuality: 0.8))

        let stored = try fixture.sut.savePhoto(jpeg, for: UUID())
        let saved = try #require(fixture.sut.loadPhoto(from: stored))

        #expect(max(saved.size.width, saved.size.height) <= CGFloat(PhotoManager.photoMaxPixelSize))
    }

    /// Only data without a location is written as it is: a small JPEG with GPS data is re-encoded,
    /// which drops the location.
    @Test
    func aJPEGWithLocationDataIsReEncodedWithoutIt() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let cgImage = try #require(UIImage(data: try makeImageData(width: 64, height: 64))?.cgImage)
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 41.0, kCGImagePropertyGPSLongitude: 29.0]
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        let input = try #require(CGImageSourceCreateWithData(output, nil))
        let inputProperties = try #require(CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any])
        try #require(inputProperties[kCGImagePropertyGPSDictionary] != nil)

        let stored = try fixture.sut.savePhoto(output as Data, for: UUID())

        let url = try #require(fixture.sut.getPhotoURL(from: stored))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test
    func aTruncatedJPEGThrowsUnreadableImageAndWritesNothing() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let prepared = try #require(
            await PhotoManager.preparedJPEGData(from: try makeImageData(width: 64, height: 64))
        )

        let error = try #require(throws: PhotoSaveError.self) {
            try fixture.sut.savePhoto(prepared.prefix(prepared.count / 2), for: UUID())
        }

        guard case .unreadableImage = error else {
            Issue.record("Expected unreadableImage, got \(error)")
            return
        }
        #expect(fixture.sut.getStorageInfo().totalPhotos == 0)
    }

    /// A camera capture keeps its orientation: the stored JPEG is upright, within the pixel limit.
    @Test
    func aCameraImageIsSavedUprightWithinThePixelLimit() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let landscape = try #require(UIImage(data: try makeImageData(width: 2_600, height: 1_300))?.cgImage)
        let portrait = UIImage(cgImage: landscape, scale: 1, orientation: .right)

        let stored = try await fixture.sut.save(.image(portrait), for: UUID())
        let url = try #require(fixture.sut.getPhotoURL(from: stored))
        let data = try Data(contentsOf: url)
        let saved = try #require(UIImage(data: data))

        #expect(data.starts(with: [0xFF, 0xD8]))
        #expect(saved.size.height > saved.size.width)
        #expect(max(saved.size.width, saved.size.height) == CGFloat(PhotoManager.photoMaxPixelSize))
    }

    /// Caregiver avatars are capped at the smaller avatar limit.
    @Test
    func renderedJPEGDataCapsAnAvatarAtTheAvatarPixelLimit() throws {
        let image = try #require(UIImage(data: try makeImageData(width: 2_600, height: 1_300)))

        let jpeg = try #require(
            PhotoManager.renderedJPEGData(from: image, maxPixelSize: PhotoManager.avatarMaxPixelSize)
        )
        let saved = try #require(UIImage(data: jpeg))

        #expect(jpeg.starts(with: [0xFF, 0xD8]))
        let cap = PhotoManager.avatarMaxPixelSize
        #expect(saved.size == CGSize(width: cap, height: cap / 2))
    }

    /// A JPEG has no alpha channel. Avatars, task photos and cat photos all go through
    /// `renderedJPEGData`, so a transparent area comes out the same colour on each: black.
    @Test
    func renderedJPEGDataTurnsATransparentImageBlack() throws {
        let size = CGSize(width: 16, height: 16)
        let format = UIGraphicsImageRendererFormat(for: .init(displayScale: 1))
        format.opaque = false
        let transparent = UIGraphicsImageRenderer(size: size, format: format).image { _ in }

        let jpeg = try #require(PhotoManager.renderedJPEGData(from: transparent, maxPixelSize: 64))
        let cgImage = try #require(UIImage(data: jpeg)?.cgImage)

        #expect([.none, .noneSkipLast, .noneSkipFirst].contains(cgImage.alphaInfo))
        #expect(try centrePixel(of: cgImage).allSatisfy { $0 <= 2 })
    }

    @Test
    func bulkDeletionOnlyRemovesFilesOwnedByTheRequestedCat() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let catId = UUID()
        let otherCatId = UUID()
        let owned = fixture.directory.appending(path: "cat_\(catId.uuidString)_one.jpg")
        let embedded = fixture.directory.appending(path: "other_\(catId.uuidString).jpg")
        let other = fixture.directory.appending(path: "cat_\(otherCatId.uuidString)_one.jpg")
        try Data([1]).write(to: owned)
        try Data([1]).write(to: embedded)
        try Data([1]).write(to: other)

        fixture.sut.deleteAllPhotos(for: catId)

        #expect(FileManager.default.fileExists(atPath: owned.path) == false)
        #expect(FileManager.default.fileExists(atPath: embedded.path))
        #expect(FileManager.default.fileExists(atPath: other.path))
    }

    private func makeFixture(
        makeUUID: @escaping @Sendable () -> UUID = { UUID() }
    ) throws -> (sut: PhotoManager, directory: URL, cleanup: () -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PhotoManagerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sut = PhotoManager(photosDirectory: directory, makeUUID: makeUUID)
        return (
            sut,
            directory,
            { try? FileManager.default.removeItem(at: directory) }
        )
    }

    /// A 2600 × 2600 PNG of random noise, larger than the photo pixel limit.
    private func makeNoiseImageData() throws -> Data {
        let filter = try #require(CIFilter(name: "CIRandomGenerator"))
        let output = try #require(
            filter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 2_600, height: 2_600))
        )
        let cgImage = try #require(CIContext().createCGImage(output, from: output.extent))
        return try #require(UIImage(cgImage: cgImage).pngData())
    }

    private static let xmpTagPath = "purrtine:CreatorTool"

    /// A 64 × 64 JPEG with no location, but with EXIF (lens maker, user comment), IPTC (city,
    /// country) and an XMP tag.
    private func makeJPEGWithMetadata() throws -> Data {
        let cgImage = try #require(UIImage(data: try makeImageData(width: 64, height: 64))?.cgImage)
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        )
        // A namespace of its own: ImageIO does not write a lone `xmp:` basic tag.
        let metadata = CGImageMetadataCreateMutable()
        try #require(
            CGImageMetadataRegisterNamespaceForPrefix(
                metadata,
                "https://example.com/purrtine-test/1.0/" as CFString,
                "purrtine" as CFString,
                nil
            )
        )
        try #require(
            CGImageMetadataSetValueWithPath(metadata, nil, Self.xmpTagPath as CFString, "Purrtine Test" as CFString)
        )
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensMake: "Test Lens Maker",
                kCGImagePropertyExifUserComment: "A private note"
            ],
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCCity: "Istanbul",
                kCGImagePropertyIPTCCountryPrimaryLocationName: "Türkiye"
            ]
        ]
        CGImageDestinationAddImageAndMetadata(destination, cgImage, metadata, properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func xmpTagValue(of source: CGImageSource) -> String? {
        guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tag = CGImageMetadataCopyTagWithPath(metadata, nil, Self.xmpTagPath as CFString) else {
            return nil
        }
        return CGImageMetadataTagCopyValue(tag) as? String
    }

    /// An opaque PNG of `width` × `height` pixels, drawn at scale 1.
    /// The red, green and blue values of the centre pixel, drawn into an sRGB bitmap.
    private func centrePixel(of image: CGImage) throws -> [UInt8] {
        var rgba = [UInt8](repeating: 255, count: 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            let offset = CGPoint(x: -CGFloat(image.width / 2), y: -CGFloat(image.height / 2))
            context.draw(image, in: CGRect(origin: offset, size: CGSize(width: image.width, height: image.height)))
            return true
        }
        try #require(drawn)
        return Array(rgba.prefix(3))
    }

    private func makeImageData(width: Int, height: Int) throws -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1)))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try #require(image.pngData())
    }
}
