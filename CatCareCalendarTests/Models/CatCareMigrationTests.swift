import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

private final class FixtureBundleToken {}

/// Proves the V1 to V2 stage on a real on-disk store written with the frozen V1 models.
@Suite("Schema migration V1 to V2")
@MainActor
struct CatCareMigrationTests {
    private static let taskTitles = ["Daily Feeding", "Refresh Water", "Brush coat"]

    /// Writes a V1 store the way the shipped app left it: one cat, three tasks with a schedule each,
    /// three completions, and only the last completion still linked to the cat.
    private func writeVersionOneStore(at url: URL) throws {
        try SchemaBaselineHarness.open(url, schema: CatCareSchemaV1.self) { context in
            let cat = CatCareSchemaV1.Cat()
            cat.name = "Miso"
            let caregiver = CatCareSchemaV1.Caregiver()
            caregiver.name = "Primary Caregiver"
            context.insert(cat)
            context.insert(caregiver)

            for (index, title) in Self.taskTitles.enumerated() {
                let task = CatCareSchemaV1.CareTask()
                task.title = title
                let schedule = CatCareSchemaV1.CareTaskSchedule()
                let completion = CatCareSchemaV1.CareTaskCompletion()
                completion.notes = "done \(title)"
                context.insert(task)
                context.insert(schedule)
                context.insert(completion)

                task.assignedCats = [cat]
                task.assignedCaregiver = caregiver
                schedule.task = task
                completion.task = task
                completion.caregiver = caregiver
                if index == Self.taskTitles.count - 1 {
                    completion.cats = [cat]
                }
            }
            try context.save()
        }
    }

    @Test("A V1 store opens under V2 with every row, task link and surviving cat link")
    func versionOneStoreMigratesWithoutDataLoss() throws {
        try SchemaBaselineHarness.withStore { url in
            try writeVersionOneStore(at: url)

            try SchemaBaselineHarness.open(
                url,
                schema: CatCareSchemaV2.self,
                migrationPlan: CatCareMigrationPlan.self
            ) { context in
                let cats = try context.fetch(FetchDescriptor<Cat>())
                let tasks = try context.fetch(FetchDescriptor<CareTask>())
                let schedules = try context.fetch(FetchDescriptor<CareTaskSchedule>())
                let completions = try context.fetch(FetchDescriptor<CareTaskCompletion>())
                let caregivers = try context.fetch(FetchDescriptor<Caregiver>())
                #expect(cats.count == 1)
                #expect(tasks.count == 3)
                #expect(schedules.count == 3)
                #expect(completions.count == 3)
                #expect(caregivers.count == 1)

                let cat = try #require(cats.first)
                #expect(Set(cat.tasks.map(\.title)) == Set(Self.taskTitles))
                for task in tasks {
                    #expect(task.schedules.count == 1)
                    #expect(task.completions.count == 1)
                    #expect(task.assignedCats == [cat])
                    #expect(task.assignedCaregiver?.name == "Primary Caregiver")
                }
                for completion in completions {
                    #expect(completion.task?.completions.first == completion)
                    #expect(completion.caregiver?.name == "Primary Caregiver")
                }

                // The one completion that still had its cat keeps it. The two that had lost it stay
                // empty: the migration does not invent history (History falls back at read time).
                let withCat = completions.filter { $0.cats.isEmpty == false }
                #expect(withCat.map { $0.task?.title } == ["Brush coat"])
                #expect(withCat.first?.cats == [cat])
                #expect(cat.completions == withCat)
            }
        }
    }

    /// `PurrtineV1Store.sqlite` was written by the code on origin/main before schema V2 (see the PR
    /// body): the real V1 models and `TaskActionService`, not the frozen copies. The app calls
    /// `fatalError` when its container fails to open, so this proves a real shipped-layout store
    /// opens under V2 instead of crashing every launch.
    @Test("A store written by the pre-V2 app code opens under V2 and keeps its data")
    func realVersionOneStoreFixtureMigrates() throws {
        let fixture = try #require(
            Bundle(for: FixtureBundleToken.self).url(forResource: "PurrtineV1Store", withExtension: "sqlite")
        )
        try SchemaBaselineHarness.withStore { url in
            try FileManager.default.copyItem(at: fixture, to: url)

            try SchemaBaselineHarness.open(
                url,
                schema: CatCareSchemaV2.self,
                migrationPlan: CatCareMigrationPlan.self
            ) { context in
                let cats = try context.fetch(FetchDescriptor<Cat>())
                let tasks = try context.fetch(FetchDescriptor<CareTask>())
                let completions = try context.fetch(FetchDescriptor<CareTaskCompletion>())
                #expect(cats.map(\.name) == ["Miso"])
                #expect(tasks.count == 3)
                // 3 starting schedules plus one next occurrence per recurring completion.
                #expect(try context.fetch(FetchDescriptor<CareTaskSchedule>()).count == 7)
                #expect(try context.fetch(FetchDescriptor<Caregiver>()).count == 1)
                #expect(completions.count == 4)

                let cat = try #require(cats.first)
                #expect(Set(cat.tasks.map(\.title)) == Set(Self.taskTitles))
                #expect(completions.allSatisfy { $0.task != nil && $0.caregiver != nil })
                let completionsPerTask = Dictionary(grouping: completions, by: { $0.task?.title ?? "" })
                    .mapValues(\.count)
                #expect(completionsPerTask == ["Daily Feeding": 2, "Refresh Water": 1, "Brush coat": 1])

                // Only the newest completion still had its cat in the old store, and it still does.
                let withCat = completions.filter { $0.cats.isEmpty == false }
                #expect(withCat.count == 1)
                #expect(withCat.first?.cats == [cat])
                #expect(cat.completions == withCat)
            }
        }
    }

    @Test("Completions recorded after the migration all keep the cat")
    func completionsAfterMigrationKeepTheirCat() throws {
        try SchemaBaselineHarness.withStore { url in
            try writeVersionOneStore(at: url)

            try SchemaBaselineHarness.open(
                url,
                schema: CatCareSchemaV2.self,
                migrationPlan: CatCareMigrationPlan.self
            ) { context in
                let tasks = try context.fetch(FetchDescriptor<CareTask>())
                for task in tasks + tasks {
                    let completion = CareTaskCompletion()
                    completion.task = task
                    completion.cats = task.assignedCats
                    context.insert(completion)
                    try context.save()
                }
            }

            try SchemaBaselineHarness.open(
                url,
                schema: CatCareSchemaV2.self,
                migrationPlan: CatCareMigrationPlan.self
            ) { context in
                let completions = try context.fetch(FetchDescriptor<CareTaskCompletion>())
                let newOnes = completions.filter { $0.notes == nil }
                #expect(newOnes.count == 6)
                #expect(newOnes.allSatisfy { $0.cats.count == 1 })
            }
        }
    }
}
