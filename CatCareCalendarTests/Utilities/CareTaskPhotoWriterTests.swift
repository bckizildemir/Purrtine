import Foundation
import Testing
import UIKit
@testable import CatCareCalendar

struct CareTaskPhotoWriterTests {
    @Test
    func savedPhotosAreWrittenToTheFolderAndNamedInOrder() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }

        let result = await fixture.sut.save([try CareTaskPhotoFolder.makeImage(), try CareTaskPhotoFolder.makeImage()])

        #expect(result.failures.isEmpty)
        #expect(result.fileNames.count == 2)
        #expect(try fixture.storedFileNames() == Set(result.fileNames))
    }

    @Test
    func aMissingFolderIsCreatedAgainBeforeTheWrite() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.directory)

        let result = await fixture.sut.save([try CareTaskPhotoFolder.makeImage()])

        #expect(result.failures.isEmpty)
        #expect(try fixture.storedFileNames() == Set(result.fileNames))
    }

    /// A camera capture keeps its orientation: the stored JPEG is upright, within the pixel limit.
    @Test
    func aCameraPhotoIsSavedUprightWithinThePixelLimit() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }
        let landscape = try CareTaskPhotoFolder.makeImage(width: 2_600, height: 1_300)
        let portrait = UIImage(cgImage: try #require(landscape.cgImage), scale: 1, orientation: .right)

        let result = await fixture.sut.save([portrait])

        let fileName = try #require(result.fileNames.first)
        let data = try Data(contentsOf: fixture.directory.appending(path: fileName))
        let saved = try #require(UIImage(data: data))
        #expect(data.starts(with: [0xFF, 0xD8]))
        #expect(saved.imageOrientation == .up)
        #expect(saved.size.height > saved.size.width)
        #expect(max(saved.size.width, saved.size.height) == CGFloat(PhotoManager.photoMaxPixelSize))
    }

    @Test
    func aBlockedFolderThrowsWriteFailedAndLogsIt() async throws {
        let fixture = try CareTaskPhotoFolder(blocked: true)
        defer { fixture.remove() }

        let result = await fixture.sut.save([try CareTaskPhotoFolder.makeImage()])

        #expect(result.fileNames.isEmpty)
        let failure = try #require(result.failures.first)
        guard case .writeFailed = failure else {
            Issue.record("Expected writeFailed, got \(failure)")
            return
        }
        #expect(fixture.log.messages.count == 1)
    }

    /// One photo that cannot be encoded does not stop the others.
    @Test
    func anUnreadablePhotoIsReportedAndTheOthersAreStillSaved() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }

        let result = await fixture.sut.save([UIImage(), try CareTaskPhotoFolder.makeImage()])

        #expect(result.fileNames.count == 1)
        let failure = try #require(result.failures.first)
        guard case .unreadableImage = failure else {
            Issue.record("Expected unreadableImage, got \(failure)")
            return
        }
        #expect(fixture.log.messages.count == 1)
    }

    @Test
    func deleteRemovesTheNamedFilesOnly() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }
        let kept = await fixture.sut.save([try CareTaskPhotoFolder.makeImage()]).fileNames
        let removed = await fixture.sut.save([try CareTaskPhotoFolder.makeImage()]).fileNames

        await fixture.sut.delete(removed)

        #expect(try fixture.storedFileNames() == Set(kept))
    }

    @Test
    func deleteIgnoresAPathOutsideTheFolder() async throws {
        let fixture = try CareTaskPhotoFolder()
        defer { fixture.remove() }
        let outside = fixture.directory.deletingLastPathComponent()
            .appending(path: "outside-\(UUID().uuidString).jpg")
        try Data([1]).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }

        await fixture.sut.delete(["../\(outside.lastPathComponent)"])

        #expect(FileManager.default.fileExists(atPath: outside.path))
        #expect(fixture.log.messages.count == 1)
    }
}
