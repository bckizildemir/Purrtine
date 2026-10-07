import UIKit
import ImageIO

/// Loads images from disk *downsampled* to a target pixel size using ImageIO, so a
/// full-resolution bitmap is never decoded into memory just to render a small thumbnail.
///
/// Cat/caregiver photos are stored as JPEGs compressed to ~1MB of *file size* but with
/// their original pixel dimensions intact (e.g. 3024×4032). `AsyncImage` decodes the whole
/// bitmap into an uncompressed backing store (~width×height×4 bytes ≈ tens of MB each) even
/// when the image is only shown in a 40×40 circle. Decoding several of those at once — e.g.
/// the multi-cat task-completion sheet — is what drives the memory spikes.
///
/// `CGImageSourceCreateThumbnailAtIndex` decodes straight to the requested size, keeping peak
/// memory per thumbnail in the tens of KB. Decoded results are kept in a small in-memory cache
/// keyed by path + pixel size so repeated renders don't re-decode.
nonisolated enum DownsampledImageLoader {
    private static let cache = DownsampledImageCache(countLimit: 120)
    private static let loadCoordinator = InFlightImageLoadCoordinator()

    /// Returns an already-decoded thumbnail if one is cached, without touching disk. Lets a
    /// view render synchronously on first layout when the image was loaded earlier.
    static func cachedImage(for url: URL, maxPixelSize: Int) -> UIImage? {
        guard maxPixelSize > 0 else { return nil }
        return cache.object(forKey: cacheKey(url: url, maxPixelSize: maxPixelSize))
    }

    /// Decodes a downsampled image off the main thread, caching the result. Returns `nil` when
    /// the file can't be read or decoded.
    static func loadImage(for url: URL, maxPixelSize: Int) async -> UIImage? {
        guard maxPixelSize > 0 else { return nil }
        let key = "\(url.path)|\(maxPixelSize)"
        if let cached = cache.object(forKey: key as NSString) { return cached }

        return await loadCoordinator.image(for: key) {
            let image = await Task.detached(priority: .userInitiated) {
                downsample(url: url, maxPixelSize: maxPixelSize)
            }.value
            if let image {
                cache.setObject(image, forKey: key as NSString)
            }
            return image
        }
    }

    private static func cacheKey(url: URL, maxPixelSize: Int) -> NSString {
        "\(url.path)|\(maxPixelSize)" as NSString
    }

    private static func downsample(url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              let cgImage = downsampledCGImage(from: source, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Downsamples encoded image `data` to a `CGImage` no larger than `maxPixelSize` on its longest
    /// edge, without materializing the full-resolution bitmap. Shared by on-disk display loading and
    /// save-time compression (see `PhotoManager.downsampledJPEGData`).
    static func downsampledCGImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0 else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return downsampledCGImage(from: source, maxPixelSize: maxPixelSize)
    }

    private static func downsampledCGImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0 else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }
}

/// A thread-safe memory cache of decoded thumbnails.
///
/// This wraps `NSCache`, which Apple documents as thread-safe: entries can be
/// added, removed and queried from several threads without external locking.
/// `NSCache` is not annotated `Sendable`, so that guarantee has to be stated
/// here; it is the reason for `@unchecked`, and this type adds no mutable state
/// of its own beyond the cache it forwards to.
///
/// `NSCache` is kept rather than a dictionary behind a `Mutex` because its
/// eviction under memory pressure is the whole point of this file.
/// Reads must stay synchronous and off the main actor so a view can render a
/// cached thumbnail during its first layout.
nonisolated private final class DownsampledImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init(countLimit: Int) {
        cache.countLimit = countLimit
    }

    func object(forKey key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    func setObject(_ image: UIImage, forKey key: NSString) {
        cache.setObject(image, forKey: key)
    }
}

actor InFlightImageLoadCoordinator {
    private struct ImageResult: @unchecked Sendable {
        let image: UIImage?
    }

    private struct RequestCountWaiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var tasks: [String: Task<ImageResult, Never>] = [:]
    private var requestCounts: [String: Int] = [:]
    private var requestCountWaiters: [String: [RequestCountWaiter]] = [:]

    func image(
        for key: String,
        operation: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        registerRequest(for: key)
        defer { unregisterRequest(for: key) }

        if let task = tasks[key] {
            return await task.value.image
        }

        let task = Task {
            ImageResult(image: await operation())
        }
        tasks[key] = task
        let result = await task.value
        tasks[key] = nil
        return result.image
    }

    func waitUntilRequestCount(_ target: Int, for key: String) async {
        guard (requestCounts[key] ?? 0) < target else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters[key, default: []].append(
                RequestCountWaiter(target: target, continuation: continuation)
            )
        }
    }

    private func registerRequest(for key: String) {
        let count = (requestCounts[key] ?? 0) + 1
        requestCounts[key] = count
        let waiters = requestCountWaiters.removeValue(forKey: key) ?? []
        var remainingWaiters: [RequestCountWaiter] = []
        for waiter in waiters {
            if count >= waiter.target {
                waiter.continuation.resume()
            } else {
                remainingWaiters.append(waiter)
            }
        }
        if remainingWaiters.isEmpty == false {
            requestCountWaiters[key] = remainingWaiters
        }
    }

    private func unregisterRequest(for key: String) {
        let count = max(0, (requestCounts[key] ?? 1) - 1)
        if count == 0 {
            requestCounts[key] = nil
        } else {
            requestCounts[key] = count
        }
    }
}
