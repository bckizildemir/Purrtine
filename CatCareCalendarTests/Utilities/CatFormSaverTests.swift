import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct CatFormSaverTests {
    private let details = CatDetails(name: "Luna", gender: .female, age: 24)
    private let container: ModelContainer

    init() throws {
        container = try TestModelContainerFactory.makeInMemoryContainer()
    }

    // MARK: - Add Cat

    @Test
    func addWritesThePhotoForTheNewCatAndCommitsBoth() async throws {
        let context = container.mainContext
        var photoOwnerIds: [UUID] = []
        let sut = CatFormSaver(savePhoto: { _, catId in
            photoOwnerIds.append(catId)
            return "new.jpg"
        })

        let cat = try await sut.add(details, photo: .data(Data("photo".utf8)), in: context)

        let saved = try #require(try context.fetch(FetchDescriptor<Cat>()).first)
        #expect(saved.name == "Luna")
        #expect(saved.photoURLs == ["new.jpg"])
        #expect(photoOwnerIds == [cat.id])
        #expect(context.hasChanges == false)
    }

    /// The form stays open on this error, so nothing may be left staged for a retry to duplicate.
    @Test
    func aFailedPhotoWriteInAddStagesNothing() async throws {
        let context = container.mainContext
        let sut = CatFormSaver(savePhoto: { _, _ in throw PhotoSaveError.unreadableImage })

        await #expect(throws: PhotoSaveError.self) {
            _ = try await sut.add(details, photo: .data(Data("photo".utf8)), in: context)
        }

        #expect(context.insertedModelsArray.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
    }

    @Test
    func aFailedAddCommitUnstagesTheCatAndDeletesItsPhotoSoARetrySavesOneCat() async throws {
        let context = container.mainContext
        var deletedPhotos: [String] = []
        let failing = CatFormSaver(
            savePhoto: { _, _ in "new.jpg" },
            deletePhoto: { deletedPhotos.append($0) },
            saveContext: { _ in throw SaveFailure() }
        )

        await #expect(throws: SaveFailure.self) {
            _ = try await failing.add(details, photo: .data(Data("photo".utf8)), in: context)
        }

        #expect(context.insertedModelsArray.isEmpty)
        #expect(deletedPhotos == ["new.jpg"])

        _ = try await CatFormSaver(savePhoto: { _, _ in "retry.jpg" }).add(
            details,
            photo: .data(Data("photo".utf8)),
            in: context
        )
        #expect(try context.fetch(FetchDescriptor<Cat>()).count == 1)
    }

    // MARK: - Edit Cat

    @Test
    func editReplacesThePhotoAndDeletesTheOldOneOnlyAfterTheCommit() async throws {
        let context = container.mainContext
        let cat = try insertSavedCat(in: context)
        var deletedPhotos: [String] = []
        var deletedBeforeCommit: [String]?
        let sut = CatFormSaver(
            savePhoto: { _, _ in "new.jpg" },
            deletePhoto: { deletedPhotos.append($0) },
            saveContext: { context in
                deletedBeforeCommit = deletedPhotos
                try context.save()
            }
        )

        try await sut.update(cat, with: details, photo: .replace(.data(Data("photo".utf8))), in: context)

        #expect(deletedBeforeCommit == [])
        #expect(deletedPhotos == ["old.jpg"])
        #expect(cat.photoURLs == ["new.jpg"])
        #expect(cat.name == "Luna")
    }

    /// "Save without photo" in Edit Cat: the other edits are saved and the current photo stays.
    @Test
    func editThatKeepsThePhotoSavesTheOtherEditsAndDeletesNothing() async throws {
        let context = container.mainContext
        let cat = try insertSavedCat(in: context)
        var deletedPhotos: [String] = []
        let sut = CatFormSaver(deletePhoto: { deletedPhotos.append($0) })

        try await sut.update(cat, with: details, photo: .keep, in: context)

        #expect(cat.name == "Luna")
        #expect(cat.photoURLs == ["old.jpg"])
        #expect(deletedPhotos.isEmpty)
        #expect(context.hasChanges == false)
    }

    @Test
    func editThatRemovesThePhotoDeletesItAfterTheCommit() async throws {
        let context = container.mainContext
        let cat = try insertSavedCat(in: context)
        var deletedPhotos: [String] = []
        let sut = CatFormSaver(deletePhoto: { deletedPhotos.append($0) })

        try await sut.update(cat, with: details, photo: .remove, in: context)

        #expect(cat.photoURLs.isEmpty)
        #expect(deletedPhotos == ["old.jpg"])
    }

    @Test
    func aFailedPhotoWriteInEditLeavesTheCatUnchanged() async throws {
        let context = container.mainContext
        let cat = try insertSavedCat(in: context)
        var deletedPhotos: [String] = []
        let sut = CatFormSaver(
            savePhoto: { _, _ in throw PhotoSaveError.writeFailed(SaveFailure()) },
            deletePhoto: { deletedPhotos.append($0) }
        )

        await #expect(throws: PhotoSaveError.self) {
            try await sut.update(cat, with: details, photo: .replace(.data(Data("photo".utf8))), in: context)
        }

        #expect(cat.name == "Mochi")
        #expect(cat.photoURLs == ["old.jpg"])
        #expect(deletedPhotos.isEmpty)
        #expect(context.hasChanges == false)
    }

    /// A later unrelated save must not commit the edit, nor a path to the new file that was deleted.
    @Test
    func aFailedEditCommitRestoresTheCatAndDeletesOnlyTheNewPhoto() async throws {
        let context = container.mainContext
        let cat = try insertSavedCat(in: context)
        let updatedAt = cat.updatedAt
        var deletedPhotos: [String] = []
        let sut = CatFormSaver(
            savePhoto: { _, _ in "new.jpg" },
            deletePhoto: { deletedPhotos.append($0) },
            saveContext: { _ in throw SaveFailure() },
            now: { updatedAt.addingTimeInterval(60) }
        )

        await #expect(throws: SaveFailure.self) {
            try await sut.update(cat, with: details, photo: .replace(.data(Data("photo".utf8))), in: context)
        }

        #expect(cat.name == "Mochi")
        #expect(cat.gender == .male)
        #expect(cat.age == 6)
        #expect(cat.updatedAt == updatedAt)
        #expect(cat.photoURLs == ["old.jpg"])
        #expect(deletedPhotos == ["new.jpg"])
    }

    // MARK: - Helpers

    private func insertSavedCat(in context: ModelContext) throws -> Cat {
        let cat = Cat(name: "Mochi", photoURLs: ["old.jpg"], age: 6, gender: .male)
        context.insert(cat)
        try context.save()
        return cat
    }
}

private struct SaveFailure: Error {}
