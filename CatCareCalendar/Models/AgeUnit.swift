import Foundation

enum AgeUnit: String, CaseIterable, Codable {
    case months, years
    var displayName: String {
        switch self {
        case .months: return String(localized: .catAddAgeUnitMonths)
        case .years: return String(localized: .catAddAgeUnitYears)
        }
    }
} 