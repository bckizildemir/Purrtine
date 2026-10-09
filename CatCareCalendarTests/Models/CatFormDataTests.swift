import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct CatFormDataTests {
    @Test(arguments: [
        (nil as Int?, nil as Int?),
        (0 as Int?, nil as Int?),
        (-4 as Int?, nil as Int?),
        (601 as Int?, nil as Int?),
        (24 as Int?, 24 as Int?)
    ])
    func validateAgeRejectsInvalidValues(input: Int?, expected: Int?) {
        #expect(AgeUtils.validateAge(input) == expected)
    }

    @Test(arguments: [
        (nil as Int?, AgeUnit.months, nil as Int?),
        (0 as Int?, AgeUnit.years, nil as Int?),
        (-1 as Int?, AgeUnit.months, nil as Int?),
        (8 as Int?, AgeUnit.months, 8 as Int?),
        (2 as Int?, AgeUnit.years, 24 as Int?)
    ])
    func monthsConversionHandlesUnknownAndYearBasedInput(
        input: Int?,
        unit: AgeUnit,
        expected: Int?
    ) {
        #expect(AgeUtils.months(from: input, unit: unit) == expected)
    }

    @Test(arguments: [
        (nil as Int?, AgeUnit.months, nil as Int?),
        (0 as Int?, AgeUnit.years, nil as Int?),
        (-1 as Int?, AgeUnit.months, nil as Int?),
        (1 as Int?, AgeUnit.months, 1 as Int?),
        (600 as Int?, AgeUnit.months, 600 as Int?),
        (601 as Int?, AgeUnit.months, nil as Int?),
        (1 as Int?, AgeUnit.years, 12 as Int?),
        (50 as Int?, AgeUnit.years, 600 as Int?),
        (51 as Int?, AgeUnit.years, nil as Int?),
        (Int.max as Int?, AgeUnit.years, nil as Int?)
    ])
    func validatedConversionEnforcesFiftyYearLimitWithoutOverflow(
        input: Int?,
        unit: AgeUnit,
        expected: Int?
    ) {
        #expect(AgeUtils.validateAndConvert(input, unit: unit) == expected)
    }

    @Test(arguments: [
        ("", false),
        (" \n ", false),
        (" Mochi ", true)
    ])
    func nameValidationTrimsWhitespace(name: String, expected: Bool) {
        var sut = CatFormData()
        sut.name = name

        #expect(sut.isNameValid == expected)
    }

    @Test(arguments: [
        ("", nil as Double?),
        ("invalid", nil as Double?),
        ("0", nil as Double?),
        ("-4.25", nil as Double?),
        ("nan", nil as Double?),
        ("inf", nil as Double?),
        ("4.25", 4.25 as Double?),
        ("4,25", 4.25 as Double?)
    ])
    func weightParsingAcceptsDotAndCommaDecimals(weight: String, expected: Double?) {
        var sut = CatFormData()
        sut.weight = weight

        #expect(sut.weightValue == expected)
    }

    @Test
    func formReportsAChangedField() {
        let cat = Cat(name: "Mochi", weight: 4.2)
        var sut = CatFormData(from: cat)
        sut.weight = "4,3"

        #expect(sut.hasChanges(comparedTo: cat))
    }

    @Test
    func formInitializedFromExistingCatDoesNotReportFalseChanges() {
        let cat = Cat(
            name: "Mochi",
            age: 24,
            gender: .female,
            breed: "British Shorthair",
            weight: 4.2,
            medicalNotes: "Annual checkup done",
            medicalConditions: ["Sensitive stomach", "Seasonal allergies"]
        )

        let formData = CatFormData(from: cat)

        #expect(formData.ageValue == 2)
        #expect(formData.ageUnit == .years)
        #expect(formData.hasChanges(comparedTo: cat) == false)
    }

    @Test
    func corruptOversizedAgeDoesNotOverflowOrCreateAFalseChange() {
        let cat = Cat(name: "Mochi", age: nil)
        var sut = CatFormData(from: cat)
        sut.ageValue = .max
        sut.ageUnit = .years

        #expect(sut.hasChanges(comparedTo: cat) == false)
    }

    @Test(arguments: [0, -1, 601, Int.max])
    func corruptPersistedAgeDisplaysAsUnknown(age: Int) {
        let cat = Cat(name: "Mochi", age: age)

        #expect(cat.ageDisplayText == String(localized: .catAgeUnknown))
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity])
    func corruptPersistedWeightDisplaysAsUnknown(weight: Double) {
        let cat = Cat(name: "Mochi", weight: weight)

        #expect(cat.weightDisplayText == String(localized: .catWeightUnknown))
    }

    @Test
    func corruptPersistedPhotoPathDoesNotResolveToThePhotoDirectory() {
        let cat = Cat(name: "Mochi", photoURLs: ["../outside.jpg"])

        #expect(cat.firstPhotoPath == nil)
        #expect(cat.firstPhotoURL == nil)
    }

    @Test
    func formInitializedFromOnboardingDataPreservesValidatedAgeAndUnit() {
        let onboardingData = TempCatData(
            name: "Luna",
            age: 2,
            ageUnit: .years,
            gender: .female,
            breed: "",
            photoData: nil,
            notes: ""
        )

        let formData = CatFormData(from: onboardingData)

        #expect(formData.name == "Luna")
        #expect(formData.ageValue == 2)
        #expect(formData.ageUnit == .years)
        #expect(formData.gender == .female)
    }

    // MARK: - Edit Cat photo change

    @Test
    func anUntouchedPhotoIsKept() {
        let formData = CatFormData()

        #expect(formData.editPhotoChange(hasChangedPhoto: false, includingPhoto: true) == .keep)
    }

    @Test
    func aNewPickReplacesThePhoto() {
        var formData = CatFormData()
        formData.photoData = Data("new".utf8)

        #expect(
            formData.editPhotoChange(hasChangedPhoto: true, includingPhoto: true)
                == .replace(.data(Data("new".utf8)))
        )
    }

    /// "Save without photo" in Edit Cat keeps the cat's current photo; it does not remove it.
    @Test
    func savingWithoutTheNewPhotoKeepsTheCurrentOne() {
        var formData = CatFormData()
        formData.photoData = Data("new".utf8)

        #expect(formData.editPhotoChange(hasChangedPhoto: true, includingPhoto: false) == .keep)
    }

    @Test
    func aRemovedPhotoIsRemoved() {
        let formData = CatFormData()

        #expect(formData.editPhotoChange(hasChangedPhoto: true, includingPhoto: true) == .remove)
    }
}
