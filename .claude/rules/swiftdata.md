---
paths:
  - "Purrtine/**/*.swift"
  - "PurrtineTests/**/*.swift"
---

# SwiftData conventions

- `@Query` is used only inside SwiftUI views; non-view code (services, view models) fetches via `ModelContext` + `FetchDescriptor`.
- Relationships use explicit delete rules (`.cascade`/`.nullify`) and explicit `inverse:` keys — check existing model definitions before adding new relationships.
- The store layout is versioned. `Models/CatCareSchemaV1.swift` (`VersionedSchema`) pins the first layout through frozen model copies in `Models/CatCareSchemaV1Models.swift`; `Models/CatCareSchemaV2.swift` is the current version and uses the live model types; `Models/CatCareMigrationPlan.swift` is the `SchemaMigrationPlan` (V1 to V2 is lightweight, proved by `CatCareMigrationTests`). `AppLaunchBootstrapper`, `PreviewData` and `TestModelContainerFactory` build their container from `CatCareSchemaV2`. Add or change a model type only together with a new schema version (freeze the old live models as nested copies first) — never edit an old version.
- Filter and sort as close to the query boundary as possible. Prefer explicit saves when correctness matters instead of relying on autosave timing.
- `PurrtineTests/Models/SchemaBaselineTests.swift` pins the V1 store layout with a recorded fingerprint. If a model change makes it fail, that is the point: add a schema version, do not re-record the fingerprint to make the test pass.
