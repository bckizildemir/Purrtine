import SwiftUI

/// A quiet "AI can make mistakes" line shown next to content that came from the cloud AI.
/// Put it only where AI content is visible, never on an empty state or a rule-based answer.
struct AIGeneratedNotice: View {
    /// Names the surface for the accessibility identifier: `ai-notice-<surface>`.
    let surface: String

    var body: some View {
        Text(.aiNoticeGenerated)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("ai-notice-\(surface)")
    }
}

#Preview {
    AIGeneratedNotice(surface: "preview")
        .padding()
}
