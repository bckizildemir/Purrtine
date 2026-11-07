import Foundation
import SwiftData

/// The current store layout. It uses the live model types.
///
/// V2 gives `CareTaskCompletion.cats` an inverse, `Cat.completions`. Without it, SwiftData
/// kept one cat link per cat across all completions: a new completion naming a cat took
/// the cat away from every older completion. See `CompletionCatsRelationshipTests`.
///
/// Every caller that needs the current `Schema` uses `CatCareSchemaV2.schema`.
enum CatCareSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Cat.self,
            CareTask.self,
            CareTaskSchedule.self,
            CareTaskCompletion.self,
            Caregiver.self
        ]
    }

    static let schema = Schema(versionedSchema: CatCareSchemaV2.self)
}
