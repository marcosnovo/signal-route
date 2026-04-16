import SwiftUI
import GameKit

// MARK: - HomeView  (mission-control panel)
struct HomeView: View {
    let onPlay: (Level) -> Void
    let onMissions: () -> Void
    var onUpgrade: (() -> Void)? = nil

    @EnvironmentObject private var gcManager: GameCenterManager
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var entitlement: EntitlementStore
    private var S: AppStrings { AppStrings(lang: settings.language) }
    @State private var secretTaps          = 0
    @State private var lastTapTime         = Date.distantPast
    @State private var showingPlanetTicket = false
    @State private var showingSettings     = false
    @State private var showingDevMenu      = false
    @AppStorage("lastPlayedMissionID") private var lastPlayedMissionID: String = ""
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundSystem()

            // Large decorative text in background
            Text("GEO")
                .font(.system(size: 200, weight: .black, design: .default))
                .foregroundStyle(Color.white.opacity(0.022))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 20, y: 50)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                systemBar
                Spacer(minLength: 24)
                contentArea
                    .opacity(contentOpacity)
                    .onAppear {
                        // Reset and fade in — fires on every home screen visit,
                        // giving a smooth "quick resume" feel when returning from a game.
                        contentOpacity = 0
                        withAnimation(.easeOut(duration: 0.45).delay(0.10)) {
                            contentOpacity = 1.0
                        }
                    }
                Spacer(minLength: 16)
                statusStrip.padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingPlanetTicket) {
            PlanetTicketView(profile: profile)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingDevMenu) {
            DevMenuView(
                onSelect: { level in
                    showingDevMenu = false
                    onPlay(level)
                },
                onDismiss: { showingDevMenu = false }
            )
        }
        // Pre-warm the ticket cache while the user is on the home screen so that
        // opening the planet pass sheet is instant instead of showing a spinner.
        .task(id: ticketCacheKey) {
            guard introCompleted else { return }
            await warmTicketCache()
        }
    }

    // MARK: Subviews

    // ── Content area — single vertical narrative flow ─────────────────────────
    private var contentArea: some View {
        VStack(spacing: 0) {
            if introCompleted {
                if let next = profile.nextMission {
                    // 1. Hero — mission identity
                    heroSection(for: next)
                        .padding(.horizontal, 24)

                    // 2. Primary CTA — PLAY
                    playButton(for: next)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // 3. Progress — integrated, not a card
                    progressRow
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                    Spacer(minLength: 18)

                    // 4. Pass — protagonist secondary element
                    AstronautProgressCard(profile: profile)
                        .padding(.horizontal, 24)
                        .onTapGesture { showingPlanetTicket = true }

                    // 5. Map — live node-network preview block
                    MapPreviewBlock(
                        completed: profile.uniqueCompletions,
                        total: LevelGenerator.levels.count,
                        onTap: onMissions
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // 6. Monetisation — subtle, below the map.
                    // Hidden during the onboarding grace period (first 3 missions).
                    // Shown only after the player has completed mission 3 and felt the hook.
                    if !entitlement.isPremium, let onUpgrade,
                       OnboardingStore.hasShownFirstHook {
                        upgradeRow(action: onUpgrade)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                } else {
                    // All missions cleared
                    AllClearCard()
                        .padding(.horizontal, 24)

                    MapPreviewBlock(
                        completed: profile.uniqueCompletions,
                        total: LevelGenerator.levels.count,
                        onTap: onMissions
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                }
            } else {
                // Pre-intro training flow
                TrainingCard()
                    .padding(.horizontal, 24)

                Button(action: { onPlay(LevelGenerator.introLevel) }) {
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
                .padding(.horizontal, 24)
                .padding(.top, 14)
            }
        }
    }

    // ── Hero section — mission identity, adapts to resume state ──────────────
    private func heroSection(for level: Level) -> some View {
        let isResume = lastPlayedMissionID == level.displayID
        return VStack(alignment: .leading, spacing: 10) {
            // "IN PROGRESS" badge when returning to a started mission
            if isResume {
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.accentPrimary)
                        .frame(width: 5, height: 5)
                        .pulsingGlow(color: AppTheme.accentPrimary, duration: 1.4)
                    TechLabel(text: S.inProgress, color: AppTheme.accentPrimary.opacity(0.88))
                }
            }

            // Mission ID — dominant, tappable (secret trigger)
            // Slightly smaller font on resume so longer "CONTINUE MISSION XX" fits
            Text(isResume
                 ? S.resumeMissionLabel(level.displayID)
                 : S.nextMissionLabel(level.displayID))
                .font(AppTheme.mono(isResume ? 28 : 38, weight: .black))
                .foregroundStyle(.white)
                .tracking(-0.5)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .onTapGesture { handleSecretTap() }

            // Objective — single clear line
            Text(S.objectiveText(type: level.objectiveType, targets: level.numTargets))
                .font(AppTheme.mono(10, weight: .regular))
                .foregroundStyle(AppTheme.sage.opacity(0.72))
                .kerning(2)

            // Difficulty — small pill, not protagonist
            Text(level.difficulty.fullLabel)
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(level.difficulty.color)
                .kerning(1.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(level.difficulty.color.opacity(0.45), lineWidth: 0.5)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Primary CTA — full-width PLAY / CONTINUE button ─────────────────────
    // Delegates to PlayCTAButton for press physics, haptic, and sound.
    // Saves lastPlayedMissionID BEFORE calling onPlay so the hero updates
    // instantly when the player returns to the home screen.
    private func playButton(for level: Level) -> some View {
        let isResume = lastPlayedMissionID == level.displayID
        return PlayCTAButton(label: isResume ? S.continueAction : S.play) {
            lastPlayedMissionID = level.displayID
            onPlay(level)
        }
    }

    // ── Progress — integrated bar + text, no card ─────────────────────────────
    private var progressRow: some View {
        let total    = LevelGenerator.levels.count
        let done     = profile.uniqueCompletions
        let fraction = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        return VStack(alignment: .leading, spacing: 6) {
            ProgressAnimatedBar(fraction: fraction)

            Text(S.missionsCompleted(done: done, total: total))
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.sage.opacity(0.65))
                .kerning(1)
        }
    }

    // ── Upgrade — subtle secondary row, no dominant box ──────────────────────
    private func upgradeRow(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "infinity")
                    .font(.system(size: 9, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(S.unlockUnlimitedAccess)
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(1)
                    Text(S.playWithoutDailyLimit)
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.60))
                        .kerning(0.5)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.accentPrimary.opacity(0.72))
            .background(AppTheme.accentPrimary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private var systemBar: some View {
        HStack {
            PlayerBlock(gcManager: gcManager)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(AppTheme.success).frame(width: 5, height: 5)
                    .pulsingGlow(color: AppTheme.success, duration: 2.0)
                TechLabel(text: S.nodeActive)
            }
            Spacer()
            // Rankings button — only visible when authenticated
            if gcManager.isAuthenticated {
                Button(action: { gcManager.openLeaderboards() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10, weight: .semibold))
                        TechLabel(text: S.rankings, color: AppTheme.sage)
                    }
                    .foregroundStyle(AppTheme.sage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.sage.opacity(0.40), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .padding(.trailing, 6)
            }
            Button(action: { showingSettings = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    TechLabel(text: S.config, color: AppTheme.sage)
                }
                .foregroundStyle(AppTheme.sage)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.sage.opacity(0.40), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
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
                // Signal: always hot
                HStack(spacing: 5) {
                    Circle().fill(AppTheme.success).frame(width: 4, height: 4)
                        .pulsingGlow(color: AppTheme.success, duration: 1.8)
                    TechLabel(text: S.signalActive, color: AppTheme.sage.opacity(0.82))
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // Mission progress
                TechLabel(
                    text: "\(S.missions)  ·  \(profile.uniqueCompletions)/\(LevelGenerator.levels.count)",
                    color: AppTheme.sage.opacity(0.82)
                )
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // System version
                TechLabel(text: "SYS  ·  v1.0", color: AppTheme.sage.opacity(0.78))
                    .frame(maxWidth: .infinity)
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
        return "\(planet.id)-\(prof.level)-\(prof.completedMissions)-\(eff)"
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
        guard TicketCache.shared.image(for: p) == nil else { return }
        let image = await Task.detached(priority: .background) {
            TicketRenderer.render(pass: p, profile: prof)
        }.value
        TicketCache.shared.cache(image, for: p)
    }

    // MARK: Secret trigger
    private func handleSecretTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 2.0 { secretTaps = 0 }
        lastTapTime = now
        secretTaps += 1
        if secretTaps >= 5 {
            secretTaps = 0
            showingDevMenu = true
        }
    }
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
/// Authenticated  → avatar photo (or initials fallback) + name + live GC status dot.
/// Not authenticated → person icon + "CONNECT" tap that triggers authentication.
private struct PlayerBlock: View {
    @ObservedObject var gcManager: GameCenterManager

    var body: some View {
        Group {
            if gcManager.isAuthenticated {
                Button(action: { gcManager.openDashboard() }) {
                    identityRow
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { gcManager.authenticate() }) {
                    connectRow
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Authenticated layout
    private var identityRow: some View {
        HStack(spacing: 8) {
            // Avatar tile — photo when loaded, initials when not yet available
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.surface)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.28), lineWidth: 0.5)
                    )
                if let avatar = gcManager.playerAvatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                } else {
                    Text(initials)
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                }
            }

            // Name + live status
            VStack(alignment: .leading, spacing: 2) {
                Text(String(gcManager.displayName.prefix(14)).uppercased())
                    .font(AppTheme.mono(9, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 4, height: 4)
                        .pulsingGlow(color: AppTheme.success, duration: 2.2)
                    Text("GC ONLINE")
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary)
                        .kerning(0.5)
                }
            }
        }
    }

    // MARK: Unauthenticated layout
    private var connectRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(AppTheme.textSecondary)
            Text("CONNECT GAME CENTER")
                .font(AppTheme.mono(7))
                .foregroundStyle(AppTheme.textSecondary)
                .kerning(0.5)
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
///   • Same top-bar layout: SIGNAL ROUTE + serial | PLANET PASS + difficulty
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

                // ── Top bar — SIGNAL ROUTE / PLANET PASS ─────────────
                // Mirrors ticket drawTopBar: faint tint, left identity, right pass label.
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        TechLabel(text: "SIGNAL ROUTE", color: .white.opacity(0.90))
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
                        TechLabel(text: planet.missionBrief, color: planet.color.opacity(0.78))
                        Text(planet.name)
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
                        TechLabel(text: "MISSION EFF", color: .white.opacity(0.52))
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
                    passStatCell(label: "LEVEL",    value: String(format: "%02d", profile.level))
                    statDivider()
                    passStatCell(label: "MISSIONS", value: String(format: "%04d", profile.completedMissions))
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
                        .foregroundStyle(AppTheme.textSecondary)
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
                        TechLabel(text: planet.name.uppercased(),
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
            withAnimation(.easeOut(duration: 0.28).delay(0.12)) { chromeVisible = true }
        }
        .task {
            let p    = pass
            let prof = profile

            // Cache hit → show immediately, no animation needed
            if let cached = TicketCache.shared.image(for: p) {
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
                TicketRenderer.render(pass: p, profile: prof)
            }.value

            phaseTask.cancel()

            // Store so subsequent opens are instant
            TicketCache.shared.cache(image, for: p)
            ticketImage = image

            // Scan reveal animation
            try? await Task.sleep(nanoseconds: 200_000_000)
            HapticsManager.light()
            withAnimation(.linear(duration: 0.65)) { scanFraction = 1 }
            try? await Task.sleep(nanoseconds: 750_000_000)
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
        // Always export the raw CGContext-rendered UIImage — never the SwiftUI 3D view.
        // This guarantees a clean 1080×1080 result regardless of the current tilt or drag state.
        guard let image = ticketImage else { return }

        // Signal the 3D view to settle and flash its export-border cue.
        isExporting = true
        HapticsManager.medium()

        Task { @MainActor in
            // Brief pause: lets the border flash play and idle settle before the sheet opens.
            try? await Task.sleep(nanoseconds: 300_000_000)

            let shareText = S.shareProgressText(level: profile.level)
            let vc = UIActivityViewController(activityItems: [shareText, image], applicationActivities: nil)
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
                isExporting = false
                return
            }
            let presenter = rootVC.presentedViewController ?? rootVC
            vc.popoverPresentationController?.sourceView = presenter.view
            vc.popoverPresentationController?.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 80,
                width: 0, height: 0
            )
            presenter.present(vc, animated: true)

            // Return to interactive mode once the share sheet has fully appeared.
            try? await Task.sleep(nanoseconds: 600_000_000)
            isExporting = false
        }
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
            SoundManager.play(.timerTick)   // 18 ms clean digital tick — subtle, sci-fi
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
///   • TimelineView period: 1/15 s → 15 fps, imperceptible for slow effects, very cheap
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

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Header
                HStack(spacing: 6) {
                    TechLabel(text: S.missionMapTitle, color: AppTheme.sage.opacity(0.72))
                    Spacer()
                    TechLabel(text: S.viewFullMap, color: AppTheme.sage.opacity(0.42))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(AppTheme.sage.opacity(0.32))
                }

                // Node network — rendered in Canvas, animated by TimelineView at 15 fps
                TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { timeline in
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
                .frame(height: 48)

                // Footer: progress text + percentage
                HStack {
                    Text(S.missionsCompleted(done: completed, total: total))
                        .font(AppTheme.mono(8))
                        .foregroundStyle(AppTheme.sage.opacity(0.55))
                        .kerning(0.8)
                    Spacer()
                    TechLabel(
                        text: total > 0 ? "\(Int(Double(completed) / Double(total) * 100))%" : "0%",
                        color: AppTheme.accentPrimary.opacity(0.60)
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.14), lineWidth: 0.5)
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
