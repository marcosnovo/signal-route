import SwiftUI

// MARK: - GameView  (telemetry dashboard)
struct GameView: View {
    @StateObject private var vm: GameViewModel
    @EnvironmentObject private var settings:  SettingsStore
    @EnvironmentObject private var gcManager: GameCenterManager
    private var S: AppStrings { AppStrings(lang: settings.language) }
    let isIntro: Bool
    let onDismiss: () -> Void
    let onIntroComplete: (() -> Void)?
    let onNextMission: (() -> Void)?
    let onMissions: (() -> Void)?
    /// Called immediately when a non-intro mission is won, before the win animation completes.
    /// Receives the completed level and the LevelUpEvent (nil if no progression change).
    let onWin: ((Level, LevelUpEvent?) -> Void)?
    /// Called when a mission ends in failure AND the player made ≥1 tap (hasInteracted).
    /// Used by ContentView to record a daily attempt consumption.
    let onFail: ((Level) -> Void)?
    let onUpgrade: (() -> Void)?

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
    /// True while the SectorCompleteView banner is visible between the win sequence and victory screen.
    @State private var showSectorComplete: Bool = false

    /// Queue for mechanic-unlock story beats shown right after the tutorial overlay closes.
    @State private var mechanicStoryQueue = StoryBeatQueue()
    /// Brief red ring flash when a working circuit connection is broken by a rotation.
    @State private var circuitErrorFlash: Double = 0
    /// Shown after mission 3 (first hook): "SIGNAL ESTABLISHED" + progress counter.
    @State private var showMilestone: Bool = false
    /// Brief loading overlay shown on mission start — masks SwiftUI view rebuild jank.
    @State private var missionLoading: Bool = true

    init(level: Level,
         isIntro: Bool = false,
         onDismiss: @escaping () -> Void,
         onIntroComplete: (() -> Void)? = nil,
         onNextMission: (() -> Void)? = nil,
         onMissions: (() -> Void)? = nil,
         onWin: ((Level, LevelUpEvent?) -> Void)? = nil,
         onFail: ((Level) -> Void)? = nil,
         onUpgrade: (() -> Void)? = nil) {
        self.isIntro          = isIntro
        self.onDismiss        = onDismiss
        self.onIntroComplete  = onIntroComplete
        self.onNextMission    = onNextMission
        self.onMissions       = onMissions
        self.onWin            = onWin
        self.onFail           = onFail
        self.onUpgrade        = onUpgrade
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

            if isIntro && overlayVisible && vm.status == .won {
                IntroWinOverlay(onComplete: onIntroComplete ?? onDismiss)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.90)).combined(with: .offset(y: 24)),
                            removal:   .opacity
                        )
                    )
            } else if isIntro && overlayVisible && vm.status == .lost {
                IntroFailOverlay(onRetry: { vm.setupLevel() })
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.90)).combined(with: .offset(y: 24)),
                            removal:   .opacity
                        )
                    )
            } else if !isIntro && overlayVisible && vm.status == .won {
                VictoryTelemetryView(vm: vm,
                                     onRestart: {
                                         // Gate every retry: daily limit may have armed during this session
                                         if EntitlementStore.shared.canPlay(vm.currentLevel) {
                                             vm.setupLevel()
                                         } else {
                                             onDismiss()
                                         }
                                     },
                                     onDismiss: onDismiss,
                                     onNextMission: onNextMission,
                                     onMissions: onMissions,
                                     onUpgrade: onUpgrade)
                    .transition(.opacity)
            } else if !isIntro && overlayVisible && vm.status == .lost {
                MissionOverlay(vm: vm,
                               onRestart: {
                                   // Gate every retry: daily limit may have armed during this session
                                   if EntitlementStore.shared.canPlay(vm.currentLevel) {
                                       vm.setupLevel()
                                   } else {
                                       onDismiss()
                                   }
                               },
                               onDismiss: onDismiss)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.88)).combined(with: .offset(y: 24)),
                            removal:   .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
            }

            // Sector complete banner — shown once when all missions in a sector are done
            if showSectorComplete, let grant = vm.pendingPassGrant {
                SectorCompleteView(pass: grant)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: 18)),
                            removal:   .opacity.combined(with: .scale(scale: 1.02))
                        )
                    )
            }

            // Mechanic unlock announcement — shown once on first encounter
            if let mechanic = vm.pendingMechanicAnnouncement {
                MechanicUnlockView(mechanic: mechanic) {
                    MechanicUnlockStore.markAnnounced(mechanic)
                    vm.pendingMechanicAnnouncement = nil
                    // Surface the narrative beat for this mechanic, if unseen
                    let ctx = StoryContext.forMechanic(mechanic, level: ProgressionStore.profile.level)
                    if let beat = StoryStore.pending(for: .mechanicUnlocked, context: ctx) {
                        mechanicStoryQueue.enqueue(beat)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.93)))
                .onAppear { SoundManager.play(.mechanicUnlock) }
            }

            // First-hook milestone — auto-dismissed after 2.2 s, then VictoryTelemetryView appears
            if showMilestone {
                MilestoneView(
                    completedCount: vm.currentLevel.id,
                    totalCount: LevelGenerator.levels.count
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(80)
            }

            // Mechanic story beat — appears after the tutorial overlay closes
            // .id(beat.id) forces a fresh StoryBeatView instance (clean @State) on each new beat,
            // matching the same pattern used by StoryModal in ContentView.
            if let beat = mechanicStoryQueue.current {
                StoryBeatView(beat: beat) { mechanicStoryQueue.advance() }
                    .id(beat.id)
                    .transition(.opacity)
                    .zIndex(200)
            }

            // Mission loading overlay — immediate dark screen with mission ID,
            // masks SwiftUI view hierarchy rebuild and board generation jank.
            if missionLoading {
                MissionLoadingOverlay(missionId: vm.currentLevel.id)
                    .transition(.opacity)
                    .zIndex(300)
            }
        }
        .task {
            // Recover any mechanic story beats orphaned by a prior app kill.
            // If a mechanic was announced (MechanicUnlockStore) but its story beat
            // was never marked as seen (StoryStore), re-enqueue it now.
            for mechanic in MechanicType.allCases where MechanicUnlockStore.hasAnnounced(mechanic) {
                let ctx = StoryContext.forMechanic(mechanic, level: ProgressionStore.profile.level)
                if let beat = StoryStore.pending(for: .mechanicUnlocked, context: ctx) {
                    mechanicStoryQueue.enqueue(beat)
                }
            }
            // Let SwiftUI finish its first layout pass, then reveal the board.
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeOut(duration: 0.25)) { missionLoading = false }
        }
        .onDisappear {
            // If the player exits mid-game (not via win or loss), record as abandon
            if vm.status == .playing {
                PlayerSkillTracker.shared.recordAbandon()
                SessionTracker.shared.recordAbandon()
            }
        }
        .onChange(of: vm.targetsOnline) { old, new in
            // Circuit broke — a rotation just disconnected a previously working target.
            // Brief red ring pulse so the player understands the tap was harmful.
            guard new < old, vm.status == .playing else { return }
            circuitErrorFlash = 1.0
            withAnimation(.easeOut(duration: 0.45)) { circuitErrorFlash = 0 }
        }
        .onChange(of: overlayVisible) { _, visible in
            if visible && vm.status == .won {
                AudioManager.shared.transition(to: .victory)
            } else if !visible {
                AudioManager.shared.transition(to: .inMission)
            }
        }
        .onChange(of: mechanicStoryQueue.current) { _, beat in
            // Duck music while an in-game story beat is visible, restore when it closes.
            if beat != nil { AudioManager.shared.duck() } else { AudioManager.shared.unduck() }
        }
        // Reactive audio: intensity ramp as targets connect
        .onChange(of: vm.targetsOnline) { old, new in
            guard vm.status == .playing else { return }
            let total = max(1, vm.targetsTotal)
            AudioManager.shared.setMissionIntensity(Float(new) / Float(total))
            // Near-failure: circuit broke — treat disconnection like a miss if we're struggling
            if new < old, Float(vm.movesLeft) / Float(max(1, vm.movesLeft + vm.movesUsed)) < 0.30 {
                AudioManager.shared.missEvent()
            }
        }
        // Near-failure: moves running low (≤20% remaining)
        .onChange(of: vm.movesLeft) { _, left in
            guard vm.status == .playing else { return }
            let total = max(1, left + vm.movesUsed)
            let ratio = Float(left) / Float(total)
            AudioManager.shared.setNearFailure(left > 0 && ratio <= 0.20)
        }
        // Near-failure: timer ticking down (≤6 s)
        .onChange(of: vm.timeRemaining) { _, remaining in
            guard vm.status == .playing else { return }
            if let r = remaining {
                AudioManager.shared.setNearFailure(r > 0 && r <= 6)
            }
        }
        .onChange(of: vm.status) { _, newStatus in
            switch newStatus {
            case .won:
                AudioManager.shared.setNearFailure(false)
                AudioManager.shared.setMissionIntensity(0)
                playWinSequence()
            case .lost:
                AudioManager.shared.setNearFailure(false)
                AudioManager.shared.setMissionIntensity(0)
                // Record attempt if the player actually interacted (≥1 tap)
                if !isIntro && vm.hasInteracted { onFail?(vm.currentLevel) }
                // No path to celebrate — show overlay right away
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                    overlayVisible = true
                }
            case .playing:
                AudioManager.shared.setNearFailure(false)
                AudioManager.shared.setMissionIntensity(0)
                // Reset — brief fade so the board isn't jarring
                withAnimation(.easeOut(duration: 0.18)) { overlayVisible = false }
                winPulse = false
                boardSuccessOpacity = 0
                signalFrontRow = -1
                signalFrontCol = -1
                gcManager.clearRankFeedback()
                showSectorComplete = false
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
        // Heavy haptic 100 ms after sound — emotional peak, console-grade win feedback
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            HapticsManager.heavy()
        }
        withAnimation(.easeOut(duration: 0.20)) { boardSuccessOpacity = 0.75 }
        withAnimation(.easeOut(duration: 0.55).delay(0.28)) { boardSuccessOpacity = 0 }
        // Notify ContentView immediately so it can collect story beats while context is accurate
        if !isIntro {
            onWin?(vm.currentLevel, vm.lastLevelUpEvent)
            // Submit cumulative leaderboard score to Game Center (fire-and-forget)
            let leaderboardScore = ProgressionStore.profile.leaderboardScore
            if leaderboardScore > 0 {
                Task { await gcManager.submitScore(leaderboardScore) }
            }
        }

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
                let navigated1 = await showSectorCompleteIfNeeded()
                if navigated1 {
                    onMissions?()
                } else {
                    autoAdvanceOrOverlay()
                }
                return
            }

            // Step interval scales with path length; capped between 40 ms and 110 ms
            let stepMs = min(110, max(40, 900 / path.count))
            let stepNs = UInt64(stepMs) * 1_000_000

            for (_, pos) in path.enumerated() {
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
            let navigated = await showSectorCompleteIfNeeded()
            if navigated {
                onMissions?()
            } else {
                autoAdvanceOrOverlay()
            }
        }
    }

    /// Flow-loop routing after the win animation settles.
    ///
    /// - Intro level: jump directly to the next step (no overlay).
    /// - Missions 1–7: auto-advance to next mission after a short pause — addictive loop, no overlay.
    /// - Mission 8 (first time): show the "SIGNAL ESTABLISHED" milestone for 2.2 s, then VictoryTelemetryView.
    /// - Mission 8+: show the standard VictoryTelemetryView overlay.
    @MainActor
    private func autoAdvanceOrOverlay() {
        if isIntro {
            (onIntroComplete ?? onDismiss)()
        } else if vm.currentLevel.id <= 7 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                (onNextMission ?? onDismiss)()
            }
        } else if vm.currentLevel.id == 8 && !OnboardingStore.hasShownFirstHook {
            OnboardingStore.markFirstHookShown()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.76)) {
                showMilestone = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeOut(duration: 0.30)) { showMilestone = false }
                try? await Task.sleep(nanoseconds: 320_000_000)
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                    overlayVisible = true
                }
            }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                overlayVisible = true
            }
        }
    }

    // MARK: - Sector complete interstitial

    /// Shows the sector-complete banner for 4.2 s, then fades it out and signals
    /// that the caller should navigate to the Mission Map instead of VictoryTelemetryView.
    /// Returns false immediately if no pass was granted this win.
    @MainActor
    @discardableResult
    private func showSectorCompleteIfNeeded() async -> Bool {
        guard vm.pendingPassGrant != nil else { return false }
        SoundManager.play(.sectorComplete)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            showSectorComplete = true
        }
        try? await Task.sleep(nanoseconds: 4_200_000_000)
        withAnimation(.easeOut(duration: 0.35)) {
            showSectorComplete = false
        }
        vm.pendingPassGrant = nil
        try? await Task.sleep(nanoseconds: 380_000_000)
        return true
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
            .opacity(isIntro ? 0 : 1)
            .disabled(isIntro)

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
                TechLabel(text: vm.activeAdjustments.isHardMode ? S.parLabel : S.usedLabel,
                          color: AppTheme.sage)
                Text(vm.activeAdjustments.isHardMode
                     ? "\(vm.currentLevel.minimumRequiredMoves)"
                     : "\(vm.movesUsed)")
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
        // Use actual starting moves (clamped by setupLevel) rather than raw maxMoves,
        // so colour thresholds remain correct in hard mode.
        let startingMoves = max(vm.currentLevel.minimumRequiredMoves,
                                vm.currentLevel.maxMoves + vm.activeAdjustments.extraMoves)
        let ratio = Double(vm.movesLeft) / Double(max(1, startingMoves))
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
                                    tile:             vm.tiles[row][col],
                                    size:             tileSize,
                                    winPulse:         winPulse,
                                    animationDelay:   Double(row + col) * 0.038,
                                    signalHighlight:  signalFrontRow == row && signalFrontCol == col,
                                    isFailureCulprit: vm.status == .lost
                                        && vm.culpritTiles.contains { $0.0 == row && $0.1 == col },
                                    interferenceScale: vm.activeAdjustments.interferenceScale,
                                    isNearSignal:     vm.isNearSignal(row: row, col: col),
                                    isHintTarget:     vm.hintEnabled && vm.hintTileRow == row && vm.hintTileCol == col,
                                    isHintPulsing:    vm.hintPulsing,
                                    isWrongTap:       vm.wrongTapRow == row && vm.wrongTapCol == col,
                                    onTap:            { vm.tap(row: row, col: col) }
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
                // Circuit error ring — brief red pulse when a working connection breaks
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .strokeBorder(Color.red.opacity(circuitErrorFlash * 0.55), lineWidth: 2.0)
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

    /// Returns true when the tile at (row, col) is adjacent to at least one energized tile
    /// but is not itself energized — used to drive the energy-bias hint layer.


    private var metricDivider: some View {
        Rectangle()
            .fill(AppTheme.sage.opacity(0.22))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Hint
    // Invisible learning: no explanatory text for the first 3 levels (intro + missions 1-2).
    // The subtle tile glow teaches the mechanic without words.
    // From mission 3 onward the standard TAP TO ROTATE label reappears.
    private var hint: some View {
        Group {
            if !isIntro && vm.currentLevel.id > 2 {
                TechLabel(text: S.tapTileToRotate, color: AppTheme.sage)
            }
            // else: no text — learning happens through the glow hint on the key tile
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
                        if !won {
                            TechLabel(text: S.failureCauseLabel(vm.failureCause),
                                      color: AppTheme.danger.opacity(0.75))
                            Text(S.failureCauseHint(vm.failureCause))
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(AppTheme.sage.opacity(0.60))
                                .kerning(0.5)
                            if vm.consecutiveFailures >= 2 {
                                Text(S.frustrationMessage(failures: vm.consecutiveFailures))
                                    .font(AppTheme.mono(9, weight: .semibold))
                                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.80))
                                    .kerning(1.5)
                                    .padding(.top, 2)
                            }
                        }
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
                            Text(won ? S.retryLevel : S.retryLabel)
                                .font(AppTheme.mono(won ? 12 : 14, weight: .bold))
                                .kerning(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: won ? 48 : 64)
                        .background(won ? AppTheme.success : AppTheme.accentPrimary)
                        .foregroundStyle(.white)
                    }
                    .breathingCTA()

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

// MARK: - IntroFailOverlay
/// Shown when the intro mission runs out of moves without completing the circuit.
/// Explains the objective and offers a retry button.
struct IntroFailOverlay: View {
    let onRetry: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    @State private var bodyRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 6) {
                    TechLabel(text: S.statusFailure, color: AppTheme.danger)
                        .pulsingGlow(color: AppTheme.danger, duration: 1.6)
                    Text(S.routingFailed)
                        .font(AppTheme.mono(24, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1)
                    TechLabel(text: S.networkDisconnected, color: AppTheme.danger.opacity(0.80))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppTheme.surface)

                TechDivider()

                // ── Body (staggered reveal) ──────────────────────────────
                VStack(spacing: 8) {
                    TechLabel(text: S.signalLost, color: AppTheme.danger)
                    Text(S.introFailInstruction)
                        .font(AppTheme.mono(11, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .kerning(0.5)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(AppTheme.backgroundSecondary)
                .opacity(bodyRevealed ? 1 : 0)
                .offset(y: bodyRevealed ? 0 : 8)

                TechDivider()

                // ── CTA ──────────────────────────────────────────────────
                Button(action: onRetry) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text(S.retryMission)
                            .font(AppTheme.mono(12, weight: .bold))
                            .kerning(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.danger)
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
                    .strokeBorder(AppTheme.danger.opacity(0.50), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .padding(.horizontal, 28)
        }
        .onAppear {
            HapticsManager.error()
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

// MARK: - SectorCompleteView
/// Full-screen cinematic interstitial shown between the win animation and the Mission Map
/// when the player completes every mission in a sector for the first time.
/// Staggered reveal: sector name → COMPLETE → divider → access granted → pass card → serial.
/// Parent auto-navigates to Mission Map after 4.2 s.
struct SectorCompleteView: View {
    let pass: PlanetPass

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    /// Planet color and identity derived directly from the pass's own planetIndex.
    private var planet: Planet {
        Planet.catalog[min(pass.planetIndex, Planet.catalog.count - 1)]
    }
    /// The name of the sector just completed — localized via AppStrings.
    private var completedName: String { S.planetName(pass.planetName) }
    /// The name of the next planet being unlocked — nil when this is the final sector.
    private var nextPlanetName: String? {
        let nextIdx = pass.planetIndex + 1
        guard nextIdx < Planet.catalog.count else { return nil }
        return S.planetName(Planet.catalog[nextIdx].name)
    }

    @State private var titleAppeared   = false
    @State private var dividerAppeared = false
    @State private var accessAppeared  = false
    @State private var cardAppeared    = false
    @State private var serialAppeared  = false
    @State private var passImage: UIImage? = nil

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Planet name + COMPLETE ───────────────────────────────
                VStack(spacing: 8) {
                    TechLabel(text: completedName, color: planet.color.opacity(0.75))
                    Text(S.zoneComplete)
                        .font(AppTheme.mono(44, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(-1.0)
                }
                .opacity(titleAppeared ? 1 : 0)
                .offset(y: titleAppeared ? 0 : 18)
                .padding(.bottom, 28)

                // ── Animated divider line ─────────────────────────────────
                Rectangle()
                    .fill(planet.color.opacity(0.55))
                    .frame(width: dividerAppeared ? 110 : 0, height: 1)
                    .animation(.easeOut(duration: 0.40).delay(0.45), value: dividerAppeared)
                    .padding(.bottom, 24)

                // ── Next planet + ACCESS GRANTED ──────────────────────────
                VStack(spacing: 6) {
                    if let next = nextPlanetName {
                        Text(next)
                            .font(AppTheme.mono(11, weight: .semibold))
                            .foregroundStyle(planet.color)
                            .tracking(3)
                    }
                    Text(S.accessGranted)
                        .font(AppTheme.mono(13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .tracking(4)
                }
                .opacity(accessAppeared ? 1 : 0)
                .offset(y: accessAppeared ? 0 : 10)
                .padding(.bottom, 42)

                // ── Planet Pass card ──────────────────────────────────────
                Group {
                    if let img = passImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 290)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: planet.color.opacity(0.40), radius: 28, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(planet.color.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(planet.color.opacity(0.18), lineWidth: 1)
                            )
                            .frame(width: 270, height: 152)
                    }
                }
                .opacity(cardAppeared ? 1 : 0)
                .scaleEffect(cardAppeared ? 1 : 0.80)
                .rotation3DEffect(.degrees(cardAppeared ? 0 : -8), axis: (x: 1, y: 0, z: 0))
                .padding(.bottom, 28)

                // ── Serial code ───────────────────────────────────────────
                TechLabel(text: pass.serialCode, color: .white.opacity(0.22))
                    .opacity(serialAppeared ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.72).delay(0.10)) {
                titleAppeared = true
            }
            dividerAppeared = true
            withAnimation(.spring(response: 0.42, dampingFraction: 0.80).delay(0.78)) {
                accessAppeared = true
            }
            withAnimation(.spring(response: 0.60, dampingFraction: 0.62).delay(1.15)) {
                cardAppeared = true
            }
            withAnimation(.easeIn(duration: 0.36).delay(1.72)) {
                serialAppeared = true
            }
        }
        .task {
            let p       = pass
            let profile = ProgressionStore.profile
            passImage   = await Task.detached(priority: .userInitiated) {
                TicketRenderer.render(pass: p, profile: profile)
            }.value
        }
    }
}

// MARK: - MilestoneView
/// Brief first-hook celebration shown after mission 3 is won for the first time.
/// Displays "SIGNAL ESTABLISHED" + a progress counter (e.g. "3 / 180 MISSIONS").
/// Auto-dismissed by the parent after 2.2 s; no CTA required.
struct MilestoneView: View {
    let completedCount: Int
    let totalCount: Int

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var iconScale: CGFloat = 0.4
    @State private var titleRevealed  = false
    @State private var counterRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 28) {

                // ── Animated success icon ───────────────────────────────
                ZStack {
                    Circle()
                        .fill(AppTheme.success.opacity(0.10))
                        .frame(width: 96, height: 96)
                    Circle()
                        .strokeBorder(AppTheme.success.opacity(0.30), lineWidth: 1.5)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(AppTheme.success)
                        .pulsingGlow(color: AppTheme.success, duration: 1.4)
                }
                .scaleEffect(iconScale)

                // ── Title ──────────────────────────────────────────────
                VStack(spacing: 6) {
                    TechLabel(text: S.statusSuccess, color: AppTheme.success)
                    Text(S.signalEstablished)
                        .font(AppTheme.mono(22, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1.5)
                }
                .opacity(titleRevealed ? 1 : 0)
                .offset(y: titleRevealed ? 0 : 10)

                // ── Progress counter + bar ─────────────────────────────
                VStack(spacing: 12) {
                    Text(S.missionProgress(completedCount, totalCount))
                        .font(AppTheme.mono(12, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                        .kerning(2)
                        .monospacedDigit()

                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.stroke)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.success)
                                .frame(
                                    width: counterRevealed
                                        ? g.size.width * CGFloat(completedCount) / CGFloat(max(1, totalCount))
                                        : 0,
                                    height: 3
                                )
                                .animation(.easeOut(duration: 0.90), value: counterRevealed)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: 200)
                }
                .opacity(counterRevealed ? 1 : 0)
                .offset(y: counterRevealed ? 0 : 8)
            }
            .padding(44)
        }
        .onAppear {
            HapticsManager.success()
            withAnimation(.spring(response: 0.50, dampingFraction: 0.58)) {
                iconScale = 1.0
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.22)) {
                titleRevealed = true
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.45)) {
                counterRevealed = true
            }
        }
    }
}

// MARK: - MissionLoadingOverlay
/// Full-screen dark overlay shown briefly while the board initializes.
/// Gives instant visual feedback on tap and masks any SwiftUI rebuild jank.
private struct MissionLoadingOverlay: View {
    let missionId: Int
    @State private var lineProgress: CGFloat = 0
    @State private var labelOpacity: Double = 0

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("MISSION \(String(format: "%03d", missionId))")
                    .font(AppTheme.mono(14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .opacity(labelOpacity)

                // Animated signal line
                GeometryReader { geo in
                    Capsule()
                        .fill(AppTheme.accentPrimary.opacity(0.6))
                        .frame(width: geo.size.width * lineProgress, height: 2)
                }
                .frame(width: 120, height: 2)

                Text("INITIALIZING")
                    .font(AppTheme.mono(9, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    .opacity(labelOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) { labelOpacity = 1 }
            withAnimation(.easeInOut(duration: 0.30)) { lineProgress = 1 }
        }
    }
}
