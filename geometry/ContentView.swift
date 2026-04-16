import SwiftUI

// Posted by DevMenuView to replay the intro without touching main game progress.
extension Notification.Name {
    static let devReplayOnboarding = Notification.Name("geometry.devReplayOnboarding")
}

struct ContentView: View {
    @State private var activeLevel: Level?        = nil
    @State private var showingLevelSelect: Bool   = false
    @State private var showingPaywall: Bool         = false
    @State private var paywallContext: PaywallContext = .nextMissionBlocked
    // Stored so onNextMission can pick the right post-win context (postVictory vs sectorExcitement)
    @State private var lastWinEvent: LevelUpEvent?  = nil
    // Armed by onWin when limit is reached; fires automatically when player returns to Home
    @State private var pendingPaywallContext: PaywallContext? = nil

    // ── Multi-step intro flow ──────────────────────────────────────────────
    /// nil = intro complete (player goes to Home as normal).
    enum IntroStep: Equatable {
        case firstLaunchBeats       // StoryModal sequence for firstLaunch trigger
        case narrative              // 4-panel NarrativeIntroView
        case gameplay               // intro mission GameView
        case clearance              // MissionClearanceView
        case firstMissionReadyBeat  // StoryModal beat before Mission 1
    }
    @State private var introStep: IntroStep? = Self.initialIntroStep()

    // ── Story beat system ──────────────────────────────────────────────────
    /// Queue of pending narrative beats — drives both intro flow and post-win beats.
    @State private var storyQueue = StoryBeatQueue()

    private static func initialIntroStep() -> IntroStep? {
        guard !OnboardingStore.hasCompletedIntro else { return nil }
        // Instant play: skip story beats and narrative panels — go straight to the intro mission.
        // Mark narrative as seen so relaunches don't fall back to the panel flow.
        OnboardingStore.markNarrativeSeen()
        return .gameplay
    }

    var body: some View {
        ZStack {
            if let step = introStep {
                switch step {

                // ── Step 0: firstLaunch story beats ───────────────────────
                // Dark backdrop only — the StoryModal overlay (zIndex 50) renders
                // on top. When the queue empties, .onChange transitions to .narrative.
                case .firstLaunchBeats:
                    Color.black.ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)
                        .onAppear {
                            let beats = StoryStore.pendingAll(for: .firstLaunch)
                            if beats.isEmpty {
                                withAnimation(.easeIn(duration: 0.35)) { introStep = .narrative }
                            } else {
                                storyQueue.enqueue(beats)
                            }
                        }

                // ── Step 4b: firstMissionReady beat ───────────────────────
                // Shown after MissionClearanceView — same dark backdrop pattern.
                // When the queue empties, .onChange opens Mission 1.
                case .firstMissionReadyBeat:
                    Color.black.ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)

                // ── Step 1: 4-panel narrative ─────────────────────────────
                case .narrative:
                    NarrativeIntroView {
                        OnboardingStore.markNarrativeSeen()
                        withAnimation(.easeIn(duration: 0.35)) { introStep = .gameplay }
                    }
                    .transition(.opacity)
                    .zIndex(10)

                // ── Step 2: gameplay onboarding mission ───────────────────
                case .gameplay:
                    GameView(
                        level: LevelGenerator.introLevel,
                        isIntro: true,
                        onDismiss: {
                            // Back/skip — don't mark complete; show intro again next launch
                            introStep = nil
                        },
                        onIntroComplete: {
                            // Flow loop: mark complete and go directly to Mission 1 — no overlay, no beat.
                            OnboardingStore.markIntroCompleted()
                            introStep   = nil
                            activeLevel = LevelGenerator.levels.first
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)

                // ── Step 3: "you are cleared" confirmation ─────────────────
                // Kept in enum for dev-replay compatibility; not entered in normal flow.
                case .clearance:
                    Color.clear.zIndex(10)
                }

            } else if let level = activeLevel {
                GameView(
                    level: level,
                    onDismiss: { activeLevel = nil },
                    onNextMission: {
                        // Navigate to the level immediately after the current one in the catalog.
                        // Using the sequential next (not profile.nextMission) keeps the button
                        // consistent with what VictoryTelemetryView displays.
                        let levels = LevelGenerator.levels
                        if let idx = levels.firstIndex(where: { $0.id == level.id }),
                           idx + 1 < levels.count {
                            // Clear pending auto-show — this tap handles the paywall directly.
                            pendingPaywallContext = nil
                            // Pick celebratory context based on last win event.
                            let ctx = PaywallMomentSelector.contextAfterWin(
                                event: lastWinEvent, entitlement: EntitlementStore.shared
                            ) ?? .postVictory
                            tryPlay(levels[idx + 1], context: ctx)
                        }
                    },
                    onMissions: { activeLevel = nil; showingLevelSelect = true },
                    onWin: { wonLevel, event in
                        lastWinEvent = event
                        EntitlementStore.shared.recordAttempt(wonLevel, didWin: true)
                        Task { await CloudSaveManager.shared.save() }
                        collectStoryBeats(for: wonLevel, event: event)
                        // Arm post-win paywall — fires when player returns to Home
                        // (either by dismissing the game or after story beats clear).
                        pendingPaywallContext = PaywallMomentSelector.contextAfterWin(
                            event: event, entitlement: EntitlementStore.shared)
                    },
                    onFail: { failedLevel in
                        EntitlementStore.shared.recordAttempt(failedLevel, didWin: false)
                    },
                    onUpgrade: {
                        activeLevel    = nil
                        showPaywall(.nextMissionBlocked)
                    }
                )
                // .id forces SwiftUI to destroy and recreate GameView (and its @StateObject
                // GameViewModel) whenever the level changes. Without this, SwiftUI recycles
                // the same view instance when activeLevel switches from Level N to Level N+1,
                // keeping the old GameViewModel — the board never updates.
                .id(level.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .trailing)
                ))
            } else if showingLevelSelect {
                MissionMapView(
                    onSelect: { level in
                        showingLevelSelect = false
                        tryPlay(level)
                    },
                    onDismiss: { showingLevelSelect = false },
                    onUpgrade: { showPaywall(.nextMissionBlocked) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal:   .move(edge: .bottom)
                ))
            } else {
                HomeView(
                    onPlay:     { level in tryPlay(level) },
                    onMissions: { showingLevelSelect = true },
                    onUpgrade:  { showPaywall(.homeSoftCTA) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal:   .move(edge: .leading)
                ))
            }

            // ── Daily limit paywall overlay ────────────────────────────────
            if showingPaywall {
                PaywallView(context: paywallContext) {
                    StoreKitManager.shared.clearState()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.90)) {
                        showingPaywall = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal:   .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(100)
            }

            // ── Story beat overlay ─────────────────────────────────────────
            // Visible during normal play (introStep == nil) and during the two
            // intro steps that rely on the queue to drive their flow.
            if let beat = storyQueue.current, activeLevel == nil, !showingPaywall,
               (introStep == nil
                || introStep == .firstLaunchBeats
                || introStep == .firstMissionReadyBeat) {
                StoryModal(beat: beat, hasNext: storyQueue.hasNext) { storyQueue.advance() }
                    .id(beat.id)   // forces fresh @State per beat; prevents dismissed/appeared bleeding across beats
                    .transition(.opacity)
                    .zIndex(50)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: activeLevel != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: showingLevelSelect)
        .animation(.spring(response: 0.44, dampingFraction: 0.88), value: introStep)
        .animation(.easeInOut(duration: 0.30), value: storyQueue.current?.id)
        // Dispatch deferred post-win beat batches when returning to Home
        .onChange(of: activeLevel?.id) { oldID, newID in
            guard oldID != nil, newID == nil else { return }
            storyQueue.dispatchPendingBatches()
            // Fire pending post-win paywall after story beats play (or immediately if none queued)
            firePendingPaywallIfReady()
        }
        // Drive intro-step transitions when the story queue empties
        .onChange(of: storyQueue.current) { _, newBeat in
            guard newBeat == nil else { return }
            switch introStep {
            case .firstLaunchBeats:
                // All firstLaunch beats seen — proceed to narrative panels
                withAnimation(.easeIn(duration: 0.35)) { introStep = .narrative }
            case .firstMissionReadyBeat:
                // firstMissionReady beat dismissed — open Mission 1
                introStep  = nil
                activeLevel = LevelGenerator.levels.first
            default:
                break
            }
            // Fire pending paywall once the emotional beat sequence closes
            firePendingPaywallIfReady()
        }
        .onReceive(NotificationCenter.default.publisher(for: .devReplayOnboarding)) { _ in
            activeLevel        = nil
            showingLevelSelect = false
            storyQueue         = StoryBeatQueue()
            // Re-surface firstMissionReady beat so it fires again after the intro mission
            StoryBeatCatalog.beats
                .filter { $0.trigger == .firstMissionReady }
                .forEach { StoryStore.markUnseen($0) }
            // Instant-play replay: jump straight to the intro mission
            withAnimation(.easeIn(duration: 0.35)) { introStep = .gameplay }
        }
    }

    // MARK: - Entitlement gate

    /// Attempts to start a level. Shows the daily-limit paywall if the free quota is exhausted.
    ///
    /// When no context is supplied, PaywallMomentSelector determines the right framing
    /// based on the level being accessed (sector entry vs mid-sector continuation).
    private func tryPlay(_ level: Level, context: PaywallContext? = nil) {
        if EntitlementStore.shared.canPlay(level) {
            activeLevel            = level
            pendingPaywallContext  = nil    // successful navigation clears any pending paywall
        } else {
            let ctx = context ?? PaywallMomentSelector.contextWhenBlocked(level)
            // Always dismiss the game before showing the paywall — cleaner transition.
            activeLevel = nil
            #if DEBUG
            print("[PAYWALL] Blocked id=\(level.id) → showing paywall ctx=\(ctx)")
            #endif
            showPaywall(ctx)
        }
    }

    /// Shows the paywall with the given context and clears any pending auto-show.
    private func showPaywall(_ context: PaywallContext) {
        pendingPaywallContext = nil
        paywallContext        = context
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
            showingPaywall = true
        }
    }

    /// Fires the pending post-win paywall if conditions allow.
    /// Called when returning to Home and when the story queue empties.
    ///
    /// If the player is frustrated (FrustrationGuard), the auto-show is deferred.
    /// The pending context is preserved — it will fire the next time the player
    /// makes an explicit navigation tap (Next Mission, map selection), which is
    /// a clear intent signal that overrides the frustration gate.
    private func firePendingPaywallIfReady() {
        guard let ctx = pendingPaywallContext,
              !showingPaywall,
              activeLevel == nil,
              introStep == nil,
              storyQueue.current == nil else { return }
        // Never auto-show during the onboarding grace period (first 3 missions).
        // Explicit taps (onNextMission, tryPlay) bypass this check intentionally.
        guard OnboardingStore.hasShownFirstHook else { return }
        // Don't auto-interrupt with a paywall when the player is frustrated.
        guard !FrustrationGuard.shouldDeferAutoPaywall() else { return }
        showPaywall(ctx)
    }

    // MARK: - Story beat collection

    /// Gathers all pending story beats triggered by a mission win and enqueues them.
    /// Called immediately on win (before navigation) so profile context is accurate.
    ///
    /// Beat sequence per sector-completing win:
    ///   1. firstMissionComplete (only on the very first mission ever)
    ///   2. sectorComplete       — retrospective of what was accomplished
    ///   3. passUnlocked         — official authorization for the next sector
    ///   4. enteringNewSector    — briefing for the destination just unlocked
    ///   5. rankUp               — personal recognition when a level threshold is crossed
    private func collectStoryBeats(for level: Level, event: LevelUpEvent?) {
        let profile = ProgressionStore.profile
        var triggers: [(StoryTrigger, StoryContext)] = []

        // 1. First mission ever completed
        if profile.uniqueCompletions == 1 {
            triggers.append((.firstMissionComplete, StoryContext(playerLevel: profile.level)))
        }

        // 2–4. Sector-related beats — fire as a sequence when the sector finishes
        if let sector = SpatialRegion.catalog.first(where: { $0.levelRange.contains(level.id) }),
           sector.levels.allSatisfy({ profile.hasCompleted(levelId: $0.id) }) {

            // 2. Sector complete — recap
            triggers.append((.sectorComplete, .forSector(sector.id, level: profile.level)))

            // 3–4. Pass + new sector entry — only when a fresh pass was actually issued
            if event?.newPass != nil {
                // 3. Pass unlocked — authorization (requiredSectorID = the sector that issued it)
                triggers.append((.passUnlocked,
                    StoryContext(playerLevel: profile.level, completedSectorID: sector.id)))
                // 4. Entering new sector — destination briefing (requiredSectorID = next sector)
                let nextID = sector.id + 1
                if SpatialRegion.catalog.contains(where: { $0.id == nextID }) {
                    triggers.append((.enteringNewSector,
                        StoryContext(playerLevel: profile.level, completedSectorID: nextID)))
                }
            }
        }

        // 5. Rank up — fire for milestone levels (2, 5, 10)
        if let event, event.levelsGained > 0 {
            triggers.append((.rankUp, .forRankUp(to: profile.level)))
        }

        let beats = StoryStore.pendingQueue(triggers: triggers)
        storyQueue.enqueueBatch(beats)
    }
}

#Preview {
    ContentView()
}
