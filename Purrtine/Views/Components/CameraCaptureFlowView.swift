import SwiftUI
import UIKit

/// Full-screen camera flow: capture with the system camera, then crop with
/// `PhotoCropView`. Sets `image` to the final cropped photo on completion.
struct CameraCaptureFlowView: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    @State private var pendingImage: UIImage?

    var body: some View {
        ZStack {
            if let pendingImage {
                PhotoCropView(
                    image: pendingImage,
                    onRetake: { self.pendingImage = nil },
                    onUse: { cropped in
                        image = cropped
                        isPresented = false
                    }
                )
            } else {
                CameraView(
                    onCapture: { pendingImage = $0 },
                    onCancel: { isPresented = false }
                )
                .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
