import Foundation
import Observation
import os
import SwiftData
import UIKit

/// Saves the Add Caregiver sheet.
///
/// The avatar is written first, off the main actor, then the caregiver is committed:
/// - An avatar that cannot be written does not stop the caregiver: it is saved without one, and
///   `save` returns `.savedWithoutAvatar` so the caregiver list can say the photo did not save.
/// - A failed commit takes the staged caregiver back out of the shared context (a targeted delete,
///   not a `rollback()`), deletes the avatar file written for this attempt, and sets
///   `isShowingSaveFailure`. The sheet stays open, so Save can try again.
/// - While a save runs, another `save` returns `nil` at once, so a double tap writes one caregiver.
@MainActor
@Observable
final class AddCaregiverModel {
    enum Outcome: Equatable {
        case saved
        case savedWithoutAvatar
    }

    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Caregivers")

    private(set) var isSaving = false
    var isShowingSaveFailure = false

    @ObservationIgnored private let saveAvatar: (UIImage) async throws -> String
    @ObservationIgnored private let deleteAvatar: (String) -> Void
    @ObservationIgnored private let saveContext: (ModelContext) throws -> Void

    init(
        saveAvatar: @escaping (UIImage) async throws -> String = { try await CaregiverAvatarStore().save($0) },
        deleteAvatar: @escaping (String) -> Void = { CaregiverAvatarStore().delete($0) },
        saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.saveAvatar = saveAvatar
        self.deleteAvatar = deleteAvatar
        self.saveContext = saveContext
    }

    /// `nil` when nothing was saved: a blank name, a save already in flight, or a failed commit.
    func save(name: String, avatar: UIImage?, in context: ModelContext) async -> Outcome? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false, isSaving == false else { return nil }
        isSaving = true
        defer { isSaving = false }

        var avatarFileName: String?
        var outcome = Outcome.saved
        if let avatar {
            do {
                avatarFileName = try await saveAvatar(avatar)
            } catch {
                Self.logger.error("Caregiver avatar not saved: \(String(describing: error), privacy: .public)")
                outcome = .savedWithoutAvatar
            }
        }

        let caregiver = Caregiver(name: trimmedName, avatarURL: avatarFileName)
        context.insert(caregiver)
        do {
            try saveContext(context)
        } catch {
            Self.logger.error("Caregiver not saved: \(String(describing: error), privacy: .public)")
            context.delete(caregiver)
            if let avatarFileName {
                deleteAvatar(avatarFileName)
            }
            isShowingSaveFailure = true
            return nil
        }
        return outcome
    }
}
