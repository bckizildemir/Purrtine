import SwiftUI

/// Shrinks the navigation bar while the user scrolls down and restores it when they scroll back up.
/// iOS 27 and later only; earlier releases keep a fixed bar.
/// Apply it to a tab's root screen, not to pushed screens, which need their back button in reach.
private struct NavigationBarScrollMinimizationModifier: ViewModifier {
  func body(content: Content) -> some View {
    // The iOS 27 SDK ships with the Swift 6.4 toolchain (Xcode 27). Older Xcode, which CI still
    // runs, has no declaration of this API, so a runtime #available check alone does not compile.
    #if compiler(>=6.4)
    if #available(iOS 27.0, *) {
      content
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
    } else {
      content
    }
    #else
    content
    #endif
  }
}

extension View {
  func minimizingNavigationBarOnScroll() -> some View {
    modifier(NavigationBarScrollMinimizationModifier())
  }
}
