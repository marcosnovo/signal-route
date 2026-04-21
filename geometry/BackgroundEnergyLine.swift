import SwiftUI

// MARK: - BackgroundEnergyLine
/// Occasional animated energy line that sweeps across the background,
/// suggesting active signal transmission through the network.
///
/// Behaviour:
///   • Idle 6–12 s between pulses (initial stagger 4–8 s so it doesn't fire on launch)
///   • Path: left edge → right edge with 1–2 right-angle turns
///   • Animation: stroke trim 0→1 over ~1.8 s, then fade out
struct BackgroundEnergyLine: View {

    @State private var points:  [CGPoint] = []
    @State private var trimEnd: CGFloat   = 0
    @State private var opacity: Double    = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Glow halo (wider, low opacity) ──────────────────────
                EnergyLinePath(points: points)
                    .trim(from: 0, to: trimEnd)
                    .stroke(
                        AppTheme.accentPrimary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                    )

                // ── Core line ───────────────────────────────────────────
                EnergyLinePath(points: points)
                    .trim(from: 0, to: trimEnd)
                    .stroke(
                        AppTheme.accentPrimary.opacity(0.70),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
            }
            .opacity(opacity)
            .allowsHitTesting(false)
            .task { await runLoop(in: geo.size) }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Loop

    private func runLoop(in size: CGSize) async {
        // Don't fire immediately on first launch
        let initial = UInt64.random(in: 4_000_000_000...8_000_000_000)
        try? await Task.sleep(nanoseconds: initial)

        while !Task.isCancelled {
            await playOnce(in: size)
            let idle = UInt64.random(in: 6_000_000_000...12_000_000_000)
            try? await Task.sleep(nanoseconds: idle)
        }
    }

    private func playOnce(in size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }

        // Reset instantly (view is invisible at this point)
        points  = generatePoints(in: size)
        trimEnd = 0
        opacity = 0

        // Fade in, then draw the line concurrently
        withAnimation(.easeIn(duration: 0.20)) { opacity = 1 }
        withAnimation(.linear(duration: 1.9))  { trimEnd = 1 }

        try? await Task.sleep(nanoseconds: 2_000_000_000)   // drawing complete

        // Brief hold, then fade out
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeOut(duration: 0.55)) { opacity = 0 }
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    // MARK: - Path generation

    /// Generates a polyline from the left edge to the right edge
    /// with 1–2 right-angle turns, staying within a safe vertical band.
    private func generatePoints(in size: CGSize) -> [CGPoint] {
        let w    = size.width
        let h    = size.height
        let yMin = h * 0.14          // clear system bar area
        let yMax = h * 0.55          // stay above HUD cards at the bottom

        func randY() -> CGFloat { CGFloat.random(in: yMin...yMax) }

        let turns = Int.random(in: 1...2)
        let y0    = randY()

        switch turns {
        case 1:
            let x1 = CGFloat.random(in: w * 0.28...w * 0.64)
            let y1 = randY()
            return [
                CGPoint(x: 0,  y: y0),
                CGPoint(x: x1, y: y0),
                CGPoint(x: x1, y: y1),
                CGPoint(x: w,  y: y1),
            ]
        default:  // 2 turns
            let x1 = CGFloat.random(in: w * 0.18...w * 0.38)
            let y1 = randY()
            let x2 = CGFloat.random(in: w * 0.56...w * 0.76)
            let y2 = randY()
            return [
                CGPoint(x: 0,  y: y0),
                CGPoint(x: x1, y: y0),
                CGPoint(x: x1, y: y1),
                CGPoint(x: x2, y: y1),
                CGPoint(x: x2, y: y2),
                CGPoint(x: w,  y: y2),
            ]
        }
    }
}

// MARK: - EnergyLinePath
/// Custom Shape that renders a polyline through the given absolute points.
private struct EnergyLinePath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() { p.addLine(to: point) }
        return p
    }
}
