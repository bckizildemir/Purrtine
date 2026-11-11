import SwiftUI

struct TaskListBottomExtensionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .ignoresSafeArea(.container, edges: .bottom)
        } else {
            content
        }
    }
}

extension View {
    func extendingUnderFloatingTabBar() -> some View {
        modifier(TaskListBottomExtensionModifier())
    }
}
