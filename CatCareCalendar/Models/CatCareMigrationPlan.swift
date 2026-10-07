import Foundation
import SwiftData

/// The migration plan for the app's store.
///
/// V1 is the only version and `stages` is empty, because no build has written a
/// store under an earlier layout. The plan exists now so the next schema change
/// adds a version and a stage in one place, instead of introducing the whole
/// mechanism under time pressure.
enum CatCareMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CatCareSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
