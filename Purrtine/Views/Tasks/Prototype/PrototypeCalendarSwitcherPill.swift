#if DEBUG
import SwiftUI

// PROTOTYPE (throwaway): floating pill that cycles the calendar variants.

struct PrototypeCalendarSwitcherPill: View {
    @Bindable private var model = PrototypeCalendarVariantModel.shared

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous variant", systemImage: "chevron.left") {
                model.variant = model.variant.next(by: -1)
            }
            Text(model.variant.label)
                .font(.footnote.bold())
                .monospacedDigit()
                .frame(minWidth: 150)
                .accessibilityIdentifier("prototype.variantLabel")
            Button("Next variant", systemImage: "chevron.right") {
                model.variant = model.variant.next(by: 1)
            }
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(radius: 6, y: 2)
    }
}
#endif
