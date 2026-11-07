import Foundation

/// The two custom-field kinds shared by every feeding template, so a lookup can
/// construct and compare an exact key instead of parsing a suffix out of a
/// general-purpose field-key string.
enum FeedingFieldKind: String {
    case portion
    case foodType
}
