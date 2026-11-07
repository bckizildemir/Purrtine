import SwiftUI

struct TaskCardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var legacyCornerRadius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(
                Color(UIColor.secondarySystemGroupedBackground),
                in: .rect(cornerRadius: legacyCornerRadius ?? cornerRadius)
            )
        }
    }
}

extension View {
    /// The same Liquid Glass (iOS 26+) / grouped-background (fallback) surface used for
    /// task rows in the Tasks list, so any other task card (e.g. the assistant's
    /// suggestion picker) can look identical.
    func taskCardSurface(cornerRadius: CGFloat = 20, legacyCornerRadius: CGFloat? = nil) -> some View {
        modifier(TaskCardSurfaceModifier(cornerRadius: cornerRadius, legacyCornerRadius: legacyCornerRadius))
    }
}
