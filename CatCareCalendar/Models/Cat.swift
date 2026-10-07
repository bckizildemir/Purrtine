import Foundation
import SwiftData

@Model
final class Cat: Hashable {
    var id: UUID
    var name: String
    var photoURLs: [String]
    var age: Int? // in months
    var gender: Gender
    var breed: String?
    var weight: Double?
    var weightUnit: WeightUnit
    var medicalNotes: String?
    var medicalConditions: [String]
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var tasks: [CareTask] = []
    
    init(
        name: String,
        photoURLs: [String] = [],
        age: Int? = nil,
        gender: Gender = .unknown,
        breed: String? = nil,
        weight: Double? = nil,
        weightUnit: WeightUnit = .kg,
        medicalNotes: String? = nil,
        medicalConditions: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.photoURLs = photoURLs
        self.age = age
        self.gender = gender
        self.breed = breed
        self.weight = weight
        self.weightUnit = weightUnit
        self.medicalNotes = medicalNotes
        self.medicalConditions = medicalConditions
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Enums
nonisolated enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .male: return String(localized: .genderMale)
        case .female: return String(localized: .genderFemale)
        case .unknown: return String(localized: .genderUnknown)
        }
    }
}

nonisolated enum WeightUnit: String, CaseIterable, Codable {
    case kg = "kg"
    case lb = "lb"
    
    var displayName: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }
}

// MARK: - Cat Extensions
extension Cat {
    var ageDisplayText: String {
        guard let ageInMonths = AgeUtils.validateAge(age) else {
            return String(localized: .catAgeUnknown)
        }
        
        if ageInMonths < 12 {
            return String(localized: .catAgeMonths(Int32(ageInMonths)))
        } else {
            let years = ageInMonths / 12
            let remainingMonths = ageInMonths % 12
            if remainingMonths == 0 {
                return String(localized: .catAgeYears(Int32(years)))
            } else {
                return String(localized: .catAgeYearsMonths(Int32(years), Int32(remainingMonths)))
            }
        }
    }
    
    var weightDisplayText: String {
        guard let weight, weight.isFinite, weight > 0 else {
            return String(localized: .catWeightUnknown)
        }
        return "\(weight.formatted(.number.precision(.fractionLength(1)))) \(weightUnit.displayName)"
    }
    
    var firstPhotoPath: String? {
        guard let fileName = photoURLs.first,
              let url = PhotoManager.shared.absoluteURL(for: fileName) else {
            return nil
        }
        return url.path
    }
    
    var firstPhotoURL: String? {
        guard let fileName = photoURLs.first,
              let url = PhotoManager.shared.absoluteURL(for: fileName) else {
            return nil
        }
        return url.absoluteString
    }
    
    var hasPhoto: Bool {
        !photoURLs.isEmpty
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: Cat, rhs: Cat) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 
