import Foundation
import PhotosUI
import SwiftUI

/// Modes for the unified cat form view
enum CatFormMode {
    /// Onboarding flow - simplified UI with Continue/Skip buttons
    case onboarding(onContinue: () -> Void, onSkip: () -> Void)
    /// Adding a new cat - full form with Cancel/Save toolbar
    case add
    /// Editing an existing cat - full form with Cancel/Save/Delete toolbar
    case edit(cat: Cat)
}

/// Unified form data structure for cat creation and editing forms.
/// Handles all state management for name, age, gender, photos, and additional details.
struct CatFormData {
    // MARK: - Essential Fields
    var name: String = ""
    var gender: Gender = .unknown
    var ageValue: Int?
    var ageText: String = ""
    var ageUnit: AgeUnit = .years

    // MARK: - Advanced Fields
    var breed: String = ""
    var weight: String = ""
    var weightUnit: WeightUnit = .kg
    var medicalNotes: String = ""
    var medicalConditions: String = ""

    // MARK: - Photo State
    var selectedPhoto: PhotosPickerItem?
    var photoData: Data?
    var capturedImage: UIImage?
    var showingPhotoOptions = false
    var showingCamera = false
    var showingCameraPermissionAlert = false
    /// True while a photo-library pick loads; the form cannot be saved until it ends.
    var isLoadingPhoto = false
    /// Why the last picked photo was not used, shown under the photo circle.
    var photoProblem: PhotoProblem?
    var showingPhotoNotSavedAlert = false

    // MARK: - UI State
    var showingAdvancedSection = false
    var isLoading = false

    enum PhotoProblem: Equatable {
        /// The photo did not load, for example an iCloud-only photo while offline. It can be retried.
        case loadFailed
        /// The photo loaded but cannot be decoded.
        case unusable
    }

    // MARK: - Focus State
    enum Field: Hashable {
        case name, age, breed, weight, medicalNotes, medicalConditions
    }
}

// MARK: - Computed Properties
extension CatFormData {
    /// Whether the name field is valid (non-empty after trimming)
    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Parsed weight value from string
    var weightValue: Double? {
        guard let value = Double(weight.replacing(",", with: ".")),
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    /// Age placeholder text based on current unit
    var agePlaceholder: String {
        ageUnit == .months ? String(localized: .catAddAgeUnitMonths) : String(localized: .catAddAgeUnitYears)
    }

    /// Whether any photo is currently selected or captured
    var hasPhoto: Bool {
        photoData != nil || capturedImage != nil
    }

    /// The selected or captured photo, not written to disk yet.
    var pendingPhoto: PendingCatPhoto? {
        if let photoData {
            return .data(photoData)
        }
        if let capturedImage {
            return .image(capturedImage)
        }
        return nil
    }

    /// The fields of a new cat, as Add Cat has always saved them.
    var detailsForNewCat: CatDetails {
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = medicalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let conditions = trimmedNotes.isEmpty ? [] :
            medicalConditions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return CatDetails(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            age: AgeUtils.months(from: ageValue, unit: ageUnit),
            breed: trimmedBreed.isEmpty ? nil : trimmedBreed,
            weight: weightValue,
            weightUnit: weightUnit,
            medicalNotes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            medicalConditions: conditions
        )
    }

    /// The fields of an edited cat, as Edit Cat has always saved them.
    var detailsForEditedCat: CatDetails {
        CatDetails(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            age: AgeUtils.months(from: AgeUtils.validateAge(ageValue), unit: ageUnit),
            breed: breed.isEmpty ? nil : breed,
            weight: weightValue,
            weightUnit: weightUnit,
            medicalNotes: medicalNotes.isEmpty ? nil : medicalNotes,
            medicalConditions: medicalConditions
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    /// Whether there are changes compared to an existing cat (for edit mode)
    func hasChanges(comparedTo cat: Cat) -> Bool {
        let ageInMonths = AgeUtils.validateAndConvert(ageValue, unit: ageUnit)

        return name != cat.name ||
               gender != cat.gender ||
               ageInMonths != cat.age ||
               breed != (cat.breed ?? "") ||
               weightValue != cat.weight ||
               weightUnit != cat.weightUnit ||
               medicalNotes != (cat.medicalNotes ?? "") ||
               medicalConditions != cat.medicalConditions.joined(separator: ", ")
               // Note: Photo changes are tracked separately via hasChangedPhoto in the view
    }
}

// MARK: - Initialization
extension CatFormData {
    /// Initialize from an existing Cat model (for editing)
    init(from cat: Cat) {
        self.name = cat.name
        self.gender = cat.gender

        // Convert age from months to appropriate unit
        if let age = cat.age, age > 0 {
            if age % 12 == 0 {
                self.ageValue = age / 12
                self.ageUnit = .years
            } else {
                self.ageValue = age
                self.ageUnit = .months
            }
            self.ageText = self.ageValue.map { String($0) } ?? ""
        } else {
            self.ageValue = nil
            self.ageText = ""
            self.ageUnit = .months
        }

        self.breed = cat.breed ?? ""
        if let weight = cat.weight {
            self.weight = String(weight)
        } else {
            self.weight = ""
        }
        self.weightUnit = cat.weightUnit
        self.medicalNotes = cat.medicalNotes ?? ""
        self.medicalConditions = cat.medicalConditions.joined(separator: ", ")

        // Show advanced section if any advanced fields have data
        self.showingAdvancedSection = cat.breed != nil || cat.weight != nil ||
                                     cat.medicalNotes != nil || !cat.medicalConditions.isEmpty
    }

    /// Initialize from OnboardingManager temp data (for onboarding flow)
    init(from onboardingData: TempCatData) {
        self.name = onboardingData.name
        self.gender = onboardingData.gender
        self.ageValue = AgeUtils.validateAge(onboardingData.age)
        self.ageText = self.ageValue.map { String($0) } ?? ""
        self.ageUnit = onboardingData.ageUnit
        self.photoData = onboardingData.photoData
    }
}
