import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct FeedingFieldSupportTests {
    // MARK: - keys(for:)

    @Test
    func keysResolveForBothFeedingTemplates() throws {
        let templates = CareTaskTemplateManager.shared.allTemplates
        let morning = try #require(templates.first { $0.kind == .morningFeeding })
        let evening = try #require(templates.first { $0.kind == .eveningFeeding })

        let morningKeys = try #require(FeedingFieldSupport.keys(for: morning))
        #expect(morningKeys.portion == "morningFeeding.field.portion")
        #expect(morningKeys.foodType == "morningFeeding.field.foodType")

        let eveningKeys = try #require(FeedingFieldSupport.keys(for: evening))
        #expect(eveningKeys.portion == "eveningFeeding.field.portion")
        #expect(eveningKeys.foodType == "eveningFeeding.field.foodType")
    }

    @Test
    func keysAreNilForNonFeedingTemplates() throws {
        let templates = CareTaskTemplateManager.shared.allTemplates
        let medication = try #require(templates.first { $0.kind == .medication })

        #expect(FeedingFieldSupport.keys(for: medication) == nil)
    }

    // MARK: - encodePortion / decodePortion

    @Test
    func encodePortionJoinsAmountAndUnitRawValue() {
        #expect(FeedingFieldSupport.encodePortion(amount: "60", unit: .grams) == "60|grams")
    }

    @Test
    func encodePortionReturnsEmptyStringForBlankAmount() {
        #expect(FeedingFieldSupport.encodePortion(amount: "   ", unit: .grams).isEmpty)
    }

    @Test
    func decodePortionReadsTheCurrentEncoding() throws {
        let decoded = try #require(FeedingFieldSupport.decodePortion("60|packs"))
        #expect(decoded.amount == "60")
        #expect(decoded.unit == .packs)
    }

    @Test
    func decodePortionFallsBackToLegacyDisplayNameEncoding() throws {
        let decoded = try #require(FeedingFieldSupport.decodePortion("2 \(FeedingPortionUnit.cans.displayName)"))
        #expect(decoded.amount == "2")
        #expect(decoded.unit == .cans)
    }

    @Test
    func decodePortionDefaultsToGramsForAnUnrecognizedUnit() throws {
        let decoded = try #require(FeedingFieldSupport.decodePortion("60 scoops"))
        #expect(decoded.amount == "60 scoops")
        #expect(decoded.unit == .grams)
    }

    @Test
    func decodePortionReturnsNilForBlankInput() {
        #expect(FeedingFieldSupport.decodePortion("   ") == nil)
    }

    // MARK: - portionDisplay

    @Test
    func portionDisplayFormatsAmountAndUnit() throws {
        let display = try #require(FeedingFieldSupport.portionDisplay(from: "60|grams"))
        #expect(display == "60 \(FeedingPortionUnit.grams.displayName)")
    }

    @Test
    func portionDisplayIsNilForBlankInput() {
        #expect(FeedingFieldSupport.portionDisplay(from: "") == nil)
    }

    // MARK: - summary

    @Test
    func summaryJoinsPortionAndFoodType() {
        let summary = FeedingFieldSupport.summary(portion: "60|grams", foodType: "Dry food")
        #expect(summary == "60 \(FeedingPortionUnit.grams.displayName) • Dry food")
    }

    @Test
    func summaryFallsBackToNotEnteredWhenBothFieldsAreMissing() {
        let summary = FeedingFieldSupport.summary(portion: nil, foodType: "   ")
        #expect(summary == String(localized: .tasksConfigNotEntered))
    }

    @Test
    func summaryIncludesOnlyTheFieldThatIsSet() {
        let summary = FeedingFieldSupport.summary(portion: nil, foodType: "Wet food")
        #expect(summary == "Wet food")
    }
}
