import SwiftUI
import UIKit

/// Square "Move and Scale" cropper shown after a camera capture.
/// The image always covers the crop square; drag and pinch adjust the visible region.
struct PhotoCropView: View {
    let onRetake: () -> Void
    let onUse: (UIImage) -> Void

    private let image: UIImage

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 5

    init(image: UIImage, onRetake: @escaping () -> Void, onUse: @escaping (UIImage) -> Void) {
        self.image = Self.normalizedOrientation(image)
        self.onRetake = onRetake
        self.onUse = onUse
    }

    var body: some View {
        GeometryReader { geometry in
            let cropSide = max(1, min(geometry.size.width, geometry.size.height - 160))

            VStack(spacing: 0) {
                Text(.photoCropTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                cropCanvas(cropSide: cropSide)

                Spacer(minLength: 0)

                controls(cropSide: cropSide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Canvas

    private func cropCanvas(cropSide: CGFloat) -> some View {
        let displaySize = displaySize(cropSide: cropSide)

        return Image(uiImage: image)
            .resizable()
            .frame(width: displaySize.width, height: displaySize.height)
            .offset(offset)
            .frame(width: cropSide, height: cropSide)
            .clipped()
            .overlay {
                Rectangle()
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(cropSide: cropSide).simultaneously(with: zoomGesture(cropSide: cropSide)))
            .accessibilityLabel(String(localized: .photoCropTitle))
    }

    private func dragGesture(cropSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, cropSide: cropSide)
            }
            .onEnded { _ in
                committedOffset = offset
            }
    }

    private func zoomGesture(cropSide: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(committedZoom * value, minZoom), maxZoom)
                offset = clampedOffset(offset, cropSide: cropSide)
            }
            .onEnded { _ in
                committedZoom = zoom
                committedOffset = clampedOffset(offset, cropSide: cropSide)
                offset = committedOffset
            }
    }

    // MARK: - Controls

    private func controls(cropSide: CGFloat) -> some View {
        HStack {
            Button(String(localized: .photoCropRetake), action: onRetake)
                .accessibilityIdentifier("photoCrop.retakeButton")

            Spacer()

            Button(String(localized: .photoCropUse)) {
                onUse(makeCroppedImage(cropSide: cropSide))
            }
            .bold()
            .accessibilityIdentifier("photoCrop.useButton")
        }
        .font(.body)
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Geometry helpers

    /// Scale that makes the image exactly cover the crop square, before user zoom.
    private func fillScale(cropSide: CGFloat) -> CGFloat {
        max(cropSide / image.size.width, cropSide / image.size.height)
    }

    private func displaySize(cropSide: CGFloat) -> CGSize {
        let scale = fillScale(cropSide: cropSide) * zoom
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func clampedOffset(_ proposed: CGSize, cropSide: CGFloat) -> CGSize {
        let displaySize = displaySize(cropSide: cropSide)
        let maxX = max(0, (displaySize.width - cropSide) / 2)
        let maxY = max(0, (displaySize.height - cropSide) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    // MARK: - Cropping

    /// Maps the visible square back into image pixels and crops.
    private func makeCroppedImage(cropSide: CGFloat) -> UIImage {
        let displayScale = fillScale(cropSide: cropSide) * zoom
        let imageSize = image.size

        let centerX = imageSize.width / 2 - committedOffset.width / displayScale
        let centerY = imageSize.height / 2 - committedOffset.height / displayScale
        let sideInImage = cropSide / displayScale

        var rect = CGRect(
            x: centerX - sideInImage / 2,
            y: centerY - sideInImage / 2,
            width: sideInImage,
            height: sideInImage
        )
        rect = rect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !rect.isNull, !rect.isEmpty else { return image }

        let pixelScale = image.scale
        let pixelRect = CGRect(
            x: rect.origin.x * pixelScale,
            y: rect.origin.y * pixelScale,
            width: rect.width * pixelScale,
            height: rect.height * pixelScale
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: pixelScale, orientation: .up)
    }

    /// Redraws the image so its orientation is `.up`, making CGImage cropping safe.
    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

#if DEBUG
#Preview("Photo Crop") {
    PhotoCropView(
        image: UIImage(systemName: "cat.fill") ?? UIImage(),
        onRetake: {},
        onUse: { _ in }
    )
}
#endif
