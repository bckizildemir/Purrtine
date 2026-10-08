import Foundation
import SwiftData

/// Saves the Add Cat and Edit Cat forms.
///
/// The photo is written first, then the cat is committed, and a replaced photo is deleted only
/// after that commit. A failure at any step leaves the store, the shared context and the photos
/// folder as they were, so the form can stay open and retry:
/// - `PhotoSaveError` means the photo could not be written. Nothing was staged.
/// - Any other error comes from the commit. The staged change is taken back out of the context
///   (a targeted undo, not a `rollback()`, because the main context is shared), and the photo
///   written for this attempt is deleted.
@MainActor
struct CatFormSaver {
    /// What an edit does with the cat's current photo.
    enum PhotoChange {
        case keep
        case remove
        case replace(PendingCatPhoto)
    }

    var savePhoto: (PendingCatPhoto, UUID) async throws -> String = { photo, catId in
        try await PhotoManager.shared.save(photo, for: catId)
    }
    var deletePhoto: (String) -> Void = { PhotoManager.shared.deletePhoto(at: $0) }
    var saveContext: (ModelContext) throws -> Void = { try $0.save() }
    var now: () -> Date = Date.init

    func add(_ details: CatDetails, photo: PendingCatPhoto?, in context: ModelContext) async throws -> Cat {
        let catId = UUID()
        let photoPath: String? = if let photo { try await savePhoto(photo, catId) } else { nil }

        let cat = Cat(name: details.name, photoURLs: photoPath.map { [$0] } ?? [])
        cat.id = catId
        details.apply(to: cat)
        context.insert(cat)

        do {
            try saveContext(context)
        } catch {
            context.delete(cat)
            if let photoPath {
                deletePhoto(photoPath)
            }
            throw error
        }
        return cat
    }

    func update(_ cat: Cat, with details: CatDetails, photo: PhotoChange, in context: ModelContext) async throws {
        let newPhotoPath: String? = if case .replace(let newPhoto) = photo {
            try await savePhoto(newPhoto, cat.id)
        } else {
            nil
        }

        let previousDetails = CatDetails(of: cat)
        let previousPhotoURLs = cat.photoURLs
        let previousUpdatedAt = cat.updatedAt

        details.apply(to: cat)
        cat.updatedAt = now()
        switch photo {
        case .keep:
            break
        case .remove:
            cat.photoURLs = []
        case .replace:
            cat.photoURLs = newPhotoPath.map { [$0] } ?? []
        }

        do {
            try saveContext(context)
        } catch {
            previousDetails.apply(to: cat)
            cat.photoURLs = previousPhotoURLs
            cat.updatedAt = previousUpdatedAt
            if let newPhotoPath {
                deletePhoto(newPhotoPath)
            }
            throw error
        }

        for oldPhotoPath in previousPhotoURLs where cat.photoURLs.contains(oldPhotoPath) == false {
            deletePhoto(oldPhotoPath)
        }
    }
}
