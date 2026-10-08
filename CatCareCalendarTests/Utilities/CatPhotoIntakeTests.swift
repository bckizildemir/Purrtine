import Foundation
import Testing
import UIKit
@testable import CatCareCalendar

@MainActor
struct CatPhotoIntakeTests {
    /// For example an iCloud-only photo while the phone is offline.
    @Test
    func aLoadThatThrowsIsLoadFailed() async {
        let result = await CatPhotoIntake.prepare { throw LoadFailure() }

        #expect(result == .loadFailed)
    }

    @Test
    func aLoadThatReturnsNoDataIsLoadFailed() async {
        let result = await CatPhotoIntake.prepare { nil }

        #expect(result == .loadFailed)
    }

    /// The form must not keep data it cannot show or save later.
    @Test
    func dataThatCannotBeDecodedIsUnusable() async {
        let result = await CatPhotoIntake.prepare { Data("not an image".utf8) }

        #expect(result == .unusable)
    }

    @Test
    func aDecodablePhotoIsReadyAsAJPEGWithinThePixelLimit() async throws {
        let size = CGSize(width: 2_600, height: 1_300)
        let png = try #require(UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1))).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }.pngData())

        let result = await CatPhotoIntake.prepare { png }

        guard case .ready(let data) = result else {
            Issue.record("Expected a ready photo, got \(result)")
            return
        }
        let image = try #require(UIImage(data: data))
        #expect(data.starts(with: [0xFF, 0xD8]))
        #expect(max(image.size.width, image.size.height) <= CGFloat(PhotoManager.photoMaxPixelSize))
    }
}

private struct LoadFailure: Error {}
