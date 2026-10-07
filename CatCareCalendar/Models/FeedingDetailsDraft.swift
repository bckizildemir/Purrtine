import Foundation

/// The feeding-specific custom-field state edited by `FeedingDetailsSheet`.
///
/// Bundles the portion and food-type values together with the template-derived labels
/// and the custom-field keys they save back to, so the sheet takes one value instead of
/// ten separate parameters.
struct FeedingDetailsDraft {
    var portionFieldKey: String?
    var foodTypeFieldKey: String?
    var portionFieldTitle: String = ""
    var portionFieldPlaceholder: String = ""
    var foodFieldTitle: String = ""
    var foodFieldPlaceholder: String = ""
    var foodTypeOptions: [String] = []
    var portionAmount: String = ""
    var portionUnit: FeedingPortionUnit = .grams
    var foodType: String = ""
}
