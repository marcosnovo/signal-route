import SwiftUI

// MARK: - TileView
/// Industrial conduit tile with energy-network role awareness.
///
/// Visual states:
///   .source  → warm orange background, bolt badge, always lit
///   .target  → distinct border; animates to "online" state when energized
///   .relay   → standard conduit; glows only when reachable from a source
///
/// Mechanic overlays:
///   rotationCap     → bottom-left badge showing rotations remaining; lock icon when exhausted
///   isOverloaded    → double-ring junction; armed state shows bright orange ring
///   autoDrift       → pulsing amber outer ring indicating drift instability
///   fragileTile     → top-left badge with remaining charges; red pulsing ring; burned = dark + X
///   chargeGate      → cyan border (closed) or teal border (open); bottom-right charge badge
///   interferenceZone → flickering static overlay obscuring tile orientation
struct TileView: View {
    let tile: Tile
    let size: CGFloat
    // connectedNorth/East/South/West removed — pipes are drawn from tile.connections directly,
    // so the 4 isConnected() calls per tile per render were computed but never consumed here.
    let winPulse: Bool
    /// Cascade delay for the win-pulse animation — tiles further from the source
    /// receive the win animation slightly later, creating a propagation wave effect.
    let animationDelay: Double
    /// True for the one tile currently at the signal front during the win sweep.
    /// Triggers a brief bright flash that travels through the circuit path.
    let signalHighlight: Bool
    /// True when this tile caused or contributed to the mission failure.
    /// Shows a coloured highlight on the loss screen so the player understands why they failed.
    let isFailureCulprit: Bool
    /// Opacity scale for the interference static overlay (1.0 = full noise, lower = reduced for low-skill players).
    var interferenceScale: Double = 1.0
    /// Very faint ambient warmth for tiles adjacent to the signal (energy bias hint layer).
    var isNearSignal: Bool = false
    /// This tile is the current soft hint target — receives a barely-perceptible glow.
    var isHintTarget: Bool = false
    /// Delayed hint active — hint target receives a slow breathing pulse after 12 s of inactivity.
    var isHintPulsing: Bool = false
    /// True for one brief frame after a tap that didn't improve the circuit.
    /// Drives a subtle red flash so the player understands the tap didn't help.
    var isWrongTap: Bool = false
    let onTap: () -> Void

    @State private var wrongFlash: Double = 0.0
    @State private var tapScale: CGFloat = 1.0
    @State private var energyScale: CGFloat = 1.0
    @State private var tapBounceTask: Task<Void, Never>? = nil
    @State private var energyBounceTask: Task<Void, Never>? = nil
    /// Drives the interference overlay flicker animation.
    @State private var interferenceFlicker: Double = 0.0
    /// Drives the connection snap flash (briefly non-zero when tile first energizes).
    @State private var connectionFlash: Double = 0.0
    /// Drives the signal-sweep flash that travels through the circuit on win.
    @State private var signalFlash: Double = 0.0

    /// Amber used consistently for all mechanic indicators
    private let mechanicAmber = Color(hex: "FFB800")
    /// Blue used for the one-way relay directional badge
    private let oneWayBlue = Color(hex: "5BA4CF")
    /// Red used for fragile tile indicators
    private let fragileRed = Color(hex: "E84040")
    /// Cyan used for charge gate indicators
    private let gateColor = Color(hex: "5BE8C8")

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
                    .padding(-1.5)
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

            // ── Auto-drift: pulsing amber outer ring ─────────────────────
            if tile.autoDriftDelay != nil {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(mechanicAmber.opacity(0.75), lineWidth: 1.5)
                    .padding(-2.5)
                    .pulsingGlow(color: mechanicAmber, duration: 1.1)
            }

            // ── Fragile tile: red warning ring (intensifies as charges deplete) ─
            if let remaining = tile.fragileChargesRemaining, !tile.isBurned {
                let urgency: Double = remaining == 1 ? 1.0 : 0.55
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(fragileRed.opacity(urgency * 0.85), lineWidth: 1.5)
                    .padding(-2.5)
                    .pulsingGlow(color: fragileRed, duration: remaining == 1 ? 0.55 : 1.0)
            }

            // ── Charge gate: border shows open/closed state ───────────────
            if let _ = tile.gateChargesRequired {
                if tile.isGateOpen {
                    // Open: teal glow — gate is conducting
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(gateColor.opacity(0.80), lineWidth: 1.5)
                        .padding(-2.5)
                        .shadow(color: gateColor.opacity(0.35), radius: 5)
                } else {
                    // Closed: dimmer cyan pulse — awaiting charge
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(gateColor.opacity(0.45), lineWidth: 1.5)
                        .padding(-2.5)
                        .pulsingGlow(color: gateColor, duration: 1.4)
                }
            }

            // ── Interference zone: flickering static overlay ──────────────
            // Static gradient — rendered once. Only overall opacity animates
            // so the GPU doesn't need to re-evaluate gradient stops every frame.
            if tile.hasInterference {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.black.opacity(0.14),
                                Color.white.opacity(0.04),
                                Color.black.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity((0.35 + interferenceFlicker * 0.65) * interferenceScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.20).repeatForever(autoreverses: true)) {
                            interferenceFlicker = 1.0
                        }
                    }
            }

            // ── Near-signal energy bias ──────────────────────────────────────
            // Tiles adjacent to the signal frontier get a barely-visible warm tint,
            // creating a subtle "pull" toward areas where signal wants to flow.
            if isNearSignal && !isHintTarget {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.accentPrimary.opacity(0.04))
                    .allowsHitTesting(false)
            }

            // ── Soft hint overlay ─────────────────────────────────────────────
            // When hints are active, the frontier tile receives a faint warmth.
            // After 12 s of inactivity the warmth intensifies to a slow pulse.
            // Opacity ceiling is kept far below any mechanic indicator so it feels
            // like a natural quality of the tile rather than an explicit marker.
            if isHintTarget {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.accentPrimary.opacity(isHintPulsing ? 0.11 : 0.05))
                    .allowsHitTesting(false)
                if isHintPulsing {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.accentPrimary.opacity(0.20), lineWidth: 0.5)
                        .pulsingGlow(color: AppTheme.accentPrimary, duration: 2.2)
                        .allowsHitTesting(false)
                }
            }

            // ── Failure culprit highlight ─────────────────────────────────
            // Shown on game-over when this tile caused or contributed to the loss:
            //   burned fragile tile → red ring + tint
            //   uncharged gate      → amber ring + tint
            if isFailureCulprit {
                let culpritColor: Color = tile.isBurned ? fragileRed : mechanicAmber
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(culpritColor.opacity(0.18))
                    .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(culpritColor.opacity(0.90), lineWidth: 2.0)
                    .padding(-3.0)
                    .shadow(color: culpritColor.opacity(0.50), radius: 8)
                    .allowsHitTesting(false)
            }

            // ── Connection snap flash ─────────────────────────────────────
            // Brief bright overlay that fires when a tile first becomes energized,
            // giving tactile "snap" feedback without altering the pipe shape.
            if connectionFlash > 0 {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(pipeColor.opacity(connectionFlash * 0.22))
                    .allowsHitTesting(false)
            }

            // ── Signal-sweep flash ────────────────────────────────────────
            // Bright pulse that travels through the circuit on win, driven by
            // signalHighlight from GameView. Fades out autonomously after ~280 ms.
            if signalFlash > 0 {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.white.opacity(signalFlash * 0.12))
                    .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accentPrimary.opacity(signalFlash * 0.90),
                                  lineWidth: 2.0)
                    .padding(-2.5)
                    .shadow(color: AppTheme.accentPrimary.opacity(signalFlash * 0.65), radius: 10)
                    .allowsHitTesting(false)
            }

            // ── Wrong-tap flash ──────────────────────────────────────────
            // Very faint red warmth that fades in 350 ms — tells the player this
            // tap didn't help without being punitive or alarming.
            if wrongFlash > 0 {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.red.opacity(wrongFlash * 0.22))
                    .allowsHitTesting(false)
            }

            // ── Conduit pipes ────────────────────────────────────────────
            // Outer channel shell (dimmed when locked)
            PipeShape(connections: tile.connections)
                .stroke(
                    Color.white.opacity(tile.isRotationLocked ? 0.04 : 0.09),
                    style: StrokeStyle(lineWidth: size * AppTheme.pipeOuter, lineCap: .butt)
                )

            // Inner energy core (lit when energized)
            PipeShape(connections: tile.connections)
                .stroke(
                    pipeColor,
                    style: StrokeStyle(lineWidth: size * AppTheme.pipeInner, lineCap: .round)
                )
                // Primary tight glow — follows the pipe exactly
                .shadow(
                    color: tile.isEnergized ? glowColor.opacity(0.60) : .clear,
                    radius: 5
                )
                // Secondary diffuse glow — widens the energy bloom
                .shadow(
                    color: tile.isEnergized ? glowColor.opacity(0.30) : .clear,
                    radius: 11
                )

            // ── Centre junction node ─────────────────────────────────────
            Circle()
                .fill(tile.isEnergized ? Color(hex: "252525") : Color(hex: "171717"))
                .frame(width: size * AppTheme.nodeRatio,
                       height: size * AppTheme.nodeRatio)
                .overlay(
                    Circle().strokeBorder(nodeRingColor,
                                          lineWidth: tile.isEnergized ? 1.5 : 1.0)
                )
                .shadow(
                    color: tile.isEnergized ? nodeRingColor.opacity(0.65) : .clear,
                    radius: 5
                )

            // Overloaded: outer ring (amber = idle, orange glow = armed)
            if tile.isOverloaded {
                Circle()
                    .strokeBorder(
                        tile.overloadArmed ? AppTheme.accentPrimary : mechanicAmber.opacity(0.55),
                        lineWidth: tile.overloadArmed ? 2.0 : 1.0
                    )
                    .frame(width: size * AppTheme.nodeRatio * 1.8,
                           height: size * AppTheme.nodeRatio * 1.8)
                    .shadow(
                        color: tile.overloadArmed ? AppTheme.accentPrimary.opacity(0.6) : .clear,
                        radius: 5
                    )
                    .animation(.spring(response: 0.18, dampingFraction: 0.6), value: tile.overloadArmed)
            }

            // ── Role badges (top-right corner) ───────────────────────────
            VStack {
                HStack {
                    Spacer()
                    roleBadge
                }
                Spacer()
            }
            .padding(4)

            // ── Rotation cap badge (bottom-left corner) ──────────────────
            if let remaining = tile.rotationsRemaining {
                VStack {
                    Spacer()
                    HStack {
                        rotationCapBadge(remaining: remaining)
                        Spacer()
                    }
                }
                .padding(3)
            }

            // ── One-way relay badge (bottom-right corner) ─────────────────
            // Arrow points in the direction signal flows through the tile.
            // Rotates dynamically as the player spins the tile so the constraint
            // is always readable in world-space.
            if !tile.baseBlockedInboundDirections.isEmpty,
               let flowDir = tile.blockedInboundDirections.first {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        oneWayBadge(flowDir: flowDir)
                    }
                }
                .padding(3)
            }

            // ── Exhausted overlay: dimming + lock icon ───────────────────
            if tile.isRotationLocked {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.black.opacity(0.40))
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.20, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.28))
            }

            // ── Burned overlay: dark + X mark ────────────────────────────
            if tile.isBurned {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.black.opacity(0.55))
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(fragileRed.opacity(0.50))
            }

            // ── Fragile badge (top-left) ──────────────────────────────────
            if let remaining = tile.fragileChargesRemaining, !tile.isBurned {
                VStack {
                    HStack {
                        fragileBadge(remaining: remaining)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
            }

            // ── Charge gate badge (bottom-right, only when not open) ──────
            if let required = tile.gateChargesRequired, !tile.isGateOpen {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        chargeGateBadge(received: tile.gateChargesReceived, required: required)
                    }
                }
                .padding(3)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(tapScale * energyScale)
        .onTapGesture {
            // Cancel any in-flight bounce so rapid taps don't accumulate
            tapBounceTask?.cancel()
            withAnimation(.spring(response: 0.10, dampingFraction: 0.5)) { tapScale = 0.80 }
            tapBounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) { tapScale = 1.0 }
            }
            onTap()
        }
        .onChange(of: tile.isEnergized) { _, isNowEnergized in
            guard isNowEnergized else { return }
            // Snap flash: brief bright overlay — fades in 300 ms
            connectionFlash = 1.0
            withAnimation(.easeOut(duration: 0.30)) { connectionFlash = 0 }
            // Scale bounce
            energyBounceTask?.cancel()
            let pulse: CGFloat = tile.role == .target ? 1.10 : 1.04
            withAnimation(.spring(response: 0.10, dampingFraction: 0.4)) { energyScale = pulse }
            energyBounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { energyScale = 1.0 }
            }
        }
        .onChange(of: signalHighlight) { _, isHighlit in
            guard isHighlit else { return }
            // Immediate bright flash
            signalFlash = 1.0
            // Scale pulse — slightly larger than the connection snap
            energyBounceTask?.cancel()
            withAnimation(.spring(response: 0.08, dampingFraction: 0.38)) { energyScale = 1.20 }
            energyBounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 90_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) { energyScale = 1.0 }
                // Fade the glow border after the pulse settles
                withAnimation(.easeOut(duration: 0.28)) { signalFlash = 0 }
            }
        }
        .onChange(of: winPulse) { _, pulsing in
            guard pulsing && tile.isEnergized else { return }
            // Larger cascade pulse — delayed by animationDelay so energy appears to travel
            // from source to target across the board (diagonal wave).
            energyBounceTask?.cancel()
            withAnimation(.spring(response: 0.14, dampingFraction: 0.35)
                              .delay(animationDelay)) { energyScale = 1.20 }
            let delayNanos = UInt64((animationDelay + 0.16) * 1_000_000_000)
            energyBounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: delayNanos)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) { energyScale = 1.0 }
            }
        }
        .onChange(of: isWrongTap) { _, wrong in
            guard wrong else { return }
            wrongFlash = 1.0
            withAnimation(.easeOut(duration: 0.35)) { wrongFlash = 0 }
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

    // MARK: - Rotation cap badge

    @ViewBuilder
    private func rotationCapBadge(remaining: Int) -> some View {
        let exhausted = remaining == 0
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(exhausted
                      ? Color.black.opacity(0.55)
                      : Color(hex: "1A1200").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            exhausted ? Color.white.opacity(0.10) : mechanicAmber.opacity(0.55),
                            lineWidth: 0.5
                        )
                )
            Text("\(remaining)")
                .font(AppTheme.mono(size * 0.17, weight: .bold))
                .foregroundStyle(exhausted ? Color.white.opacity(0.22) : mechanicAmber)
        }
        .frame(width: size * 0.27, height: size * 0.24)
    }

    // MARK: - One-way relay badge

    /// Small directional badge showing the signal-flow direction through the relay.
    /// `flowDir` is the world-space direction signal travels (= the blocked inbound direction,
    /// since blocking that entry forces signal to travel in that direction).
    @ViewBuilder
    private func oneWayBadge(flowDir: Direction) -> some View {
        let angle: Double = switch flowDir {
        case .north: -90
        case .east:   0
        case .south:  90
        case .west:  180
        }
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "0A141E").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(oneWayBlue.opacity(0.65), lineWidth: 0.5)
                )
            Image(systemName: "arrow.right")
                .font(.system(size: size * 0.13, weight: .bold))
                .foregroundStyle(oneWayBlue)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size * 0.27, height: size * 0.24)
        .shadow(color: oneWayBlue.opacity(0.25), radius: 2)
    }

    // MARK: - Fragile badge

    @ViewBuilder
    private func fragileBadge(remaining: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "200A0A").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(fragileRed.opacity(remaining == 1 ? 0.90 : 0.55), lineWidth: 0.5)
                )
            Text("\(remaining)")
                .font(AppTheme.mono(size * 0.17, weight: .bold))
                .foregroundStyle(fragileRed.opacity(remaining == 1 ? 1.0 : 0.80))
        }
        .frame(width: size * 0.27, height: size * 0.24)
    }

    // MARK: - Charge gate badge

    @ViewBuilder
    private func chargeGateBadge(received: Int, required: Int) -> some View {
        let remaining = required - received
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "071E1A").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(gateColor.opacity(0.65), lineWidth: 0.5)
                )
            Text("\(remaining)")
                .font(AppTheme.mono(size * 0.17, weight: .bold))
                .foregroundStyle(gateColor)
        }
        .frame(width: size * 0.27, height: size * 0.24)
    }

    // MARK: - Derived colours

    private var cellBackground: Color {
        if tile.isBurned { return Color(hex: "140808") }
        if tile.isRotationLocked { return Color(hex: "181818") }
        switch tile.role {
        case .source:
            return Color(hex: "221A14")
        case .target:
            return tile.isEnergized ? Color(hex: "192319") : Color(hex: "1A1A1F")
        default:
            if tile.isOverloaded && tile.overloadArmed {
                return Color(hex: "1E1800")   // warm amber tint when armed
            }
            return Color(hex: "1C1C1C")
        }
    }

    private var cellBorder: Color {
        if tile.isRotationLocked { return Color.white.opacity(0.06) }
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
        if tile.isRotationLocked { return Color.white.opacity(0.10) }
        guard tile.isEnergized else { return Color.white.opacity(0.22) }
        return tile.role == .target ? AppTheme.accentSecondary : AppTheme.accentPrimary
    }

    private var glowColor: Color {
        tile.role == .target ? AppTheme.accentSecondary : AppTheme.accentPrimary
    }

    private var nodeRingColor: Color {
        if tile.isRotationLocked { return Color.white.opacity(0.10) }
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
