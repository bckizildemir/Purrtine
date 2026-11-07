import Foundation
import os

/// Turns a photo-library pick into data the cat form can keep.
///
/// The photo is downsampled here, once, so the form never holds data that it cannot show or save
/// later. Every failure is logged; the form decides what the caregiver sees.
enum CatPhotoIntake {
    enum Outcome: Equatable {
        /// The JPEG that `PhotoManager.preparedJPEGData` made, ready to show and to save as
        /// `PendingCatPhoto.prepared`.
        case ready(Data)
        /// The photo did not load, for example an iCloud-only photo while the phone is offline.
        case loadFailed
        /// The photo loaded but cannot be decoded.
        case unusable
    }

    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Photos")

    static func prepare(_ load: () async throws -> Data?) async -> Outcome {
        let data: Data
        do {
            guard let loaded = try await load() else {
                logger.error("Picked photo not loaded: no data")
                return .loadFailed
            }
            data = loaded
        } catch {
            logger.error("Picked photo not loaded: \(String(describing: error), privacy: .public)")
            return .loadFailed
        }

        guard let jpeg = await PhotoManager.preparedJPEGData(from: data) else {
            logger.error("Picked photo cannot be used: the image data cannot be decoded")
            return .unusable
        }
        return .ready(jpeg)
    }
}
