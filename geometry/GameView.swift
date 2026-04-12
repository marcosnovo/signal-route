import SwiftUI

// MARK: - GameView  (telemetry dashboard)
struct GameView: View {
    @StateObject private var vm: GameViewModel
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    let isIntro: Bool
    let onDismiss: () -> Void
    let onIntroComplete: (() -> Void)?
    let onNextMission: (() -> Void)?
    let onMissions: (() -> Void)?

    /// Controls when the overlay actually appears — decoupled from vm.status
    /// so we can show the winning path before covering the board.
    @State private var overlayVisible: Bool = false
    /// Triggers a synchronized pulse on all energized tiles when the game is won.
    @State private var winPulse: Bool = false
    /// Success ring opacity for the board container flash on win.
    @State private var boardSuccessOpacity: Double = 0
    /// Position of the moving signal front during the win sweep animation.
    @State private var signalFrontRow: Int = -1
    @State private var signalFrontCol: Int = -1

    init(level: Level,
         isIntro: Bool = false,
         onDismiss: @escaping () -> Void,
         onIntroComplete: (() -> Void)? = nil,
         onNextMission: (() -> Void)? = nil,
         onMissions: (() -> Void)? = nil) {
        self.isIntro          = isIntro
        self.onDismiss        = onDismiss
        self.onIntroComplete  = onIntroComplete
        self.onNextMission    = onNextMission
        self.onMissions       = onMissions
        _vm = StateObject(wrappedValue: GameViewModel(level: level))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                header
                movesBar
                timerBar
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
            } else if !isIntro && overlayVisible && vm.status == .won {
                VictoryTelemetryView(vm: vm,
                                     onRestart: { vm.setupLevel() },
                                     onDismiss: onDismiss,
                                     onNextMission: onNextMission,
                                     onMissions: onMissions)
                    .transition(.opacity)
            } else if !isIntro && overlayVisible && vm.status == .lost {
                MissionOverlay(vm: vm,
                               onRestart: { vm.setupLevel() },
                               onDismiss: onDismiss)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.88)).combined(with: .offset(y: 24)),
                            removal:   .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
            }

            // Mechanic unlock announcement — shown once on first encounter
            if let mechanic = vm.pendingMechanicAnnouncement {
                MechanicUnlockView(mechanic: mechanic) {
                    MechanicUnlockStore.markAnnounced(mechanic)
                    vm.pendingMechanicAnnouncement = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.93)))
                .onAppear { SoundManager.play(.mechanicUnlock) }
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
                // Reset — brief fade so the board isn't jarring
                withAnimation(.easeOut(duration: 0.18)) { overlayVisible = false }
                winPulse = false
                boardSuccessOpacity = 0
                signalFrontRow = -1
                signalFrontCol = -1
            }
        }
    }

    // MARK: - Win sequence
    /// 1. Sound + success ring flash (immediate feedback).
    /// 2. Signal sweeps through the circuit in BFS order — each tile flashes briefly.
    /// 3. winPulse: cascade scale across all energized tiles.
    /// 4. Overlay appears.
    private func playWinSequence() {
        SoundManager.play(.win)
        withAnimation(.easeOut(duration: 0.20)) { boardSuccessOpacity = 0.75 }
        withAnimation(.easeOut(duration: 0.55).delay(0.28)) { boardSuccessOpacity = 0 }

        Task { @MainActor in
            // Brief pause — let the player see the completed board
            try? await Task.sleep(nanoseconds: 180_000_000)

            // ── Signal sweep through circuit path ─────────────────────
            let path = vm.signalPath
            guard !path.isEmpty else {
                // Fallback: no path data → skip to winPulse immediately
                winPulse = true
                HapticsManager.medium()
                try? await Task.sleep(nanoseconds: 450_000_000)
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) { overlayVisible = true }
                return
            }

            // Step interval scales with path length; capped between 40 ms and 110 ms
            let stepMs = min(110, max(40, 900 / path.count))
            let stepNs = UInt64(stepMs) * 1_000_000

            for (i, pos) in path.enumerated() {
                signalFrontRow = pos.0
                signalFrontCol = pos.1

                // Haptic on target tiles so player feels each connection
                if vm.tiles[pos.0][pos.1].role == .target {
                    HapticsManager.light()
                }

                try? await Task.sleep(nanoseconds: stepNs)
            }

            // Clear the moving front
            signalFrontRow = -1
            signalFrontCol = -1

            // ── Cascade scale pulse across all energized tiles ─────────
            winPulse = true
            HapticsManager.success()

            // Let the pulse settle before covering the board
            try? await Task.sleep(nanoseconds: 380_000_000)
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
                    TechLabel(text: isIntro ? S.skip : S.home)
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
                TechLabel(text: isIntro ? S.skip : S.home)
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
                TechLabel(text: S.movesRemaining, color: AppTheme.sage)
                Text("\(vm.movesLeft)")
                    .font(AppTheme.mono(38, weight: .black))
                    .foregroundStyle(movesColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: vm.movesLeft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                TechLabel(text: S.usedLabel, color: AppTheme.sage)
                Text("\(vm.movesUsed)")
                    .font(AppTheme.mono(22, weight: .bold))
                    .foregroundStyle(AppTheme.sage.opacity(0.55))
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

    // MARK: - Timer bar (only shown on timed levels)
    @ViewBuilder
    private var timerBar: some View {
        if let remaining = vm.timeRemaining, let limit = vm.currentLevel.timeLimit {
            let ratio = Double(remaining) / Double(max(1, limit))
            let timerColor: Color = ratio > 0.4 ? AppTheme.success
                                  : ratio > 0.2 ? AppTheme.accentPrimary
                                  : AppTheme.danger

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    TechLabel(text: S.timeRemaining, color: AppTheme.sage)
                    Text(timeString(remaining))
                        .font(AppTheme.mono(28, weight: .black))
                        .foregroundStyle(timerColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: remaining)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    TechLabel(text: S.elapsed, color: AppTheme.sage)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.stroke)
                                .frame(height: 3)
                            Rectangle()
                                .fill(timerColor)
                                .frame(width: g.size.width * ratio, height: 3)
                                .animation(.linear(duration: 1.0), value: remaining)
                        }
                    }
                    .frame(width: 80, height: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { TechDivider() }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }

    // MARK: - Objective banner
    private var objectiveSection: some View {
        let objType = vm.currentLevel.objectiveType
        let accentColor = objType.accentColor

        return VStack(spacing: 0) {
            // Primary row: objective label
            HStack(spacing: 10) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 14)
                Image(systemName: objType.iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accentColor)
                TechLabel(text: S.objectiveHUD, color: AppTheme.sage)
                Text("→")
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.sage.opacity(0.65))
                Text(S.objectiveText(type: vm.currentLevel.objectiveType, targets: vm.targetsTotal))
                    .font(AppTheme.mono(10, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(0.5)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)

            // Secondary row: live objective metric
            objectiveMetricRow
                .padding(.horizontal, 20)
                .padding(.bottom, 9)
        }
        .overlay(alignment: .bottom) { TechDivider() }
    }

    @ViewBuilder
    private var objectiveMetricRow: some View {
        switch vm.currentLevel.objectiveType {
        case .normal:
            EmptyView()

        case .maxCoverage:
            // Live coverage bar
            HStack(spacing: 8) {
                TechLabel(text: S.gridCoverage)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1).fill(AppTheme.stroke).frame(height: 3)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: "FFB800"))
                            .frame(width: g.size.width * CGFloat(vm.gridCoveragePercent) / 100, height: 3)
                            .animation(.easeOut(duration: 0.15), value: vm.gridCoveragePercent)
                    }
                }
                .frame(height: 3)
                TechLabel(text: "\(vm.gridCoveragePercent)%", color: Color(hex: "FFB800"))
                    .monospacedDigit()
                    .animation(.easeInOut(duration: 0.15), value: vm.gridCoveragePercent)
            }
            .padding(.top, 6)

        case .energySaving:
            // Live waste counter
            let waste = vm.energyWaste
            let exceeded = vm.energyWasteExceeded
            let wasteColor: Color = exceeded ? AppTheme.danger : AppTheme.success
            HStack(spacing: 8) {
                TechLabel(text: S.extraNodes)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < waste ? (exceeded ? AppTheme.danger : Color(hex: "FFB800")) : AppTheme.stroke)
                            .frame(width: 18, height: 3)
                            .animation(.easeOut(duration: 0.15), value: waste)
                    }
                }
                TechLabel(text: "\(waste)/2",
                          color: wasteColor)
                    .monospacedDigit()
                    .animation(.easeInOut(duration: 0.15), value: waste)
                if exceeded {
                    TechLabel(text: S.reduceNetwork, color: AppTheme.danger)
                }
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Board
    private var boardSection: some View {
        GeometryReader { geo in
            let gap: CGFloat     = AppTheme.gap
            let pad: CGFloat     = AppTheme.tilePadding
            let available        = geo.size.width - pad * 2 - gap * CGFloat(vm.gridSize - 1)
            let tileSize         = available / CGFloat(vm.gridSize)

            VStack(spacing: 0) {
                VStack(spacing: gap) {
                    ForEach(0..<vm.gridSize, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<vm.gridSize, id: \.self) { col in
                                TileView(
                                    tile:            vm.tiles[row][col],
                                    size:            tileSize,
                                    winPulse:        winPulse,
                                    animationDelay:  Double(row + col) * 0.038,
                                    signalHighlight: signalFrontRow == row && signalFrontCol == col,
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
                        .strokeBorder(AppTheme.sage.opacity(0.18), lineWidth: 0.5)
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

    // MARK: - Status panel
    private var statusPanel: some View {
        VStack(spacing: 0) {
            TechDivider()
            HStack(spacing: 0) {
                // 1. Targets online
                HUDMetric(
                    label: S.targetsOnline,
                    value: "\(vm.targetsOnline)/\(vm.targetsTotal)",
                    valueColor: vm.networkOnline ? AppTheme.accentSecondary : AppTheme.textPrimary
                )
                .animation(.easeInOut(duration: 0.20), value: vm.targetsOnline)

                metricDivider

                // 2. Objective-specific middle metric
                objectiveHUDMetric

                metricDivider

                // 3. Network status
                HUDMetric(
                    label: S.network,
                    value: vm.networkOnline ? S.online : S.offline,
                    valueColor: vm.networkOnline ? AppTheme.success : AppTheme.accentPrimary
                )
                .pulsingGlow(color: vm.networkOnline ? AppTheme.success : AppTheme.accentPrimary,
                             duration: vm.networkOnline ? 1.8 : 1.1)
                .animation(.easeInOut(duration: 0.30), value: vm.networkOnline)
            }
            .padding(.vertical, 14)
            .background(AppTheme.backgroundSecondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var objectiveHUDMetric: some View {
        switch vm.currentLevel.objectiveType {
        case .normal:
            HUDMetric(
                label: S.activeNodes,
                value: "\(vm.activeNodes)",
                valueColor: AppTheme.textPrimary
            )
            .animation(.easeInOut(duration: 0.15), value: vm.activeNodes)

        case .maxCoverage:
            HUDMetric(
                label: S.coverage,
                value: "\(vm.gridCoveragePercent)%",
                valueColor: Color(hex: "FFB800")
            )
            .animation(.easeInOut(duration: 0.15), value: vm.gridCoveragePercent)

        case .energySaving:
            HUDMetric(
                label: S.waste,
                value: "\(vm.energyWaste)/2",
                valueColor: vm.energyWasteExceeded ? AppTheme.danger : AppTheme.success
            )
            .animation(.easeInOut(duration: 0.15), value: vm.energyWaste)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(AppTheme.sage.opacity(0.22))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Hint
    private var hint: some View {
        Group {
            if isIntro {
                VStack(spacing: 5) {
                    TechLabel(text: S.rotateTilesToRouteSignal,
                              color: AppTheme.accentPrimary)
                    TechLabel(text: S.tapAnyTileToRotate, color: AppTheme.sage)
                }
            } else {
                TechLabel(text: S.tapTileToRotate, color: AppTheme.sage)
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
        VStack(spacing: 4) {
            TechLabel(text: label, color: AppTheme.sage.opacity(0.80))
            Text(value)
                .font(AppTheme.mono(14, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MissionOverlay  (win / lose)
struct MissionOverlay: View {
    @ObservedObject var vm: GameViewModel
    let onRestart: () -> Void
    let onDismiss: () -> Void
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

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
                        TechLabel(text: won ? S.statusSuccess : S.statusFailure,
                                  color: won ? AppTheme.success : AppTheme.danger)
                            .pulsingGlow(color: won ? AppTheme.success : AppTheme.danger,
                                         duration: 1.6)
                        Text(won ? S.networkRestored : S.signalLost)
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
                            OverlayStatCell(label: S.score,            value: "\(vm.score)")
                            Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 32)
                            OverlayStatCell(label: S.movesOverlay,     value: "\(vm.movesUsed)")
                            Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 32)
                            OverlayStatCell(label: S.remainingOverlay, value: "\(vm.movesLeft)")
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
                            Text(won ? S.retryLevel : S.tryAgain)
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
                                Text(S.shareResult)
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
                        Text(S.returnToBase)
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
            TechLabel(text: S.efficiencyBar, color: AppTheme.sage)
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

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    @State private var bodyRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 6) {
                    TechLabel(text: S.statusSuccess, color: AppTheme.success)
                        .pulsingGlow(color: AppTheme.success, duration: 1.6)
                    Text(S.signalRouted)
                        .font(AppTheme.mono(24, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1)
                    TechLabel(text: S.networkOnline, color: AppTheme.accentSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppTheme.surface)

                TechDivider()

                // ── Body (staggered reveal) ──────────────────────────────
                VStack(spacing: 4) {
                    TechLabel(text: S.systemCalibrationComplete)
                    TechLabel(text: S.clearedForDeployment,
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
                        Text(S.accessGranted)
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
            TechLabel(text: label, color: AppTheme.sage)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MechanicUnlockView
/// Full-screen announcement shown the first time the player encounters a new mechanic.
/// Dismissed by tapping "UNDERSTOOD" — the mechanic is then marked announced in UserDefaults.
struct MechanicUnlockView: View {
    let mechanic: MechanicType
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    @State private var bodyRevealed = false

    private let amber = Color(hex: "FFB800")

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                VStack(spacing: 10) {
                    Image(systemName: mechanic.iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(amber)
                        .pulsingGlow(color: amber, duration: 1.3)

                    TechLabel(text: S.newMechanicUnlocked, color: amber)

                    Text(S.mechanicTitle(mechanic))
                        .font(AppTheme.mono(20, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(AppTheme.surface)

                TechDivider()

                // ── Message (staggered reveal) ────────────────────────────
                Text(S.mechanicMessage(mechanic))
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.backgroundSecondary)
                    .opacity(bodyRevealed ? 1 : 0)
                    .offset(y: bodyRevealed ? 0 : 8)

                TechDivider()

                // ── CTA ──────────────────────────────────────────────────
                Button(action: onDismiss) {
                    Text(S.understood)
                        .font(AppTheme.mono(12, weight: .bold))
                        .kerning(2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(amber)
                        .foregroundStyle(Color.black)
                }
            }
            .background(AppTheme.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(amber.opacity(0.55), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.20)) {
                bodyRevealed = true
            }
        }
    }
}
