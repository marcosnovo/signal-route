import SwiftUI

// MARK: - BackgroundSystem
/// Single entry point for all background atmosphere layers.
///
/// Layer order (back → front):
///   1. BackgroundGrid        — drifting technical grid lines (structure)
///   2. BackgroundStarfield   — 40 tiny static stars, slow independent twinkling (deep space)
///   3. BackgroundSignalNodes — asynchronous pulsing dots + traveling particles (presence/parallax)
///   4. BackgroundEnergyLine  — occasional sweeping signal line (event / flow)
///
/// Design rules shared across all layers:
///   • Base opacity  ≤ 0.08   — nearly invisible at rest
///   • Peak opacity  ≤ 0.55   — visible but never competing with UI content
///   • Palette       — orange (accent), sage (secondary), white (neutral)
///   • Zero hit testing — all decoration, never intercepting touches
struct BackgroundSystem: View {

    var body: some View {
        ZStack {
            BackgroundGrid()
            BackgroundStarfield()
            BackgroundSignalNodes()
            BackgroundEnergyLine()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - BackgroundStarfield
/// 40 tiny static stars (1–2 pt) spread across the full canvas.
/// Each twinkles independently at a very slow rate (4–9 s cycle).
///
/// Implementation: single Canvas inside a TimelineView at 4 fps.
/// CPU cost is negligible — 40 ellipse fills at 4 fps total ≈ 160 paths/s.
/// Stars never move; only opacity animates via sin(), creating a calm starfield feel.
private struct BackgroundStarfield: View {

    /// Deterministic star descriptors — created once, never mutated.
    private static let stars: [(x: CGFloat, y: CGFloat, phase: Double, rate: Double, size: CGFloat)] = {
        (0..<40).map { i in
            let s = Double(i)
            // Pseudo-random scatter using linear congruential offsets
            let x = CGFloat((s * 23.7 + 7.3).truncatingRemainder(dividingBy: 100)) / 100
            let y = CGFloat((s * 37.1 + 13.9).truncatingRemainder(dividingBy: 100)) / 100
            let phase = s * 2.39   // golden-ratio-ish stagger so no two stars peak together
            let rate  = 0.18 + (s.truncatingRemainder(dividingBy: 9)) * 0.05  // 0.18–0.58 rad/s (4–9 s cycle)
            let size  = i % 4 == 0 ? 1.8 : (i % 3 == 0 ? 1.4 : 1.0)          // mostly tiny, a few slightly larger
            return (x, y, phase, rate, size)
        }
    }()

    var body: some View {
        // 4 fps is imperceptible for slow twinkle cycles (4–9 s) and costs almost nothing.
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in Self.stars {
                    let cx = star.x * size.width
                    let cy = star.y * size.height
                    // Opacity range: 0.02 (floor) … 0.12 (peak) — never distracting
                    let osc = 0.5 + 0.5 * sin(t * star.rate + star.phase)
                    let opacity = 0.02 + 0.10 * osc
                    let r = star.size / 2
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                               width: star.size, height: star.size)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
