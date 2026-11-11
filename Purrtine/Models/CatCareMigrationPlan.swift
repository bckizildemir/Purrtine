import Foundation
import SwiftData

/// The migration plan for the app's store.
///
/// V1 to V2 adds the `Cat.completions` inverse of `CareTaskCompletion.cats`. The stage
/// is lightweight: `CatCareMigrationTests` proves a V1 store keeps every row and link.
/// It does not restore cat links that V1 had already lost; `HistoryPresentation` covers
/// those at read time.
enum CatCareMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CatCareSchemaV1.self, CatCareSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: CatCareSchemaV1.self, toVersion: CatCareSchemaV2.self)]
    }
}
