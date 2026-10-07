import SwiftData
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct CaregiverBootstrapperTests {
    @Test
    func createsSinglePrimaryCaregiverAndIsIdempotent() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)

        let caregivers = try context.fetch(FetchDescriptor<Caregiver>())

        #expect(caregivers.count == 1)
        #expect(caregivers.first?.isPrimary == true)
        #expect(caregivers.first?.localizationKey == CaregiverBootstrapper.defaultCaregiverLocalizationKey)
    }
}
