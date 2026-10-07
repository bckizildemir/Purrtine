import Foundation
import Testing
import UIKit
@testable import CatCareCalendar

@Suite
struct DownsampledImageLoaderTests {
    @Test
    func diskLoadingDownsamplesAndCachesTheDecodedInstance() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DownsampledImageLoaderTests-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 80, height: 40)))
        }
        try #require(image.pngData()).write(to: url)

        let firstResult = await DownsampledImageLoader.loadImage(for: url, maxPixelSize: 10)
        let firstImage = try #require(firstResult)
        let cachedImage = try #require(
            DownsampledImageLoader.cachedImage(for: url, maxPixelSize: 10)
        )
        let secondResult = await DownsampledImageLoader.loadImage(for: url, maxPixelSize: 10)
        let secondImage = try #require(secondResult)

        #expect(max(firstImage.size.width, firstImage.size.height) <= 10)
        #expect(firstImage === cachedImage)
        #expect(firstImage === secondImage)
    }

    @Test
    func corruptDiskPayloadIsNotDecodedOrCached() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DownsampledImageLoaderTests-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not-an-image".utf8).write(to: url)

        let image = await DownsampledImageLoader.loadImage(for: url, maxPixelSize: 64)

        #expect(image == nil)
        #expect(DownsampledImageLoader.cachedImage(for: url, maxPixelSize: 64) == nil)
    }

    @Test(arguments: [Int.min, -1, 0])
    func invalidPixelLimitsAreRejected(maxPixelSize: Int) throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 2, height: 2)))
        }
        let data = try #require(image.pngData())

        #expect(
            DownsampledImageLoader.downsampledCGImage(
                from: data,
                maxPixelSize: maxPixelSize
            ) == nil
        )
    }

    @Test
    func concurrentRequestsForTheSameImageShareOneDecode() async throws {
        let sut = InFlightImageLoadCoordinator()
        let probe = ImageDecodeProbe()
        let key = UUID().uuidString

        let first = Task {
            await sut.image(for: key) {
                await probe.decode()
            }
        }
        await sut.waitUntilRequestCount(1, for: key)
        let second = Task {
            await sut.image(for: key) {
                await probe.decode()
            }
        }
        await sut.waitUntilRequestCount(2, for: key)
        await probe.waitUntilDecodeStarts()

        let countBeforeRelease = await probe.decodeCount
        #expect(countBeforeRelease == 1)
        await probe.release()
        let firstResult = await first.value
        let secondResult = await second.value
        let firstImage = try #require(firstResult)
        let secondImage = try #require(secondResult)
        let finalDecodeCount = await probe.decodeCount

        #expect(firstImage === secondImage)
        #expect(finalDecodeCount == 1)
    }
}

private actor ImageDecodeProbe {
    private(set) var decodeCount = 0
    private let image = UIImage()
    private var isDecodeStarted = false
    private var decodeStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func decode() async -> UIImage? {
        decodeCount += 1
        isDecodeStarted = true
        decodeStartWaiters.forEach { $0.resume() }
        decodeStartWaiters = []
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return image
    }

    func waitUntilDecodeStarts() async {
        if isDecodeStarted { return }
        await withCheckedContinuation { continuation in
            decodeStartWaiters.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
