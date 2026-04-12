import SwiftUI

// MARK: - BackgroundSignalNodes
/// 16 tiny network nodes distributed across the background.
/// Each node pulses independently on a randomised period — no two in sync.
///
/// Nodes are stored in @State so positions and task state survive
/// across parent view re-renders (e.g. GameCenter auth updates).
struct BackgroundSignalNodes: View {

    // @State means this array is created once when the view enters the hierarchy
    // and never recreated on parent re-renders. All node UUIDs remain stable.
    @State private var nodes:     [NodePoint]         = BackgroundSignalNodes.makeNodes()
    @State private var particles: [TravelingParticle] = BackgroundSignalNodes.makeParticles()

    private static func makeNodes() -> [NodePoint] {
        let cols = 4, rows = 4
        var pts: [NodePoint] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let xRel = (CGFloat(col) + CGFloat.random(in: 0.15...0.85)) / CGFloat(cols)
                let yRel = (CGFloat(row) + CGFloat.random(in: 0.15...0.85)) / CGFloat(rows)
                pts.append(NodePoint(
                    xRel:        xRel,
                    yRel:        yRel,
                    initialWait: Double.random(in: 0...12),
                    period:      Double.random(in: 6...16)
                ))
            }
        }
        return pts
    }

    /// Generates 8 depth particles that drift upward at varying speeds and sizes,
    /// creating a sense of travelling through space (parallax depth).
    private static func makeParticles() -> [TravelingParticle] {
        let colors: [Color] = [Color(hex: "D9E7D8"), .white, Color(hex: "4DB87A")]
        return (0..<8).map { _ in
            // Start distributed across lower 70 % of screen, travel ~40–80 % upward
            let startY = CGFloat.random(in: 0.30...1.05)
            let dist   = CGFloat.random(in: 0.40...0.80)
            return TravelingParticle(
                xRel:          CGFloat.random(in: 0.04...0.96),
                startYRel:     startY,
                travelDistRel: -dist,                             // negative = upward
                duration:      Double.random(in: 7...20),
                delay:         Double.random(in: 0...22),
                color:         colors.randomElement()!,
                baseSize:      CGFloat.random(in: 1.8...4.0)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(nodes) { node in
                SignalNodeView(node: node, size: geo.size)
            }
            ForEach(particles) { particle in
                TravelingParticleView(particle: particle, containerSize: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - NodePoint

private struct NodePoint: Identifiable {
    let id          = UUID()
    let xRel:        CGFloat   // 0…1 relative to container
    let yRel:        CGFloat
    let initialWait: Double    // seconds before first pulse
    let period:      Double    // idle seconds between pulses
    let color:       Color
    let dotSize:     CGFloat

    init(xRel: CGFloat, yRel: CGFloat, initialWait: Double, period: Double) {
        self.xRel        = xRel
        self.yRel        = yRel
        self.initialWait = initialWait
        self.period      = period
        // Mix of sage and near-white; occasional tiny orange node for variety
        let roll = CGFloat.random(in: 0...1)
        if roll < 0.55 {
            self.color = Color(hex: "D9E7D8")  // sage (accentSecondary)
        } else if roll < 0.85 {
            self.color = Color.white
        } else {
            self.color = Color(hex: "FF6A3D")  // rare accent node
        }
        self.dotSize = CGFloat.random(in: 2.5...4.0)
    }
}

// MARK: - SignalNodeView

private struct SignalNodeView: View {
    let node: NodePoint
    let size: CGSize

    @State private var opacity: Double  = 0.06
    @State private var scale:  CGFloat  = 1.0

    var body: some View {
        Circle()
            .fill(node.color)
            .frame(width: node.dotSize, height: node.dotSize)
            .scaleEffect(scale)
            .opacity(opacity)
            // Fixed radius — only color opacity animates (no re-blur per frame).
            .shadow(color: node.color.opacity(min(opacity * 1.4, 0.50)), radius: 6)
            .position(x: node.xRel * size.width, y: node.yRel * size.height)
            .task { await pulseLoop() }
    }

    // MARK: Pulse loop
    private func pulseLoop() async {
        // Stagger: each node wakes at a different time
        try? await Task.sleep(nanoseconds: nanoseconds(node.initialWait))

        while !Task.isCancelled {
            // ── Activate ────────────────────────────────────────────────
            let peakOpacity = Double.random(in: 0.32...0.55)
            let peakScale   = CGFloat.random(in: 1.18...1.38)
            withAnimation(.easeOut(duration: 0.25)) {
                opacity = peakOpacity
                scale   = peakScale
            }

            // Hold at peak
            try? await Task.sleep(nanoseconds: nanoseconds(Double.random(in: 0.30...0.55)))
            guard !Task.isCancelled else { return }

            // ── Deactivate ───────────────────────────────────────────────
            withAnimation(.easeIn(duration: 0.55)) {
                opacity = 0.06
                scale   = 1.0
            }

            // Idle until next pulse
            try? await Task.sleep(nanoseconds: nanoseconds(node.period))
        }
    }

    private func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}

// MARK: - TravelingParticle

/// A dot that drifts in a fixed direction across the screen, looping endlessly.
/// Small size + slow speed = background (far away). Large + fast = foreground (near).
private struct TravelingParticle: Identifiable {
    let id            = UUID()
    let xRel:          CGFloat   // fixed horizontal lane (0…1)
    let startYRel:     CGFloat   // Y at the start of each trip (0…1)
    let travelDistRel: CGFloat   // signed distance to travel (negative = upward)
    let duration:      Double    // seconds to complete one trip
    let delay:         Double    // initial stagger before first trip
    let color:         Color
    let baseSize:      CGFloat   // dot diameter
}

// MARK: - TravelingParticleView

private struct TravelingParticleView: View {
    let particle:      TravelingParticle
    let containerSize: CGSize

    @State private var yRel:     CGFloat
    @State private var opacity:  Double  = 0
    @State private var dotScale: CGFloat = 0.5

    init(particle: TravelingParticle, containerSize: CGSize) {
        self.particle      = particle
        self.containerSize = containerSize
        _yRel = State(initialValue: particle.startYRel)
    }

    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.baseSize, height: particle.baseSize)
            .scaleEffect(dotScale)
            .opacity(opacity)
            // No shadow on tiny travel dots — they're 1.8–4 pt; shadow cost exceeds visual benefit.
            .position(
                x: particle.xRel      * containerSize.width,
                y: yRel               * containerSize.height
            )
            .task { await travelLoop() }
    }

    private func travelLoop() async {
        // Each particle starts at a different time so they're never all in sync
        try? await Task.sleep(nanoseconds: UInt64(particle.delay * 1_000_000_000))

        while !Task.isCancelled {
            // ── Snap back to start (invisible) ─────────────────────────
            yRel     = particle.startYRel
            dotScale = 0.5
            opacity  = 0
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            // ── Fade in ─────────────────────────────────────────────────
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = Double.random(in: 0.14...0.26)
            }

            // ── Travel: linear motion + subtle size growth ──────────────
            // Growing from 0.5→ ~1.0 scale simulates approaching the viewer
            let endScale = CGFloat.random(in: 0.85...1.25)
            withAnimation(.linear(duration: particle.duration)) {
                yRel     = particle.startYRel + particle.travelDistRel
                dotScale = endScale
            }

            // ── Fade out near end of trip ────────────────────────────────
            let fadeStartNS = UInt64(max(0, particle.duration - 1.4) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: fadeStartNS)
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 1.4)) { opacity = 0 }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
        }
    }
}
