import Foundation

/// The profile fields the cat form edits, apart from the photo. `CatFormSaver` applies them to a
/// `Cat`, and keeps a copy of the cat's previous values to put back when a commit fails.
struct CatDetails: Equatable {
    var name: String
    var gender: Gender = .unknown
    /// In months.
    var age: Int?
    var breed: String?
    var weight: Double?
    var weightUnit: WeightUnit = .kg
    var medicalNotes: String?
    var medicalConditions: [String] = []
}

extension CatDetails {
    init(of cat: Cat) {
        self.init(
            name: cat.name,
            gender: cat.gender,
            age: cat.age,
            breed: cat.breed,
            weight: cat.weight,
            weightUnit: cat.weightUnit,
            medicalNotes: cat.medicalNotes,
            medicalConditions: cat.medicalConditions
        )
    }

    func apply(to cat: Cat) {
        cat.name = name
        cat.gender = gender
        cat.age = age
        cat.breed = breed
        cat.weight = weight
        cat.weightUnit = weightUnit
        cat.medicalNotes = medicalNotes
        cat.medicalConditions = medicalConditions
    }
}
