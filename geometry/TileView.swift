import SwiftUI

// MARK: - TileView
/// Industrial conduit tile with energy-network role awareness.
///
/// Visual states:
///   .source  → warm orange background, bolt badge, always lit
///   .target  → distinct border; animates to "online" state when energized
///   .relay   → standard conduit; glows only when reachable from a source
struct TileView: View {
    let tile: Tile
    let size: CGFloat
    let connectedNorth: Bool
    let connectedEast: Bool
    let connectedSouth: Bool
    let connectedWest: Bool
    let onTap: () -> Void

    @State private var tapScale: CGFloat = 1.0
    @State private var energyScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(cellBorder, lineWidth: borderWidth)
                )

            // Source: extra outer ring so it reads as an emitter
            if tile.role == .source {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.55), lineWidth: 1.5)
                    .padding(-1.5)   // bleed slightly outside normal bounds
            }

            // Target (unpowered): dashed outline expectation ring
            if tile.role == .target && !tile.isEnergized {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(
                        AppTheme.accentSecondary.opacity(0.40),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .padding(-1.5)
            }

            // Target (powered): solid glowing border
            if tile.role == .target && tile.isEnergized {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accentSecondary.opacity(0.85), lineWidth: 1.5)
                    .padding(-1.5)
                    .shadow(color: AppTheme.accentSecondary.opacity(0.5), radius: 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // ── Conduit pipes ────────────────────────────────────────────
            // Outer channel shell
            PipeShape(connections: tile.connections)
                .stroke(
                    Color.white.opacity(0.09),
                    style: StrokeStyle(lineWidth: size * AppTheme.pipeOuter, lineCap: .butt)
                )

            // Inner energy core (lit when energized)
            PipeShape(connections: tile.connections)
                .stroke(
                    pipeColor,
                    style: StrokeStyle(lineWidth: size * AppTheme.pipeInner, lineCap: .round)
                )
                .shadow(
                    color: tile.isEnergized ? glowColor.opacity(0.55) : .clear,
                    radius: 7
                )


            // ── Centre junction node ─────────────────────────────────────
            Circle()
                .fill(Color(hex: "171717"))
                .frame(width: size * AppTheme.nodeRatio,
                       height: size * AppTheme.nodeRatio)
                .overlay(
                    Circle().strokeBorder(nodeRingColor, lineWidth: 1.0)
                )

            // ── Role badges (top-right corner) ───────────────────────────
            VStack {
                HStack {
                    Spacer()
                    roleBadge
                }
                Spacer()
            }
            .padding(4)
        }
        .frame(width: size, height: size)
        .scaleEffect(tapScale * energyScale)
        .onTapGesture {
            withAnimation(.spring(response: 0.10, dampingFraction: 0.5)) { tapScale = 0.80 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) { tapScale = 1.0 }
            }
            onTap()
        }
        .onChange(of: tile.isEnergized) { _, isNowEnergized in
            guard isNowEnergized else { return }
            let pulse: CGFloat = tile.role == .target ? 1.10 : 1.04
            withAnimation(.spring(response: 0.10, dampingFraction: 0.4)) { energyScale = pulse }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { energyScale = 1.0 }
            }
        }
    }

    // MARK: - Role badge

    @ViewBuilder
    private var roleBadge: some View {
        switch tile.role {
        case .source:
            // Bolt: always visible, always orange
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(AppTheme.accentPrimary)

        case .target:
            // Crosshair → checkmark when powered; colour shifts sage green
            Image(systemName: tile.isEnergized ? "checkmark.circle.fill" : "scope")
                .font(.system(size: size * 0.17, weight: .semibold))
                .foregroundStyle(
                    tile.isEnergized
                        ? AppTheme.accentSecondary
                        : Color.white.opacity(0.35)
                )

        default:
            EmptyView()
        }
    }

    // MARK: - Derived colours

    private var cellBackground: Color {
        switch tile.role {
        case .source:
            // Warm dark tint – communicates "active emitter"
            return Color(hex: "221A14")
        case .target:
            // Slightly cool when waiting, warm when powered
            return tile.isEnergized ? Color(hex: "192319") : Color(hex: "1A1A1F")
        default:
            return Color(hex: "1C1C1C")
        }
    }

    private var cellBorder: Color {
        switch tile.role {
        case .source:
            return AppTheme.accentPrimary.opacity(0.35)
        case .target:
            return tile.isEnergized
                ? AppTheme.accentSecondary.opacity(0.45)
                : Color.white.opacity(0.12)
        default:
            return tile.isEnergized
                ? AppTheme.accentPrimary.opacity(0.22)
                : AppTheme.stroke
        }
    }

    private var borderWidth: CGFloat {
        tile.role == .relay ? 0.5 : 0.75
    }

    /// Pipe fill colour – source/relay use orange, target uses sage green when powered
    private var pipeColor: Color {
        guard tile.isEnergized else { return Color.white.opacity(0.22) }
        return tile.role == .target ? AppTheme.accentSecondary : AppTheme.accentPrimary
    }

    private var glowColor: Color {
        tile.role == .target ? AppTheme.accentSecondary : AppTheme.accentPrimary
    }

    private var nodeRingColor: Color {
        guard tile.isEnergized else { return Color.white.opacity(0.18) }
        return tile.role == .target ? AppTheme.accentSecondary : AppTheme.accentPrimary
    }
}

// MARK: - PipeShape
/// Straight lines from tile centre to each connected edge midpoint.
struct PipeShape: Shape {
    let connections: Set<Direction>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        for dir in connections {
            let end: CGPoint
            switch dir {
            case .north: end = CGPoint(x: cx, y: rect.minY)
            case .south: end = CGPoint(x: cx, y: rect.maxY)
            case .east:  end = CGPoint(x: rect.maxX, y: cy)
            case .west:  end = CGPoint(x: rect.minX, y: cy)
            }
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: end)
        }
        return path
    }
}
