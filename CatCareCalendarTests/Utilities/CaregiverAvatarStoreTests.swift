import Foundation
import ImageIO
import Testing
import UIKit
@testable import CatCareCalendar

struct CaregiverAvatarStoreTests {
    private let directory = URL.temporaryDirectory.appending(path: "CaregiverAvatarStoreTests-\(UUID().uuidString)")

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test
    func saveWritesAJPEGScaledToTheAvatarSizeAndReturnsItsFileName() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = CaregiverAvatarStore(directory: directory)

        let fileName = try await sut.save(image(width: 1024, height: 768))

        #expect(fileName == URL(filePath: fileName).lastPathComponent)
        let data = try Data(contentsOf: directory.appending(path: fileName))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 512)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 384)
    }

    @Test
    func aFolderThatCannotBeCreatedThrowsAWriteFailure() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not a folder".utf8).write(to: directory)
        let sut = CaregiverAvatarStore(directory: directory)

        await #expect {
            _ = try await sut.save(image(width: 8, height: 8))
        } throws: { error in
            guard case PhotoSaveError.writeFailed = error else { return false }
            return true
        }
    }

    @Test
    func deleteRemovesASavedAvatar() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = CaregiverAvatarStore(directory: directory)
        let fileName = try await sut.save(image(width: 8, height: 8))

        sut.delete(fileName)

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: fileName).path) == false)
    }
}
