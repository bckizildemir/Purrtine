import SwiftUI

private struct NavigationChromeTitleModifier: ViewModifier {
  let semanticTitle: String
  let visualTitle: Text
  let visualSubtitle: Text?
  let usesEditorToolbarRole: Bool
  var titleFont: Font = .title3.weight(.semibold)
  var subtitleFont: Font = .subheadline.weight(.semibold)

  @ViewBuilder
  func body(content: Content) -> some View {
    let titleContent = content
      .navigationTitle(semanticTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .title) {
          NavigationChromeTitleView(
            title: visualTitle,
            subtitle: visualSubtitle,
            titleFont: titleFont,
            subtitleFont: subtitleFont
          )
        }
      }

    if usesEditorToolbarRole {
      titleContent.toolbarRole(.editor)
    } else {
      titleContent
    }
  }
}

extension View {
  func navigationChromeTitle(
    semanticTitle: String,
    visualTitle: Text,
    visualSubtitle: Text? = nil,
    usesEditorToolbarRole: Bool = true,
    titleFont: Font = .title3.weight(.semibold),
    subtitleFont: Font = .subheadline.weight(.semibold)
  ) -> some View {
    modifier(
      NavigationChromeTitleModifier(
        semanticTitle: semanticTitle,
        visualTitle: visualTitle,
        visualSubtitle: visualSubtitle,
        usesEditorToolbarRole: usesEditorToolbarRole,
        titleFont: titleFont,
        subtitleFont: subtitleFont
      )
    )
  }
}
