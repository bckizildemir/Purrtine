import Foundation

/// Describes the repeat configuration the user can customize from the UI.
struct RepeatConfiguration: Equatable {
    private static let maximumInterval = Int(Int32.max)

    enum Unit: String, CaseIterable, Identifiable {
        case day
        case week
        case month
        case year
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .day: return String(localized: .repeatUnitDay)
            case .week: return String(localized: .repeatUnitWeek)
            case .month: return String(localized: .repeatUnitMonth)
            case .year: return String(localized: .repeatUnitYear)
            }
        }
        
        var localizedSingular: String {
            switch self {
            case .day: return String(localized: .repeatUnitDay)
            case .week: return String(localized: .repeatUnitWeek)
            case .month: return String(localized: .repeatUnitMonth)
            case .year: return String(localized: .repeatUnitYear)
            }
        }
        
        var localizedPlural: String {
            switch self {
            case .day: return String(localized: .repeatUnitDays)
            case .week: return String(localized: .repeatUnitWeeks)
            case .month: return String(localized: .repeatUnitMonths)
            case .year: return String(localized: .repeatUnitYears)
            }
        }
        
        /// Maps the UI unit to the schedule frequency enum we persist.
        var mappedFrequency: CareTaskFrequency {
            switch self {
            case .day: return .daily
            case .week: return .weekly
            case .month: return .monthly
            case .year: return .monthly // Stored as monthly with 12 * interval
            }
        }
    }
    
    var unit: Unit
    var interval: Int
    var selectedWeekdays: Set<Int> = [] // Applies only to weekly schedules
    
    init(unit: Unit = .day, interval: Int = 1, selectedWeekdays: Set<Int> = []) {
        self.unit = unit
        self.interval = Self.normalizedInterval(interval)
        self.selectedWeekdays = Self.validWeekdays(from: selectedWeekdays)
    }
    
    /// Builds a configuration from persisted schedule values.
    static func from(frequency: CareTaskFrequency, interval: Int, customDays: Set<Int>) -> RepeatConfiguration {
        switch frequency {
        case .daily:
            return RepeatConfiguration(unit: .day, interval: max(1, interval))
        case .weekly:
            return RepeatConfiguration(unit: .week, interval: interval, selectedWeekdays: customDays)
        case .biweekly:
            return RepeatConfiguration(
                unit: .week,
                interval: scaledInterval(interval, by: 2),
                selectedWeekdays: customDays
            )
        case .monthly:
            if interval % 12 == 0 && interval / 12 >= 1 {
                return RepeatConfiguration(unit: .year, interval: max(1, interval / 12))
            } else {
                return RepeatConfiguration(unit: .month, interval: max(1, interval))
            }
        case .custom:
            return RepeatConfiguration(unit: .day, interval: max(1, interval))
        case .once:
            return RepeatConfiguration(unit: .day, interval: 1)
        }
    }
    
    /// Applies configuration back to the model-friendly values.
    func resolvedFrequency() -> (frequency: CareTaskFrequency, interval: Int, customDays: [Int]?) {
        let normalizedInterval = Self.normalizedInterval(interval)
        switch unit {
        case .day:
            return (.daily, normalizedInterval, nil)
        case .week:
            let normalizedDays = Self.validWeekdays(from: selectedWeekdays).sorted()
            return (.weekly, normalizedInterval, normalizedDays.isEmpty ? nil : normalizedDays)
        case .month:
            return (.monthly, normalizedInterval, nil)
        case .year:
            return (.monthly, Self.scaledInterval(normalizedInterval, by: 12), nil)
        }
    }
    
    func localizedSummary() -> String {
        let interval = Self.normalizedInterval(interval)
        switch unit {
        case .day:
            if interval == 1 {
                return String(localized: .repeatSummaryDaily)
            }
            return String(localized: .repeatSummaryEvery(Int32(interval), localizedPlural(interval)))
        case .week:
            let base: String
            if interval == 1 {
                base = String(localized: .repeatSummaryWeekly)
            } else {
                base = String(localized: .repeatSummaryEvery(Int32(interval), localizedPlural(interval)))
            }
            let validWeekdays = Self.validWeekdays(from: selectedWeekdays)
            if validWeekdays.isEmpty == false {
                let weekdaySymbols = Calendar.current.shortWeekdaySymbols
                let names = validWeekdays
                    .sorted()
                    .map { weekdaySymbols[$0] }
                    .joined(separator: ", ")
                return base + " · " + names
            }
            return base
        case .month:
            if interval == 1 {
                return String(localized: .repeatSummaryMonthly)
            }
            return String(localized: .repeatSummaryEvery(Int32(interval), localizedPlural(interval)))
        case .year:
            if interval == 1 {
                return String(localized: .repeatSummaryYearly)
            }
            return String(localized: .repeatSummaryEvery(Int32(interval), localizedPlural(interval)))
        }
    }
    
    private func localizedPlural(_ count: Int) -> String {
        count == 1 ? unit.localizedSingular : unit.localizedPlural
    }

    private static func validWeekdays(from weekdays: Set<Int>) -> Set<Int> {
        weekdays.filter { (0...6).contains($0) }
    }

    private static func normalizedInterval(_ interval: Int) -> Int {
        min(max(1, interval), maximumInterval)
    }

    private static func scaledInterval(_ interval: Int, by multiplier: Int) -> Int {
        let normalizedInterval = normalizedInterval(interval)
        guard normalizedInterval <= maximumInterval / multiplier else {
            return maximumInterval
        }
        return normalizedInterval * multiplier
    }
}
