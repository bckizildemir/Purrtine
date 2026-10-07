import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct PreviewDataTests {
    @Test(arguments: PreviewScenario.allCases)
    func createsEveryScenarioInMemory(scenario: PreviewScenario) throws {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let container = try PreviewData.makeContainer(
            for: scenario,
            referenceDate: referenceDate
        )
        let context = container.mainContext

        let cats = try context.fetch(FetchDescriptor<Cat>())
        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let schedules = try context.fetch(FetchDescriptor<CareTaskSchedule>())
        let completions = try context.fetch(FetchDescriptor<CareTaskCompletion>())
        let caregivers = try context.fetch(FetchDescriptor<Caregiver>())

        switch scenario {
        case .empty:
            #expect(cats.isEmpty)
            #expect(tasks.isEmpty)
            #expect(schedules.isEmpty)
            #expect(completions.isEmpty)
            #expect(caregivers.isEmpty)
        case .singleCat:
            #expect(cats.count == 1)
            #expect(tasks.isEmpty)
            #expect(caregivers.count == 1)
        case .standard:
            #expect(cats.count == 2)
            #expect(tasks.count == 4)
            #expect(schedules.count == 4)
            #expect(completions.count == 1)
        case .history:
            #expect(cats.count == 2)
            #expect(tasks.count == 8)
            #expect(completions.count == 5)
        case .longContent:
            #expect(cats.count == 2)
            #expect(tasks.count == 4)
            #expect(tasks.contains { $0.title.count > 40 })
        }
    }

    @Test("The preview container builds from the V1 schema")
    func previewContainerCarriesVersionOneEntities() throws {
        let container = try PreviewData.makeContainer(
            for: .empty,
            referenceDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

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
}
