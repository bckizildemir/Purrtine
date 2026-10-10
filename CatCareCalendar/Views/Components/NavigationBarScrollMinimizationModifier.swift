import SwiftUI

/// Shrinks the navigation bar while the user scrolls down and restores it when they scroll back up.
/// iOS 27 and later only; earlier releases keep a fixed bar.
/// Apply it to a tab's root screen, not to pushed screens, which need their back button in reach.
private struct NavigationBarScrollMinimizationModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 27.0, *) {
      content
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
    } else {
      content
    }
  }
}

extension View {
  func minimizingNavigationBarOnScroll() -> some View {
    modifier(NavigationBarScrollMinimizationModifier())
  }
}
