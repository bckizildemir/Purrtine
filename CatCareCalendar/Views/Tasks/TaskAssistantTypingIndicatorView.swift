import SwiftUI

struct TaskAssistantTypingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            TaskAssistantMascotView(expression: .thinking, diameter: 28)
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(isAnimating ? 1 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear { isAnimating = true }

            Spacer(minLength: 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: .taskAssistantTypingIndicator))
    }
}
