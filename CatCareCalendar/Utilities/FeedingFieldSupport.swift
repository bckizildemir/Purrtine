import Foundation

/// Encoding, decoding, and display rules for the feeding custom fields of a task template.
///
/// The portion value is persisted as `"<amount>|<unitRawValue>"`. Older records stored
/// `"<amount> <unitDisplayName>"`, so `decodePortion(_:)` still accepts that form.
enum FeedingFieldSupport {
    /// The custom-field keys that hold the portion and the food type of a feeding template.
    ///
    /// Returns `nil` when the template is not a feeding template, or when either field is absent.
    static func keys(for template: CareTaskTemplate) -> (portion: String, foodType: String)? {
        guard template.kind == .morningFeeding || template.kind == .eveningFeeding else {
            return nil
        }

        let portionKey = template.kind.feedingFieldKey(.portion)
        let foodKey = template.kind.feedingFieldKey(.foodType)

        guard template.customFields.contains(where: { $0.key == portionKey }),
              template.customFields.contains(where: { $0.key == foodKey }) else {
            return nil
        }

        return (portionKey, foodKey)
    }

    static func encodePortion(amount: String, unit: FeedingPortionUnit) -> String {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(trimmed)|\(unit.rawValue)"
    }

    static func decodePortion(_ storedValue: String) -> (amount: String, unit: FeedingPortionUnit)? {
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let separatorIndex = trimmed.firstIndex(of: "|") {
            let amountPart = String(trimmed[..<separatorIndex])
            let unitPart = String(trimmed[trimmed.index(after: separatorIndex)...])
            if let unit = FeedingPortionUnit(rawValue: unitPart) {
                return (amountPart, unit)
            }
        }

        let components = trimmed.split(separator: " ")
        if components.count >= 2,
           let unitCandidate = components.last,
           let unit = FeedingPortionUnit.fromDisplayOrRaw(String(unitCandidate)) {
            return (components.dropLast().joined(separator: " "), unit)
        }

        return (trimmed, .grams)
    }

    /// The portion shown to the user, or `nil` when no value is stored.
    static func portionDisplay(from storedValue: String) -> String? {
        guard let decoded = decodePortion(storedValue) else { return nil }

        let amount = decoded.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        return amount.isEmpty ? decoded.unit.displayName : "\(amount) \(decoded.unit.displayName)"
    }

    /// The single-line summary of both feeding fields, for a collapsed option row.
    static func summary(portion: String?, foodType: String?) -> String {
        var components: [String] = []

        if let portion, let formatted = portionDisplay(from: portion) {
            components.append(formatted)
        }

        if let foodType {
            let trimmedFood = foodType.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedFood.isEmpty == false {
                components.append(trimmedFood)
            }
        }

        return components.isEmpty
            ? String(localized: .tasksConfigNotEntered)
            : components.joined(separator: " • ")
    }
}
