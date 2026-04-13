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
                Spacer()
                titleSection.padding(.bottom, 32)
                missionSection.padding(.horizontal, 24)
                if introCompleted {
                    AstronautProgressCard(profile: profile)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .onTapGesture { showingPlanetTicket = true }
                }
                Spacer()
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

    private var titleSection: some View {
        VStack(spacing: 10) {
            GeoTitle()
                .onTapGesture { handleSecretTap() }
            Text(S.restoreTheNetwork)
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.sage.opacity(0.82))
                .kerning(3)
        }
    }

    private var introCompleted: Bool { OnboardingStore.hasCompletedIntro }
    private var profile: AstronautProfile { ProgressionStore.profile }

    // MARK: Mission section — adapts to player state
    private var missionSection: some View {
        VStack(spacing: 14) {
            if introCompleted {
                if let next = profile.nextMission {
                    // Next sequential mission
                    NextMissionCard(level: next)

                    Button(action: { onPlay(next) }) {
                        HStack(spacing: 0) {
                            // Left: mission context + action verb
                            VStack(alignment: .leading, spacing: 2) {
                                Text(S.nextMissionLabel(next.displayID))
                                    .font(AppTheme.mono(9, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .kerning(2)
                                Text(S.launch)
                                    .font(AppTheme.mono(17, weight: .black))
                                    .foregroundStyle(.white)
                                    .kerning(1)
                            }
                            .padding(.leading, 20)

                            Spacer()

                            // Right: arrow panel with dark overlay
                            ZStack {
                                Color.black.opacity(0.16)
                                    .frame(width: 58)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(AppTheme.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                    .breathingCTA()
                } else {
                    // Player has cleared all 180 missions
                    AllClearCard()
                }

                // Upgrade pill — free users only
                if !entitlement.isPremium, let onUpgrade {
                    Button(action: onUpgrade) {
                        HStack(spacing: 8) {
                            Image(systemName: "infinity")
                                .font(.system(size: 10, weight: .bold))
                            Text(S.unlimitedAccess)
                                .font(AppTheme.mono(9, weight: .bold))
                                .kerning(1.5)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .padding(.horizontal, 14)
                        .background(AppTheme.accentPrimary.opacity(0.07))
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.80))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .strokeBorder(AppTheme.accentPrimary.opacity(0.20), lineWidth: 0.5)
                        )
                    }
                }

                // Mission Map shortcut — always visible for returning players
                Button(action: onMissions) {
                    HStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 11, weight: .semibold))
                        Text(S.missionMap)
                            .font(AppTheme.mono(11, weight: .bold))
                            .kerning(2)
                        Spacer()
                        Text("\(profile.uniqueCompletions)/\(LevelGenerator.levels.count)")
                            .font(AppTheme.mono(10))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .padding(.horizontal, 16)
                    .background(AppTheme.backgroundSecondary)
                    .foregroundStyle(AppTheme.sage.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.sage.opacity(0.18), lineWidth: 0.5)
                    )
                }
            } else {
                // New / returning pre-training player — prompt the intro
                TrainingCard()

                Button(action: { onPlay(LevelGenerator.introLevel) }) {
                    HStack(spacing: 10) {
                        Text(S.initializeTraining)
                            .font(AppTheme.mono(12, weight: .bold))
                            .kerning(2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.accentPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .breathingCTA()
            }
        }
    }

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

// MARK: - MissionCard
struct MissionCard: View {
    let level: Level
    var result: GameResult? = nil

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: "DAILY MISSION · \(dateString)", color: AppTheme.accentPrimary)
                    Text(level.displayName)
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                if let result {
                    // Completion badge replaces difficulty label
                    HStack(spacing: 4) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.danger)
                        Text(result.success ? "COMPLETE" : "FAILED")
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.danger)
                            .kerning(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                (result.success ? AppTheme.success : AppTheme.danger).opacity(0.45),
                                lineWidth: 0.5
                            )
                    )
                    .pulsingGlow(color: result.success ? AppTheme.success : AppTheme.danger)
                } else {
                    Text(level.difficulty.fullLabel)
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(level.difficulty.color)
                        .kerning(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(level.difficulty.color.opacity(0.45), lineWidth: 0.5)
                        )
                        .pulsingGlow(color: level.difficulty.color, duration: 1.5)
                }
            }
            .padding(16)

            TechDivider()

            // Stats row
            HStack(spacing: 0) {
                MiniStatCell(label: "GRID", value: "\(level.gridSize) × \(level.gridSize)")
                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                if let result {
                    MiniStatCell(label: "EFFICIENCY", value: "\(result.efficiencyPercent)%",
                                 accent: result.success)
                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                    MiniStatCell(label: "MOVES USED", value: "\(result.movesUsed)")
                } else {
                    MiniStatCell(label: "MOVES", value: "\(level.maxMoves)")
                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                    MiniStatCell(label: "SIGNAL", value: "ACTIVE", accent: true)
                }
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.strokeBright, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - NextMissionCard
/// Home screen card showing the next sequential mission the player should tackle.
struct NextMissionCard: View {
    let level: Level

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
                    TechLabel(text: S.nextMission, color: AppTheme.accentPrimary)
                    Text(level.displayName)
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(dark)
                }
                Spacer()
                Text(level.difficulty.fullLabel)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(level.difficulty.color)
                    .kerning(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(level.difficulty.color.opacity(0.55), lineWidth: 0.5)
                    )
                    .pulsingGlow(color: level.difficulty.color, duration: 1.5)
            }
            .padding(16)

            Rectangle().fill(sep).frame(height: 0.5)

            HStack(spacing: 0) {
                MiniStatCell(label: S.gridLabel, value: "\(level.gridSize) × \(level.gridSize)",
                             labelColor: muted, valueColor: dark)
                Rectangle().fill(sep).frame(width: 0.5, height: 24)
                MiniStatCell(label: S.objectiveLabel, value: S.hudLabel(level.objectiveType),
                             labelColor: muted, valueColor: dark)
                Rectangle().fill(sep).frame(width: 0.5, height: 24)
                MiniStatCell(label: S.targetsLabel, value: "\(level.numTargets)",
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
/// Authenticated  → square avatar tile + name + live GC status dot.
/// Not authenticated → silent fallback to system label (no visual noise).
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
                TechLabel(text: "ORBITAL SYS  v1.0")
            }
        }
        // Present GK sign-in sheet when GameKit needs it
        .sheet(item: Binding(
            get: { gcManager.presentationViewController.map(UIVCWrapper.init) },
            set: { _ in }
        )) { wrapper in
            UIViewControllerRepresentableWrapper(viewController: wrapper.vc)
                .ignoresSafeArea()
        }
    }

    // MARK: Authenticated layout
    private var identityRow: some View {
        HStack(spacing: 8) {
            // Square avatar tile — mission-control aesthetic
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.surface)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.28), lineWidth: 0.5)
                    )
                Text(initials)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
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

    private var initials: String {
        let words = gcManager.displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1))
        }
        return String(gcManager.displayName.prefix(2)).uppercased()
    }
}

/// Thin Identifiable wrapper so `.sheet(item:)` works with UIViewController.
private struct UIVCWrapper: Identifiable {
    let id = UUID()
    let vc: UIViewController
}

/// Bridges a UIViewController into SwiftUI for the GK sign-in sheet.
private struct UIViewControllerRepresentableWrapper: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
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
                        Text(S.sharePass)
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

            let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
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

// MARK: - AstronautSilhouette
/// Front-facing astronaut bust drawn with Canvas.
/// Coordinate space: 60×80 pt. Visual language: industrial sci-fi —
/// wide round helmet, dark visor with glare, collar joint, chest panel
/// with twin gauges, orange centre stripe, and paired upper arms.
private struct AstronautSilhouette: View {
    let color: Color
    var size: CGFloat = 60   // rendered width; height = size × 4/3

    var body: some View {
        Canvas { ctx, sz in
            let sx = sz.width  / 60
            let sy = sz.height / 80

            // ── Left arm ──────────────────────────────────────────────
            let lArm = Path(roundedRect: CGRect(x: 0,     y: 50*sy, width: 11*sx, height: 26*sy),
                             cornerRadius: 4*sx)
            ctx.fill(lArm, with: .color(color))

            // ── Right arm ─────────────────────────────────────────────
            let rArm = Path(roundedRect: CGRect(x: 49*sx, y: 50*sy, width: 11*sx, height: 26*sy),
                             cornerRadius: 4*sx)
            ctx.fill(rArm, with: .color(color))

            // ── Torso ─────────────────────────────────────────────────
            let torso = Path(roundedRect: CGRect(x: 9*sx, y: 47*sy, width: 42*sx, height: 33*sy),
                              cornerRadius: 5*sx)
            ctx.fill(torso, with: .color(color))

            // ── Centre vertical accent stripe (orange) ─────────────────
            let stripe = Path(roundedRect: CGRect(x: 28*sx, y: 47*sy, width: 4*sx, height: 33*sy),
                               cornerRadius: 1*sx)
            ctx.fill(stripe, with: .color(AppTheme.accentPrimary.opacity(0.65)))

            // ── Chest panel inset stroke ───────────────────────────────
            let panel = Path(roundedRect: CGRect(x: 15*sx, y: 52*sy, width: 30*sx, height: 18*sy),
                              cornerRadius: 2*sx)
            ctx.stroke(panel, with: .color(.white.opacity(0.28)), lineWidth: 0.8*sx)

            // ── Gauge circle L ─────────────────────────────────────────
            let g1 = Path(ellipseIn: CGRect(x: 17*sx, y: 55*sy, width: 7*sx, height: 7*sy))
            ctx.fill(g1, with: .color(.white.opacity(0.20)))
            ctx.stroke(g1, with: .color(.white.opacity(0.42)), lineWidth: 0.5*sx)

            // ── Gauge circle R ─────────────────────────────────────────
            let g2 = Path(ellipseIn: CGRect(x: 36*sx, y: 55*sy, width: 7*sx, height: 7*sy))
            ctx.fill(g2, with: .color(.white.opacity(0.20)))
            ctx.stroke(g2, with: .color(.white.opacity(0.42)), lineWidth: 0.5*sx)

            // ── Status indicator dot ───────────────────────────────────
            let dot = Path(ellipseIn: CGRect(x: 27*sx, y: 66*sy, width: 6*sx, height: 4*sy))
            ctx.fill(dot, with: .color(.white.opacity(0.80)))

            // ── Collar ring ────────────────────────────────────────────
            let collar = Path(roundedRect: CGRect(x: 17*sx, y: 41*sy, width: 26*sx, height: 7*sy),
                               cornerRadius: 2*sx)
            ctx.fill(collar, with: .color(color))
            ctx.stroke(collar, with: .color(.white.opacity(0.22)), lineWidth: 0.7*sx)

            // ── Neck ───────────────────────────────────────────────────
            let neck = Path(CGRect(x: 24*sx, y: 35*sy, width: 12*sx, height: 7*sy))
            ctx.fill(neck, with: .color(color))

            // ── Helmet outer ───────────────────────────────────────────
            let helmet = Path(roundedRect: CGRect(x: 8*sx, y: 0, width: 44*sx, height: 38*sy),
                               cornerRadius: 22*sx)
            ctx.fill(helmet, with: .color(color))

            // Helmet rim highlight
            let rim = Path(roundedRect: CGRect(x: 9*sx, y: 1*sy, width: 42*sx, height: 36*sy),
                            cornerRadius: 21*sx)
            ctx.stroke(rim, with: .color(.white.opacity(0.15)), lineWidth: 1.5*sx)

            // ── Visor ──────────────────────────────────────────────────
            let visor = Path(ellipseIn: CGRect(x: 13*sx, y: 9*sy, width: 34*sx, height: 20*sy))
            ctx.fill(visor, with: .color(.black.opacity(0.60)))
            ctx.stroke(visor, with: .color(.white.opacity(0.30)), lineWidth: 0.8*sx)

            // Visor glare — upper-left reflection
            let glare = Path(ellipseIn: CGRect(x: 18*sx, y: 11*sy, width: 10*sx, height: 5*sy))
            ctx.fill(glare, with: .color(.white.opacity(0.25)))
        }
        .frame(width: size, height: size * 80 / 60)
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
