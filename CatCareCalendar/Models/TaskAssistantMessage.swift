import Foundation

struct TaskAssistantMessage: Identifiable {
    enum Role {
        case assistant
        case user
    }

    enum Style {
        case normal
        case failure
    }

    let id = UUID()
    let role: Role
    let text: String
    let style: Style
    /// The failure has a fix in the Settings app (notifications are off), so the bubble shows an
    /// "Open Settings" button. The view model sets it; the bubble only reads it.
    let offersOpenSettings: Bool
    let createdAt: Date

    init(
        role: Role,
        text: String,
        style: Style = .normal,
        offersOpenSettings: Bool = false,
        createdAt: Date = Date()
    ) {
        self.role = role
        self.text = text
        self.style = style
        self.offersOpenSettings = offersOpenSettings
        self.createdAt = createdAt
    }
}
