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

    /// A solid-colour image at scale 1 that encodes as a JPEG; 8 × 8 unless a size is given.
    static func makeImage(width: Int = 8, height: Int = 8) throws -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1)))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        try #require(image.jpegData(compressionQuality: 1) != nil)
        return image
    }
}
