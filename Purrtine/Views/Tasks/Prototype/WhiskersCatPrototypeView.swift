#if DEBUG
import SwiftUI

// PROTOTYPE (throwaway): code-drawn line-art Whiskers. Single stroke weight, round caps, accent color.
// Blinks every 3-4 s and wags its tail; under Reduce Motion the tail stays still and only the blink runs.

struct WhiskersCatPrototypeView: View {
    /// Height of the cat; the width follows the 5:6 drawing box.
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var eyeOpenness: CGFloat = 1

    private var lineWidth: CGFloat { max(1.5, height * 0.03) }
    private var style: StrokeStyle { StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round) }

    var body: some View {
        ZStack {
            tail
            WhiskersBodyShape().stroke(Theme.accent, style: style)
            WhiskersHeadShape().stroke(Theme.accent, style: style)
            WhiskersFaceShape().stroke(Theme.accent, style: style)
            WhiskersEyesShape()
                .fill(Theme.accent)
                .scaleEffect(x: 1, y: eyeOpenness, anchor: UnitPoint(x: 0.5, y: 0.32))
        }
        .frame(width: height * 5 / 6, height: height)
        .task { await blinkForever() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var tail: some View {
        let shape = WhiskersTailShape().stroke(Theme.accent, style: style)
        let anchor = UnitPoint(x: 0.66, y: 0.82)
        if reduceMotion {
            shape
        } else {
            PhaseAnimator([-9.0, 9.0]) { angle in
                shape.rotationEffect(.degrees(angle), anchor: anchor)
            } animation: { _ in
                .easeInOut(duration: 1.3)
            }
        }
    }

    private func blinkForever() async {
        while Task.isCancelled == false {
            try? await Task.sleep(for: .seconds(Double.random(in: 3...4)))
            withAnimation(.easeIn(duration: 0.05)) { eyeOpenness = 0.1 }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.08)) { eyeOpenness = 1 }
        }
    }
}

/// Maps a 100 x 120 drawing space into the shape's rect.
nonisolated private struct WhiskersSpace {
    let rect: CGRect

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x / 100, y: rect.minY + rect.height * y / 120)
    }
}

nonisolated private struct WhiskersHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = WhiskersSpace(rect: rect)
        var path = Path()
        // Head: rounded blob.
        path.move(to: s.point(24, 40))
        path.addQuadCurve(to: s.point(50, 18), control: s.point(26, 18))
        path.addQuadCurve(to: s.point(76, 40), control: s.point(74, 18))
        path.addQuadCurve(to: s.point(50, 62), control: s.point(78, 62))
        path.addQuadCurve(to: s.point(24, 40), control: s.point(22, 62))
        // Ears.
        path.move(to: s.point(26, 28))
        path.addLine(to: s.point(27, 6))
        path.addLine(to: s.point(43, 19))
        path.move(to: s.point(74, 28))
        path.addLine(to: s.point(73, 6))
        path.addLine(to: s.point(57, 19))
        return path
    }
}

nonisolated private struct WhiskersFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = WhiskersSpace(rect: rect)
        var path = Path()
        // Nose and mouth.
        path.move(to: s.point(47.5, 45))
        path.addLine(to: s.point(52.5, 45))
        path.addLine(to: s.point(50, 48))
        path.closeSubpath()
        path.move(to: s.point(50, 48))
        path.addLine(to: s.point(50, 51))
        path.addQuadCurve(to: s.point(44, 52), control: s.point(47, 55))
        path.move(to: s.point(50, 51))
        path.addQuadCurve(to: s.point(56, 52), control: s.point(53, 55))
        // Whiskers.
        for (dx, dy) in [(-1.0, -2.0), (-1.0, 3.0)] {
            path.move(to: s.point(38, 47))
            path.addLine(to: s.point(38 + dx * 24, 47 + dy * 2))
            path.move(to: s.point(62, 47))
            path.addLine(to: s.point(62 - dx * 24, 47 + dy * 2))
        }
        return path
    }
}

nonisolated private struct WhiskersEyesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = WhiskersSpace(rect: rect)
        var path = Path()
        for x in [39.0, 61.0] {
            let center = s.point(x, 38)
            path.addEllipse(in: CGRect(
                x: center.x - rect.width * 0.028,
                y: center.y - rect.height * 0.04,
                width: rect.width * 0.056,
                height: rect.height * 0.08
            ))
        }
        return path
    }
}

nonisolated private struct WhiskersBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = WhiskersSpace(rect: rect)
        var path = Path()
        path.move(to: s.point(36, 60))
        path.addQuadCurve(to: s.point(24, 100), control: s.point(20, 80))
        path.addLine(to: s.point(66, 100))
        path.addQuadCurve(to: s.point(64, 60), control: s.point(80, 80))
        // Front paws.
        path.move(to: s.point(42, 100))
        path.addLine(to: s.point(42, 84))
        path.move(to: s.point(54, 100))
        path.addLine(to: s.point(54, 84))
        return path
    }
}

nonisolated private struct WhiskersTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = WhiskersSpace(rect: rect)
        var path = Path()
        path.move(to: s.point(66, 98))
        path.addCurve(to: s.point(94, 66), control1: s.point(90, 104), control2: s.point(100, 82))
        return path
    }
}

#Preview("Whiskers prototype") {
    WhiskersCatPrototypeView(height: 160)
        .padding()
}
#endif
