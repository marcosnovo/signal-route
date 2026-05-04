import SwiftUI
import GameKit

// MARK: - HomeView  (mission-control panel)
struct HomeView: View {
    let onPlay: (Level) -> Void
    let onMissions: () -> Void
    var onUpgrade: (() -> Void)? = nil
    var onVersus:  (() -> Void)? = nil
    var onDailyChallenge: (() -> Void)? = nil

    @EnvironmentObject private var gcManager: GameCenterManager
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var entitlement: EntitlementStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    #if DEBUG
    @State private var devSecretStep = 0
    @State private var devLastTap    = Date.distantPast
    #endif
    @State private var showingPlanetTicket = false
    @State private var showingSettings     = false
    #if DEBUG
    @State private var showingDevMenu      = false
    #endif
    @AppStorage("lastPlayedMissionID") private var lastPlayedMissionID: String = ""
    @State private var contentOpacity: Double = 0
    @State private var heroOffset: CGFloat    = 18
    @State private var fabPulsing             = false
    @State private var rankPulsing            = false
    @State private var showingLeaderboardPicker = false
    @State private var showingRankings = false

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundSystem()

            // Ambient center glow — system heartbeat
            RadialGradient(
                colors: [
                    AppTheme.accentPrimary.opacity(0.055),
                    AppTheme.accentPrimary.opacity(0.015),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Planet pass ghost — ticket silhouette behind hero, changes with planet
            if introCompleted {
                passGhostLayer
            }

            // Decorative watermark
            Text("GEO")
                .font(.system(size: 200, weight: .black, design: .default))
                .foregroundStyle(Color.white.opacity(0.018))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 20, y: 50)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                systemBar
                contentArea
                    .opacity(contentOpacity)
                    .offset(y: heroOffset)
                    .onAppear {
                        contentOpacity = 0
                        heroOffset = 18
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08)) {
                            contentOpacity = 1.0
                            heroOffset = 0
                        }
                    }
                    .frame(maxHeight: .infinity)
                statusStrip.padding(.bottom, 32)
            }
        }
        .overlay {
            if showingLeaderboardPicker {
                LeaderboardPickerOverlay(
                    onDismiss: { showingLeaderboardPicker = false }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showingLeaderboardPicker)
        .overlay {
            if showingRankings {
                RankingsView(onDismiss: { showingRankings = false })
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(21)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showingRankings)
        .sheet(isPresented: $showingPlanetTicket) {
            PlanetTicketView(profile: profile)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showingDevMenu) {
            DevMenuView(
                onSelect: { level in
                    showingDevMenu = false
                    onPlay(level)
                },
                onDismiss: { showingDevMenu = false }
            )
        }
        #endif
        .task(id: ticketCacheKey) {
            guard introCompleted else { return }
            await warmTicketCache()
        }
        .onAppear {
            entitlement.checkExpiry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPlanetPass)) { _ in
            showingPlanetTicket = true
        }
    }

    // MARK: - Planet pass ghost layer

    /// Ghosted ticket silhouette rendered behind the hero content.
    /// Uses the real AstronautProgressCard (correct planet colors) blurred + faded
    /// so it reads as an atmospheric artefact, not a UI element.
    private var passGhostLayer: some View {
        AstronautProgressCard(profile: profile)
            .frame(width: 360)
            .frame(height: 180, alignment: .top)
            .clipped()
            .drawingGroup()
            .blur(radius: 18)
            .opacity(0.07)
            .rotationEffect(.degrees(-3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(x: 18, y: 10)
            .allowsHitTesting(false)
    }

    // MARK: - Content area

    private var contentArea: some View {
        Group {
            if introCompleted {
                if let next = profile.nextMission {
                    systemUI(for: next)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            AllClearCard()
                                .padding(.horizontal, 20)
                                .padding(.top, 32)
                            MapPreviewBlock(
                                completed: profile.uniqueCompletions,
                                total: LevelGenerator.levels.count,
                                onTap: onMissions
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            Spacer(minLength: 40)
                        }
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        TrainingCard()
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                        Button(action: { SoundManager.play(.tapPrimary); onPlay(LevelGenerator.introLevel) }) {
                            HStack(spacing: 10) {
                                Text(S.initializeTraining)
                                    .font(AppTheme.mono(12, weight: .bold))
                                    .kerning(2)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.accentPrimary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        }
                        .breathingCTA()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }

    // MARK: - System UI — full-viewport layout, no cards

    private func systemUI(for level: Level) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: max(16, geo.size.height * 0.08))

                // HERO — mission identity, no box/border
                heroBlock(for: level)
                    .padding(.horizontal, 28)

                Spacer(minLength: 36)

                // CTA FAB — centered floating action button
                ctaFAB(for: level)

                Spacer(minLength: 20)

                // Zone separator — visually divides CTA from meta-info HUD
                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .frame(height: 0.5)
                    .padding(.horizontal, 28)

                Spacer(minLength: 18)

                // HUD — compact secondary context
                hudLayer(for: level)
                    .padding(.horizontal, 28)

                Spacer(minLength: 16)
            }
        }
    }

    // MARK: - HERO block — mission identity, borderless

    private func heroBlock(for level: Level) -> some View {
        let isResume = lastPlayedMissionID == level.displayID
        let total    = LevelGenerator.levels.count
        let done     = profile.uniqueCompletions
        let frac     = total > 0 ? CGFloat(done) / CGFloat(total) : 0

        return VStack(alignment: .leading, spacing: 0) {

            // Status label + difficulty pill
            HStack(alignment: .center) {
                if isResume {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppTheme.accentPrimary)
                            .frame(width: 4, height: 4)
                            .pulsingGlow(color: AppTheme.accentPrimary, duration: 1.4)
                        TechLabel(text: S.inProgress, color: AppTheme.accentPrimary)
                    }
                } else {
                    TechLabel(text: S.nextMission,
                              color: AppTheme.sage.opacity(0.72))
                }
                Spacer()
                // Difficulty — floating tag, no box background
                Text(level.difficulty.fullLabel)
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(level.difficulty.color)
                    .kerning(1.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(level.difficulty.color.opacity(0.35), lineWidth: 0.5)
                    )
            }
            .padding(.bottom, 10)

            // Mission number
            Text(S.nextMissionLabel(level.displayID))
                .font(AppTheme.mono(48, weight: .black))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(-1)
                .minimumScaleFactor(0.72)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                #if DEBUG
                .onTapGesture { advanceDev(zone: 1) }
                #endif

            // Objective line
            Text(S.objectiveText(type: level.objectiveType, targets: level.numTargets))
                .font(AppTheme.mono(10))
                .foregroundStyle(AppTheme.sage.opacity(0.78))
                .kerning(1.0)
                .padding(.top, 6)

            // Campaign progress — bar + live percentage readout
            HStack(alignment: .center, spacing: 10) {
                ProgressAnimatedBar(fraction: frac)
                Text("\(Int((frac * 100).rounded()))%")
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.90))
                    .monospacedDigit()
            }
            .padding(.top, 12)
        }
    }

    // MARK: - CTA FAB — floating action button

    @ViewBuilder
    private func ctaFAB(for level: Level) -> some View {
        let isBlocked = !entitlement.isPremium && entitlement.dailyLimitReached
        let showDaily = entitlement.isPremium
        let showVersus = VersusFeatureFlag.isVisibleInHome && gcManager.isAuthenticated

        VStack(spacing: 12) {
            // Row 1: Primary CTA
            if isBlocked {
                blockedFAB()
            } else {
                let showDailyCount = !entitlement.isPremium
                    && !entitlement.isInIntroPhase
                    && entitlement.dailyPlaysUsed > 0
                VStack(spacing: 8) {
                    activeFAB(label: S.play) {
                        lastPlayedMissionID = level.displayID
                        onPlay(level)
                    }
                    if showDailyCount {
                        Text(S.dailyPlaysLabel(
                            used:  entitlement.dailyPlaysUsed,
                            limit: EntitlementStore.dailyLimit
                        ))
                        .font(AppTheme.mono(8))
                        .foregroundStyle(AppTheme.sage.opacity(0.58))
                        .kerning(0.8)
                    }
                }
            }

            // Row 2: Daily + Versus side by side (or single if only one visible)
            if showDaily || showVersus {
                HStack(spacing: 10) {
                    if showDaily {
                        dailyChallengeCompactCTA
                    }
                    if showVersus {
                        versusCompactCTA
                    }
                }
                .frame(width: 260)
            }


            // Row 3: Leaderboard
            leaderboardSecondaryButton
        }
    }

    /// Compact daily challenge button for the side-by-side row.
    @ViewBuilder
    private var dailyChallengeCompactCTA: some View {
        let played = DailyStore.hasPlayedToday
        if played {
            let won = DailyStore.todayResult?.success == true
            HStack(spacing: 10) {
                Image(systemName: won ? "checkmark.circle.fill" : "clock.badge.checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.sage.opacity(0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(won ? S.dailyChallengeCompleted : S.dailyChallengePlayed)
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(AppTheme.sage.opacity(0.55))
                    Text(S.dailyChallengeNextIn)
                        .font(AppTheme.mono(7, weight: .medium))
                        .kerning(0.4)
                        .foregroundStyle(AppTheme.sage.opacity(0.35))
                }
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let secs = max(0, DailyChallengeConfig.secondsUntilNext)
                    let h = Int(secs) / 3600
                    let m = (Int(secs) % 3600) / 60
                    let s = Int(secs) % 60
                    Text(String(format: "%02d:%02d:%02d", h, m, s))
                        .font(AppTheme.mono(13, weight: .black))
                        .kerning(1.0)
                        .foregroundStyle(AppTheme.sage.opacity(0.5))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppTheme.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.12), lineWidth: 0.5)
            )
        } else {
            Button(action: {
                SoundManager.play(.tapPrimary)
                HapticsManager.medium()
                onDailyChallenge?()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                    Text(S.dailyChallenge)
                        .font(AppTheme.mono(8, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.accentPrimary.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(PlayPressStyle(onPress: {
                HapticsManager.medium()
                SoundManager.play(.tapPrimary)
            }))
        }
    }

    /// Compact versus button for the side-by-side row.
    private var versusCompactCTA: some View {
        Button(action: {
            SoundManager.play(.tapPrimary)
            HapticsManager.medium()
            onVersus?()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.sage)
                Text(S.versus)
                    .font(AppTheme.mono(8, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(AppTheme.sage.opacity(0.82))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppTheme.sage.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Muted countdown label shown when the daily challenge has been played.
    private var dailyChallengePlayedLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(S.dailyChallengeCompleted)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(0.8)
            Text("·")
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let secs = max(0, DailyChallengeConfig.secondsUntilNext)
                let h = Int(secs) / 3600
                let m = (Int(secs) % 3600) / 60
                let s = Int(secs) % 60
                Text(S.nextIn(String(format: "%02d:%02d:%02d", h, m, s)))
                    .font(AppTheme.mono(8))
                    .kerning(0.6)
            }
        }
        .foregroundStyle(AppTheme.sage.opacity(0.38))
    }

    /// Active / resume — centered pill with animated glow
    private func activeFAB(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(AppTheme.mono(15, weight: .black))
                    .kerning(3)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(width: 260, height: 58)
            .background(AppTheme.accentPrimary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(PlayPressStyle(onPress: {
            HapticsManager.medium()
            SoundManager.play(.tapPrimary)
        }))
        .shadow(color: AppTheme.accentPrimary.opacity(fabPulsing ? 0.28 : 0.10),
                radius: 12, y: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                fabPulsing = true
            }
        }
    }

    /// Secondary ranking button — always visible below the primary CTA.
    ///
    /// Width matches `activeFAB` (260 pt) so both elements form a clean vertical stack.
    /// Authenticated: trophy.fill (success green) + localized ranking label + live green dot.
    /// Unauthenticated: trophy outline + "CONNECT" text (tapping triggers GK sign-in).
    private var leaderboardSecondaryButton: some View {
        let isAuth = gcManager.isAuthenticated
        return Button(action: {
            SoundManager.play(.tapSecondary)
            if isAuth { showingLeaderboardPicker = true } else { gcManager.authenticate() }
        }) {
            HStack(spacing: 10) {
                // Trophy icon — always present, color conveys auth state
                Image(systemName: isAuth ? "trophy.fill" : "trophy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isAuth
                            ? AppTheme.success.opacity(0.85)
                            : AppTheme.textSecondary.opacity(0.42)
                    )

                // Label
                Text(isAuth ? S.leaderboard : S.connectForLeaderboard)
                    .font(AppTheme.mono(11, weight: .bold))
                    .kerning(1.8)
                    .foregroundStyle(
                        isAuth
                            ? AppTheme.sage.opacity(0.82)
                            : AppTheme.textSecondary.opacity(0.52)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                // Right indicator: live dot when authenticated, subtle arrow when not
                if isAuth {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 5, height: 5)
                        .pulsingGlow(color: AppTheme.success, duration: 2.8)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.30))
                }
            }
            .padding(.horizontal, 18)
            .frame(width: 260, height: 44)
            .background(
                isAuth
                    ? AppTheme.success.opacity(0.06)
                    : Color.white.opacity(0.030)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(
                        isAuth
                            ? AppTheme.success.opacity(0.22)
                            : Color.white.opacity(0.07),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        // Subtle pulse — offset from main CTA so they don't sync visually
        .scaleEffect(rankPulsing ? 1.007 : 1.0)
        .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: rankPulsing)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                rankPulsing = true
            }
        }
    }

    /// Blocked state — upgrade dominant, prominent countdown FAB, daily count below.
    /// Note: `leaderboardSecondaryButton` is rendered by the parent `ctaFAB`, always below this block.
    private func blockedFAB() -> some View {
        VStack(spacing: 12) {
            // Upgrade CTA — dominant, full accent treatment
            if let onUpgrade {
                Button(action: onUpgrade) {
                    HStack(spacing: 10) {
                        Image(systemName: "infinity")
                            .font(.system(size: 13, weight: .bold))
                        Text(S.unlockUnlimitedAccess)
                            .font(AppTheme.mono(12, weight: .black))
                            .kerning(1.5)
                    }
                    .frame(width: 260, height: 58)
                    .background(AppTheme.accentPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .breathingCTA()
            }

            // Countdown container — fixed 260×58 frame shared by both branches.
            // Wrapping both content states in a single clipped ZStack prevents any
            // layout shift or text overflow when the TimelineView fires.
            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                let remaining = entitlement.remainingCooldown
                ZStack {
                    if remaining <= 0 {
                        // Cooldown cleared — show dim placeholder while checkExpiry fires
                        Text(S.play)
                            .font(AppTheme.mono(15, weight: .black))
                            .kerning(3)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.32))
                            .onAppear { entitlement.checkExpiry() }
                    } else {
                        VStack(spacing: 3) {
                            Text(S.availableIn.uppercased())
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.58))
                                .kerning(2)
                            Text(formatCooldown(remaining))
                                .font(AppTheme.mono(20, weight: .black))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                                .monospacedDigit()
                                .tracking(-0.5)
                        }
                    }
                }
                // Stable outer frame — both content states live inside this boundary.
                // .clipped() prevents any content from rendering outside the 260×58 box.
                .frame(width: 260, height: 58)
                .clipped()
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }

            // Daily plays used label
            Text(S.dailyPlaysLabel(
                used:  entitlement.dailyPlaysUsed,
                limit: EntitlementStore.dailyLimit
            ))
            .font(AppTheme.mono(8))
            .foregroundStyle(AppTheme.sage.opacity(0.58))
            .kerning(0.8)
        }
    }

    private func formatCooldown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - HUD layer — dual-square module + optional upgrade nudge

    private func hudLayer(for level: Level) -> some View {
        let planet   = profile.currentPlanet
        let isEarned = PassStore.hasPass(for: planet.id)
        let done     = profile.uniqueCompletions
        let total    = LevelGenerator.levels.count

        return VStack(spacing: 10) {

            // ── Dual square modules ─────────────────────────────────────────
            HStack(spacing: 12) {
                passTile(planet: planet, isEarned: isEarned)
                mapTile(done: done, total: total)
            }

            // Soft upgrade nudge — non-blocked free users only
            if !entitlement.isPremium, let onUpgrade,
               OnboardingStore.hasShownFirstHook,
               !entitlement.dailyLimitReached {
                Button(action: onUpgrade) {
                    HStack(spacing: 6) {
                        Image(systemName: "infinity")
                            .font(.system(size: 7, weight: .semibold))
                        Text(S.unlockUnlimitedAccess)
                            .font(AppTheme.mono(7, weight: .bold))
                            .kerning(0.5)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 6, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.58))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pass tile

    private func passTile(planet: Planet, isEarned: Bool) -> some View {
        let statusColor = isEarned ? AppTheme.success : planet.color
        let effSegments = min(5, max(0, Int((profile.averageEfficiency * 5).rounded())))
        let effPct      = profile.averageEfficiencyPercent
        // Same dark base used by TicketRenderer and AstronautProgressCard
        let ticketDark  = Color(red: 0.040, green: 0.047, blue: 0.059)

        return Button(action: { SoundManager.play(.tapSecondary); showingPlanetTicket = true }) {
            ZStack(alignment: .topLeading) {

                // ── Background: ticket dark + right-edge planet orb glow ─
                RoundedRectangle(cornerRadius: 18)
                    .fill(ticketDark)
                    .overlay(
                        // Orb at the trailing edge mirrors the full-ticket sphere
                        RadialGradient(
                            colors: [planet.color.opacity(0.24),
                                     planet.color.opacity(0.05),
                                     Color.clear],
                            center: .trailing,
                            startRadius: 0,
                            endRadius: 80
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(planet.color.opacity(0.40), lineWidth: 0.5)
                    )

                // ── Left accent stripe — full-height, 4 pt, planet color ─
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(planet.color)
                        .frame(width: 4)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // ── Content ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    // Top bar — tinted header, flush with tile top (ticket DNA)
                    HStack {
                        TechLabel(text: S.planetPass, color: planet.color)
                        Spacer()
                        Text(planet.difficulty.fullLabel)
                            .font(AppTheme.mono(7, weight: .bold))
                            .foregroundStyle(planet.color.opacity(0.80))
                            .kerning(0.8)
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(planet.color.opacity(0.07))

                    Rectangle()
                        .fill(planet.color.opacity(0.30))
                        .frame(height: 0.5)

                    // Body — planet identity + efficiency + status
                    VStack(alignment: .leading, spacing: 0) {

                        // Planet name — hero element
                        Text(S.planetName(planet.name))
                            .font(AppTheme.mono(17, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .tracking(-0.3)

                        Text(S.zoneBrief(planet.missionBrief))
                            .font(AppTheme.mono(8))
                            .foregroundStyle(planet.color.opacity(0.82))
                            .kerning(0.5)
                            .padding(.top, 2)

                        Spacer(minLength: 6)

                        // 5-segment efficiency bar — same rounding logic as TicketRenderer
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i < effSegments
                                          ? planet.color.opacity(0.88)
                                          : Color.white.opacity(0.16))
                                    .frame(height: 3)
                            }
                        }
                        TechLabel(text: "\(effPct)%  EFF",
                                  color: planet.color.opacity(0.80))
                            .padding(.top, 3)

                        Spacer(minLength: 6)

                        Rectangle()
                            .fill(planet.color.opacity(0.22))
                            .frame(height: 0.5)
                            .padding(.bottom, 5)

                        // Status + VIEW PASS tap cue
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 5, height: 5)
                                .pulsingGlow(color: statusColor, duration: 2.0)
                            Text(isEarned ? "UNLOCKED" : "ACTIVE")
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(statusColor.opacity(0.85))
                                .kerning(0.5)
                            Spacer()
                            HStack(spacing: 3) {
                                TechLabel(text: S.viewPass,
                                          color: planet.color.opacity(0.88))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(planet.color.opacity(0.78))
                            }
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Map tile

    private func mapTile(done: Int, total: Int) -> some View {
        let frac = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        let pct  = Int((frac * 100).rounded())

        return Button(action: { SoundManager.play(.tapSecondary); onMissions() }) {
            ZStack(alignment: .topLeading) {

                // ── Background ───────────────────────────────────────────
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.surface)
                    .overlay(
                        RadialGradient(
                            colors: [AppTheme.accentPrimary.opacity(0.10), Color.clear],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 90
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.22), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 0) {

                    // ── Tinted header bar — mirrors passTile pattern ──────
                    HStack {
                        TechLabel(text: S.missionMapTitle,
                                  color: AppTheme.accentPrimary.opacity(0.72))
                        Spacer()
                        Text("\(pct)%")
                            .font(AppTheme.mono(7, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary.opacity(0.90))
                            .kerning(0.5)
                            .monospacedDigit()
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 12)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.accentPrimary.opacity(0.07))
                    .transaction { $0.animation = nil }

                    Rectangle()
                        .fill(AppTheme.accentPrimary.opacity(0.22))
                        .frame(height: 0.5)

                    // ── Body ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Hero: done / total — static, never animates
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(done)")
                                .font(AppTheme.mono(22, weight: .black))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                            Text("/ \(total)")
                                .font(AppTheme.mono(11))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.62))
                        }
                        .transaction { $0.animation = nil }
                        Text(S.missionsCompletedShort)
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.60))
                            .kerning(0.3)
                            .padding(.top, 1)
                            .transaction { $0.animation = nil }

                        Spacer(minLength: 4)

                        // ── Mini signal-network canvas (only animated element) ──
                        MiniNetworkCanvas(activeFrac: frac)
                            .frame(height: 46)

                        Spacer(minLength: 4)

                        // ── Thin progress bar ─────────────────────────────
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule()
                                    .fill(AppTheme.accentPrimary.opacity(0.65))
                                    .frame(width: max(4, geo.size.width * frac))
                            }
                        }
                        .frame(height: 3)
                        .transaction { $0.animation = nil }

                        Spacer(minLength: 6)

                        // ── Footer separator + CTA ────────────────────────
                        Rectangle()
                            .fill(AppTheme.accentPrimary.opacity(0.16))
                            .frame(height: 0.5)
                            .padding(.bottom, 5)

                        HStack(spacing: 4) {
                            Text(S.viewFullMap)
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(AppTheme.accentPrimary.opacity(0.92))
                                .kerning(0.8)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppTheme.accentPrimary.opacity(0.82))
                        }
                        .transaction { $0.animation = nil }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - System bar — minimal header

    private var systemBar: some View {
        HStack(alignment: .center, spacing: 10) {
            PlayerBlock(gcManager: gcManager)

            Spacer()

            Button(action: { SoundManager.play(.tapSecondary); showingRankings = true }) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.stroke.opacity(0.6), lineWidth: 0.5)
                    )
            }

            Button(action: { showingSettings = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .bold))
                    Text("CONFIG")
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.8)
                }
                .foregroundStyle(AppTheme.textPrimary.opacity(0.75))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.stroke.opacity(0.6), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var introCompleted: Bool { OnboardingStore.hasCompletedIntro }
    private var profile: AstronautProfile { ProgressionStore.profile }

    // MARK: Status strip — live system readout replacing dead nav tabs
    private var statusStrip: some View {
        VStack(spacing: 0) {
            TechDivider()
            HStack(spacing: 0) {
                // Signal: always hot  [secret zone 2]
                HStack(spacing: 5) {
                    Circle().fill(AppTheme.success).frame(width: 4, height: 4)
                        .pulsingGlow(color: AppTheme.success, duration: 1.8)
                    TechLabel(text: S.signalActive, color: AppTheme.sage.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                #if DEBUG
                .onTapGesture { advanceDev(zone: 2) }
                #endif

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // Mission progress
                TechLabel(
                    text: "\(S.missions)  ·  \(profile.uniqueCompletions)/\(LevelGenerator.levels.count)",
                    color: AppTheme.sage.opacity(0.82)
                )
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // System version  [secret zone 0]
                TechLabel(text: "SYS  ·  v1.1.0", color: AppTheme.sage.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    #if DEBUG
                    .onTapGesture { advanceDev(zone: 0) }
                    #endif
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: Ticket cache pre-warming

    /// Composite key matching TicketCache's cacheKey — re-fires the task only when ticket data changes.
    private var ticketCacheKey: String {
        let prof = profile
        let planet = prof.currentPlanet
        let eff = Int((prof.averageEfficiency * 100).rounded())
        return "\(planet.id)-\(prof.level)-\(prof.completedMissions)-\(eff)-\(settings.language.rawValue)"
    }

    /// Renders the planet pass image at background priority while the user is on the home screen.
    /// By the time they tap "TAP TO VIEW PLANET PASS", the image is already cached.
    private func warmTicketCache() async {
        let prof = profile
        let planet = prof.currentPlanet
        let p: PlanetPass = {
            if let earned = PassStore.all.first(where: { $0.planetIndex == planet.id }) {
                return earned
            }
            var provisional = PlanetPass(
                id:              UUID(),
                planetName:      planet.name,
                planetIndex:     planet.id,
                levelReached:    prof.level,
                efficiencyScore: prof.averageEfficiency,
                missionCount:    prof.completedMissions,
                timestamp:       Date()
            )
            provisional.isEarned = false
            return provisional
        }()
        let lang = settings.language
        guard TicketCache.shared.image(for: p, language: lang) == nil else { return }
        let image = await Task.detached(priority: .userInitiated) {
            TicketRenderer.render(pass: p, profile: prof, language: lang)
        }.value
        TicketCache.shared.cache(image, for: p, language: lang)
    }

    #if DEBUG
    // MARK: Secret DEV menu trigger
    // Sequence: v1.0 (zone 0) → next mission (zone 1) → v1.0 (zone 0) → signal (zone 2)
    private static let devSequence = [0, 1, 0, 2]

    private func advanceDev(zone: Int) {
        let now = Date()
        if now.timeIntervalSince(devLastTap) > 4.0 { devSecretStep = 0 }
        devLastTap = now
        if Self.devSequence[devSecretStep] == zone {
            devSecretStep += 1
            if devSecretStep >= Self.devSequence.count {
                devSecretStep = 0
                showingDevMenu = true
            }
        } else {
            devSecretStep = Self.devSequence[0] == zone ? 1 : 0
        }
    }
    #endif
}

// MARK: - AllClearCard
/// Shown when the player has completed every mission in the catalogue.
struct AllClearCard: View {
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.success)
            Text(S.allMissionsCleared)
                .font(AppTheme.mono(13, weight: .bold))
                .foregroundStyle(Color(hex: "141414"))
                .kerning(2)
            Text(S.allMissionsClearedSub(count: LevelGenerator.levels.count))
                .font(AppTheme.mono(10))
                .foregroundStyle(.black.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "C7D7C6"))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.success.opacity(0.45), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - TrainingCard
/// Mission card variant shown to players who haven't completed the intro yet.
struct TrainingCard: View {
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private let bg    = Color(hex: "C7D7C6")
    private let dark  = Color(hex: "141414")
    private let muted = Color.black.opacity(0.52)
    private let sep   = Color.black.opacity(0.10)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: S.systemCalibration, color: AppTheme.accentPrimary)
                    Text(S.trainingMission)
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(dark)
                }
                Spacer()
                Text(S.required)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
                    .kerning(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.55), lineWidth: 0.5)
                    )
                    .pulsingGlow(color: AppTheme.accentPrimary)
            }
            .padding(16)

            Rectangle().fill(sep).frame(height: 0.5)

            HStack(spacing: 0) {
                MiniStatCell(label: S.gridLabel, value: "3 × 3",
                             labelColor: muted, valueColor: dark)
                Rectangle().fill(sep).frame(width: 0.5, height: 24)
                MiniStatCell(label: S.movesLabel, value: "5",
                             labelColor: muted, valueColor: dark)
                Rectangle().fill(sep).frame(width: 0.5, height: 24)
                MiniStatCell(label: S.signalLabel, value: S.readyValue, accent: true,
                             labelColor: muted, valueColor: dark)
            }
            .padding(.vertical, 12)
        }
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.accentPrimary.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - MiniStatCell
struct MiniStatCell: View {
    let label: String
    let value: String
    var accent: Bool = false
    var labelColor: Color = AppTheme.sage.opacity(0.80)
    var valueColor: Color = AppTheme.textPrimary

    var body: some View {
        VStack(spacing: 3) {
            TechLabel(text: label, color: labelColor)
            Text(value)
                .font(AppTheme.mono(12, weight: .semibold))
                .foregroundStyle(accent ? AppTheme.success : valueColor)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PlayerBlock
/// Top-left identity module.
/// Authenticated  → circular avatar (photo or initials) + name + GC status.
/// Not authenticated → ghost circle + "connect" prompt.
private struct PlayerBlock: View {
    @ObservedObject var gcManager: GameCenterManager

    private let avatarSize: CGFloat = 38

    var body: some View {
        Group {
            if gcManager.isAuthenticated {
                Button(action: { gcManager.openDashboard() }) { identityRow }
                    .buttonStyle(.plain)
            } else {
                Button(action: { gcManager.authenticate() }) { connectRow }
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: Authenticated
    private var identityRow: some View {
        HStack(spacing: 10) {
            avatarCircle
            VStack(alignment: .leading, spacing: 4) {
                Text(String(gcManager.displayName.prefix(16)).uppercased())
                    .font(AppTheme.mono(11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 5, height: 5)
                        .pulsingGlow(color: AppTheme.success, duration: 2.2)
                    Text("GC  ·  ONLINE")
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.60))
                        .kerning(0.5)
                }
            }
        }
    }

    // MARK: Unauthenticated
    private var connectRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.surface)
                .frame(width: avatarSize, height: avatarSize)
                .overlay(Circle().strokeBorder(AppTheme.stroke, lineWidth: 0.75))
                .overlay(
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("GAME CENTER")
                    .font(AppTheme.mono(10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("TAP TO CONNECT")
                    .font(AppTheme.mono(7))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    .kerning(0.5)
            }
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surface)
                .frame(width: avatarSize, height: avatarSize)
                .overlay(Circle().strokeBorder(AppTheme.accentPrimary.opacity(0.28), lineWidth: 0.75))
            if let avatar = gcManager.playerAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(AppTheme.mono(11, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
            }
        }
    }

    private var initials: String {
        let words = gcManager.displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1))
        }
        return String(gcManager.displayName.prefix(2)).uppercased()
    }
}


// MARK: - AstronautProgressCard
/// Home screen mission pass — a compact 2D preview of the full Planet Pass ticket.
///
/// Inherits the ticket's exact visual DNA (TicketRenderer layer order):
///   • Same dark background colour (TicketRenderer.drawBackground)
///   • Same left accent bar — planet colour, full height
///   • Same top-bar layout: SIGNAL VOID + serial | PLANET PASS + difficulty
///   • Same planet name as the hero element (large, white, .black mono weight)
///   • Same MISSION EFFICIENCY section + 10-segment bar (same rounding logic)
///   • Same 4-cell stats grid: LEVEL / MISSIONS / RANK / VIEW PASS
///   • Same planet orb watermark — right-edge radial glow
///
/// Tapping opens PlanetTicketView — both pieces read as the same artefact
/// at different scales.
struct AstronautProgressCard: View {
    let profile: AstronautProfile

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private var planet: Planet          { profile.currentPlanet }
    private var rule:   ProgressionRule { profile.progressionRule }

    /// True when the player has earned (completed) the pass for the current planet/sector.
    private var isPassEarned: Bool { PassStore.hasPass(for: planet.id) }

    /// Serial code matching PlanetPass.serialCode format.
    /// Training state uses "TRN" suffix; earned passes use the planet abbreviation.
    private var serialCode: String {
        if !isPassEarned { return String(format: "SR-%04d-TRN", profile.completedMissions) }
        let abbrev = String(planet.name.prefix(3)).replacingOccurrences(of: " ", with: "_")
        return String(format: "SR-%04d-%@", profile.completedMissions, abbrev)
    }

    /// Segments filled in the 10-cell bar — rounded to nearest integer,
    /// matching TicketRenderer's own logic.
    private var efficiencySegments: Int {
        min(10, max(0, Int((profile.averageEfficiency * 10).rounded())))
    }

    // Exact background used by TicketRenderer.drawBackground
    private let ticketBg = Color(red: 0.040, green: 0.047, blue: 0.059)

    var body: some View {
        HStack(spacing: 0) {

            // ── Left accent bar — same as ticket (full height) ────────
            Rectangle()
                .fill(planet.color)
                .frame(width: 4)

            VStack(spacing: 0) {

                // ── Top bar — SIGNAL VOID / PLANET PASS ──────────────
                // Mirrors ticket drawTopBar: faint tint, left identity, right pass label.
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        TechLabel(text: "SIGNAL VOID", color: .white.opacity(0.90))
                        TechLabel(text: serialCode,     color: .white.opacity(0.38))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        TechLabel(text: isPassEarned ? S.planetPass : S.trainingClearance,
                                  color: planet.color)
                        TechLabel(text: planet.difficulty.fullLabel, color: planet.color.opacity(0.60))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(planet.color.opacity(0.055))

                Rectangle().fill(planet.color.opacity(0.28)).frame(height: 0.5)

                // ── Planet name — hero element ────────────────────────
                // Mirrors ticket drawPlanetSection: missionBrief + large name.
                ZStack(alignment: .trailing) {
                    // Planet orb echo — faint radial glow at right edge,
                    // same placement as the large sphere in the full ticket.
                    RadialGradient(
                        colors: [planet.color.opacity(0.17), planet.color.opacity(0.03), .clear],
                        center: .center, startRadius: 0, endRadius: 56
                    )
                    .frame(width: 112, height: 112)
                    .offset(x: 22)
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 2) {
                        TechLabel(text: S.zoneBrief(planet.missionBrief), color: planet.color.opacity(0.78))
                        Text(S.planetName(planet.name))
                            .font(AppTheme.mono(28, weight: .black))
                            .foregroundStyle(.white)
                            .tracking(-0.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                Rectangle().fill(planet.color.opacity(0.22)).frame(height: 0.5)

                // ── Efficiency — mirrors ticket drawEfficiency ────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        TechLabel(text: S.missionEff, color: .white.opacity(0.52))
                        Text("\(profile.averageEfficiencyPercent)%")
                            .font(AppTheme.mono(20, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    // 10-segment bar — exact ticket segment count and rounding
                    HStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i < efficiencySegments
                                      ? planet.color
                                      : Color.white.opacity(0.10))
                                .frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Rectangle().fill(planet.color.opacity(0.18)).frame(height: 0.5)

                // ── Stats row — mirrors ticket drawStats: 4-cell grid ─
                HStack(spacing: 0) {
                    passStatCell(label: S.levelLabel, value: String(format: "%02d", profile.level))
                    statDivider()
                    passStatCell(label: S.missionsLabel, value: String(format: "%04d", profile.completedMissions))
                    statDivider()
                    passStatCell(label: "RANK",     value: profile.rankTitle)
                    statDivider()
                    // 4th cell — VIEW PASS tap cue (planet-color pill)
                    HStack(spacing: 3) {
                        TechLabel(text: S.viewPass, color: planet.color.opacity(0.88))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(planet.color.opacity(0.72))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(planet.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(planet.color.opacity(0.20), lineWidth: 0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(ticketBg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(planet.color.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    /// Stat cell matching the ticket's drawStats layout — label above value.
    private func passStatCell(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            TechLabel(text: label, color: .white.opacity(0.42))
            Text(value)
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statDivider() -> some View {
        Rectangle()
            .fill(planet.color.opacity(0.18))
            .frame(width: 0.5)
            .padding(.vertical, 4)
    }
}

// MARK: - PlanetTicketView
/// Modal sheet that renders and displays the player's current planet pass.
/// Plays a scan-reveal animation on first display, then activates the share button.
///
/// Shows the persisted PlanetPass if one exists for the current planet,
/// otherwise synthesises a pass from the live profile state.
struct PlanetTicketView: View {
    let profile: AstronautProfile
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var ticketImage:   UIImage? = nil
    /// 0 = scan not started, 1 = scan complete (image fully revealed)
    @State private var scanFraction:  CGFloat  = 0
    /// True once the scan animation finishes — enables share + activates share button color
    @State private var revealed:      Bool     = false
    /// Drives the arc spinner rotation in the loading state
    @State private var spinAngle:     Double   = 0
    /// Cycles 0-2 to rotate loading copy text
    @State private var loadingPhase:  Int      = 0
    /// True while the export is being prepared — tells PlanetPass3DView to settle and flash.
    @State private var isExporting:   Bool     = false
    /// Resolved sheet width — set via onGeometryChange; seeded with a safe default.
    @State private var viewWidth: CGFloat      = 393
    /// Drives the entry animation for nav strip and share section.
    @State private var chromeVisible: Bool     = false

    private var planet: Planet { profile.currentPlanet }

    private var pass: PlanetPass {
        if let earned = PassStore.all.first(where: { $0.planetIndex == planet.id }) {
            return earned
        }
        var p = PlanetPass(
            id:              UUID(),
            planetName:      planet.name,
            planetIndex:     planet.id,
            levelReached:    profile.level,
            efficiencyScore: profile.averageEfficiency,
            missionCount:    profile.completedMissions,
            timestamp:       Date()
        )
        p.isEarned = false
        return p
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav strip ────────────────────────────────────────
                HStack {
                    // Bordered pill close button — discrete but clear
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                            TechLabel(text: S.close)
                        }
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
                        )
                    }

                    Spacer()

                    // Title + planet name subtitle
                    VStack(spacing: 2) {
                        TechLabel(text: pass.isEarned ? S.planetPass : S.trainingClearance,
                                  color: planet.color)
                        TechLabel(text: S.planetName(planet.name).uppercased(),
                                  color: planet.color.opacity(0.50))
                    }

                    Spacer()

                    // Invisible balance to keep title centred
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        TechLabel(text: S.close)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { TechDivider() }
                .opacity(chromeVisible ? 1 : 0)
                .offset(y: chromeVisible ? 0 : 6)

                // ── Ticket area — square hero ────────────────────────
                ticketArea
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                TechDivider()
                    .opacity(chromeVisible ? 1 : 0)

                // ── Share button — activates after reveal ─────────────
                Button(action: sharePass) {
                    HStack(spacing: 8) {
                        if revealed {
                            // Small planet-color dot accent — "passport activated"
                            Circle()
                                .fill(planet.color)
                                .frame(width: 5, height: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Image(systemName: revealed ? "square.and.arrow.up" : "lock")
                            .font(.system(size: 11, weight: revealed ? .bold : .regular))
                        Text(S.shareProgress)
                            .font(AppTheme.mono(12, weight: .bold))
                            .kerning(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    // Dims slightly while the export border flash plays
                    .background(
                        (revealed ? planet.color : AppTheme.backgroundSecondary)
                            .opacity(isExporting ? 0.55 : 1.0)
                    )
                    .foregroundStyle(revealed ? .black.opacity(0.85) : AppTheme.textSecondary)
                    .animation(.easeOut(duration: 0.40), value: revealed)
                    .animation(.easeOut(duration: 0.15), value: isExporting)
                }
                .disabled(!revealed || isExporting)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .opacity(chromeVisible ? 1 : 0)
                .offset(y: chromeVisible ? 0 : 6)
            }
        }
        .presentationDetents([.height(sheetContentHeight)])
        .presentationDragIndicator(.visible)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) { chromeVisible = true }
        }
        .task {
            let p    = pass
            let prof = profile
            let lang = settings.language

            // Cache hit → show immediately, no animation needed
            if let cached = TicketCache.shared.image(for: p, language: lang) {
                ticketImage = cached
                revealed    = true
                return
            }

            // Cache miss → cycle loading copy while rendering off-thread
            let phaseTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    if !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.35)) { loadingPhase += 1 }
                    }
                }
            }

            // Render on a background thread — doesn't block the UI
            let image = await Task.detached(priority: .userInitiated) {
                TicketRenderer.render(pass: p, profile: prof, language: lang)
            }.value

            phaseTask.cancel()

            // Store so subsequent opens are instant
            TicketCache.shared.cache(image, for: p, language: lang)
            ticketImage = image

            // Quick scan reveal animation
            HapticsManager.light()
            withAnimation(.linear(duration: 0.25)) { scanFraction = 1 }
            try? await Task.sleep(nanoseconds: 280_000_000)
            revealed = true
            HapticsManager.medium()
        }
    }

    // MARK: Ticket area

    @ViewBuilder
    private var ticketArea: some View {
        if let img = ticketImage {
            PlanetPass3DView(
                image:        img,
                scanFraction: scanFraction,
                revealed:     revealed,
                accentColor:  planet.color,
                isExporting:  isExporting
            )
        } else {
            // Loading state — shown only on first open (subsequent opens use cache)
            let copies = [S.preparingPass, S.renderingPass, S.generatingCredential]
            ZStack {
                // Base card
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(planet.color.opacity(0.20), lineWidth: 0.5)
                    )

                // Corner registration marks — sci-fi card framing
                Canvas { ctx, size in
                    let len: CGFloat  = 10
                    let pad: CGFloat  = 14
                    let lw:  CGFloat  = 0.7
                    let marks: [(CGPoint, CGPoint, CGPoint)] = [
                        (CGPoint(x: pad, y: pad + len),      CGPoint(x: pad, y: pad),      CGPoint(x: pad + len, y: pad)),
                        (CGPoint(x: size.width - pad - len, y: pad),      CGPoint(x: size.width - pad, y: pad),      CGPoint(x: size.width - pad, y: pad + len)),
                        (CGPoint(x: pad, y: size.height - pad - len), CGPoint(x: pad, y: size.height - pad), CGPoint(x: pad + len, y: size.height - pad)),
                        (CGPoint(x: size.width - pad - len, y: size.height - pad), CGPoint(x: size.width - pad, y: size.height - pad), CGPoint(x: size.width - pad, y: size.height - pad - len)),
                    ]
                    for (a, b, c) in marks {
                        var p = Path()
                        p.move(to: a); p.addLine(to: b); p.addLine(to: c)
                        ctx.stroke(p, with: .color(planet.color.opacity(0.35)), lineWidth: lw)
                    }
                }
                .allowsHitTesting(false)

                // Centre content
                VStack(spacing: 20) {
                    // Dual-ring spinner
                    ZStack {
                        // Outer ring — slow, counter-rotates, planet colour
                        Circle()
                            .trim(from: 0, to: 0.55)
                            .stroke(
                                planet.color.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
                            )
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-spinAngle * 0.55))
                        // Inner ring — fast, accent colour
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                AppTheme.accentPrimary.opacity(0.85),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(spinAngle))
                    }
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            spinAngle = 360
                        }
                    }

                    // Cycling copy with fade transition
                    VStack(spacing: 10) {
                        Text(copies[loadingPhase % copies.count])
                            .font(AppTheme.mono(8, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .kerning(1.5)
                            .id(loadingPhase)
                            .transition(.opacity)

                        // Three-dot progress — advances with loadingPhase
                        HStack(spacing: 5) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(i < (loadingPhase % 3) + 1
                                          ? AppTheme.accentPrimary.opacity(0.75)
                                          : AppTheme.stroke)
                                    .frame(width: 4, height: 4)
                                    .animation(.easeOut(duration: 0.25), value: loadingPhase)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Layout

    /// Sheet height = square ticket + all fixed chrome, sized for the current device.
    /// nav(42) + topPad(20) + bottomPad(16) + divider(1) + shareTopPad(12) + share(52) + shareBottomPad(8)
    /// + safe-area buffer(40) = 191 pt overhead.
    private var sheetContentHeight: CGFloat {
        let ticketSize = viewWidth - 32   // 16pt horizontal padding each side
        return ticketSize + 191
    }

    // MARK: Share

    private func sharePass() {
        guard let image = ticketImage else { return }

        isExporting = true
        HapticsManager.medium()

        let shareText = S.shareProgressText(level: profile.level)
        let vc = UIActivityViewController(activityItems: [shareText, image], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in self.isExporting = false }
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            isExporting = false
            return
        }
        while let next = presenter.presentedViewController, !next.isBeingDismissed {
            presenter = next
        }
        vc.popoverPresentationController?.sourceView = presenter.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.maxY - 80,
            width: 0, height: 0
        )
        presenter.present(vc, animated: true)
    }
}

// MARK: - ProgressAnimatedBar
/// 3 pt capsule progress bar that animates from 0 to `fraction` on first appear.
/// Extracted to its own view so `@State` survives re-renders of its parent.
private struct ProgressAnimatedBar: View {
    let fraction: CGFloat
    @State private var displayFraction: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(AppTheme.accentPrimary.opacity(0.50))
                    .frame(width: max(4, geo.size.width * displayFraction))
            }
        }
        .frame(height: 3)
        .onAppear {
            // Reset on every appear so returning from a game re-plays the animation.
            displayFraction = 0
            withAnimation(.easeOut(duration: 0.85).delay(0.30)) {
                displayFraction = fraction
            }
        }
    }
}

// MARK: - MiniNetworkCanvas
/// Compact animated node-network used inside the map tile.
///
/// Layout: 16 nodes in a 4×4 deterministic grid with small per-node jitter.
/// Active nodes (proportional to `activeFrac`) glow orange; one active edge per cycle
/// sweeps as a "signal flow" — the same visual language as the game board itself.
/// Driven by TimelineView at 8 fps — imperceptible for slow effects, very cheap.
private struct MiniNetworkCanvas: View {
    let activeFrac: CGFloat

    // Deterministic 16-node layout: 4 cols × 4 rows with small per-node jitter
    private static let positions: [(CGFloat, CGFloat)] = {
        (0..<16).map { i in
            let col = i % 4, row = i / 4
            let x = (CGFloat(col) + 0.5) / 4.0
            let y = (CGFloat(row) + 0.5) / 4.0
            // Jitter derived from index — no randomness, fully deterministic
            let jx = CGFloat((row * 3 + col * 7) % 5 - 2) * 0.028
            let jy = CGFloat((col * 5 + row * 11) % 5 - 2) * 0.038
            return (x + jx, y + jy)
        }
    }()

    // Horizontal edges (right neighbours) + vertical edges (all pairs in 4×4)
    private static let edges: [(Int, Int)] = {
        var e = [(Int, Int)]()
        for row in 0..<4 {
            for col in 0..<4 {
                let i = row * 4 + col
                if col < 3 { e.append((i, i + 1)) }   // horizontal
                if row < 3 { e.append((i, i + 4)) }   // vertical
            }
        }
        return e
    }()

    private var activeCount: Int {
        max(1, Int((activeFrac * CGFloat(Self.positions.count)).rounded()))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { timeline in
            Canvas { ctx, size in
                let t     = timeline.date.timeIntervalSinceReferenceDate
                let act   = activeCount
                let pos   = Self.positions
                let edges = Self.edges

                // 1. All edges — active-pair edges are brighter
                for (a, b) in edges {
                    let pa   = CGPoint(x: pos[a].0 * size.width, y: pos[a].1 * size.height)
                    let pb   = CGPoint(x: pos[b].0 * size.width, y: pos[b].1 * size.height)
                    let both = a < act && b < act
                    var path = Path()
                    path.move(to: pa)
                    path.addLine(to: pb)
                    ctx.stroke(path, with: .color(.white.opacity(both ? 0.20 : 0.05)),
                               lineWidth: 0.5)
                }

                // 2. Signal sweep — one active edge glows per cycle
                let activeEdges = edges.filter { $0.0 < act && $0.1 < act }
                if !activeEdges.isEmpty {
                    let cycle = t.truncatingRemainder(dividingBy: 3.0)
                    let idx   = Int(cycle / 3.0 * Double(activeEdges.count)) % activeEdges.count
                    let (a, b) = activeEdges[idx]
                    let pa = CGPoint(x: pos[a].0 * size.width, y: pos[a].1 * size.height)
                    let pb = CGPoint(x: pos[b].0 * size.width, y: pos[b].1 * size.height)
                    var flow = Path()
                    flow.move(to: pa)
                    flow.addLine(to: pb)
                    ctx.stroke(flow, with: .color(AppTheme.accentPrimary.opacity(0.80)),
                               lineWidth: 1.5)
                }

                // 3. Nodes — active ones pulse with a soft outer glow
                for (i, (nx, ny)) in pos.enumerated() {
                    let cx       = nx * size.width
                    let cy       = ny * size.height
                    let isActive = i < act
                    let pulse    = isActive ? 0.5 + 0.5 * sin(t * 1.6 + Double(i) * 0.9) : 0.0
                    let r: CGFloat = isActive ? 2.0 : 1.0

                    if isActive {
                        // Soft outer glow
                        let gr = r + 2.0 + CGFloat(pulse) * 1.5
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: cx - gr, y: cy - gr,
                                                   width: gr * 2, height: gr * 2)),
                            with: .color(AppTheme.accentPrimary.opacity(0.05 + 0.07 * pulse))
                        )
                    }
                    // Core dot
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                               width: r * 2, height: r * 2)),
                        with: .color(isActive
                            ? AppTheme.accentPrimary.opacity(0.58 + 0.24 * pulse)
                            : .white.opacity(0.10))
                    )
                }
            }
        }
    }
}

// MARK: - PlayPressStyle
/// ButtonStyle that adds a spring press-in (0.97 scale) and fires a callback on finger-down.
/// The callback is used to trigger haptics + SFX at the moment of touch, not at action fire.
private struct PlayPressStyle: ButtonStyle {
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                .spring(response: 0.20, dampingFraction: 0.60),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { onPress() }
            }
    }
}

// MARK: - PlayCTAButton
/// Full-width primary action button with:
///   • Spring press-in to 0.97 scale (physical tactile feel)
///   • Spring release back to 1.0
///   • Breathing glow shadow (idle ambient pulse)
///   • Medium haptic on finger-down
///   • Subtle sci-fi click SFX on finger-down (gated by SoundManager.sfxEnabled)
private struct PlayCTAButton: View {
    let label: String
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(AppTheme.mono(18, weight: .black))
                    .kerning(4)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .padding(.horizontal, 22)
            .background(AppTheme.accentPrimary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(PlayPressStyle(onPress: {
            HapticsManager.medium()
            SoundManager.play(.tapPrimary)
        }))
        .shadow(color: AppTheme.accentPrimary.opacity(pulsing ? 0.42 : 0.06), radius: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - MapPreviewBlock
/// Live mission-map preview replacing the old text-link mapRow.
///
/// Renders a compact node-network visualization using Canvas + TimelineView:
///   • 32 nodes in a scattered 8×4 grid
///   • Active (completed) nodes glow orange; inactive nodes are dim white
///   • Active edges brighter; one edge at a time cycles as a "signal flow" sweep
///   • All animation is driven by the system clock — no @State timers, no per-node views
///   • TimelineView period: 1/8 s → 8 fps, imperceptible for slow effects, very cheap
struct MapPreviewBlock: View {
    let completed: Int
    let total: Int
    let onTap: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    // ── Deterministic node positions — 8 cols × 4 rows with small jitter ─────
    private static let positions: [(CGFloat, CGFloat)] = {
        (0..<32).map { i in
            let col = i % 8, row = i / 8
            let x = (CGFloat(col) + 0.5) / 8.0
            let y = (CGFloat(row) + 0.5) / 4.0
            let jx = CGFloat((row * 3 + col * 7) % 5 - 2) * 0.012
            let jy = CGFloat((col * 5 + row * 11) % 5 - 2) * 0.018
            return (x + jx, y + jy)
        }
    }()

    // ── Neighbour edges: right + sparse vertical ──────────────────────────────
    private static let edges: [(Int, Int)] = {
        var e = [(Int, Int)]()
        for row in 0..<4 {
            for col in 0..<8 {
                let i = row * 8 + col
                if col < 7 { e.append((i, i + 1)) }
                if row < 3 && col % 3 == 0 { e.append((i, i + 8)) }
            }
        }
        return e
    }()

    private var activeNodeCount: Int {
        let frac = total > 0 ? Double(completed) / Double(total) : 0
        return max(1, Int(frac * Double(Self.positions.count)))
    }

    private var completionPct: Int { total > 0 ? Int(Double(completed) / Double(total) * 100) : 0 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        TechLabel(text: S.missionMapTitle, color: AppTheme.textSecondary.opacity(0.60))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completed)")
                                .font(AppTheme.mono(20, weight: .black))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                            Text("/ \(total)")
                                .font(AppTheme.mono(11))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(S.viewFullMap)
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary.opacity(0.80))
                            .kerning(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary.opacity(0.70))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.accentPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.18), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // ── Node network ─────────────────────────────────────────
                TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { timeline in
                    Canvas { ctx, size in
                        let t   = timeline.date.timeIntervalSinceReferenceDate
                        let act = activeNodeCount
                        let pos = Self.positions
                        let edges = Self.edges

                        // ── 1. Edges ──────────────────────────────────────
                        for (a, b) in edges {
                            let pa = CGPoint(x: pos[a].0 * size.width, y: pos[a].1 * size.height)
                            let pb = CGPoint(x: pos[b].0 * size.width, y: pos[b].1 * size.height)
                            let both = a < act && b < act
                            var path = Path(); path.move(to: pa); path.addLine(to: pb)
                            ctx.stroke(path, with: .color(.white.opacity(both ? 0.22 : 0.06)),
                                       lineWidth: 0.5)
                        }

                        // ── 2. Signal flow sweep — one active edge cycles ─
                        let activeEdges = edges.filter { $0.0 < act && $0.1 < act }
                        if !activeEdges.isEmpty {
                            let cycle = t.truncatingRemainder(dividingBy: 4.0)
                            let idx   = Int(cycle / 4.0 * Double(activeEdges.count)) % activeEdges.count
                            let (a, b) = activeEdges[idx]
                            let pa = CGPoint(x: pos[a].0 * size.width, y: pos[a].1 * size.height)
                            let pb = CGPoint(x: pos[b].0 * size.width, y: pos[b].1 * size.height)
                            var flow = Path(); flow.move(to: pa); flow.addLine(to: pb)
                            ctx.stroke(flow, with: .color(AppTheme.accentPrimary.opacity(0.70)),
                                       lineWidth: 1.2)
                        }

                        // ── 3. Nodes ──────────────────────────────────────
                        for (i, (nx, ny)) in pos.enumerated() {
                            let cx   = nx * size.width
                            let cy   = ny * size.height
                            let isActive = i < act
                            let pulse = isActive ? 0.5 + 0.5 * sin(t * 1.8 + Double(i) * 0.9) : 0.0
                            let r: CGFloat = isActive ? 2.2 : 1.2

                            if isActive {
                                // Soft outer glow
                                let gr = r + 2.5 + CGFloat(pulse) * 1.5
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: cx - gr, y: cy - gr,
                                                           width: gr * 2, height: gr * 2)),
                                    with: .color(AppTheme.accentPrimary.opacity(0.05 + 0.06 * pulse))
                                )
                            }
                            // Node dot
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                                       width: r * 2, height: r * 2)),
                                with: .color(isActive
                                    ? AppTheme.accentPrimary.opacity(0.55 + 0.22 * pulse)
                                    : .white.opacity(0.12))
                            )
                        }
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

                // ── Footer ───────────────────────────────────────────────
                Rectangle().fill(AppTheme.stroke).frame(height: 0.5)

                HStack {
                    Text(S.missionsCompleted(done: completed, total: total))
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
                        .kerning(0.8)
                    Spacer()
                    Text("\(completionPct)% COMPLETE")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.60))
                        .kerning(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.14), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GeoTitle
/// "GEOMETRY" with two independent ambient effects:
///   • Periodic tilt on the "R" (easter egg, ~6s cycle)
///   • Rare glitch: horizontal offset + RGB-split ghost copies (~8–15s interval, ~150ms duration)
private struct GeoTitle: View {
    @State private var rTilt:       Double  = 0
    @State private var isGlitching: Bool    = false
    @State private var glitchX:     CGFloat = 0
    @State private var glitchY:     CGFloat = 0

    var body: some View {
        ZStack {
            // Ghost layers — only during glitch (RGB-split simulation)
            if isGlitching {
                // Orange ghost — shifted right + slight Y warp
                letters
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.55))
                    .offset(x: glitchX + 11, y: glitchY)
                // Sage ghost — shifted left in opposite direction
                letters
                    .foregroundStyle(AppTheme.accentSecondary.opacity(0.38))
                    .offset(x: glitchX - 7, y: -glitchY * 0.6)
            }
            // Primary text — desaturates slightly during glitch
            letters
                .foregroundStyle(AppTheme.textPrimary)
                .offset(x: isGlitching ? glitchX : 0)
                .opacity(isGlitching ? 0.68 : 1.0)
        }
        .task { await tiltLoop() }
        .task { await glitchLoop() }
    }

    /// Letter layout shared by all layers.
    @ViewBuilder
    private var letters: some View {
        HStack(spacing: 0) {
            Text("GEOMET").kerning(5)
            Text("R").kerning(5)
                .rotationEffect(.degrees(rTilt))
            Text("Y")
        }
        .font(AppTheme.mono(26, weight: .heavy))
    }

    // MARK: Tilt loop (~6 s cycle)
    private func tiltLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { rTilt = 10 }
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) { rTilt = 0 }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: Glitch loop (8–16 s idle, ~230 ms burst with 3 flashes)
    private func glitchLoop() async {
        // Stagger so glitch never fires immediately on launch
        try? await Task.sleep(nanoseconds: UInt64.random(in: 8_000_000_000...13_000_000_000))
        while !Task.isCancelled {
            // --- flash 1: main hit ---
            glitchX = CGFloat.random(in: -12...12)
            glitchY = CGFloat.random(in: -3...3)
            isGlitching = true
            try? await Task.sleep(nanoseconds: 55_000_000)   // 55 ms

            // --- flash 2: reposition while still glitching ---
            glitchX = CGFloat.random(in: -9...9)
            glitchY = CGFloat.random(in: -2...2)
            try? await Task.sleep(nanoseconds: 40_000_000)   // 40 ms

            // --- brief blackout (primary disappears) ---
            isGlitching = false
            try? await Task.sleep(nanoseconds: 25_000_000)   // 25 ms

            // --- flash 3: final twitch ---
            glitchX = CGFloat.random(in: -7...7)
            glitchY = 0
            isGlitching = true
            try? await Task.sleep(nanoseconds: 55_000_000)   // 55 ms

            // --- reset ---
            isGlitching = false
            glitchX = 0
            glitchY = 0

            // --- next idle ---
            let idle = UInt64.random(in: 8_000_000_000...16_000_000_000)
            try? await Task.sleep(nanoseconds: idle)
        }
    }
}

// MARK: - ConfettiOverlay

private struct ConfettiParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let size: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let color: Color
    let isCircle: Bool
}

struct ConfettiOverlay: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var startDate = Date()
    private let duration: TimeInterval = 3.0
    private let particleCount = 80
    private let orange = Color(hex: "FF6A3D")
    private let sage = Color(hex: "4DB87A")

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            Canvas { context, size in
                for p in particles {
                    let t = CGFloat(elapsed)
                    let x = p.x * size.width + p.vx * t
                    let y = p.y * size.height + p.vy * t + 120 * t * t
                    let alpha = max(0, 1.0 - CGFloat(elapsed / duration))

                    guard y < size.height + 20, alpha > 0 else { continue }

                    var ctx = context
                    ctx.opacity = Double(alpha)
                    let angle = Angle.degrees(p.rotation + p.rotationSpeed * elapsed)
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: angle)

                    if p.isCircle {
                        let r = p.size / 2
                        let circle = Path(ellipseIn: CGRect(x: -r, y: -r, width: p.size, height: p.size))
                        ctx.fill(circle, with: .color(p.color))
                    } else {
                        let w = p.size * 0.5
                        let h = p.size
                        let rect = Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                        ctx.fill(rect, with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { spawnParticles() }
    }

    private func spawnParticles() {
        startDate = Date()
        particles = (0..<particleCount).map { i in
            ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 0.1...0.9),
                y: CGFloat.random(in: -0.15...(-0.02)),
                vx: CGFloat.random(in: -60...60),
                vy: CGFloat.random(in: 20...180),
                size: CGFloat.random(in: 4...9),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -360...360),
                color: Bool.random() ? orange : sage,
                isCircle: Bool.random()
            )
        }
    }
}

// MARK: - LeaderboardPickerOverlay
struct LeaderboardPickerOverlay: View {
    let onDismiss: () -> Void

    @EnvironmentObject private var gcManager: GameCenterManager
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    enum Section { case leaderboards, achievements }
    enum MainCategory { case global, daily, weekly }

    @State private var revealed = false
    @State private var section: Section = .leaderboards
    @State private var mainCategory: MainCategory = .global
    @State private var diffFilter: DifficultyTier? = nil
    @State private var boards: [String: GameCenterManager.LeaderboardData] = [:]
    @State private var loadingIDs: Set<String> = []
    @State private var achievements: [GameCenterManager.AchievementData] = []
    @State private var achievementsLoaded = false
    @State private var selectedAchievementID: String? = nil
    @State private var showingChallengeFlow = false
    @State private var showConfetti = false

    // Dark background + sage highlights
    private let dark   = Color(hex: "171717")
    private let sage   = Color(hex: "D9E7D8")
    private let ink    = Color(hex: "2A2A2A")
    private let light  = Color(hex: "F0EDE8")
    private let muted  = Color(hex: "9A9A9A")
    private let orange = Color(hex: "FF6A3D")

    private var activeID: String {
        switch mainCategory {
        case .global:
            guard let tier = diffFilter else { return GameCenterManager.leaderboardTotalScore }
            return tierBoardID(tier)
        case .daily:  return GameCenterManager.leaderboardDailyChallenge
        case .weekly: return GameCenterManager.leaderboardDailyCumulative
        }
    }

    private var categoryLabel: String {
        switch mainCategory {
        case .global:
            if let tier = diffFilter {
                return "\u{25C8} \(S.leaderboardPickerTitle) \u{00B7} \(S.difficultyFullLabel(tier))"
            }
            return "\u{25C8} \(S.leaderboardPickerTitle) \u{00B7} \(S.leaderboardGlobalShort)"
        case .daily:
            return "\u{25C8} \(S.dailyChallengeContext)"
        case .weekly:
            return "\u{25C8} \(S.dailyAccumContext)"
        }
    }

    var body: some View {
        ZStack {
            dark.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Rectangle().fill(light.opacity(0.08)).frame(height: 0.5)
                leaderboardContent
            }
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 10)

            if showingChallengeFlow {
                ChallengeFlowOverlay(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) { showingChallengeFlow = false }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }

            if showConfetti {
                ConfettiOverlay()
                    .ignoresSafeArea()
                    .zIndex(10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.08)) {
                revealed = true
            }
            fetchAllBoards()
            Task { await gcManager.refreshActiveChallengeCount() }
        }
        .onChange(of: gcManager.isAuthenticated) { _, authed in
            if authed { boards = [:]; fetchAllBoards() }
        }
        .onChange(of: activeID) { _, newID in
            showConfetti = false
            if let data = boards[newID], data.playerRank == 1 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    showConfetti = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { SoundManager.play(.tapSecondary); onDismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(light)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(S.leaderboardPickerTitle)
                .font(AppTheme.mono(12, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(light)
            Spacer()
            Button(action: { SoundManager.play(.tapPrimary); gcManager.openChallenges() }) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(muted)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Section toggle

    private var sectionToggle: some View {
        HStack(spacing: 0) {
            sectionTab(S.leaderboardPickerTitle, sec: .leaderboards)
            sectionTab(S.achievements, sec: .achievements)
        }
    }

    private func sectionTab(_ label: String, sec: Section) -> some View {
        let active = section == sec
        return Button(action: {
            SoundManager.play(.tapSecondary)
            withAnimation(.easeInOut(duration: 0.15)) { section = sec }
            if sec == .leaderboards { selectedAchievementID = nil }
            if sec == .achievements { fetchAchievements() }
        }) {
            Text(label)
                .font(AppTheme.mono(10, weight: active ? .bold : .medium))
                .kerning(0.8)
                .foregroundStyle(active ? light : muted.opacity(0.6))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    if active {
                        Rectangle().fill(sage).frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leaderboard content

    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            segmentedControl
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if mainCategory == .global {
                difficultyPills
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            if loadingIDs.contains(activeID) {
                Spacer()
                ProgressView().tint(sage)
                Spacer()
            } else if let data = boards[activeID] {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if let rank = data.playerRank {
                                heroRankCard(data: data, rank: rank)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)
                                    .onAppear {
                                        if rank == 1 {
                                            showConfetti = true
                                        }
                                    }
                            }

                            if data.totalPlayers > 0 {
                                HStack {
                                    Text(S.rankingCount(data.totalPlayers))
                                        .font(AppTheme.mono(9, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundStyle(muted)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 6)
                            }

                            Rectangle().fill(light.opacity(0.08)).frame(height: 1)

                            LazyVStack(spacing: 0) {
                                ForEach(data.entries, id: \.rank) { entry in
                                    playerRow(entry: entry)
                                        .id(entry.rank)
                                }
                            }
                        }
                    }
                    .onAppear { scrollToLocal(proxy: proxy) }
                }
            } else {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(muted.opacity(0.4))
                    Text(S.leaderboardEmpty)
                        .font(AppTheme.mono(10, weight: .medium))
                        .foregroundStyle(muted)
                }
                Spacer()
            }

            Button(action: {
                SoundManager.play(.tapPrimary)
                withAnimation(.easeInOut(duration: 0.2)) { showingChallengeFlow = true }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(S.inviteFriends)
                        .font(AppTheme.mono(11, weight: .bold))
                        .kerning(1)
                    if gcManager.activeChallengeCount > 0 {
                        Text("\(gcManager.activeChallengeCount)")
                            .font(AppTheme.mono(9, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color(hex: "FF6A3D"))
                            .clipShape(Circle())
                    }
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(sage)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .task(id: activeID) { fetchBoard(activeID) }
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(S.leaderboardGlobalShort, cat: .global)
            segmentButton(S.leaderboardDailyShort, cat: .daily)
            segmentButton(S.leaderboardAccumShort, cat: .weekly)
        }
        .background(light.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(light.opacity(0.08), lineWidth: 0.5))
    }

    private func segmentButton(_ label: String, cat: MainCategory) -> some View {
        let active = mainCategory == cat
        return Button(action: {
            SoundManager.play(.tapSecondary)
            withAnimation(.easeInOut(duration: 0.15)) {
                mainCategory = cat
                diffFilter = nil
            }
        }) {
            Text(label)
                .font(AppTheme.mono(10, weight: .bold))
                .kerning(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(active ? ink : light)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(active ? sage : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Difficulty pills

    private var difficultyPills: some View {
        HStack(spacing: 6) {
            diffPill(S.leaderboardAllTiers, tier: nil)
            ForEach(DifficultyTier.allCases, id: \.self) { tier in
                diffPill(S.difficultyFullLabel(tier), tier: tier)
            }
        }
    }

    private func diffPill(_ label: String, tier: DifficultyTier?) -> some View {
        let active = diffFilter == tier
        return Button(action: {
            SoundManager.play(.tapSecondary)
            withAnimation(.easeInOut(duration: 0.15)) { diffFilter = tier }
        }) {
            Text(label)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(active ? ink : muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(active ? sage : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(active ? Color.clear : light.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero rank card (sage green widget card on dark bg)

    private func heroRankCard(data: GameCenterManager.LeaderboardData, rank: Int) -> some View {
        let localEntry = data.entries.first(where: { $0.isLocalPlayer })
        let aboveEntry = data.entries.first(where: { $0.rank == rank - 1 })
        let localScore = localEntry?.score ?? 0
        let gap = aboveEntry.map { $0.score - localScore }
        let progress: Float = aboveEntry.map { $0.score > 0 ? Float(localScore) / Float($0.score) : 0 } ?? 1.0
        let pct = data.totalPlayers > 0 ? max(1, Int(Double(rank) / Double(data.totalPlayers) * 100)) : 0
        let sageMid = ink.opacity(0.5)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(categoryLabel)
                    .font(AppTheme.mono(8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(sageMid)
                Spacer()
                Text("\u{2606} SV|\(data.totalPlayers)")
                    .font(AppTheme.mono(10, weight: .bold))
                    .foregroundStyle(ink)
            }

            Rectangle().fill(ink.opacity(0.12)).frame(height: 0.5).padding(.top, 8)

            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .top, spacing: -6) {
                    Text("#")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(ink)
                        .offset(y: 8)
                    Text("\(rank)")
                        .font(.system(size: 96, weight: .heavy))
                        .foregroundStyle(orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(localScore.formatted())
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if pct > 0 {
                        Text("TOP \(pct)% \u{00B7} \(S.leaderboardOfTotal(data.totalPlayers))")
                            .font(AppTheme.mono(8, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(sageMid)
                    }
                }
                .padding(.top, 16)
            }
            .padding(.top, 4)

            if let gap, gap > 0, rank > 1 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ink.opacity(0.08))
                            Capsule().fill(orange)
                                .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
                        }
                    }
                    .frame(height: 6)
                    .clipShape(Capsule())

                    HStack {
                        Text(S.ptsToNextRank(gap.formatted(), rank - 1))
                            .font(AppTheme.mono(8, weight: .medium))
                            .foregroundStyle(orange.opacity(0.8))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(sageMid)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(16)
        .background(sage)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Player row (white text on dark)

    private func playerRow(entry: LeaderboardEntrySnapshot) -> some View {
        let isLocal = entry.isLocalPlayer

        return HStack(spacing: 0) {
            Text("#\(entry.rank)")
                .font(AppTheme.mono(13, weight: .heavy))
                .foregroundStyle(isLocal ? orange : light)
                .frame(width: 44, alignment: .leading)

            Text(entry.displayName)
                .font(AppTheme.mono(13, weight: isLocal ? .bold : .medium))
                .foregroundStyle(isLocal ? orange : light)
                .lineLimit(1)

            if isLocal {
                Text(S.leaderboardYou)
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(orange.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.leading, 6)
            }

            Spacer()

            Text(entry.score.formatted())
                .font(AppTheme.mono(13, weight: .bold))
                .foregroundStyle(isLocal ? orange : light.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isLocal ? orange.opacity(0.08) : Color.clear)
    }

    // MARK: - Achievements content (dark bg)

    private var achievementsContent: some View {
        Group {
            if !achievementsLoaded {
                Spacer()
                ProgressView().tint(sage)
                Spacer()
            } else if achievements.isEmpty {
                Spacer()
                Text(S.leaderboardEmpty)
                    .font(AppTheme.mono(10, weight: .medium))
                    .foregroundStyle(muted)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(achievements) { ach in
                            Button(action: {
                                SoundManager.play(.tapSecondary)
                                withAnimation(.easeInOut(duration: 0.2)) { selectedAchievementID = ach.identifier }
                            }) {
                                achievementRow(ach)
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(light.opacity(0.06)).frame(height: 0.5).padding(.leading, 68)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func achievementRow(_ ach: GameCenterManager.AchievementData) -> some View {
        HStack(spacing: 12) {
            if let img = ach.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .saturation(ach.isCompleted ? 1 : 0.3)
                    .opacity(ach.isCompleted ? 1 : 0.5)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(light.opacity(0.04))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(muted.opacity(0.4))
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ach.title)
                    .font(AppTheme.mono(11, weight: ach.isCompleted ? .bold : .medium))
                    .foregroundStyle(ach.isCompleted ? light : muted.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(ach.descriptionText)
                        .font(AppTheme.mono(8, weight: .medium))
                        .foregroundStyle(muted.opacity(0.5))
                        .lineLimit(1)

                    if ach.maximumPoints > 0 {
                        Text(S.achievementPoints(ach.maximumPoints))
                            .font(AppTheme.mono(7, weight: .bold))
                            .foregroundStyle(ach.isCompleted ? orange : muted.opacity(0.4))
                    }
                }
            }

            Spacer()

            if ach.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(orange)
            } else if ach.percentComplete > 0 {
                Text("\(Int(ach.percentComplete))%")
                    .font(AppTheme.mono(10, weight: .bold))
                    .foregroundStyle(orange)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(light.opacity(0.15))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Achievement detail (sage green card)

    private func achievementDetail(_ ach: GameCenterManager.AchievementData) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    SoundManager.play(.tapSecondary)
                    withAnimation(.easeInOut(duration: 0.2)) { selectedAchievementID = nil }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text(S.achievements)
                            .font(AppTheme.mono(10, weight: .semibold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(muted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle().fill(light.opacity(0.06)).frame(height: 0.5)

            AchievementCard3D(ach: ach, sage: sage, ink: ink, light: light, muted: muted, orange: orange, S: S)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Helpers

    private func scrollToLocal(proxy: ScrollViewProxy) {
        if let rank = boards[activeID]?.playerRank {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(rank, anchor: .center) }
            }
        }
    }

    private func tierBoardID(_ tier: DifficultyTier) -> String {
        switch tier {
        case .easy:   return GameCenterManager.leaderboardTierEasy
        case .medium: return GameCenterManager.leaderboardTierMedium
        case .hard:   return GameCenterManager.leaderboardTierHard
        case .expert: return GameCenterManager.leaderboardTierExpert
        }
    }

    private func fetchBoard(_ id: String) {
        guard boards[id] == nil, !loadingIDs.contains(id) else { return }
        loadingIDs.insert(id)
        Task {
            var data = await gcManager.fetchLeaderboard(id: id, count: 25)
            if data == nil {
                try? await Task.sleep(for: .seconds(1.5))
                data = await gcManager.fetchLeaderboard(id: id, count: 25)
            }
            if let data { boards[id] = data }
            loadingIDs.remove(id)
        }
    }

    private func fetchAllBoards() {
        fetchBoard(activeID)
    }

    private func fetchAchievements() {
        guard !achievementsLoaded else { return }
        Task {
            let data = await gcManager.fetchAchievements()
            achievements = data
            achievementsLoaded = true
        }
    }

}

// MARK: - ChallengeFlowOverlay
struct ChallengeFlowOverlay: View {
    let onDismiss: () -> Void

    @EnvironmentObject private var gcManager: GameCenterManager
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var defs: [GameCenterManager.ChallengeDefinitionData] = []
    @State private var loaded = false

    private let dark   = Color(hex: "171717")
    private let sage   = Color(hex: "D9E7D8")
    private let ink    = Color(hex: "2A2A2A")
    private let light  = Color(hex: "F0EDE8")
    private let muted  = Color(hex: "9A9A9A")
    private let orange = Color(hex: "FF6A3D")

    var body: some View {
        ZStack {
            dark.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Rectangle().fill(light.opacity(0.08)).frame(height: 0.5)
                challengePickerList
            }
        }
        .onAppear {
            Task {
                defs = await gcManager.fetchChallengeDefinitions()
                loaded = true
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: {
                SoundManager.play(.tapSecondary)
                onDismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(light)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(S.challengeSelectTitle)
                .font(AppTheme.mono(12, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(light)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Challenge picker list

    private var challengePickerList: some View {
        Group {
            if !loaded {
                Spacer()
                ProgressView().tint(sage)
                Spacer()
            } else if defs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "flag.2.crossed")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(muted.opacity(0.4))
                    Text(S.challengeNone)
                        .font(AppTheme.mono(10, weight: .medium))
                        .foregroundStyle(muted)
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(defs) { def in
                            Button(action: {
                                SoundManager.play(.tapPrimary)
                                gcManager.triggerChallenge(identifier: def.identifier)
                            }) {
                                challengeCard(def)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private func challengeCard(_ def: GameCenterManager.ChallengeDefinitionData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let lbTitle = def.leaderboardTitle {
                    Text("\u{25C8} \(lbTitle.uppercased())")
                        .font(AppTheme.mono(7, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(ink.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
                if def.hasActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(orange)
                            .frame(width: 5, height: 5)
                        Text(S.challengeActive)
                            .font(AppTheme.mono(7, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            Rectangle().fill(ink.opacity(0.08)).frame(height: 0.5).padding(.top, 8)

            HStack(spacing: 14) {
                if let img = def.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ink.opacity(0.06))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(orange)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(def.title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(ink)
                        .lineLimit(2)

                    if let details = def.details {
                        Text(details)
                            .font(AppTheme.mono(9, weight: .medium))
                            .foregroundStyle(ink.opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.top, 10)

            HStack(spacing: 6) {
                if !def.durationOptions.isEmpty {
                    ForEach(Array(def.durationOptions.enumerated()), id: \.offset) { _, dc in
                        Text(formatDuration(dc))
                            .font(AppTheme.mono(7, weight: .bold))
                            .foregroundStyle(ink.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ink.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
                if def.isRepeatable {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise")
                            .font(.system(size: 7, weight: .semibold))
                        Text(S.challengeRepeatable)
                            .font(AppTheme.mono(7, weight: .bold))
                    }
                    .foregroundStyle(ink.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ink.opacity(0.06))
                    .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ink.opacity(0.3))
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(sage)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func formatDuration(_ dc: DateComponents) -> String {
        if let weeks = dc.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        }
        if let days = dc.day, days > 0 {
            return days == 1 ? "1 day" : "\(days) days"
        }
        if let hours = dc.hour, hours > 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "—"
    }
}

// MARK: - AchievementCard3D
/// Full-screen interactive 3D achievement card — same drag/motion/shine treatment as PlanetPass3DView.
private struct AchievementCard3D: View {
    let ach: GameCenterManager.AchievementData
    let sage: Color
    let ink: Color
    let light: Color
    let muted: Color
    let orange: Color
    let S: AppStrings

    // ── Tilt state ────────────────────────────────────────────────────
    @State private var tilt: CGSize = .zero
    @State private var isDragging = false

    // ── Idle drift ────────────────────────────────────────────────────
    @State private var idleTiltX: Double = 0
    @State private var idleTiltY: Double = 0

    // ── Entry animation ───────────────────────────────────────────────
    @State private var entryOpacity: Double  = 0
    @State private var entryOffsetY: CGFloat = 20
    @State private var entryScale:   CGFloat = 0.92
    @State private var entryTiltX:   Double  = 4.0
    @State private var entryTiltY:   Double  = -6.0

    // ── Tap feedback ──────────────────────────────────────────────────
    @State private var tapScale:     CGFloat = 1.0
    @State private var tapGlowAlpha: Double  = 0.0

    // ── Sheen sweep ───────────────────────────────────────────────────
    @State private var sheenX: CGFloat = -0.5

    // ── Device motion ─────────────────────────────────────────────────
    @ObservedObject private var motion: DeviceMotionManager = .shared
    @State private var motionDragScale: Double = 1.0

    // ── Constants ─────────────────────────────────────────────────────
    private let restTiltX:    Double  =  2.5
    private let restTiltY:    Double  = -3.5
    private let maxTilt:      Double  =  8.0
    private let dragScale:    CGFloat =  80
    private let motionMaxTilt: Double =  5.0
    private let cornerR:      CGFloat = 20

    private func norm(_ v: CGFloat) -> Double {
        Double(max(-1.0, min(1.0, v / dragScale)))
    }
    private var normX: Double { norm(tilt.width) }
    private var normY: Double { norm(tilt.height) }
    private var mX: Double { motion.isAvailable ? motion.tiltX * motionDragScale : 0 }
    private var mY: Double { motion.isAvailable ? motion.tiltY * motionDragScale : 0 }

    private var activeTiltX: Double { restTiltX + normY * maxTilt + entryTiltX + idleTiltX + mY * motionMaxTilt }
    private var activeTiltY: Double { restTiltY + normX * maxTilt + entryTiltY + idleTiltY + mX * motionMaxTilt }

    private var glossShiftX: Double { -normX * 0.14 - mX * 0.10 }
    private var glossShiftY: Double { -normY * 0.10 - mY * 0.08 }
    private var specularX: Double { 0.30 - normX * 0.18 - mX * 0.14 }
    private var specularY: Double { 0.20 - normY * 0.12 - mY * 0.10 }

    private var specularIntensity: Double {
        let dx = specularX - 0.30, dy = specularY - 0.20
        return max(0.25, 1.0 - sqrt(dx * dx + dy * dy) * 2.4)
    }

    private var glossIntensity: Double {
        max(0.55, min(1.2, 1.0 - mX * 0.25 - mY * 0.15))
    }

    private var bevelLightOpacity: Double {
        max(0.08, min(0.40, 0.25 + (-normX - normY - mX - mY) * 0.04))
    }
    private var bevelDarkOpacity: Double {
        max(0.06, min(0.32, 0.16 + (normX + normY + mX + mY) * 0.035))
    }

    private let cardBg = Color(red: 0.070, green: 0.075, blue: 0.085)

    var body: some View {
        ZStack {
            // Edge slab — physical card thickness
            RoundedRectangle(cornerRadius: cornerR)
                .fill(Color.black.opacity(0.55))
                .offset(x: 3 + CGFloat(normX) * 4, y: 8 + CGFloat(normY) * 5)

            // Card content
            cardContent
                .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))

            // Inner shadow — surface curvature
            innerShadow

            // Gloss overlay
            glossOverlay

            // Specular dot
            specularDot

            // Bevel stroke
            bevelOverlay

            // Tap glow
            RoundedRectangle(cornerRadius: cornerR)
                .fill(.white.opacity(tapGlowAlpha))
                .allowsHitTesting(false)

            // Sheen sweep
            sheenSweep
        }
        .rotation3DEffect(.degrees(activeTiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(activeTiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.50), radius: 5, x: 2, y: 5)
        .shadow(
            color: .black.opacity(0.28),
            radius: 28,
            x: 5 + CGFloat(normX) * 7 + CGFloat(mX) * 4,
            y: 16 + CGFloat(normY) * 7 + CGFloat(mY) * 4
        )
        .scaleEffect(entryScale * tapScale)
        .offset(y: entryOffsetY)
        .opacity(entryOpacity)
        .onTapGesture { handleTap() }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        SoundManager.play(.ticketMove)
                        withAnimation(.easeOut(duration: 0.12)) {
                            idleTiltX = 0; idleTiltY = 0; motionDragScale = 0.15
                        }
                    }
                    tilt = value.translation
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { tilt = .zero }
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.30)) { motionDragScale = 1.0 }
                }
        )
        .onAppear { motion.start(); SoundManager.play(.ticketOpen) }
        .onDisappear { motion.stop() }
        .task { await runEntry() }
        .task { await runIdle() }
    }

    // MARK: - Card content

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Hero image
            ZStack {
                Color.black.opacity(0.25)
                Group {
                    if let img = ach.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .saturation(ach.isCompleted ? 1 : 0.20)
                            .opacity(ach.isCompleted ? 1 : 0.45)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                }
                .frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            ach.isCompleted ? orange.opacity(0.55) : Color.white.opacity(0.10),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: ach.isCompleted ? orange.opacity(0.25) : Color.clear, radius: 16, y: 4)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.3, contentMode: .fit)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

            // Info section
            VStack(spacing: 6) {
                HStack {
                    TechLabel(text: "ACHIEVEMENT", color: .white.opacity(0.35))
                    Spacer()
                    if ach.isCompleted {
                        HStack(spacing: 4) {
                            Circle().fill(orange).frame(width: 5, height: 5)
                            TechLabel(text: "UNLOCKED", color: orange.opacity(0.85))
                        }
                    } else {
                        TechLabel(text: "LOCKED", color: .white.opacity(0.28))
                    }
                }

                Text(ach.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(ach.descriptionText)
                    .font(AppTheme.mono(9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
                .padding(.horizontal, 16)

            // Badges + status row
            HStack(spacing: 6) {
                if ach.maximumPoints > 0 {
                    badgePill(S.achievementPoints(ach.maximumPoints), icon: "star.fill", color: orange)
                }
                if let rarity = ach.rarityPercent {
                    badgePill(S.achievementRarity(Int(rarity)), icon: "person.2.fill", color: .white.opacity(0.45))
                }
                if ach.isReplayable {
                    badgePill(S.achievementReplayable, icon: "arrow.trianglehead.2.counterclockwise", color: .white.opacity(0.45))
                }
                Spacer(minLength: 0)
                statusBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(cardBg)
    }

    private func badgePill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(AppTheme.mono(7, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusBadge: some View {
        if ach.isCompleted {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(S.achievementCompleted)
                    .font(AppTheme.mono(7, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(orange)
        } else if ach.percentComplete > 0 {
            Text("\(Int(ach.percentComplete))%")
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(orange)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .medium))
                Text(S.achievementLocked)
                    .font(AppTheme.mono(7, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(.white.opacity(0.28))
        }
    }

    // MARK: - Shine layers

    private var innerShadow: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.14), .clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.18)
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.12)],
                startPoint: UnitPoint(x: 0.5, y: 0.82), endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerR))
        .allowsHitTesting(false)
    }

    private var glossOverlay: some View {
        let g = glossIntensity
        return RoundedRectangle(cornerRadius: cornerR)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.12 * g), location: 0.00),
                        .init(color: .white.opacity(0.05 * g), location: 0.36),
                        .init(color: .clear,                    location: 0.54),
                    ],
                    startPoint: UnitPoint(x: 0.10 + glossShiftX, y: glossShiftY),
                    endPoint:   UnitPoint(x: 0.90 + glossShiftX, y: 1.0 + glossShiftY)
                )
            )
            .allowsHitTesting(false)
    }

    private var specularDot: some View {
        let a = specularIntensity
        return RadialGradient(
            colors: [
                .white.opacity(0.06 + a * 0.18),
                .white.opacity(0.02 + a * 0.04),
                .clear,
            ],
            center:      UnitPoint(x: specularX, y: specularY),
            startRadius: 0,
            endRadius:   40 + (1.0 - a) * 55
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerR))
        .allowsHitTesting(false)
    }

    private var bevelOverlay: some View {
        RoundedRectangle(cornerRadius: cornerR)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(bevelLightOpacity),        location: 0.00),
                        .init(color: .white.opacity(bevelLightOpacity * 0.30), location: 0.30),
                        .init(color: .black.opacity(bevelDarkOpacity * 0.30),  location: 0.70),
                        .init(color: .black.opacity(bevelDarkOpacity),         location: 1.00),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1.0
            )
            .allowsHitTesting(false)
    }

    private var sheenSweep: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.0),
                    .init(color: .white.opacity(0.22), location: 0.5),
                    .init(color: .clear,               location: 1.0),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 48)
            .rotationEffect(.degrees(-26), anchor: .center)
            .offset(x: sheenX * geo.size.width - 24)
            .frame(maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerR))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 0.55).delay(0.4)) { sheenX = 1.5 }
        }
    }

    // MARK: - Animations

    private func handleTap() {
        HapticsManager.light()
        withAnimation(.easeOut(duration: 0.09)) { tapScale = 0.96 }
        Task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.50)) { tapScale = 1.0 }
        }
        withAnimation(.easeOut(duration: 0.07)) { tapGlowAlpha = 0.09 }
        Task {
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.easeOut(duration: 0.26)) { tapGlowAlpha = 0.0 }
        }
    }

    private func runEntry() async {
        withAnimation(.easeOut(duration: 0.35)) {
            entryOpacity = 1.0; entryOffsetY = 0; entryScale = 1.02
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.spring(response: 0.52, dampingFraction: 0.64)) {
            entryScale = 1.0; entryTiltX = 0; entryTiltY = 0
        }
    }

    private func runIdle() async {
        try? await Task.sleep(nanoseconds: 950_000_000)
        var flip = false
        while !Task.isCancelled {
            if !isDragging {
                let y: Double = flip ? -0.9 : 0.9
                let x: Double = flip ? 0.5 : -0.5
                withAnimation(.easeInOut(duration: 3.2)) { idleTiltY = y }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                if !isDragging {
                    withAnimation(.easeInOut(duration: 4.5)) { idleTiltX = x }
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            flip.toggle()
        }
    }
}
