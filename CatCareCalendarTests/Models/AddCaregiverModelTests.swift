import Foundation
import SwiftData
import Testing
import UIKit
@testable import CatCareCalendar

@MainActor
struct AddCaregiverModelTests {
    private struct CommitFailure: Error {}

    private let container: ModelContainer
    private let avatar = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
        UIColor.orange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    init() throws {
        container = try TestModelContainerFactory.makeInMemoryContainer()
    }

    @Test
    func aSaveWithAPhotoStoresTheCaregiverWithItsAvatarFileName() async throws {
        let context = container.mainContext
        let sut = AddCaregiverModel(saveAvatar: { _ in "avatar.jpg" }, deleteAvatar: { _ in })

        let outcome = await sut.save(name: "Ayşe", avatar: avatar, in: context)

        #expect(outcome == .saved)
        let saved = try #require(try context.fetch(FetchDescriptor<Caregiver>()).first)
        #expect(saved.name == "Ayşe")
        #expect(saved.avatarURL == "avatar.jpg")
        #expect(context.hasChanges == false)
        #expect(sut.isSaving == false)
    }

    @Test
    func aSaveWithoutAPhotoWritesNoFile() async throws {
        let context = container.mainContext
        var avatarWrites = 0
        let sut = AddCaregiverModel(saveAvatar: { _ in
            avatarWrites += 1
            return "avatar.jpg"
        }, deleteAvatar: { _ in })

        let outcome = await sut.save(name: "Ayşe", avatar: nil, in: context)

        #expect(outcome == .saved)
        #expect(avatarWrites == 0)
        let saved = try #require(try context.fetch(FetchDescriptor<Caregiver>()).first)
        #expect(saved.avatarURL == nil)
    }

    /// The sheet closes on this outcome, and the caregiver list shows the "photo did not save" note.
    @Test
    func aFailedAvatarWriteStillSavesTheCaregiverWithoutAnAvatar() async throws {
        let context = container.mainContext
        let sut = AddCaregiverModel(
            saveAvatar: { _ in throw PhotoSaveError.writeFailed(CocoaError(.fileWriteOutOfSpace)) },
            deleteAvatar: { _ in }
        )

        let outcome = await sut.save(name: "Ayşe", avatar: avatar, in: context)

        #expect(outcome == .savedWithoutAvatar)
        let saved = try #require(try context.fetch(FetchDescriptor<Caregiver>()).first)
        #expect(saved.name == "Ayşe")
        #expect(saved.avatarURL == nil)
        #expect(sut.isShowingSaveFailure == false)
    }

    /// The sheet stays open on this outcome, so nothing may stay staged for the retry to duplicate.
    @Test
    func aFailedCommitStagesNothingAndAsksForARetry() async throws {
        let context = container.mainContext
        let sut = AddCaregiverModel(
            saveAvatar: { _ in "avatar.jpg" },
            deleteAvatar: { _ in },
            saveContext: { _ in throw CommitFailure() }
        )

        let outcome = await sut.save(name: "Ayşe", avatar: avatar, in: context)

        #expect(outcome == nil)
        #expect(sut.isShowingSaveFailure)
        #expect(sut.isSaving == false)
        #expect(try context.fetch(FetchDescriptor<Caregiver>()).isEmpty)
    }

    @Test
    func aFailedCommitDeletesTheAvatarFileItWrote() async throws {
        let context = container.mainContext
        var deletedAvatars: [String] = []
        let sut = AddCaregiverModel(
            saveAvatar: { _ in "avatar.jpg" },
            deleteAvatar: { deletedAvatars.append($0) },
            saveContext: { _ in throw CommitFailure() }
        )

        _ = await sut.save(name: "Ayşe", avatar: avatar, in: context)

        #expect(deletedAvatars == ["avatar.jpg"])
    }

    @Test
    func aRetryAfterAFailedCommitSavesOneCaregiver() async throws {
        let context = container.mainContext
        var commitAttempts = 0
        let sut = AddCaregiverModel(
            saveAvatar: { _ in "avatar.jpg" },
            deleteAvatar: { _ in },
            saveContext: { context in
                commitAttempts += 1
                if commitAttempts == 1 {
                    throw CommitFailure()
                }
                try context.save()
            }
        )

        _ = await sut.save(name: "Ayşe", avatar: avatar, in: context)
        let retryOutcome = await sut.save(name: "Ayşe", avatar: avatar, in: context)

        #expect(retryOutcome == .saved)
        let caregivers = try context.fetch(FetchDescriptor<Caregiver>())
        #expect(caregivers.count == 1)
        #expect(caregivers.first?.avatarURL == "avatar.jpg")
    }

    /// A second tap while the first save waits on the avatar write must not start a second save.
    @Test
    func aSecondSaveWhileOneIsInFlightDoesNothing() async throws {
        let context = container.mainContext
        let (writeStarted, writeStartedContinuation) = AsyncStream.makeStream(of: Void.self)
        let (releaseWrite, releaseWriteContinuation) = AsyncStream.makeStream(of: Void.self)
        var avatarWrites = 0
        let sut = AddCaregiverModel(saveAvatar: { _ in
            avatarWrites += 1
            writeStartedContinuation.yield()
            for await _ in releaseWrite { break }
            return "avatar.jpg"
        }, deleteAvatar: { _ in })

        let firstSave = Task { await sut.save(name: "Ayşe", avatar: avatar, in: context) }
        for await _ in writeStarted { break }
        #expect(sut.isSaving)

        let secondOutcome = await sut.save(name: "Ayşe", avatar: avatar, in: context)
        releaseWriteContinuation.yield()
        let firstOutcome = await firstSave.value

        #expect(secondOutcome == nil)
        #expect(sut.isShowingSaveFailure == false)
        #expect(firstOutcome == .saved)
        #expect(avatarWrites == 1)
        #expect(try context.fetch(FetchDescriptor<Caregiver>()).count == 1)
    }

    @Test
    func aBlankNameSavesNothing() async throws {
        let context = container.mainContext
        let sut = AddCaregiverModel(saveAvatar: { _ in "avatar.jpg" }, deleteAvatar: { _ in })

        let outcome = await sut.save(name: "   ", avatar: avatar, in: context)

        #expect(outcome == nil)
        #expect(try context.fetch(FetchDescriptor<Caregiver>()).isEmpty)
    }
}
