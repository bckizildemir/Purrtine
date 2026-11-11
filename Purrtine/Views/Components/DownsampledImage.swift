import SwiftUI

/// Drop-in replacement for `AsyncImage(url:)` when a photo is displayed at a small, fixed size.
///
/// Unlike `AsyncImage`, this decodes the file *downsampled* to the display size (see
/// ``DownsampledImageLoader``) instead of loading the full-resolution bitmap into memory, and
/// caches the decoded thumbnail so repeated renders don't re-decode. Apply `.frame(...)` and
/// `.clipShape(...)` to the result exactly as you would with `AsyncImage`; the image fills the
/// frame with `.aspectRatio(contentMode: .fill)`.
struct DownsampledImage<Placeholder: View>: View {
    /// Point size of the (square) area the image is displayed in. Combined with the display
    /// scale to pick the decode resolution.
    let targetPointSize: CGFloat
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    init(
        url: URL?,
        targetPointSize: CGFloat,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetPointSize = targetPointSize
        self.placeholder = placeholder
    }

    private var maxPixelSize: Int {
        Int((targetPointSize * displayScale).rounded(.up))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: TaskKey(path: url?.path, maxPixelSize: maxPixelSize)) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }

        if let cached = DownsampledImageLoader.cachedImage(for: url, maxPixelSize: maxPixelSize) {
            image = cached
            return
        }

        image = await DownsampledImageLoader.loadImage(for: url, maxPixelSize: maxPixelSize)
    }

    /// Identity for `.task(id:)` so the decode re-runs when the file or resolution changes.
    private struct TaskKey: Equatable {
        let path: String?
        let maxPixelSize: Int
    }
}
