import SwiftUI

/// A centralized theme provider for consistent styling across the app.
enum Theme {
    // MARK: - Background Colors
    /// The primary background color for main views.
    static let background = Color(.systemBackground)
    /// The background color for content layered on top of the main background.
    static let backgroundSecondary = Color(.secondarySystemBackground)
    /// The background color for grouped content, like lists or settings.
    static let backgroundGrouped = Color(.systemGroupedBackground)
    /// The background color for content layered on top of grouped backgrounds.
    static let backgroundGroupedSecondary = Color(.secondarySystemGroupedBackground)
    /// The background color for controls layered inside grouped content.
    static let backgroundGroupedTertiary = Color(.tertiarySystemGroupedBackground)

    // MARK: - Text Colors
    static let label = Color(.label)
    static let labelSecondary = Color(.secondaryLabel)
    static let labelTertiary = Color(.tertiaryLabel)
    static let labelQuaternary = Color(.quaternaryLabel)

    // MARK: - Fill Colors
    static let fill = Color(.systemFill)
    static let fillSecondary = Color(.secondarySystemFill)

    // MARK: - Functional Colors
    static let accent = Color.accentColor
    /// The color for a completed or satisfied state.
    static let success = Color(.systemGreen)
    static let destructive = Color(.systemRed)
    static let separator = Color(.separator)
    static let link = Color(.link)

    // MARK: - Row Icon Tints
    /// Tints for the leading icons of the task-form rows.
    ///
    /// Named by the row they belong to rather than by hue, so a call site states its role and the
    /// palette can change in one place. These are decorative: every row also carries a text label,
    /// so no state is communicated by color alone.
    static let iconDate = Color(.systemRed)
    static let iconTime = Color(.systemBlue)
    static let iconPriority = Color(.systemRed)
    static let iconSchedule = Color(.systemGreen)
    static let iconCaregiver = Color(.systemPurple)
    static let iconReminder = Color(.systemPurple)
    static let iconCats = Color(.systemOrange)
    static let iconNeutral = Color(.systemGray)
}
