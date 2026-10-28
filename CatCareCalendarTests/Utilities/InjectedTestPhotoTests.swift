#if DEBUG
import Foundation
import ImageIO
import Testing
@testable import CatCareCalendar

struct InjectedTestPhotoTests {
    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    @Test
    func rotatedPhotoIsAJPEGWithOrientationSix() throws {
        let data = try #require(InjectedTestPhoto.rotated.makeData())
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))

        #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
        #expect(try properties(of: data)[kCGImagePropertyOrientation] as? Int == 6)
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
    }

    @Test
    func largePhotoExceedsFourThousandPixels() throws {
        let data = try #require(InjectedTestPhoto.large.makeData())
        let info = try properties(of: data)
        let width = try #require(info[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(info[kCGImagePropertyPixelHeight] as? Int)

        #expect(max(width, height) > 4000)
    }

    @Test
    func heicPhotoDecodesAsHEIC() throws {
        // Reports a failure here if the simulator cannot encode HEIC.
        let data = try #require(InjectedTestPhoto.heic.makeData(), "This device cannot encode HEIC")
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))

        #expect(CGImageSourceGetType(source) as String? == "public.heic")
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
    }
}
#endif
