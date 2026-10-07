import Foundation
import SwiftData

/// The first named version of the persistent store layout.
///
/// The app has not shipped, so V1 is a baseline rather than the record of a past
/// release: it pins today's layout so a later change becomes a visible, testable
/// V2 plus a migration stage instead of a silent store rewrite.
///
/// Add a model type here only together with a new version. Never edit V1 after a
/// build reaches a store you must keep.
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

    /// The single, shared `Schema` instance for this version. Every caller that needs a
    /// `Schema` for this store layout should use this instead of constructing its own
    /// `Schema(versionedSchema: CatCareSchemaV1.self)`.
    static let schema = Schema(versionedSchema: CatCareSchemaV1.self)
}
