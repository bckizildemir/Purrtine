#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo the app supplies itself, instead of the system photo picker, under
/// `-ui-testing -inject-test-photo[=<name>]` (#52).
///
/// The system picker runs out of process, so neither the UI tests nor a hand check can pick from
/// it. With the flag, "choose from library" feeds these bytes into the same code that
/// `loadTransferable(type: Data.self)` feeds. The fixtures are generated in code, so no resource
/// has to be bundled. Debug builds only: a release build has neither the type nor any call site.
nonisolated enum InjectedTestPhoto: String, CaseIterable, Sendable {
    /// A small landscape JPEG that carries EXIF orientation 6. Upright it is a portrait with a
    /// red band along the top, a yellow band along the bottom and a blue middle.
    case rotated
    /// A JPEG wider than 4000 px, to reach the size cap (#59).
    case large
    /// A HEIC image, encoded with ImageIO.
    case heic

    static let `default`: InjectedTestPhoto = .rotated

    static let rotatedStoredSize = (width: 320, height: 240)
    static let largeSize = (width: 4200, height: 3000)
    static let heicSize = (width: 400, height: 300)

    /// The fixture bytes off the main actor. `nil` when the image could not be encoded.
    func load() async -> Data? {
        await Task.detached { [self] in makeData() }.value
    }

    func makeData() -> Data? {
        switch self {
        case .rotated:
            let size = Self.rotatedStoredSize
            guard let image = Self.makeImage(width: size.width, height: size.height, draw: Self.drawRotatedMarkers)
            else { return nil }
            return Self.encode(image, type: .jpeg, orientation: 6)
        case .large:
            let size = Self.largeSize
            guard let image = Self.makeImage(width: size.width, height: size.height, draw: Self.drawGradient)
            else { return nil }
            return Self.encode(image, type: .jpeg, orientation: nil)
        case .heic:
            let size = Self.heicSize
            guard let image = Self.makeImage(width: size.width, height: size.height, draw: Self.drawGradient)
            else { return nil }
            return Self.encode(image, type: .heic, orientation: nil)
        }
    }

    // MARK: - Drawing

    private static func makeImage(
        width: Int,
        height: Int,
        draw: (CGContext, Int, Int) -> Void
    ) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        draw(context, width, height)
        return context.makeImage()
    }

    /// Stored 320x240. Orientation 6 turns the stored left edge into the upright top, so the red
    /// band sits on the left and the yellow band on the right of the stored pixels.
    private static func drawRotatedMarkers(_ context: CGContext, _ width: Int, _ height: Int) {
        context.setFillColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let band = CGFloat(width) / 5
        context.setFillColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: band, height: CGFloat(height)))
        context.setFillColor(red: 0.95, green: 0.85, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: CGFloat(width) - band, y: 0, width: band, height: CGFloat(height)))
    }

    private static func drawGradient(_ context: CGContext, _ width: Int, _ height: Int) {
        let colors = [
            CGColor(red: 0.95, green: 0.55, blue: 0.2, alpha: 1),
            CGColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1)
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)
        else { return }
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: width, y: height),
            options: []
        )
    }

    // MARK: - Encoding

    private static func encode(_ image: CGImage, type: UTType, orientation: Int?) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            return nil
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
#endif
