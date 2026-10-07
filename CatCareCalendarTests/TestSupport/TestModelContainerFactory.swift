import SwiftData
@testable import CatCareCalendar

enum TestModelContainerFactory {
    @MainActor
    static func makeInMemoryContainer() throws -> ModelContainer {
        // The model list lives in `CatCareSchemaV1` so this container can never drift
        // from the app's real store layout. See `AppLaunchBootstrapper.makeModelContainer`.
        let schema = CatCareSchemaV1.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CatCareMigrationPlan.self,
            configurations: configuration
        )
    }
}
