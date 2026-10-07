import SwiftUI

enum TaskAssistantMascotExpression {
    case idle
    case thinking
}

/// A simple flat, vector-drawn cat face used as the assistant's mascot. Colors come entirely
/// from `Theme` so the illustration tracks light/dark mode and the user's accent color like
/// every other view in the app, without needing an image asset.
struct TaskAssistantMascotView: View {
    let expression: TaskAssistantMascotExpression
    let diameter: CGFloat

    private var earSize: CGFloat { diameter * 0.32 }
    private var eyeSize: CGFloat { diameter * 0.11 }
    private var eyeSpacing: CGFloat { diameter * 0.24 }
    private var whiskerLength: CGFloat { diameter * 0.22 }

    var body: some View {
        ZStack {
            earPair

            Circle()
                .fill(Theme.accent.opacity(0.15))
                .overlay {
                    Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
                }
                .frame(width: diameter, height: diameter)

            whiskers

            VStack(spacing: diameter * 0.08) {
                eyes
                mouth
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var earPair: some View {
        HStack(spacing: diameter * 0.34) {
            TaskAssistantMascotEar()
                .fill(Theme.accent)
                .frame(width: earSize, height: earSize)
                .rotationEffect(.degrees(-18))
            TaskAssistantMascotEar()
                .fill(Theme.accent)
                .frame(width: earSize, height: earSize)
                .rotationEffect(.degrees(18))
        }
        .offset(y: -diameter * 0.46)
    }

    private var eyes: some View {
        HStack(spacing: eyeSpacing) {
            eyeShape
            eyeShape
        }
    }

    @ViewBuilder
    private var eyeShape: some View {
        switch expression {
        case .idle:
            Circle()
                .fill(Theme.label)
                .frame(width: eyeSize, height: eyeSize)
        case .thinking:
            Capsule()
                .fill(Theme.label)
                .frame(width: eyeSize * 1.4, height: eyeSize * 0.55)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch expression {
        case .idle:
            TaskAssistantMascotSmile()
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: diameter * 0.28, height: diameter * 0.12)
        case .thinking:
            Capsule()
                .fill(Theme.accent)
                .frame(width: diameter * 0.16, height: diameter * 0.05)
        }
    }

    private var whiskers: some View {
        HStack {
            VStack(alignment: .leading, spacing: diameter * 0.05) {
                whiskerLine
                whiskerLine
            }
            Spacer()
            VStack(alignment: .trailing, spacing: diameter * 0.05) {
                whiskerLine
                whiskerLine
            }
        }
        .frame(width: diameter * 1.15)
        .offset(y: diameter * 0.08)
    }

    private var whiskerLine: some View {
        Rectangle()
            .fill(Theme.labelTertiary)
            .frame(width: whiskerLength, height: 1)
    }
}

nonisolated private struct TaskAssistantMascotEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

nonisolated private struct TaskAssistantMascotSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

#if DEBUG
#Preview("Task Assistant Mascot") {
    HStack(spacing: 24) {
        VStack {
            TaskAssistantMascotView(expression: .idle, diameter: 64)
            Text("idle")
        }
        VStack {
            TaskAssistantMascotView(expression: .thinking, diameter: 64)
            Text("thinking")
        }
    }
    .padding()
}
#endif
