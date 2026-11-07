import Foundation
import SwiftData

/// Frozen copies of the five model types as `CatCareSchemaV1` laid them out.
///
/// V2 changed `Cat` and `CareTaskCompletion`, so V1 can no longer point at the live
/// classes: it would describe V2's layout and the migration would have nothing to
/// migrate from. These copies hold stored properties only. Never edit them. They have
/// the same entity names as the live types (the `@Model` macro uses the unqualified
/// class name), and `SchemaBaselineTests.versionOneLayoutMatchesBaseline` proves the
/// layout is unchanged.
extension CatCareSchemaV1 {
    @Model
    final class Cat {
        var id: UUID
        var name: String
        var photoURLs: [String]
        var age: Int?
        var gender: Gender
        var breed: String?
        var weight: Double?
        var weightUnit: WeightUnit
        var medicalNotes: String?
        var medicalConditions: [String]
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade) var tasks: [CareTask] = []

        init() {
            id = UUID()
            name = ""
            photoURLs = []
            gender = .unknown
            weightUnit = .kg
            medicalConditions = []
            createdAt = Date()
            updatedAt = Date()
        }
    }

    @Model
    final class CareTask {
        var id: UUID
        var title: String
        var taskDescription: String?
        var category: CareTaskCategory
        var iconName: String
        var priority: CareTaskPriority
        var status: CareTaskStatus
        var isTemplate: Bool
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \CareTaskSchedule.task) var schedules: [CareTaskSchedule] = []
        @Relationship(deleteRule: .cascade, inverse: \CareTaskCompletion.task) var completions: [CareTaskCompletion] = []
        @Relationship(inverse: \Cat.tasks) var assignedCats: [Cat] = []
        @Relationship var assignedCaregiver: Caregiver?

        init() {
            id = UUID()
            title = ""
            category = .general
            iconName = "circle"
            priority = .medium
            status = .pending
            isTemplate = false
            createdAt = Date()
            updatedAt = Date()
        }
    }

    @Model
    final class CareTaskSchedule {
        var id: UUID
        var scheduledDate: Date
        var scheduledTime: Date?
        var frequency: CareTaskFrequency
        var frequencyInterval: Int
        var endDate: Date?
        var isActive: Bool
        var reminderMinutes: Int?
        var customDays: [Int]?
        var createdAt: Date

        @Relationship var task: CareTask?

        init() {
            id = UUID()
            scheduledDate = Date()
            frequency = .once
            frequencyInterval = 1
            isActive = true
            createdAt = Date()
        }
    }

    @Model
    final class CareTaskCompletion {
        #Index<CareTaskCompletion>([\.completedAt], [\.completedForDate])

        var id: UUID
        var completedAt: Date
        var completedForDate: Date
        var notes: String?
        var photoURLs: [String]
        var wasOnTime: Bool
        var completionDuration: TimeInterval?

        @Relationship var task: CareTask?
        @Relationship(deleteRule: .nullify) var cats: [Cat] = []
        @Relationship var caregiver: Caregiver?

        init() {
            id = UUID()
            completedAt = Date()
            completedForDate = Date()
            photoURLs = []
            wasOnTime = true
        }
    }

    @Model
    final class Caregiver {
        var id: UUID
        var name: String
        var avatarURL: String?
        var createdAt: Date
        var role: CaregiverRole
        var localizationKey: String?

        @Relationship(inverse: \CareTaskCompletion.caregiver)
        var completions: [CareTaskCompletion] = []

        init() {
            id = UUID()
            name = ""
            createdAt = Date()
            role = .member
        }
    }
}
