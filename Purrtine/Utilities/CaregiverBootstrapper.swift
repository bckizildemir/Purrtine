import Foundation
import SwiftData

// MARK: - Caregiver Bootstrapper
/// Ensures a default caregiver exists at app launch to prevent crashes when creating tasks
enum CaregiverBootstrapper {
    /// Localization key persisted on the default caregiver so its display name follows the app language.
    /// Persisted as data, so it must stay a raw key string rather than a generated symbol.
    static let defaultCaregiverLocalizationKey = "tasks.config.myself"

    static func ensureDefaultCaregiverExists(in context: ModelContext) {
        // Check if any caregivers exist
        let descriptor = FetchDescriptor<Caregiver>()
        
        do {
            let existingCaregivers = try context.fetch(descriptor)
            if !existingCaregivers.isEmpty {
                return
            }
        } catch {
            print("Error fetching caregivers: \(error.localizedDescription)")
            // Continue to create default caregiver even if fetch fails
        }
        
        // Create localized default caregiver
        let defaultCaregiver = Caregiver(
            name: String(localized: .tasksConfigMyself),
            role: .primary,
            localizationKey: Self.defaultCaregiverLocalizationKey
        )
        context.insert(defaultCaregiver)
        
        do {
            try context.save()
            print("Default caregiver created: \(defaultCaregiver.displayName)")
        } catch {
            print("Error saving default caregiver: \(error.localizedDescription)")
        }
    }
}

