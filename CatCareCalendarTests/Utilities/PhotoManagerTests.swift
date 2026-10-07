import Foundation
import CoreImage
import Testing
import UIKit
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
        try makeImageData().write(to: externalURL)
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
        try makeImageData().write(to: externalURL)
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
        let data = try makeImageData()

        let stored = try #require(fixture.sut.savePhoto(data, for: catId))
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
    func invalidImageDataIsNotSaved() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        #expect(fixture.sut.savePhoto(Data("not an image".utf8), for: UUID()) == nil)
        #expect(fixture.sut.getStorageInfo().totalPhotos == 0)
    }

    @Test
    func largeImageIsDownsampledToTheConfiguredPixelLimit() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let filter = try #require(CIFilter(name: "CIRandomGenerator"))
        let output = try #require(
            filter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 2_600, height: 2_600))
        )
        let cgImage = try #require(CIContext().createCGImage(output, from: output.extent))
        let data = try #require(UIImage(cgImage: cgImage).pngData())

        let stored = fixture.sut.savePhoto(data, for: UUID())

        let storedPath = try #require(stored)
        let savedImage = try #require(fixture.sut.loadPhoto(from: storedPath))

        #expect(max(savedImage.size.width, savedImage.size.height) <= CGFloat(PhotoManager.photoMaxPixelSize))
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

    private func makeImageData() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 16, height: 16)))
        }
        return try #require(image.pngData())
    }
}
