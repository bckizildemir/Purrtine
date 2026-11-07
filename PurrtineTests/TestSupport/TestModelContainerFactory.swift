import SwiftData
@testable import Purrtine

enum TestModelContainerFactory {
    @MainActor
    static func makeInMemoryContainer() throws -> ModelContainer {
        // The model list lives in `CatCareSchemaV2` (the current version) so this container can
        // never drift from the app's real store layout. See `AppLaunchBootstrapper.makeModelContainer`.
        let schema = CatCareSchemaV2.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CatCareMigrationPlan.self,
            configurations: configuration
        )
    }
}
