import SwiftUI

// Posted by DevMenuView to replay the intro without touching main game progress.
extension Notification.Name {
    static let devReplayOnboarding = Notification.Name("geometry.devReplayOnboarding")
    static let widgetDeepLink = Notification.Name("geometry.widgetDeepLink")
    static let openPlanetPass = Notification.Name("geometry.openPlanetPass")
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
    // When true, firePendingPaywallIfReady bypasses hasShownFirstHook + FrustrationGuard.
    // Set when an explicit user tap (Next Mission) arms the paywall after beats play.
    @State private var pendingPaywallBypassesHook: Bool = false

    // ── Deferred next level (story beats play first) ───────────────────
    @State private var deferredNextLevel: Level? = nil

    // ── Versus mode ──────────────────────────────────────────────────────
    @State private var showingVersus: Bool = false

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
        guard !OnboardingStore.hasCompletedIntro else {
            // Intro was completed in a previous session. Check whether the
            // firstMissionReady beat was killed before the player dismissed it:
            // if still unseen, re-surface the step so the beat can play.
            if !StoryStore.pendingAll(for: .firstMissionReady).isEmpty {
                return .firstMissionReadyBeat
            }
            return nil
        }
        if !OnboardingStore.hasSeenNarrativeIntro {
            // True first launch — show the two intro story beats before the gameplay mission.
            // markNarrativeSeen is deferred to the .firstLaunchBeats onChange so it only fires
            // after the beats are dismissed (or if none are pending).
            return .firstLaunchBeats
        }
        // App killed mid-onboarding (relaunched before finishing the intro mission) —
        // skip beats and go straight to the gameplay mission.
        return .gameplay
    }

    // MARK: - Audio state

    private var audioState: AudioState {
        if showingPaywall              { return .cooldown  }   // silence: only SFX during paywall decision
        if showingLevelSelect          { return .homeIdle  }   // keep ambient music while browsing missions
        if storyQueue.current != nil   { return .story     }
        if activeLevel != nil          { return .inMission }
        return .homeIdle
    }

    var body: some View {
        ZStack {
            if let step = introStep {
                switch step {

                // ── Step 0: firstLaunch story beats ───────────────────────
                // Dark backdrop only — the StoryModal overlay (zIndex 50) renders
                // on top. When the queue empties, .onChange transitions to .gameplay
                // (skipping the 4-panel narrative for instant play).
                case .firstLaunchBeats:
                    Color.black.ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)
                        .onAppear {
                            let beats = StoryStore.pendingAll(for: .firstLaunch)
                            if beats.isEmpty {
                                // No beats pending — jump straight to the intro mission.
                                OnboardingStore.markNarrativeSeen()
                                withAnimation(.easeIn(duration: 0.35)) { introStep = .gameplay }
                            } else {
                                storyQueue.enqueue(beats)
                            }
                        }

                // ── Step 4b: firstMissionReady beat ───────────────────────
                // Shown after MissionClearanceView — same dark backdrop pattern.
                // When the queue empties, .onChange opens Mission 1.
                // Also acts as recovery point: if the app was killed after
                // markIntroCompleted() but before the beat was dismissed, the
                // queue is empty on relaunch — onAppear re-enqueues the beat.
                case .firstMissionReadyBeat:
                    Color.black.ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(9)
                        .onAppear {
                            // Guard: queue already populated by onIntroComplete in the same session.
                            guard storyQueue.current == nil else { return }
                            let beats = StoryStore.pendingAll(for: .firstMissionReady)
                            if beats.isEmpty {
                                // Beat was already seen (e.g., dev replay) — skip to Mission 1.
                                introStep   = nil
                                activeLevel = LevelGenerator.levels.first
                            } else {
                                storyQueue.enqueue(beats)
                            }
                        }

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
                            OnboardingStore.markIntroCompleted()
                            // Show "ready for mission 1" beat before opening Mission 1.
                            // Falls back to direct navigation if the beat was already seen
                            // (e.g., dev replay or pre-fix installs).
                            let readyBeats = StoryStore.pendingAll(for: .firstMissionReady)
                            if readyBeats.isEmpty {
                                introStep   = nil
                                activeLevel = LevelGenerator.levels.first
                            } else {
                                storyQueue.enqueue(readyBeats)
                                introStep = .firstMissionReadyBeat
                            }
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
                            let nextLevel = levels[idx + 1]
                            // Show pending story beats before navigating to next mission.
                            // Beats (sector complete, rank-up, etc.) should play in front of
                            // the next mission, not wait until the player returns to Home.
                            storyQueue.dispatchPendingBatches()
                            if storyQueue.current != nil {
                                deferredNextLevel = nextLevel
                                activeLevel = nil   // dismiss game → story overlay shows
                            } else {
                                let ctx = PaywallMomentSelector.contextAfterWin(
                                    event: lastWinEvent, entitlement: EntitlementStore.shared
                                ) ?? .postVictory
                                tryPlay(nextLevel, context: ctx)
                            }
                        }
                    },
                    onMissions: { activeLevel = nil; showingLevelSelect = true },
                    onWin: { wonLevel, event in
                        lastWinEvent = event
                        if wonLevel.isDailyChallenge {
                            // Daily wins: cloud save only — no entitlement, no story beats, no paywall
                            Task { await CloudSaveManager.shared.save() }
                        } else {
                            EntitlementStore.shared.recordAttempt(wonLevel, didWin: true)
                            Task { await CloudSaveManager.shared.save() }
                            collectStoryBeats(for: wonLevel, event: event)
                            pendingPaywallContext = PaywallMomentSelector.contextAfterWin(
                                event: event, entitlement: EntitlementStore.shared)
                        }
                    },
                    onFail: { failedLevel in
                        if failedLevel.isDailyChallenge {
                            // One attempt only — dismiss to home, no entitlement tracking
                            activeLevel = nil
                        } else {
                            EntitlementStore.shared.recordAttempt(failedLevel, didWin: false)
                        }
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
            } else {
                HomeView(
                    onPlay:     { level in tryPlay(level) },
                    onMissions: { showingLevelSelect = true },
                    onUpgrade:  { showPaywall(.homeSoftCTA) },
                    onVersus:   { showingVersus = true },
                    onDailyChallenge: {
                        DailyStore.markStarted()
                        activeLevel = DailyLevelFactory.todayLevel
                    }
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
        .animation(.spring(response: 0.44, dampingFraction: 0.88), value: introStep)
        .animation(.easeInOut(duration: 0.30), value: storyQueue.current?.id)
        // ── Mission map modal ────────────────────────────────────────────
        .sheet(isPresented: $showingLevelSelect) {
            MissionMapView(
                onSelect: { level in
                    showingLevelSelect = false
                    // Brief delay so the modal dismiss animation completes cleanly
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        tryPlay(level)
                    }
                },
                onDismiss: { showingLevelSelect = false },
                onUpgrade: {
                    showingLevelSelect = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        showPaywall(.nextMissionBlocked)
                    }
                }
            )
            .environmentObject(SettingsStore.shared)
            .environmentObject(EntitlementStore.shared)
        }
        .fullScreenCover(isPresented: $showingVersus) {
            VersusView(
                matchManager: VersusMatchmakingManager.shared,
                onDismiss: { showingVersus = false }
            )
            .environmentObject(VersusMatchmakingManager.shared)
            .environmentObject(SettingsStore.shared)
        }
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
                // All firstLaunch beats seen — go straight to intro mission (no narrative panels).
                OnboardingStore.markNarrativeSeen()
                withAnimation(.easeIn(duration: 0.35)) { introStep = .gameplay }
            case .firstMissionReadyBeat:
                // firstMissionReady beat dismissed — open Mission 1
                introStep  = nil
                activeLevel = LevelGenerator.levels.first
            default:
                break
            }
            // Resume deferred next mission after story beats finish
            if let next = deferredNextLevel {
                deferredNextLevel = nil
                tryPlay(next)
                return
            }
            // Fire pending paywall once the emotional beat sequence closes
            firePendingPaywallIfReady()
        }
        .onAppear {
            AudioManager.shared.transition(to: audioState)
        }
        .onChange(of: audioState) { _, newState in
            AudioManager.shared.transition(to: newState)
        }
        // Sonic logo + silence-as-design when sector-complete beat appears
        .onChange(of: storyQueue.current) { _, newBeat in
            guard newBeat?.trigger == .sectorComplete else { return }
            // Cut music so accessGranted() rings out in silence, then story ambient fades in
            AudioManager.shared.stopMusic()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)   // 600 ms — after accessGranted
                SoundManager.play(.sonicLogoShort)
            }
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
        // Widget deep link handler
        .onReceive(NotificationCenter.default.publisher(for: .widgetDeepLink)) { note in
            guard introStep == nil,
                  let route = note.userInfo?["route"] as? DeepLinkRoute else { return }
            switch route {
            case .home:
                activeLevel = nil
                showingLevelSelect = false
            case .missions:
                activeLevel = nil
                showingLevelSelect = true
            case .leaderboards:
                activeLevel = nil
                showingLevelSelect = false
                GameCenterManager.shared.openLeaderboards()
            case .pass:
                activeLevel = nil
                showingLevelSelect = false
                // Navigate to home and open the PlanetTicketView sheet
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    NotificationCenter.default.post(name: .openPlanetPass, object: nil)
                }
            case .dailyChallenge:
                guard EntitlementStore.shared.isPremium,
                      !DailyStore.hasPlayedToday else { return }
                activeLevel = nil
                showingLevelSelect = false
                DailyStore.markStarted()
                activeLevel = DailyLevelFactory.todayLevel
            }
        }
    }

    // MARK: - Entitlement gate

    /// Attempts to start a level. Shows the daily-limit paywall if the free quota is exhausted.
    ///
    /// When no context is supplied, PaywallMomentSelector determines the right framing
    /// based on the level being accessed (sector entry vs mid-sector continuation).
    private func tryPlay(_ level: Level, context: PaywallContext? = nil) {
        if level.isDailyChallenge || EntitlementStore.shared.canPlay(level) {
            activeLevel                = level
            pendingPaywallContext      = nil
            pendingPaywallBypassesHook = false
        } else {
            let ctx = context ?? PaywallMomentSelector.contextWhenBlocked(level)
            // Immediate "access denied" feedback — fires before paywall animates in.
            HapticsManager.error()
            SoundManager.play(.tileLocked)
            // Always dismiss the game before showing the paywall — cleaner transition.
            activeLevel = nil
            // Flush any pending post-win story beats synchronously so they can play
            // before the upgrade prompt. If beats are now queued, defer the paywall
            // until the last beat closes (firePendingPaywallIfReady handles this).
            storyQueue.dispatchPendingBatches()
            if storyQueue.current != nil {
                // Beats are queued — paywall waits after them.
                // Bypass onboarding guards: this is an explicit tap, not an auto-show.
                pendingPaywallContext      = ctx
                pendingPaywallBypassesHook = true
            } else {
                #if DEBUG
                print("[PAYWALL] Blocked id=\(level.id) → showing paywall ctx=\(ctx)")
                #endif
                showPaywall(ctx)
            }
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
        if !pendingPaywallBypassesHook {
            // Auto-show guards — apply only when returning to Home organically,
            // not when an explicit user tap (Next Mission) deferred the paywall.
            guard OnboardingStore.hasShownFirstHook else { return }
            guard !FrustrationGuard.shouldDeferAutoPaywall() else { return }
        }
        pendingPaywallBypassesHook = false
        showPaywall(ctx)
    }

    // MARK: - Story beat collection

    /// Gathers all pending story beats triggered by a mission win and enqueues them.
    /// Called immediately on win (before navigation) so profile context is accurate.
    ///
    /// Beat sequence per sector-completing win:
    ///   0. firstMissionComplete (only on the very first mission ever)
    ///   1. sectorComplete       — retrospective of what was accomplished
    ///   2. passUnlocked         — official authorization for the next sector
    ///   3. enteringNewSector    — briefing for the destination just unlocked
    ///   4. rankUp               — personal recognition when a level threshold is crossed
    ///   5. onboardingComplete   — gate context (positive beats play first, gate last)
    private func collectStoryBeats(for level: Level, event: LevelUpEvent?) {
        let profile = ProgressionStore.profile
        var triggers: [(StoryTrigger, StoryContext)] = []

        // 0. First mission ever completed
        if profile.uniqueCompletions == 1 {
            triggers.append((.firstMissionComplete, StoryContext(playerLevel: profile.level)))
        }

        // 1–3. Sector-related beats — fire as a sequence when the sector finishes
        if let sector = SpatialRegion.catalog.first(where: { $0.levelRange.contains(level.id) }),
           sector.levels.allSatisfy({ profile.hasCompleted(levelId: $0.id) }) {

            // 1. Sector complete — recap
            triggers.append((.sectorComplete, .forSector(sector.id, level: profile.level)))

            // 2–3. Pass + new sector entry — only when a fresh pass was actually issued
            if event?.newPass != nil {
                // 2. Pass unlocked — authorization (requiredSectorID = the sector that issued it)
                triggers.append((.passUnlocked,
                    StoryContext(playerLevel: profile.level, completedSectorID: sector.id)))
                // 3. Entering new sector — destination briefing (requiredSectorID = next sector)
                let nextID = sector.id + 1
                if SpatialRegion.catalog.contains(where: { $0.id == nextID }) {
                    triggers.append((.enteringNewSector,
                        StoryContext(playerLevel: profile.level, completedSectorID: nextID)))
                }
            }
        }

        // 4. Rank up — fire for milestone levels (2, 5, 10)
        if let event, event.levelsGained > 0 {
            triggers.append((.rankUp, .forRankUp(to: profile.level)))
        }

        // 5. Onboarding complete — fires the first time the free-intro quota is exhausted.
        //    Placed LAST so all positive beats (rank-up, sector clear) play before the gate.
        let ent = EntitlementStore.shared
        if !ent.isPremium,
           !ent.isInIntroPhase,
           !StoryStore.isSeen("story_onboarding_complete") {
            triggers.append((.onboardingComplete, StoryContext(playerLevel: profile.level)))
        }

        let beats = StoryStore.pendingQueue(triggers: triggers)
        storyQueue.enqueueBatch(beats)
    }
}

#Preview {
    ContentView()
}
