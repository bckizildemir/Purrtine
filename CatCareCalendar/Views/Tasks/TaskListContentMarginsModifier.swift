import SwiftUI

struct TaskListContentMarginsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.bottom, 128, for: .scrollContent)
        } else {
            content
        }
    }
}

extension View {
    func addingFloatingTabBarScrollClearance() -> some View {
        modifier(TaskListContentMarginsModifier())
    }
}
