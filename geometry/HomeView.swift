import SwiftUI
import GameKit

// MARK: - HomeView  (mission-control panel)
struct HomeView: View {
    let onPlay: (Level) -> Void
    let onMissions: () -> Void

    @EnvironmentObject private var gcManager: GameCenterManager
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
                        .padding(.top, 10)
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
    }

    // MARK: Subviews

    private var systemBar: some View {
        HStack {
            PlayerBlock(gcManager: gcManager)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(AppTheme.success).frame(width: 5, height: 5)
                    .pulsingGlow(color: AppTheme.success, duration: 2.0)
                TechLabel(text: "NODE ACTIVE")
            }
            Spacer()
            Button(action: { showingSettings = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.sage.opacity(0.65))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var titleSection: some View {
        VStack(spacing: 18) {
            // Logo (secret menu trigger: tap 5× within 2 s)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.35), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image("AppLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .onTapGesture { handleSecretTap() }

            VStack(spacing: 7) {
                GeoTitle()
                Text("RESTORE THE NETWORK")
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(3)
            }
        }
    }

    private var introCompleted: Bool { OnboardingStore.hasCompletedIntro }
    private var profile: AstronautProfile { ProgressionStore.profile }

    // MARK: Mission section — adapts to player state
    private var missionSection: some View {
        VStack(spacing: 10) {
            if introCompleted {
                if let next = profile.nextMission {
                    // Next sequential mission
                    NextMissionCard(level: next)

                    Button(action: { onPlay(next) }) {
                        HStack(spacing: 0) {
                            // Left: mission context + action verb
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MISSION \(next.displayID)")
                                    .font(AppTheme.mono(9, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .kerning(2)
                                Text("LAUNCH")
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

                // Mission Map shortcut — always visible for returning players
                Button(action: onMissions) {
                    HStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 11, weight: .semibold))
                        Text("MISSION MAP")
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
                    .foregroundStyle(AppTheme.sage.opacity(0.75))
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
                        Text("INITIALIZE TRAINING")
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
                    TechLabel(text: "SIGNAL  ·  ACTIVE", color: AppTheme.sage.opacity(0.70))
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // Mission progress
                TechLabel(
                    text: "MISSIONS  ·  \(profile.uniqueCompletions)/\(LevelGenerator.levels.count)",
                    color: AppTheme.sage.opacity(0.70)
                )
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 18)

                // System version
                TechLabel(text: "SYS  ·  v1.0", color: AppTheme.sage.opacity(0.50))
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
        }
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: "NEXT MISSION", color: AppTheme.accentPrimary)
                    Text(level.displayName)
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
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
                            .strokeBorder(level.difficulty.color.opacity(0.45), lineWidth: 0.5)
                    )
                    .pulsingGlow(color: level.difficulty.color, duration: 1.5)
            }
            .padding(16)

            TechDivider()

            HStack(spacing: 0) {
                MiniStatCell(label: "GRID", value: "\(level.gridSize) × \(level.gridSize)")
                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                MiniStatCell(label: "OBJECTIVE", value: level.objectiveType.hudLabel)
                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                MiniStatCell(label: "TARGETS", value: "\(level.numTargets)")
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.accentPrimary.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - AllClearCard
/// Shown when the player has completed every mission in the catalogue.
struct AllClearCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.success)
            Text("ALL MISSIONS CLEARED")
                .font(AppTheme.mono(13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .kerning(2)
            Text("You've completed all \(LevelGenerator.levels.count) missions.")
                .font(AppTheme.mono(10))
                .foregroundStyle(AppTheme.sage.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.success.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - TrainingCard
/// Mission card variant shown to players who haven't completed the intro yet.
struct TrainingCard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: "SYSTEM CALIBRATION", color: AppTheme.accentPrimary)
                    Text("TRAINING MISSION")
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Text("REQUIRED")
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
                    .kerning(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.45), lineWidth: 0.5)
                    )
                    .pulsingGlow(color: AppTheme.accentPrimary)
            }
            .padding(16)

            TechDivider()

            HStack(spacing: 0) {
                MiniStatCell(label: "GRID", value: "3 × 3")
                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                MiniStatCell(label: "MOVES", value: "5")
                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 24)
                MiniStatCell(label: "SIGNAL", value: "READY", accent: true)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
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

    var body: some View {
        VStack(spacing: 3) {
            TechLabel(text: label, color: AppTheme.sage.opacity(0.80))
            Text(value)
                .font(AppTheme.mono(12, weight: .semibold))
                .foregroundStyle(accent ? AppTheme.success : AppTheme.textPrimary)
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
/// Compact progression block shown on Home for returning players.
/// Shows level, rank, current/next planet, and a clear breakdown of what's
/// needed to reach the next level: quality mission count, efficiency threshold,
/// and how many unique missions remain.
struct AstronautProgressCard: View {
    let profile: AstronautProfile

    private var rule: ProgressionRule { profile.progressionRule }
    private var planet: Planet { profile.currentPlanet }
    private var qualityCount: Int {
        profile.qualityCompletions(minEfficiency: rule.requiredAvgEfficiency)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Rectangle()
                    .fill(planet.color)
                    .frame(width: 2, height: 14)
                TechLabel(text: "ASTRONAUT PROFILE", color: AppTheme.sage)
                Spacer()
                TechLabel(text: profile.rankTitle, color: planet.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            TechDivider()

            // ── Level + Destination row ───────────────────────────────
            HStack(spacing: 0) {
                // Left: big level number
                VStack(alignment: .leading, spacing: 3) {
                    TechLabel(text: "LEVEL", color: AppTheme.sage)
                    Text("\(profile.level)")
                        .font(AppTheme.mono(40, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 56)

                // Right: current + next planet
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        TechLabel(text: "DESTINATION", color: AppTheme.sage)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(planet.color)
                                .frame(width: 5, height: 5)
                                .pulsingGlow(color: planet.color, duration: 2.2)
                            Text(planet.name)
                                .font(AppTheme.mono(10, weight: .bold))
                                .foregroundStyle(planet.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    if let next = profile.nextPlanet {
                        VStack(alignment: .leading, spacing: 2) {
                            TechLabel(text: "NEXT TARGET", color: AppTheme.sage)
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(next.name)
                                    .font(AppTheme.mono(9))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }

            TechDivider()

            // ── Progress to next level ────────────────────────────────
            VStack(spacing: 9) {
                // Label row: section header + quality threshold badge
                HStack {
                    TechLabel(text: "PROGRESS TO LEVEL \(profile.level + 1)", color: AppTheme.sage)
                    Spacer()
                    // Badge showing the efficiency bar required for a mission to count
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary)
                        Text("≥\(rule.requiredEfficiencyPercent)% TO QUALIFY")
                            .font(AppTheme.mono(7, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary)
                            .kerning(0.5)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.40), lineWidth: 0.5)
                    )
                }

                // Segmented progress bar (10 segments)
                HStack(spacing: 3) {
                    ForEach(0..<10, id: \.self) { i in
                        let filled = CGFloat(i) < CGFloat(profile.levelProgress) * 10
                        RoundedRectangle(cornerRadius: 1)
                            .fill(filled ? planet.color : AppTheme.stroke)
                            .frame(height: 4)
                            .animation(.easeOut(duration: 0.3), value: profile.levelProgress)
                    }
                }

                // Stat row: QUALIFIED | REMAINING | AVG EFF
                HStack(spacing: 0) {
                    // Qualified missions (unique levels at threshold)
                    VStack(alignment: .leading, spacing: 1) {
                        TechLabel(text: "QUALIFIED", color: AppTheme.sage)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(qualityCount)")
                                .font(AppTheme.mono(16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                            Text("/ \(rule.requiredMissions)")
                                .font(AppTheme.mono(8))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    // Missions still needed (centre column)
                    if profile.missionsRemaining > 0 {
                        VStack(alignment: .center, spacing: 1) {
                            TechLabel(text: "REMAINING", color: AppTheme.sage)
                            Text("\(profile.missionsRemaining)")
                                .font(AppTheme.mono(16, weight: .bold))
                                .foregroundStyle(AppTheme.accentPrimary)
                                .monospacedDigit()
                        }
                    } else {
                        VStack(alignment: .center, spacing: 1) {
                            TechLabel(text: "STATUS", color: AppTheme.sage)
                            Text("READY")
                                .font(AppTheme.mono(11, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                                .pulsingGlow(color: AppTheme.success)
                        }
                    }

                    Spacer()

                    // Average efficiency (trailing)
                    VStack(alignment: .trailing, spacing: 1) {
                        TechLabel(text: "AVG EFF", color: AppTheme.sage)
                        Text("\(profile.averageEfficiencyPercent)%")
                            .font(AppTheme.mono(16, weight: .bold))
                            .foregroundStyle(
                                profile.averageEfficiency >= rule.requiredAvgEfficiency
                                ? AppTheme.success : AppTheme.textPrimary
                            )
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            TechDivider()

            // ── Tap affordance footer ─────────────────────────────────
            HStack {
                TechLabel(text: "TAP TO VIEW PLANET PASS")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(
            // Astronaut silhouette floats behind the card content, top-right corner
            ZStack(alignment: .topTrailing) {
                AppTheme.surface
                AstronautSilhouette(color: planet.color, size: 78)
                    .opacity(0.16)
                    .offset(x: 6, y: -8)
                    .allowsHitTesting(false)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(planet.color.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - PlanetTicketView
/// Modal sheet that renders and displays the player's current planet pass.
/// Tapping "SHARE PASS" exports the ticket via the system share sheet.
///
/// Shows the persisted PlanetPass if one exists for the current planet,
/// otherwise synthesises a pass from the live profile state.
struct PlanetTicketView: View {
    let profile: AstronautProfile
    @Environment(\.dismiss) private var dismiss

    @State private var ticketImage: UIImage? = nil

    private var pass: PlanetPass {
        let planet = profile.currentPlanet
        // Use real pass if issued; else create a live-stats snapshot
        return PassStore.all.first(where: { $0.planetIndex == planet.id })
            ?? PlanetPass(
                id:              UUID(),
                planetName:      planet.name,
                planetIndex:     planet.id,
                levelReached:    profile.level,
                efficiencyScore: profile.averageEfficiency,
                missionCount:    profile.completedMissions,
                timestamp:       Date()
            )
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav strip ─────────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            TechLabel(text: "CLOSE")
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    TechLabel(text: "PLANET PASS",
                              color: profile.currentPlanet.color)
                    Spacer()
                    // Balance spacer — invisible mirror of close button
                    HStack(spacing: 5) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        TechLabel(text: "CLOSE")
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { TechDivider() }

                // ── Ticket image ─────────────────────────────────────
                if let img = ticketImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                } else {
                    // Placeholder while rendering
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .fill(AppTheme.surface)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(AppTheme.textSecondary)
                                TechLabel(text: "RENDERING PASS…")
                            }
                        )
                        .padding(16)
                }

                Spacer(minLength: 0)

                TechDivider()

                // ── Share button ──────────────────────────────────────
                Button(action: sharePass) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("SHARE PASS")
                            .font(AppTheme.mono(12, weight: .bold))
                            .kerning(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(profile.currentPlanet.color)
                    .foregroundStyle(.black.opacity(0.85))
                }
                .disabled(ticketImage == nil)
            }
        }
        .task {
            // UIGraphicsImageRenderer runs on MainActor (UIKit requirement).
            // The render is ~30ms for 1080×1080, acceptable on a appearing modal sheet.
            ticketImage = TicketRenderer.render(pass: pass, profile: profile)
        }
    }

    private func sharePass() {
        guard let image = ticketImage else { return }

        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // Present from the sheet's own presented VC if available
        let presenter = rootVC.presentedViewController ?? rootVC
        vc.popoverPresentationController?.sourceView = presenter.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.maxY - 80,
            width: 0, height: 0
        )

        presenter.present(vc, animated: true)
        HapticsManager.light()
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
