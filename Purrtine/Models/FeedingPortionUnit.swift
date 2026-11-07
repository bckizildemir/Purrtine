import Foundation

/// The unit of a feeding portion entered on the task forms.
enum FeedingPortionUnit: String, CaseIterable, Identifiable {
    case grams
    case packs
    case cans
    case pounds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grams: String(localized: .feedingPortionUnitGrams)
        case .packs: String(localized: .feedingPortionUnitPacks)
        case .cans: String(localized: .feedingPortionUnitCans)
        case .pounds: String(localized: .feedingPortionUnitPounds)
        }
    }

    /// Resolves a unit from either its stored raw value or its localized display name.
    ///
    /// The display-name path exists for values persisted before the raw-value encoding landed.
    static func fromDisplayOrRaw(_ value: String) -> FeedingPortionUnit? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first {
            $0.rawValue.lowercased() == normalized || $0.displayName.lowercased() == normalized
        }
    }
}
