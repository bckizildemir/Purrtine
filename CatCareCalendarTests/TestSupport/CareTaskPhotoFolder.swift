import Foundation
import Testing
import UIKit
@testable import CatCareCalendar

/// A throwaway task photo folder and a writer rooted in it. With `blocked`, a regular file sits where
/// the folder should be, so neither the folder nor a photo can be written.
struct CareTaskPhotoFolder {
    let directory: URL
    let log: LogSpy
    let sut: CareTaskPhotoWriter
    private let root: URL

    init(blocked: Bool = false) throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "CareTaskPhotoWriterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        directory = root.appending(path: "CareTaskPhotos", directoryHint: .isDirectory)
        if blocked {
            try Data([1]).write(to: directory)
        } else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let log = LogSpy()
        self.log = log
        sut = CareTaskPhotoWriter(photosDirectory: directory, logFailure: { log.record($0) })
    }

    func storedFileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    /// A small, solid-colour image that encodes as a JPEG.
    static func makeImage() throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        try #require(image.jpegData(compressionQuality: 1) != nil)
        return image
    }
}
