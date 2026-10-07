import SwiftUI

struct HomeSectionSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(Theme.backgroundGroupedSecondary, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func homeSectionSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(HomeSectionSurfaceModifier(cornerRadius: cornerRadius))
    }
}
