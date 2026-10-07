import Foundation
import SwiftData
@testable import CatCareCalendar

/// Opens and reopens a real on-disk SwiftData store so a schema change can be proved
/// safe before it ships. In-memory containers cannot show migration behaviour: they
/// never read a store that an earlier schema wrote.
///
/// Use `SchemaBaselineHarness.withStore` for one store per test. The harness deletes
/// the store directory when the test ends.
enum SchemaBaselineHarness {
    enum Failure: Error, CustomStringConvertible {
        case brokenRelationships([String])

        var description: String {
            switch self {
            case .brokenRelationships(let names):
                return "The reopened store lost these relationships: \(names.joined(separator: ", "))"
            }
        }

        /// The sorted names of the lost edges, or nil for a failure of another kind.
        /// A test asserts against this instead of it matches the case inline, so no
        /// unreachable `else` branch is needed. The switch is exhaustive on purpose:
        /// a second case added later breaks the build here, which is a louder signal
        /// than a runtime `Issue.record` in a branch that never runs.
        var brokenRelationshipNames: [String]? {
            switch self {
            case .brokenRelationships(let names):
                return names.sorted()
            }
        }
    }

    /// Values of every seeded model, captured before the store closes. The reopen
    /// assertions compare against these instead of against live model objects,
    /// which the closed container invalidates.
    struct Fixture: Equatable {
        var catName: String
        var catAge: Int?
        var catMedicalConditions: [String]
        var caregiverName: String
        var caregiverRole: CaregiverRole
        var taskTitle: String
        var taskCategory: CareTaskCategory
        var taskStatus: CareTaskStatus
        var scheduleFrequency: CareTaskFrequency
        var scheduleReminderMinutes: Int?
        var scheduleCustomDays: [Int]?
        var completionNotes: String?
        var completionPhotoURLs: [String]
    }

    static let referenceFixture = Fixture(
        catName: "Schema Baseline Cat",
        catAge: 42,
        catMedicalConditions: ["asthma", "allergy"],
        caregiverName: "Schema Baseline Caregiver",
        caregiverRole: .primary,
        taskTitle: "Schema Baseline Task",
        taskCategory: .medication,
        taskStatus: .pending,
        scheduleFrequency: .weekly,
        scheduleReminderMinutes: 15,
        scheduleCustomDays: [1, 3, 5],
        completionNotes: "Schema baseline completion",
        completionPhotoURLs: ["baseline-photo.jpg"]
    )

    /// Runs `body` with a private store directory, then removes it.
    static func withStore<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaBaseline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory.appendingPathComponent("store.sqlite", isDirectory: false))
    }

    /// Opens the store at `url` with `schema`, hands a context to `body`, then drops
    /// the last reference to the container so the next `open` call reads what this one
    /// wrote.
    ///
    /// What carries the data between two calls is the SQLite write-ahead log, not a
    /// close. SwiftData publishes no `close()` on `ModelContainer`, so this helper
    /// cannot force a checkpoint, and the release of the container is not a documented
    /// flush point. A second container over the same URL reads the same log, which is
    /// why the pattern works. Keep `body` free of stored container references, or a
    /// later call can read a store that the previous one still holds open.
    static func open<Result>(
        _ url: URL,
        schema: any VersionedSchema.Type,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
        body: (ModelContext) throws -> Result
    ) throws -> Result {
        let resolvedSchema = Schema(versionedSchema: schema)
        let configuration = ModelConfiguration(schema: resolvedSchema, url: url)
        let container = try ModelContainer(
            for: resolvedSchema,
            migrationPlan: migrationPlan,
            configurations: configuration
        )
        let context = ModelContext(container)
        return try body(context)
    }

    /// Inserts one instance of every model type, with every relationship wired.
    static func seed(_ fixture: Fixture = referenceFixture, into context: ModelContext) throws {
        let cat = Cat(
            name: fixture.catName,
            age: fixture.catAge,
            gender: .female,
            medicalConditions: fixture.catMedicalConditions
        )
        let caregiver = Caregiver(name: fixture.caregiverName, role: fixture.caregiverRole)
        let task = CareTask(
            title: fixture.taskTitle,
            category: fixture.taskCategory,
            status: fixture.taskStatus
        )
        let schedule = CareTaskSchedule(
            scheduledDate: Date(timeIntervalSince1970: 1_700_000_000),
            frequency: fixture.scheduleFrequency,
            reminderMinutes: fixture.scheduleReminderMinutes,
            customDays: fixture.scheduleCustomDays
        )
        let completion = CareTaskCompletion(
            completedAt: Date(timeIntervalSince1970: 1_700_003_600),
            notes: fixture.completionNotes,
            photoURLs: fixture.completionPhotoURLs
        )

        context.insert(cat)
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        context.insert(completion)

        task.assignedCats = [cat]
        task.assignedCaregiver = caregiver
        schedule.task = task
        completion.task = task
        completion.cats = [cat]
        completion.caregiver = caregiver

        try context.save()
    }

    /// Reopens the store at `url` under the V1 schema and the migration plan, then
    /// reads the fixture back. This is the "second open" that every store test needs.
    static func reopenFixture(at url: URL) throws -> Fixture? {
        try open(
            url,
            schema: CatCareSchemaV1.self,
            migrationPlan: CatCareMigrationPlan.self
        ) { context in
            try readFixture(from: context)
        }
    }

    /// Reads the seeded row of every model type back out of `context`.
    /// Returns nil when any model type or relationship is missing.
    static func readFixture(from context: ModelContext) throws -> Fixture? {
        guard let cat = try context.fetch(FetchDescriptor<Cat>()).first,
              let caregiver = try context.fetch(FetchDescriptor<Caregiver>()).first,
              let task = try context.fetch(FetchDescriptor<CareTask>()).first,
              let schedule = try context.fetch(FetchDescriptor<CareTaskSchedule>()).first,
              let completion = try context.fetch(FetchDescriptor<CareTaskCompletion>()).first else {
            return nil
        }

        // A lost relationship is data loss too. Throw with the names of the broken
        // edges rather than report matching scalar values from a store whose graph
        // came back disconnected, and rather than collapse every cause into nil.
        let edges: [(String, Bool)] = [
            ("CareTask.assignedCats", task.assignedCats.first == cat),
            ("CareTask.assignedCaregiver", task.assignedCaregiver == caregiver),
            ("CareTask.schedules", task.schedules.first == schedule),
            ("CareTask.completions", task.completions.first == completion),
            ("CareTaskSchedule.task", schedule.task == task),
            ("CareTaskCompletion.task", completion.task == task),
            ("CareTaskCompletion.cats", completion.cats.first == cat),
            ("CareTaskCompletion.caregiver", completion.caregiver == caregiver),
            ("Cat.tasks", cat.tasks.first == task),
            ("Caregiver.completions", caregiver.completions.first == completion)
        ]
        let brokenEdges = edges.filter { $0.1 == false }.map(\.0)
        guard brokenEdges.isEmpty else {
            throw Failure.brokenRelationships(brokenEdges)
        }

        return Fixture(
            catName: cat.name,
            catAge: cat.age,
            catMedicalConditions: cat.medicalConditions,
            caregiverName: caregiver.name,
            caregiverRole: caregiver.role,
            taskTitle: task.title,
            taskCategory: task.category,
            taskStatus: task.status,
            scheduleFrequency: schedule.frequency,
            scheduleReminderMinutes: schedule.reminderMinutes,
            scheduleCustomDays: schedule.customDays,
            completionNotes: completion.notes,
            completionPhotoURLs: completion.photoURLs
        )
    }

    /// Renders a stable text description of everything `Schema` reflects about a
    /// version's entities: attribute names, types and options, relationship names,
    /// destinations, inverses, delete rules and cardinality, plus the indexes and
    /// uniqueness constraints of each entity. Two schemas that produce the same text
    /// describe the same store layout, as far as `Schema` surfaces it.
    ///
    /// Coverage stops where `Schema.Entity` stops, and stops again at the type level.
    /// It does not read `defaultValue`, `originalName`, `hashModifier`,
    /// `minimumModelCount`, `maximumModelCount`, `relationship.options`,
    /// `versionIdentifier`, or entity inheritance, and it records an attribute's type
    /// by name only, so anything below the type level stays invisible - an enum case
    /// whose `rawValue` changes is the case that matters here, because that one does
    /// change the stored bytes. Treat the list as examples, not as a closed set.
    ///
    /// One reflection dependency remains on purpose. `attribute.valueType` has type
    /// `any Any.Type`, and the rendered text comes from `String(describing:)` on that
    /// metatype. Swift publishes no stable text contract for a metatype, and it offers
    /// no documented alternative, so this field cannot get the fixed-vocabulary
    /// treatment that `optionList(of:)` and `deleteRuleName(_:)` give their fields.
    /// It reads `Optional<String>` and `Array<String>` on both verified OS versions.
    /// A toolchain that changes metatype text breaks the literal with no model change.
    static func fingerprint(of schema: any VersionedSchema.Type) -> String {
        let resolved = Schema(versionedSchema: schema)
        return resolved.entities
            .sorted { $0.name < $1.name }
            .map(entityFingerprint)
            .joined(separator: "\n")
    }

    private static func entityFingerprint(_ entity: Schema.Entity) -> String {
        let attributes = entity.attributes
            .map { "\($0.name):\($0.valueType) options=\(optionList(of: $0))" }
            .sorted()
        let relationships = entity.relationships
            .map { relationship in
                let inverse = relationship.inverseName ?? "-"
                return "\(relationship.name)->\(relationship.destination)"
                    + " inverse=\(inverse) rule=\(deleteRuleName(relationship.deleteRule))"
                    + " toOne=\(relationship.isToOneRelationship)"
            }
            .sorted()
        // Property order within one index or one constraint is part of the layout,
        // so only the outer list is sorted.
        let indices = entity.indices
            .map { $0.joined(separator: "+") }
            .sorted()
        let uniquenessConstraints = entity.uniquenessConstraints
            .map { $0.joined(separator: "+") }
            .sorted()
        return ([entity.name]
            + attributes.map { "  attr \($0)" }
            + relationships.map { "  rel \($0)" }
            + indices.map { "  index \($0)" }
            + uniquenessConstraints.map { "  unique \($0)" })
            .joined(separator: "\n")
    }

    /// The whole vocabulary of delete rules this fingerprint records, mapped to fixed
    /// text owned by this file. This is the same treatment `optionList(of:)` gives an
    /// attribute option, and for the same reason: `"\(relationship.deleteRule)"` reads
    /// the default reflection text of `Schema.Relationship.DeleteRule`, and Swift
    /// publishes no stable text contract for that. `DeleteRule` declares neither
    /// `CustomStringConvertible` nor `CustomDebugStringConvertible` today, so the
    /// reflection text happens to equal the case name. A future SDK that adds a
    /// `description` would change the rendered line without any model change - the
    /// exact false alarm this test exists to prevent.
    ///
    /// `DeleteRule` is a non-frozen SDK enum, so a new case can arrive. That case
    /// renders the fixed token `unrecognisedDeleteRule` and FAILS
    /// `versionOneLayoutMatchesBaseline` loudly. The fix when it fires is to add the
    /// case below, then re-record the literal. The 4 names here match the case names
    /// and the raw values of the enum, so this mapping changes no recorded text.
    private static func deleteRuleName(_ rule: Schema.Relationship.DeleteRule) -> String {
        switch rule {
        case .noAction: return "noAction"
        case .nullify: return "nullify"
        case .cascade: return "cascade"
        case .deny: return "deny"
        @unknown default: return "unrecognisedDeleteRule"
        }
    }

    /// The whole vocabulary of attribute options this fingerprint records. Every name
    /// here is fixed text owned by this file, so the rendered line depends only on the
    /// model declarations - never on the SDK version, and never on an undocumented
    /// debug rendering.
    ///
    /// `Schema.Attribute.Option` is a struct of static factories, not an enum, so
    /// there are no cases to switch over. It is `Hashable`, so an identity comparison
    /// against each known value is the mapping. Enumerated from the installed
    /// `SwiftData.swiftinterface`, which is the iOS 27 SDK on this machine. `.codable`
    /// is left out on purpose: it is `@available(iOS 27, *)` and does not exist in the
    /// iOS 26.5 SDK, so naming it would break the build on a released Xcode, and no
    /// model declares it. An option outside this list is handled - see
    /// `optionList(of:)`.
    private static let knownAttributeOptions: [(name: String, option: Schema.Attribute.Option)] = [
        ("allowsCloudEncryption", .allowsCloudEncryption),
        ("ephemeral", .ephemeral),
        ("externalStorage", .externalStorage),
        ("preserveValueOnDeletion", .preserveValueOnDeletion),
        ("spotlight", .spotlight),
        ("unique", .unique)
    ]

    /// Renders an attribute's options as sorted names from `knownAttributeOptions`.
    /// Sorting removes the order SwiftData happens to report them in. An empty list
    /// still prints, which is what makes a later `.unique` or `.externalStorage` show
    /// up as a diff.
    ///
    /// This replaced `String(reflecting:)`. That form pinned the golden literal to an
    /// unspecified SDK detail: `Schema.Attribute.Option` publishes no documented text
    /// form, and iOS 26.5 rendered it differently from iOS 18.5, so the same models
    /// failed the baseline on one of the two OS versions this repo verifies on.
    ///
    /// Decision A - a `transformable` option is NOT part of the layout signature.
    /// SwiftData synthesises one for every collection-valued attribute on iOS 26 and
    /// later, and reports none on iOS 18. The developer did not write it, so a change
    /// in it does not mean the models changed, and recording it makes one set of
    /// models fingerprint two ways across the supported OS range - the exact false
    /// alarm this test exists to prevent. The declaration behind it is still covered:
    /// the collection shows up in `valueType`, as `Array<String>` and
    /// `Optional<Array<Int>>`. The price, stated plainly: an explicitly declared
    /// `@Attribute(.transformable(by:))`, and a change of its transformer, are both
    /// invisible here, because `Schema` offers no way to tell a declared transformable
    /// from a synthesised one. No model in this repo declares one.
    ///
    /// Decision B - an option outside `knownAttributeOptions` renders the fixed token
    /// `unrecognisedOption`. So a future SDK option FAILS
    /// `versionOneLayoutMatchesBaseline` loudly instead of rendering as empty, and the
    /// failure text still carries no SDK string. The token is deliberately not
    /// specific: it says "an option arrived that this mapping does not know", not
    /// which one. The fix when it fires is to add the case above, then re-record the
    /// literal. A `fatalError` was the alternative and is worse here: a loud red test
    /// reports the same fact without taking down the rest of the suite.
    ///
    /// THE RULE: an option is dropped ONLY when it equals a transformable value this
    /// file constructs itself. Everything else renders `unrecognisedOption`. There is
    /// no counting, no budget, and no sample.
    ///
    /// Two earlier forms of this function were weaker, and both are worth recording so
    /// neither returns.
    ///
    /// The first counted. It discarded the first unrecognised option whenever
    /// `attribute.isTransformable` was true, and never checked which option it had
    /// discarded. So `.compressed` on `Cat.photoURLs` arrived as the single
    /// unrecognised option, the count said "one, as expected", and the option vanished.
    ///
    /// The second derived the drop set from a sample: a probe model with no declared
    /// options, whose reported options were treated as synthesised. That was WORSE than
    /// the token in 3 ways, and it was a regression. A runtime that attaches a second
    /// option, say `.codable`, to collection attributes attaches it to the probe too,
    /// so the probe authorises the drop and a real change in stored bytes disappears. A
    /// new option on a scalar attribute such as `Cat.name` was authorised the same way,
    /// where the plain token had failed loudly. A runtime reporting both a transformable
    /// and a second option had both dropped. A sample cannot tell "the SDK added this"
    /// from "the SDK added this and it matters".
    ///
    /// Inverting the rule removes all 3. The drop set is now closed and written here.
    private static func optionList(of attribute: Schema.Attribute) -> String {
        var names: [String] = []
        for option in attribute.options {
            if let known = knownAttributeOptions.first(where: { $0.option == option }) {
                names.append(known.name)
            } else if isConstructedTransformable(option) {
                // Identified as the transformable, by value, against a candidate this
                // file built. Not part of the layout signature: the developer did not
                // write it.
                continue
            } else {
                names.append("unrecognisedOption")
            }
        }
        return "[" + names.sorted().joined(separator: ",") + "]"
    }

    /// The rendered option text of `attribute`, exposed so a test can assert that no
    /// V1 attribute reports an option this harness cannot identify. The golden literal
    /// catches that too, but only while nobody re-records the literal with the token
    /// baked into it.
    static func renderedOptions(of attribute: Schema.Attribute) -> String {
        optionList(of: attribute)
    }

    /// The CLASS name of the transformer, which is not the name SwiftData uses. Kept
    /// only so the candidate list also covers a runtime that builds its option from the
    /// class name. Note the `Transformer` suffix, and see `transformableCandidates`.
    private static let secureUnarchiveTransformerClassName = "NSSecureUnarchiveFromDataTransformer"

    /// The transformable options this file can construct, and therefore the only
    /// options `optionList(of:)` is allowed to drop.
    ///
    /// MEASURED, not assumed. The option SwiftData synthesises for a collection-valued
    /// attribute carries the REGISTERED transformer name `NSSecureUnarchiveFromData`,
    /// WITHOUT the `Transformer` suffix. Resolved against live SwiftData on macOS
    /// 26.5.1.
    ///
    /// So exactly one of the 3 candidates below matches on iOS 26: the
    /// `NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue` form.
    /// The by-type form and the class-name form do not match. Both of those carry the
    /// class name `NSSecureUnarchiveFromDataTransformer` and are equal to each other, so
    /// together they contribute 1 distinct value, and it is the wrong one. A list of the
    /// 2 of them alone is what turned the iOS 26.5 run red on all 4 collection
    /// attributes while iOS 18.5 stayed green.
    ///
    /// With all 3 present, the reported run is green on both legs. On iOS 18 no such
    /// option is synthesised, so no candidate is consulted there.
    ///
    /// All 3 stay. The 2 that do not match cost nothing and they cover a runtime that
    /// builds its option from the class name instead. Read the list as a list of forms,
    /// not as a list of distinct values.
    ///
    /// Chosen over a `debugDescription` comparison on purpose. `Option` does conform to
    /// `CustomDebugStringConvertible`, and matching on that text would identify any
    /// transformable form, including this one, with no candidate list at all. But that
    /// text is an undocumented SDK rendering, and a dependence on exactly that kind of
    /// text is the defect this whole function was written to remove. A constructed value
    /// is worse at coverage and better at stability. When it misses, it misses loudly
    /// and a run says which form arrived, which is how the third candidate was found.
    private static let transformableCandidates: [Schema.Attribute.Option] = [
        .transformable(by: NSSecureUnarchiveFromDataTransformer.self),
        .transformable(by: secureUnarchiveTransformerClassName),
        .transformable(by: NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue)
    ]

    /// A linear `==` search, deliberately not a `Set` and not a hash lookup. A set
    /// membership test would rest on `hash(into:)` being consistent with `==` for
    /// `Option`, and nothing published states that. `==` alone is the smaller
    /// dependency, and 3 candidates make the cost irrelevant.
    ///
    /// On iOS 26 the match is the registered-name form, `NSSecureUnarchiveFromData`.
    /// The other 2 candidates never match on that runtime, so this search reads all 3
    /// entries for every synthesised option, and that is still 3 comparisons.
    ///
    /// A future SDK that uses a transformable form no candidate can construct makes
    /// this return false, so the token fires and the baseline goes red. That is the
    /// correct direction, and nothing here suppresses it.
    private static func isConstructedTransformable(_ option: Schema.Attribute.Option) -> Bool {
        for candidate in transformableCandidates where candidate == option {
            return true
        }
        return false
    }

    /// Every relationship of every entity in `schema`, each paired with its entity
    /// name. Sorted the same way `attributes(of:)` sorts.
    ///
    /// Exists so a test can prove the delete-rule check had relationships to inspect.
    /// A schema with no relationships renders no `rule=` field at all, so a search for
    /// `unrecognisedDeleteRule` over the rendered layout would pass vacuously.
    static func relationships(
        of schema: any VersionedSchema.Type
    ) -> [(entity: String, relationship: Schema.Relationship)] {
        Schema(versionedSchema: schema).entities
            .sorted { $0.name < $1.name }
            .flatMap { entity in
                entity.relationships
                    .sorted { $0.name < $1.name }
                    .map { (entity: entity.name, relationship: $0) }
            }
    }

    /// Every attribute of every entity in `schema`, each paired with its entity name.
    /// Sorted by entity name, then by attribute name, so a failure names one attribute
    /// and the order does not move between runs.
    static func attributes(
        of schema: any VersionedSchema.Type
    ) -> [(entity: String, attribute: Schema.Attribute)] {
        Schema(versionedSchema: schema).entities
            .sorted { $0.name < $1.name }
            .flatMap { entity in
                entity.attributes
                    .sorted { $0.name < $1.name }
                    .map { (entity: entity.name, attribute: $0) }
            }
    }
}
