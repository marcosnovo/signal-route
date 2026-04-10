import SwiftUI

// MARK: - GameView  (telemetry dashboard)
struct GameView: View {
    @StateObject private var vm: GameViewModel
    let isIntro: Bool
    let onDismiss: () -> Void
    let onIntroComplete: (() -> Void)?

    /// Controls when the overlay actually appears — decoupled from vm.status
    /// so we can show the winning path before covering the board.
    @State private var overlayVisible: Bool = false
    /// Triggers a synchronized pulse on all energized tiles when the game is won.
    @State private var winPulse: Bool = false
    /// Success ring opacity for the board container flash on win.
    @State private var boardSuccessOpacity: Double = 0

    init(level: Level,
         isIntro: Bool = false,
         onDismiss: @escaping () -> Void,
         onIntroComplete: (() -> Void)? = nil) {
        self.isIntro          = isIntro
        self.onDismiss        = onDismiss
        self.onIntroComplete  = onIntroComplete
        _vm = StateObject(wrappedValue: GameViewModel(level: level))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                header
                movesBar
                objectiveSection
                boardSection
                    .padding(.vertical, 6)
                statusPanel
                Spacer(minLength: 0)
                hint
            }

            if isIntro && overlayVisible {
                IntroWinOverlay(onComplete: onIntroComplete ?? onDismiss)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.90)).combined(with: .offset(y: 24)),
                            removal:   .opacity
                        )
                    )
            } else if !isIntro && overlayVisible {
                MissionOverlay(vm: vm, onRestart: { vm.setupLevel() }, onDismiss: onDismiss)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.88)).combined(with: .offset(y: 24)),
                            removal:   .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
            }
        }
        .onChange(of: vm.status) { _, newStatus in
            switch newStatus {
            case .won:
                playWinSequence()
            case .lost:
                // No path to celebrate — show overlay right away
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                    overlayVisible = true
                }
            case .playing:
                // Reset after restart
                overlayVisible = false
                winPulse = false
                boardSuccessOpacity = 0
            }
        }
    }

    // MARK: - Win sequence
    /// 1. Energized tiles pulse (winPulse → TileView).
    /// 2. Success ring flashes around the board container.
    /// 3. After ~750 ms the player has seen the complete circuit → overlay appears.
    private func playWinSequence() {
        winPulse = true
        withAnimation(.easeOut(duration: 0.20)) { boardSuccessOpacity = 0.75 }
        withAnimation(.easeOut(duration: 0.55).delay(0.28)) { boardSuccessOpacity = 0 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                overlayVisible = true
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: isIntro ? "forward.fill" : "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    TechLabel(text: isIntro ? "SKIP" : "HOME")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.currentLevel.displayName)
                    .font(AppTheme.mono(12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(1)
                TechLabel(text: vm.currentLevel.difficulty.fullLabel,
                          color: vm.currentLevel.difficulty.color)
            }

            Spacer()

            // Invisible balance spacer
            HStack(spacing: 6) {
                Image(systemName: isIntro ? "forward.fill" : "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                TechLabel(text: isIntro ? "SKIP" : "HOME")
            }
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Moves bar
    private var movesBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                TechLabel(text: "MOVES REMAINING")
                Text("\(vm.movesLeft)")
                    .font(AppTheme.mono(38, weight: .black))
                    .foregroundStyle(movesColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: vm.movesLeft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                TechLabel(text: "USED")
                Text("\(vm.movesUsed)")
                    .font(AppTheme.mono(22, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var movesColor: Color {
        let ratio = Double(vm.movesLeft) / Double(max(1, vm.currentLevel.maxMoves))
        if ratio > 0.4 { return AppTheme.textPrimary }
        if ratio > 0.2 { return AppTheme.accentPrimary }
        return AppTheme.danger
    }

    // MARK: - Objective banner
    private var objectiveSection: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(AppTheme.accentPrimary)
                .frame(width: 2, height: 14)
            TechLabel(text: "OBJECTIVE")
            Text("→")
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.textSecondary)
            Text(vm.objectiveText)
                .font(AppTheme.mono(10, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .kerning(0.5)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Board
    private var boardSection: some View {
        GeometryReader { geo in
            let gap: CGFloat     = AppTheme.gap
            let pad: CGFloat     = AppTheme.tilePadding
            let available        = geo.size.width - pad * 2 - gap * CGFloat(vm.gridSize - 1)
            let tileSize         = available / CGFloat(vm.gridSize)

            VStack(spacing: 0) {
                TechLabel(text: "GRID ANALYSIS")
                    .padding(.bottom, 8)

                VStack(spacing: gap) {
                    ForEach(0..<vm.gridSize, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<vm.gridSize, id: \.self) { col in
                                TileView(
                                    tile:            vm.tiles[row][col],
                                    size:            tileSize,
                                    connectedNorth:  vm.isConnected(row: row, col: col, direction: .north),
                                    connectedEast:   vm.isConnected(row: row, col: col, direction: .east),
                                    connectedSouth:  vm.isConnected(row: row, col: col, direction: .south),
                                    connectedWest:   vm.isConnected(row: row, col: col, direction: .west),
                                    winPulse:        winPulse,
                                    onTap:           { vm.tap(row: row, col: col) }
                                )
                            }
                        }
                    }
                }
                .padding(pad)
                .background(AppTheme.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
                )
                // Success ring — flashes when the circuit closes, fades before overlay
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .strokeBorder(AppTheme.success.opacity(boardSuccessOpacity), lineWidth: 2.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1.08, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    // MARK: - Status panel (replaces abstract integrity bar)
    private var statusPanel: some View {
        VStack(spacing: 0) {
            TechDivider()
            HStack(spacing: 0) {
                // 1. Targets online
                HUDMetric(
                    label: "TARGETS ONLINE",
                    value: "\(vm.targetsOnline)/\(vm.targetsTotal)",
                    valueColor: vm.networkOnline ? AppTheme.accentSecondary : AppTheme.textPrimary
                )
                .animation(.easeInOut(duration: 0.2), value: vm.targetsOnline)

                metricDivider

                // 2. Active nodes
                HUDMetric(
                    label: "ACTIVE NODES",
                    value: "\(vm.activeNodes)",
                    valueColor: AppTheme.textPrimary
                )
                .animation(.easeInOut(duration: 0.15), value: vm.activeNodes)

                metricDivider

                // 3. Network status — the clearest readout of win state
                HUDMetric(
                    label: "NETWORK",
                    value: vm.networkOnline ? "ONLINE" : "OFFLINE",
                    valueColor: vm.networkOnline ? AppTheme.success : AppTheme.textSecondary
                )
                .pulsingGlow(color: AppTheme.success)
                .animation(.easeInOut(duration: 0.2), value: vm.networkOnline)
            }
            .padding(.vertical, 12)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(AppTheme.stroke)
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Hint
    private var hint: some View {
        Group {
            if isIntro {
                VStack(spacing: 5) {
                    TechLabel(text: "ROTATE TILES TO ROUTE THE SIGNAL",
                              color: AppTheme.accentPrimary)
                    TechLabel(text: "TAP ANY TILE TO ROTATE IT")
                }
            } else {
                TechLabel(text: "TAP TILE TO ROTATE")
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - HUDMetric
/// A single labelled metric cell used in the status panel.
private struct HUDMetric: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 3) {
            TechLabel(text: label)
            Text(value)
                .font(AppTheme.mono(13, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MissionOverlay  (win / lose)
struct MissionOverlay: View {
    @ObservedObject var vm: GameViewModel
    let onRestart: () -> Void
    let onDismiss: () -> Void

    /// Drives staggered reveal of the stats block on win.
    @State private var statsRevealed = false

    private var won: Bool { vm.status == .won }

    var body: some View {
        ZStack {
            Color.black.opacity(won ? 0.80 : 0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Status header ────────────────────────────────────────
                HStack {
                    Rectangle()
                        .fill(won ? AppTheme.success : AppTheme.danger)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        TechLabel(text: won ? "STATUS: SUCCESS" : "STATUS: FAILURE",
                                  color: won ? AppTheme.success : AppTheme.danger)
                            .pulsingGlow(color: won ? AppTheme.success : AppTheme.danger,
                                         duration: 1.6)
                        Text(won ? "MISSION COMPLETE" : "ROUTE FAILURE")
                            .font(AppTheme.mono(22, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                            .kerning(1)
                    }
                    .padding(.leading, 14)
                    Spacer()
                }
                .padding(20)
                .background(AppTheme.surface)

                TechDivider()

                // ── Stats (win only, staggered reveal) ───────────────────
                if won {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            OverlayStatCell(label: "SCORE",     value: "\(vm.score)")
                            Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 32)
                            OverlayStatCell(label: "MOVES",     value: "\(vm.movesUsed)")
                            Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 32)
                            OverlayStatCell(label: "REMAINING", value: "\(vm.movesLeft)")
                        }
                        .padding(.vertical, 14)

                        TechDivider()

                        // Efficiency bar
                        if let result = vm.gameResult {
                            efficiencyRow(result: result)
                        }
                    }
                    .background(AppTheme.backgroundSecondary)
                    .opacity(statsRevealed ? 1 : 0)
                    .offset(y: statsRevealed ? 0 : 10)

                    TechDivider()
                }

                // ── Actions ──────────────────────────────────────────────
                VStack(spacing: 0) {
                    Button(action: onRestart) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text(won ? "RETRY LEVEL" : "TRY AGAIN")
                                .font(AppTheme.mono(12, weight: .bold))
                                .kerning(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(won ? AppTheme.success : AppTheme.danger)
                        .foregroundStyle(.white)
                    }

                    TechDivider()

                    if won, let result = vm.gameResult {
                        ShareLink(item: result.shareText) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11, weight: .bold))
                                Text("SHARE RESULT")
                                    .font(AppTheme.mono(11, weight: .bold))
                                    .kerning(1.5)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(AppTheme.textPrimary)
                        }

                        TechDivider()
                    }

                    Button(action: onDismiss) {
                        Text("RETURN TO HOME")
                            .font(AppTheme.mono(11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .kerning(1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .background(AppTheme.surface)
            }
            .background(AppTheme.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(
                        won ? AppTheme.success.opacity(0.45) : AppTheme.strokeBright,
                        lineWidth: won ? 1.0 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .padding(.horizontal, 24)
        }
        .onAppear {
            guard won else { return }
            HapticsManager.success()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.18)) {
                statsRevealed = true
            }
        }
    }

    // MARK: Efficiency bar
    @ViewBuilder
    private func efficiencyRow(result: GameResult) -> some View {
        HStack(spacing: 10) {
            TechLabel(text: "EFFICIENCY")
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < result.filledBlocks
                              ? AppTheme.success
                              : AppTheme.stroke)
                        .frame(height: 4)
                }
            }
            TechLabel(text: "\(result.efficiencyPercent)%", color: AppTheme.success)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - IntroWinOverlay
/// Shown instead of MissionOverlay when the intro mission is won.
/// Minimal: no score/efficiency details — just confirmation and a single CTA.
struct IntroWinOverlay: View {
    let onComplete: () -> Void

    @State private var bodyRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 6) {
                    TechLabel(text: "STATUS: SUCCESS", color: AppTheme.success)
                        .pulsingGlow(color: AppTheme.success, duration: 1.6)
                    Text("SIGNAL ROUTED")
                        .font(AppTheme.mono(24, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1)
                    TechLabel(text: "NETWORK ONLINE", color: AppTheme.accentSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppTheme.surface)

                TechDivider()

                // ── Body (staggered reveal) ──────────────────────────────
                VStack(spacing: 4) {
                    TechLabel(text: "MISSION MECHANICS UNDERSTOOD")
                    TechLabel(text: "READY FOR DAILY MISSIONS",
                              color: AppTheme.accentPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.backgroundSecondary)
                .opacity(bodyRevealed ? 1 : 0)
                .offset(y: bodyRevealed ? 0 : 8)

                TechDivider()

                // ── CTA ──────────────────────────────────────────────────
                Button(action: onComplete) {
                    HStack(spacing: 10) {
                        Text("BEGIN MISSIONS")
                            .font(AppTheme.mono(12, weight: .bold))
                            .kerning(2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.accentPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .breathingCTA()
                .padding(20)
                .background(AppTheme.surface)
            }
            .background(AppTheme.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.success.opacity(0.50), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .padding(.horizontal, 28)
        }
        .onAppear {
            HapticsManager.success()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.20)) {
                bodyRevealed = true
            }
        }
    }
}

// MARK: - OverlayStatCell
struct OverlayStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTheme.mono(20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
            TechLabel(text: label)
        }
        .frame(maxWidth: .infinity)
    }
}
