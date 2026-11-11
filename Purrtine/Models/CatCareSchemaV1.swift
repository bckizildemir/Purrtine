import Foundation
import SwiftData

/// The first named version of the persistent store layout.
///
/// V1 describes the store as the first builds wrote it. Its models are the frozen
/// copies in `CatCareSchemaV1Models.swift`, not the live types, so a later change to a
/// live model cannot rewrite V1. The one deliberate difference from V2: V1's
/// `CareTaskCompletion.cats` has no inverse on `Cat`.
///
/// Never edit V1 or its frozen models.
enum CatCareSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Cat.self,
            CareTask.self,
            CareTaskSchedule.self,
            CareTaskCompletion.self,
            Caregiver.self
        ]
    }

    /// The shared `Schema` instance for this version.
    static let schema = Schema(versionedSchema: CatCareSchemaV1.self)
}
