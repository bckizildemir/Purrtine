import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

/// Deliberately NOT `.serialized`. Three of these tests build a real on-disk
/// `ModelContainer` over the V1 schema, but `SchemaBaselineHarness.withStore` gives
/// each one its own UUID directory, so no two tests share a file. No flaky run has
/// been measured here. Add `.serialized` when a run shows a false red, and record the
/// run that showed it - not before.
@Suite("Schema baseline")
@MainActor
struct SchemaBaselineTests {
    @Test("An on-disk store written under V1 reopens under the migration plan with no data loss")
    func versionedStoreReopensWithoutDataLoss() throws {
        try SchemaBaselineHarness.withStore { url in
            try SchemaBaselineHarness.open(url, schema: CatCareSchemaV1.self) { context in
                try SchemaBaselineHarness.seed(into: context)
            }

            let fixture = try #require(try SchemaBaselineHarness.reopenFixture(at: url))
            #expect(fixture == SchemaBaselineHarness.referenceFixture)
        }
    }

    @Test("The harness returns nil when the reopened store holds no rows")
    func harnessReturnsNilForEmptyStore() throws {
        try SchemaBaselineHarness.withStore { url in
            let readBack = try SchemaBaselineHarness.reopenFixture(at: url)
            #expect(readBack == nil)
        }
    }

    @Test("The harness names the lost edges when a reopened store keeps its rows but loses a relationship")
    func harnessNamesBrokenRelationships() throws {
        try SchemaBaselineHarness.withStore { url in
            try SchemaBaselineHarness.open(url, schema: CatCareSchemaV1.self) { context in
                try SchemaBaselineHarness.seed(into: context)
            }

            // Every row survives; only the task edge of the schedule goes away. Matching
            // scalars alone would call this store intact, so the throw is the only signal.
            //
            // This open carries the migration plan, exactly as `reopenFixture` does.
            // The seed open above deliberately does not: it stands for the version that
            // shipped and wrote the store. Every open after that one is a reopen, and a
            // reopen in production always runs the plan.
            try SchemaBaselineHarness.open(
                url,
                schema: CatCareSchemaV1.self,
                migrationPlan: CatCareMigrationPlan.self
            ) { context in
                let schedule = try #require(try context.fetch(FetchDescriptor<CareTaskSchedule>()).first)
                schedule.task = nil
                try context.save()
            }

            // `#require(throws:)` returns the error itself and stops the test here on a
            // store that came back intact. The older `#expect(throws:)` plus a second
            // `#require` reported one fault as two failures.
            let failure = try #require(throws: SchemaBaselineHarness.Failure.self) {
                try SchemaBaselineHarness.reopenFixture(at: url)
            }

            // Pinned as an exact list, not two `contains` checks: a store that lost
            // every edge would satisfy `contains` too, and the point of this test is
            // that the other eight edges survived.
            //
            // `brokenRelationshipNames` sorts the list and returns nil for a failure of
            // another kind, so no unreachable `else` branch is needed here. A second
            // `Failure` case added later breaks the build inside that property, which
            // is louder than a runtime check in a branch that never runs.
            #expect(failure.brokenRelationshipNames == ["CareTask.schedules", "CareTaskSchedule.task"])
        }
    }

    /// Guards the one thing that can now go wrong in the option text.
    ///
    /// Neither escape token may appear anywhere in the rendered layout.
    ///
    /// `SchemaBaselineHarness` owns 2 tokens. `unrecognisedOption` fires for an
    /// attribute option it cannot name and cannot identify as the transformable.
    /// `unrecognisedDeleteRule` fires for a `DeleteRule` case it cannot name. Each one
    /// says "something arrived that this mapping does not cover".
    ///
    /// The golden literal already fails when a token appears. That is not enough. The
    /// comment above the literal tells a person to re-record it from a failing run, and
    /// a person who re-records without extending the mapping bakes the token into the
    /// literal. The baseline then passes forever over the thing nobody identified. This
    /// test blocks that path for both tokens, whatever the literal says.
    ///
    /// The attribute loop runs per attribute so a failure names the offender. The
    /// fingerprint check covers the relationship side, where the delete-rule token
    /// lives.
    ///
    /// A loop, not `@Test(arguments:)`, on purpose. The argument list would come from
    /// the schema under test, so the reported test count would track the number of
    /// attributes and move on every model change. One test with a named failure per
    /// attribute gives the same diagnosis and a stable count.
    @Test("No V1 attribute or relationship reports something the harness cannot identify")
    func everyVersionOneOptionIsIdentified() throws {
        let attributes = SchemaBaselineHarness.attributes(of: CatCareSchemaV1.self)

        // Without this the loop below asserts nothing when the enumeration returns
        // empty, and an empty pass reads exactly like a clean one.
        try #require(!attributes.isEmpty)
        let coveredEntities = Set(attributes.map(\.entity)).sorted()
        #expect(
            coveredEntities == [
                "CareTask",
                "CareTaskCompletion",
                "CareTaskSchedule",
                "Caregiver",
                "Cat"
            ],
            "The attribute enumeration reached \(coveredEntities), not all 5 V1 entities"
        )

        for (entityName, attribute) in attributes {
            let rendered = SchemaBaselineHarness.renderedOptions(of: attribute)
            #expect(
                !rendered.contains("unrecognisedOption"),
                """
                \(entityName).\(attribute.name) rendered \(rendered). An option \
                arrived that knownAttributeOptions does not name and that \
                transformableCandidates cannot construct. Extend one of those two, \
                then re-record the literal. Never re-record the token itself.
                """
            )
        }

        // The delete-rule token has no per-attribute seam, so read it off the whole
        // rendered layout. The rationale is the same one the option token gets.
        //
        // A schema with no relationships renders no `rule=` field, so the search below
        // would pass on a layout that never carried a delete rule at all. Prove there
        // was something to inspect first.
        let relationships = SchemaBaselineHarness.relationships(of: CatCareSchemaV1.self)
        try #require(!relationships.isEmpty)

        let fingerprint = SchemaBaselineHarness.fingerprint(of: CatCareSchemaV1.self)
        #expect(
            !fingerprint.contains("unrecognisedDeleteRule"),
            """
            The rendered layout carries unrecognisedDeleteRule, so a DeleteRule case \
            arrived that SchemaBaselineHarness.deleteRuleName(_:) does not name. \
            Extend that mapping, then re-record the literal. Never re-record the \
            token itself.
            """
        )
    }

    @Test("The V1 schema layout matches the recorded baseline")
    func versionOneLayoutMatchesBaseline() {
        #expect(SchemaBaselineHarness.fingerprint(of: CatCareSchemaV1.self) == Self.versionOneFingerprint)
    }

    @Test("The app builds its container from the V1 schema")
    func appContainerCarriesVersionOneEntities() throws {
        let configuration = AppLaunchConfiguration(
            arguments: [],
            environment: ["CATCARE_UNIT_TESTING": "1"]
        )
        let container = try AppLaunchBootstrapper.makeModelContainer(using: configuration)

        let entityNames = container.schema.entities.map(\.name).sorted()

        #expect(
            entityNames == [
                "CareTask",
                "CareTaskCompletion",
                "CareTaskSchedule",
                "Caregiver",
                "Cat"
            ]
        )
    }

    @Test("The test factory builds its container from the V1 schema")
    @MainActor func testFactoryCarriesVersionOneEntities() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()

        let entityNames = container.schema.entities.map(\.name).sorted()

        #expect(
            entityNames == [
                "CareTask",
                "CareTaskCompletion",
                "CareTaskSchedule",
                "Caregiver",
                "Cat"
            ]
        )
    }

    /// Recorded from `SchemaBaselineHarness.fingerprint(of: CatCareSchemaV1.self)` on
    /// a real run, by making this expectation fail and copying the value out of the
    /// failure message. Recorded on iPhone 12 / iOS 26.5 and verified unchanged on
    /// iPhone 12 / iOS 18.5, which are the two destinations CLAUDE.md verifies on.
    ///
    /// A diff here means the store layout changed. That needs a new `VersionedSchema`
    /// and a `MigrationStage`, not an edit to this literal. There are two exceptions,
    /// and both are escape tokens that the harness owns:
    ///
    /// - `unrecognisedOption` means a newer SDK reported an attribute option that
    ///   `SchemaBaselineHarness.knownAttributeOptions` does not name yet.
    /// - `unrecognisedDeleteRule` means a newer SDK added a `DeleteRule` case that
    ///   `SchemaBaselineHarness.deleteRuleName(_:)` does not name yet.
    ///
    /// Extend the mapping the token points at first. Then re-record the whole literal
    /// from a failing run.
    static let versionOneFingerprint = """
    CareTask
      attr category:CareTaskCategory options=[]
      attr createdAt:Date options=[]
      attr iconName:String options=[]
      attr id:UUID options=[]
      attr isTemplate:Bool options=[]
      attr priority:CareTaskPriority options=[]
      attr status:CareTaskStatus options=[]
      attr taskDescription:Optional<String> options=[]
      attr title:String options=[]
      attr updatedAt:Date options=[]
      rel assignedCaregiver->Caregiver inverse=- rule=nullify toOne=true
      rel assignedCats->Cat inverse=tasks rule=nullify toOne=false
      rel completions->CareTaskCompletion inverse=task rule=cascade toOne=false
      rel schedules->CareTaskSchedule inverse=task rule=cascade toOne=false
    CareTaskCompletion
      attr completedAt:Date options=[]
      attr completedForDate:Date options=[]
      attr completionDuration:Optional<Double> options=[]
      attr id:UUID options=[]
      attr notes:Optional<String> options=[]
      attr photoURLs:Array<String> options=[]
      attr wasOnTime:Bool options=[]
      rel caregiver->Caregiver inverse=completions rule=nullify toOne=true
      rel cats->Cat inverse=- rule=nullify toOne=false
      rel task->CareTask inverse=completions rule=nullify toOne=true
      index binary+completedAt
      index binary+completedForDate
    CareTaskSchedule
      attr createdAt:Date options=[]
      attr customDays:Optional<Array<Int>> options=[]
      attr endDate:Optional<Date> options=[]
      attr frequency:CareTaskFrequency options=[]
      attr frequencyInterval:Int options=[]
      attr id:UUID options=[]
      attr isActive:Bool options=[]
      attr reminderMinutes:Optional<Int> options=[]
      attr scheduledDate:Date options=[]
      attr scheduledTime:Optional<Date> options=[]
      rel task->CareTask inverse=schedules rule=nullify toOne=true
    Caregiver
      attr avatarURL:Optional<String> options=[]
      attr createdAt:Date options=[]
      attr id:UUID options=[]
      attr localizationKey:Optional<String> options=[]
      attr name:String options=[]
      attr role:CaregiverRole options=[]
      rel completions->CareTaskCompletion inverse=caregiver rule=nullify toOne=false
    Cat
      attr age:Optional<Int> options=[]
      attr breed:Optional<String> options=[]
      attr createdAt:Date options=[]
      attr gender:Gender options=[]
      attr id:UUID options=[]
      attr medicalConditions:Array<String> options=[]
      attr medicalNotes:Optional<String> options=[]
      attr name:String options=[]
      attr photoURLs:Array<String> options=[]
      attr updatedAt:Date options=[]
      attr weight:Optional<Double> options=[]
      attr weightUnit:WeightUnit options=[]
      rel tasks->CareTask inverse=assignedCats rule=cascade toOne=false
    """
}
