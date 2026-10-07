import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct RepeatConfigurationTests {
    /// One persisted-schedule mapping case, kept as an explicitly typed value so the
    /// type-checker solves it once here instead of inside the `@Test` macro expansion.
    struct ScheduleMappingCase: Sendable {
        let frequency: CareTaskFrequency
        let interval: Int
        let customDays: Set<Int>
        let expectedUnit: RepeatConfiguration.Unit
        let expectedInterval: Int
        let expectedWeekdays: Set<Int>
    }

    nonisolated static let scheduleMappingCases: [ScheduleMappingCase] = [
        ScheduleMappingCase(
            frequency: .daily,
            interval: 1,
            customDays: [],
            expectedUnit: .day,
            expectedInterval: 1,
            expectedWeekdays: []
        ),
        ScheduleMappingCase(
            frequency: .weekly,
            interval: 3,
            customDays: [1, 5],
            expectedUnit: .week,
            expectedInterval: 3,
            expectedWeekdays: [1, 5]
        ),
        ScheduleMappingCase(
            frequency: .biweekly,
            interval: 1,
            customDays: [2, 4],
            expectedUnit: .week,
            expectedInterval: 2,
            expectedWeekdays: [2, 4]
        ),
        ScheduleMappingCase(
            frequency: .monthly,
            interval: 4,
            customDays: [],
            expectedUnit: .month,
            expectedInterval: 4,
            expectedWeekdays: []
        ),
        ScheduleMappingCase(
            frequency: .monthly,
            interval: 24,
            customDays: [],
            expectedUnit: .year,
            expectedInterval: 2,
            expectedWeekdays: []
        )
    ]

    @Test(arguments: RepeatConfigurationTests.scheduleMappingCases)
    func persistedScheduleMapsToExpectedUiConfiguration(_ mapping: ScheduleMappingCase) {
        let configuration = RepeatConfiguration.from(
            frequency: mapping.frequency,
            interval: mapping.interval,
            customDays: mapping.customDays
        )

        #expect(configuration.unit == mapping.expectedUnit)
        #expect(configuration.interval == mapping.expectedInterval)
        #expect(configuration.selectedWeekdays == mapping.expectedWeekdays)
    }

    @Test
    func weeklyConfigurationResolvesToSortedCustomDays() {
        let configuration = RepeatConfiguration(
            unit: .week,
            interval: 2,
            selectedWeekdays: [5, 1, 3]
        )

        let resolved = configuration.resolvedFrequency()

        #expect(resolved.frequency == .weekly)
        #expect(resolved.interval == 2)
        #expect(resolved.customDays == [1, 3, 5])
    }

    @Test
    func weeklyConfigurationDiscardsInvalidCustomDays() {
        let configuration = RepeatConfiguration(
            unit: .week,
            selectedWeekdays: [-1, 1, 6, 7, Int.max]
        )

        let resolved = configuration.resolvedFrequency()

        #expect(configuration.selectedWeekdays == [1, 6])
        #expect(resolved.customDays == [1, 6])
    }

    @Test
    func yearlyConfigurationResolvesToMonthlyFrequencyInTwelveMonthSteps() {
        let configuration = RepeatConfiguration(unit: .year, interval: 2)

        let resolved = configuration.resolvedFrequency()

        #expect(resolved.frequency == .monthly)
        #expect(resolved.interval == 24)
        #expect(resolved.customDays == nil)
    }

    @Test
    func intervalIsNormalizedToMinimumOfOne() {
        let configuration = RepeatConfiguration(unit: .day, interval: 0)

        #expect(configuration.interval == 1)
    }

    @Test
    func corruptOversizedIntervalsAreClampedAcrossMappingResolutionAndDisplay() {
        let mapped = RepeatConfiguration.from(
            frequency: .biweekly,
            interval: .max,
            customDays: []
        )
        var mutated = RepeatConfiguration(unit: .year)
        mutated.interval = .max

        let resolved = mutated.resolvedFrequency()
        let summary = mutated.localizedSummary()

        #expect(mapped.interval == Int(Int32.max))
        #expect(resolved.interval == Int(Int32.max))
        #expect(summary.isEmpty == false)
    }
}
