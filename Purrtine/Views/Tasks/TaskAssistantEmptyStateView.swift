import SwiftUI

struct TaskAssistantEmptyStateView: View {
    let chips: [TaskAssistantSuggestion]
    let accessibilityIdentifier: String
    let onSelectChip: (TaskAssistantSuggestion) -> Void

    init(
        chips: [TaskAssistantSuggestion],
        accessibilityIdentifier: String = "taskAssistant.emptyState",
        onSelectChip: @escaping (TaskAssistantSuggestion) -> Void
    ) {
        self.chips = chips
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onSelectChip = onSelectChip
    }

    var body: some View {
        VStack(spacing: 16) {
            TaskAssistantMascotView(expression: .idle, diameter: 64)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(.taskAssistantEmptyStateTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier(accessibilityIdentifier)

                Text(.taskAssistantEmptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !chips.isEmpty {
                chipRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
    }

    private var chipRow: some View {
        TaskAssistantFlowLayout(spacing: 8) {
            ForEach(chips) { chip in
                Button {
                    onSelectChip(chip)
                } label: {
                    Label {
                        Text(chip.task.title)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityLabel(String(localized: .taskAssistantQuickActionChipLabel(chip.task.title)))
                .accessibilityIdentifier("taskAssistant.quickAction.\(chip.task.title)")
            }
        }
    }
}

/// Wraps its children onto multiple lines instead of clipping or requiring horizontal
/// scrolling — keeps chip rows fully visible at any device width.
struct TaskAssistantFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                totalWidth = max(totalWidth, origin.x - spacing)
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, origin.x - spacing)

        return CGSize(width: min(totalWidth, maxWidth), height: origin.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, anchor: .topLeading, proposal: .unspecified)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
#Preview("Task Assistant Empty State") {
    PreviewHost(scenario: .standard) {
        TaskAssistantEmptyStateView(chips: []) { _ in }
    }
}
#endif
