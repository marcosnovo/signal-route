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
    @State private var nodes: [NodePoint] = BackgroundSignalNodes.makeNodes()

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

    var body: some View {
        GeometryReader { geo in
            ForEach(nodes) { node in
                SignalNodeView(node: node, size: geo.size)
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
            .shadow(color: node.color.opacity(min(opacity * 1.2, 0.55)), radius: scale * 4)
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
