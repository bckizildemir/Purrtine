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
    let createdAt: Date

    init(role: Role, text: String, style: Style = .normal, createdAt: Date = Date()) {
        self.role = role
        self.text = text
        self.style = style
        self.createdAt = createdAt
    }
}
