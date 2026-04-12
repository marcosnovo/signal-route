import SwiftUI

// MARK: - DevMenuView
/// Hidden QA / testing console. Accessible via 5-tap logo on the Home screen.
///
/// ## Tabs
///   LEVELS — full level browser with difficulty / objective / completion filters.
///   TOOLS  — player-state controls, reset actions, mechanic message inspector.
struct DevMenuView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void

    // ── Tab ───────────────────────────────────────────────────────────────
    enum DevTab { case levels, tools }
    @State private var activeTab: DevTab = .levels

    // ── Level filter state ────────────────────────────────────────────────
    @State private var filterDifficulty: DifficultyTier?    = nil
    @State private var filterObjective: LevelObjectiveType? = nil
    @State private var filterStatus: CompletionFilter       = .all

    enum CompletionFilter { case all, open, done }

    // ── Tools state ───────────────────────────────────────────────────────
    /// Level shown in the stepper — applied only when the user taps APPLY.
    @State private var devLevel: Int      = 1
    /// Bumped after every mutation to force re-reads from UserDefaults.
    @State private var refreshID: UUID    = UUID()
    /// Tracks which reset action is pending a confirmation dialog.
    @State private var pendingReset: ResetAction? = nil

    enum ResetAction: Identifiable {
        case all, missions, passes, mechanics
        var id: Self { self }
        var title: String {
            switch self {
            case .all:       return "RESET ALL PROGRESS"
            case .missions:  return "RESET MISSION DATA"
            case .passes:    return "RESET PLANET PASSES"
            case .mechanics: return "RESET MECHANIC UNLOCKS"
            }
        }
        var message: String {
            switch self {
            case .all:
                return "Deletes level, all missions, passes, and mechanic announcements. Cannot be undone."
            case .missions:
                return "Clears all completed missions. Level stays the same."
            case .passes:
                return "Removes all collected planet passes and the render cache."
            case .mechanics:
                return "All mechanic unlock messages will re-appear next time they are encountered."
            }
        }
    }

    // ── Derived ───────────────────────────────────────────────────────────

    /// Always fresh — re-read from UserDefaults on every render triggered by refreshID.
    private var profile: AstronautProfile {
        _ = refreshID
        return ProgressionStore.profile
    }

    private var filteredLevels: [Level] {
        LevelGenerator.levels.filter { level in
            if let d = filterDifficulty, level.difficulty != d { return false }
            if let o = filterObjective,  level.objectiveType != o { return false }
            switch filterStatus {
            case .open: if  profile.hasCompleted(levelId: level.id) { return false }
            case .done: if !profile.hasCompleted(levelId: level.id) { return false }
            case .all:  break
            }
            return true
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                navStrip
                tabBar
                TechDivider()

                switch activeTab {
                case .levels:
                    filterBar
                    TechDivider()
                    levelList
                case .tools:
                    toolsPanel
                }
            }
        }
        .onAppear { devLevel = profile.level }
        .confirmationDialog(
            pendingReset?.title ?? "",
            isPresented: Binding(
                get: { pendingReset != nil },
                set: { if !$0 { pendingReset = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingReset {
                Button("CONFIRM — \(action.title)", role: .destructive) {
                    executeReset(action)
                }
                Button("CANCEL", role: .cancel) { pendingReset = nil }
            }
        } message: {
            if let action = pendingReset { Text(action.message) }
        }
    }

    // MARK: - Nav strip

    private var navStrip: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    TechLabel(text: "CLOSE")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                TechLabel(text: "DEV CONSOLE", color: AppTheme.accentPrimary)
                TechLabel(
                    text: "LVL \(profile.level)  ·  \(profile.uniqueCompletions)/\(LevelGenerator.levels.count) MISSIONS",
                    color: AppTheme.sage.opacity(0.60)
                )
            }

            Spacer()

            Button(action: resetFilters) {
                TechLabel(text: "FILTERS", color: AppTheme.sage.opacity(0.60))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("LEVELS", icon: "list.bullet",           tab: .levels)
            Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5)
            tabButton("TOOLS",  icon: "wrench.and.screwdriver", tab: .tools)
        }
        .frame(height: 36)
        .background(AppTheme.backgroundSecondary)
    }

    private func tabButton(_ label: String, icon: String, tab: DevTab) -> some View {
        Button(action: { activeTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                TechLabel(
                    text: label,
                    color: activeTab == tab ? AppTheme.accentPrimary : AppTheme.textSecondary
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(activeTab == tab ? AppTheme.accentPrimary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill("ALL", active: filterDifficulty == nil, color: AppTheme.sage) {
                    filterDifficulty = nil
                }
                ForEach(DifficultyTier.allCases) { tier in
                    filterPill(tier.label, active: filterDifficulty == tier, color: tier.color) {
                        filterDifficulty = filterDifficulty == tier ? nil : tier
                    }
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 14)

                filterPill("NRM", active: filterObjective == .normal,
                           color: LevelObjectiveType.normal.accentColor) {
                    filterObjective = filterObjective == .normal ? nil : .normal
                }
                filterPill("CVR", active: filterObjective == .maxCoverage,
                           color: LevelObjectiveType.maxCoverage.accentColor) {
                    filterObjective = filterObjective == .maxCoverage ? nil : .maxCoverage
                }
                filterPill("SAV", active: filterObjective == .energySaving,
                           color: LevelObjectiveType.energySaving.accentColor) {
                    filterObjective = filterObjective == .energySaving ? nil : .energySaving
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 14)

                filterPill("OPEN", active: filterStatus == .open,
                           color: AppTheme.accentPrimary) {
                    filterStatus = filterStatus == .open ? .all : .open
                }
                filterPill("DONE", active: filterStatus == .done,
                           color: AppTheme.success) {
                    filterStatus = filterStatus == .done ? .all : .done
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .background(AppTheme.backgroundSecondary)
    }

    @ViewBuilder
    private func filterPill(
        _ label: String,
        active: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(active ? .black : AppTheme.textSecondary)
                .kerning(0.8)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(active ? color : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(active ? color : AppTheme.sage.opacity(0.20), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Level list

    private var levelList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredLevels) { level in
                    Button(action: { onSelect(level) }) { levelRow(level) }
                        .buttonStyle(.plain)
                    TechDivider()
                }
            }
        }
    }

    private func levelRow(_ level: Level) -> some View {
        let completed = profile.hasCompleted(levelId: level.id)
        let bestEff   = profile.bestEfficiencyByLevel[String(level.id)]

        return HStack(spacing: 10) {
            Text(String(format: "%03d", level.id))
                .font(AppTheme.mono(11, weight: .bold))
                .foregroundStyle(AppTheme.sage.opacity(0.80))
                .frame(width: 30, alignment: .leading)

            Text("\(level.gridSize)×\(level.gridSize)")
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 26)

            Text(level.difficulty.label)
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(level.difficulty.color)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(level.difficulty.color.opacity(0.40), lineWidth: 0.5)
                )

            Image(systemName: level.objectiveType.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(level.objectiveType.accentColor.opacity(0.85))

            if level.timeLimit != nil {
                Image(systemName: "timer")
                    .font(.system(size: 8))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(level.minimumRequiredMoves)/\(level.maxMoves)")
                .font(AppTheme.mono(8))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 38, alignment: .trailing)

            if let eff = bestEff {
                Text("\(Int(eff * 100))%")
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(AppTheme.success.opacity(0.80))
                    .frame(width: 32, alignment: .trailing)
                    .monospacedDigit()
            } else {
                Color.clear.frame(width: 32)
            }

            Circle()
                .fill(completed ? AppTheme.success : AppTheme.stroke)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.backgroundPrimary)
        .contentShape(Rectangle())
    }

    // MARK: - Tools panel

    private var toolsPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                playerStateSection
                TechDivider()
                resetSection
                TechDivider()
                mechanicMessagesSection
            }
        }
    }

    // ── Player state ───────────────────────────────────────────────────────

    private var playerStateSection: some View {
        VStack(spacing: 0) {
            sectionHeader("PLAYER STATE")

            // Level stepper
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    TechLabel(text: "ASTRONAUT LEVEL", color: AppTheme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(devLevel)")
                            .font(AppTheme.mono(40, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                            .monospacedDigit()
                        Text(rankLabel(for: devLevel))
                            .font(AppTheme.mono(9, weight: .semibold))
                            .foregroundStyle(AppTheme.accentPrimary)
                            .kerning(1)
                    }
                }
                .padding(.leading, 16)

                Spacer()

                // +/– buttons
                HStack(spacing: 0) {
                    stepperBtn("minus", enabled: devLevel > 1) { devLevel = max(1, devLevel - 1) }
                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 32)
                    stepperBtn("plus", enabled: devLevel < 20) { devLevel = min(20, devLevel + 1) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.sage.opacity(0.22), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .padding(.trailing, 16)
            }
            .padding(.vertical, 14)

            // Planet unlock dots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Planet.catalog) { planet in
                        let unlocked = planet.requiredLevel <= devLevel
                        HStack(spacing: 4) {
                            Circle()
                                .fill(unlocked ? planet.color : AppTheme.stroke)
                                .frame(width: 5, height: 5)
                            TechLabel(
                                text: planet.name,
                                color: unlocked ? planet.color : AppTheme.textSecondary.opacity(0.35)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)

            // Apply button
            Button(action: applyLevelJump) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                    Text("APPLY LEVEL JUMP  →  LVL \(devLevel)")
                        .font(AppTheme.mono(10, weight: .bold))
                        .kerning(1.2)
                }
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(devLevel == profile.level
                            ? AppTheme.backgroundSecondary
                            : AppTheme.accentPrimary)
                .foregroundStyle(devLevel == profile.level
                                 ? AppTheme.textSecondary
                                 : .black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .disabled(devLevel == profile.level)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Live profile stats
            HStack(spacing: 0) {
                miniStat("LEVEL",     "\(profile.level)")
                statDivider()
                miniStat("MISSIONS",  "\(profile.uniqueCompletions)")
                statDivider()
                miniStat("AVG EFF",   "\(profile.averageEfficiencyPercent)%")
                statDivider()
                miniStat("PLANET",    profile.currentPlanet.name)
            }
            .padding(.bottom, 16)
        }
        .background(AppTheme.surface)
    }

    // ── Reset ──────────────────────────────────────────────────────────────

    private var resetSection: some View {
        VStack(spacing: 0) {
            sectionHeader("RESET")
            VStack(spacing: 8) {
                resetRow(
                    "RESET ALL PROGRESS",
                    sub: "level · missions · passes · mechanics",
                    color: AppTheme.danger
                ) { pendingReset = .all }

                resetRow(
                    "RESET MISSION DATA",
                    sub: "clears completions, keeps level",
                    color: AppTheme.accentPrimary
                ) { pendingReset = .missions }

                resetRow(
                    "RESET PLANET PASSES",
                    sub: "removes passes + image cache",
                    color: AppTheme.sage
                ) { pendingReset = .passes }

                resetRow(
                    "RESET MECHANIC UNLOCKS",
                    sub: "all 8 messages will show again",
                    color: AppTheme.sage
                ) { pendingReset = .mechanics }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // ── Mechanic messages ──────────────────────────────────────────────────

    private var mechanicMessagesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("MECHANIC UNLOCK MESSAGES  ·  \(MechanicType.allCases.count) TOTAL")
            ForEach(MechanicType.allCases, id: \.rawValue) { mechanic in
                mechanicRow(mechanic)
                TechDivider()
            }
        }
    }

    private func mechanicRow(_ mechanic: MechanicType) -> some View {
        let seen = MechanicUnlockStore.hasAnnounced(mechanic)

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: mechanic.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(seen ? AppTheme.success : AppTheme.accentPrimary)
                    .frame(width: 16)

                TechLabel(text: mechanic.unlockTitle, color: AppTheme.textPrimary)

                Spacer()

                // Seen badge
                Text(seen ? "SEEN" : "UNSEEN")
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(seen ? AppTheme.success : AppTheme.accentPrimary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                (seen ? AppTheme.success : AppTheme.accentPrimary).opacity(0.50),
                                lineWidth: 0.5
                            )
                    )
            }

            // Message preview (3 lines)
            Text(mechanic.unlockMessage)
                .font(AppTheme.mono(8))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Mark unseen — only visible when already seen
            if seen {
                Button(action: {
                    MechanicUnlockStore.markUnannounced(mechanic)
                    refreshID = UUID()
                }) {
                    Text("MARK AS UNSEEN")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .kerning(0.5)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(AppTheme.sage.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.backgroundPrimary)
    }

    // MARK: - Layout helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Rectangle().fill(AppTheme.accentPrimary).frame(width: 2, height: 10)
            TechLabel(text: title, color: AppTheme.accentPrimary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func stepperBtn(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35))
                .frame(width: 44, height: 36)
        }
        .disabled(!enabled)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            TechLabel(text: label, color: AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(AppTheme.sage)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func statDivider() -> some View {
        Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 28)
    }

    private func resetRow(
        _ title: String,
        sub: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppTheme.mono(9, weight: .bold))
                        .foregroundStyle(color)
                        .kerning(0.8)
                    Text(sub)
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color.opacity(0.45))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(color.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func applyLevelJump() {
        ProgressionStore.devSetLevel(devLevel)
        TicketCache.shared.invalidateAll()
        refreshID = UUID()
    }

    private func executeReset(_ action: ResetAction) {
        switch action {
        case .all:
            ProgressionStore.devResetAll()
            TicketCache.shared.invalidateAll()
        case .missions:
            ProgressionStore.devResetMissions()
            TicketCache.shared.invalidateAll()
        case .passes:
            PassStore.reset()
            TicketCache.shared.invalidateAll()
        case .mechanics:
            MechanicUnlockStore.reset()
        }
        devLevel  = ProgressionStore.profile.level
        refreshID = UUID()
        pendingReset = nil
    }

    private func resetFilters() {
        filterDifficulty = nil
        filterObjective  = nil
        filterStatus     = .all
    }

    private func rankLabel(for level: Int) -> String {
        switch level {
        case 1...2:  return "CADET"
        case 3...4:  return "PILOT"
        case 5...6:  return "NAVIGATOR"
        case 7...9:  return "COMMANDER"
        default:     return "ADMIRAL"
        }
    }
}
