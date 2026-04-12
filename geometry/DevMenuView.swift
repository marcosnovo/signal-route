import SwiftUI

// MARK: - DevMenuView
/// Hidden QA / testing tool. Accessible via 5-tap logo on the Home screen.
/// Shows ALL levels regardless of player progression, with filters for rapid testing.
struct DevMenuView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void

    // MARK: Filter state
    @State private var filterDifficulty: DifficultyTier?       = nil
    @State private var filterObjective: LevelObjectiveType?    = nil
    @State private var filterStatus: CompletionFilter          = .all

    enum CompletionFilter { case all, open, done }

    // MARK: Derived

    private var profile: AstronautProfile { ProgressionStore.profile }

    private var filteredLevels: [Level] {
        LevelGenerator.levels.filter { level in
            if let d = filterDifficulty, level.difficulty != d { return false }
            if let o = filterObjective, level.objectiveType != o { return false }
            switch filterStatus {
            case .open: if profile.hasCompleted(levelId: level.id) { return false }
            case .done: if !profile.hasCompleted(levelId: level.id) { return false }
            case .all: break
            }
            return true
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                navStrip
                filterBar
                TechDivider()
                levelList
            }
        }
    }

    // MARK: Nav strip

    private var navStrip: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    TechLabel(text: "CLOSE")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                TechLabel(text: "DEV CONSOLE", color: AppTheme.accentPrimary)
                TechLabel(
                    text: "\(filteredLevels.count) / \(LevelGenerator.levels.count) LEVELS",
                    color: AppTheme.sage.opacity(0.60)
                )
            }

            Spacer()

            Button(action: resetFilters) {
                TechLabel(text: "RESET", color: AppTheme.sage.opacity(0.60))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Difficulty
                filterPill("ALL", active: filterDifficulty == nil,
                           color: AppTheme.sage) { filterDifficulty = nil }
                ForEach(DifficultyTier.allCases) { tier in
                    filterPill(tier.label, active: filterDifficulty == tier,
                               color: tier.color) {
                        filterDifficulty = filterDifficulty == tier ? nil : tier
                    }
                }

                Rectangle()
                    .fill(AppTheme.sage.opacity(0.18))
                    .frame(width: 0.5, height: 14)

                // Objective
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

                Rectangle()
                    .fill(AppTheme.sage.opacity(0.18))
                    .frame(width: 0.5, height: 14)

                // Completion status
                filterPill("OPEN", active: filterStatus == .open,
                           color: AppTheme.accentPrimary) { filterStatus = filterStatus == .open ? .all : .open }
                filterPill("DONE", active: filterStatus == .done,
                           color: AppTheme.success) { filterStatus = filterStatus == .done ? .all : .done }
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? color : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(active ? color : AppTheme.sage.opacity(0.20), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: Level list

    private var levelList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredLevels) { level in
                    Button(action: { onSelect(level) }) {
                        levelRow(level)
                    }
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
            // ── Mission ID ─────────────────────────────────────────────
            Text(String(format: "%03d", level.displayID))
                .font(AppTheme.mono(11, weight: .bold))
                .foregroundStyle(AppTheme.sage.opacity(0.80))
                .frame(width: 30, alignment: .leading)

            // ── Grid size ──────────────────────────────────────────────
            Text("\(level.gridSize)×\(level.gridSize)")
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 26)

            // ── Difficulty badge ───────────────────────────────────────
            Text(level.difficulty.label)
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(level.difficulty.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(level.difficulty.color.opacity(0.40), lineWidth: 0.5)
                )

            // ── Objective icon ─────────────────────────────────────────
            Image(systemName: level.objectiveType.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(level.objectiveType.accentColor.opacity(0.85))

            // ── Timed indicator ────────────────────────────────────────
            if level.timeLimit != nil {
                Image(systemName: "timer")
                    .font(.system(size: 8))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // ── Move budget ────────────────────────────────────────────
            Text("\(level.minimumRequiredMoves)/\(level.maxMoves)")
                .font(AppTheme.mono(8))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 38, alignment: .trailing)

            // ── Best efficiency ────────────────────────────────────────
            if let eff = bestEff {
                Text("\(Int(eff * 100))%")
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(AppTheme.success.opacity(0.80))
                    .frame(width: 32, alignment: .trailing)
                    .monospacedDigit()
            } else {
                Color.clear.frame(width: 32)
            }

            // ── Completion dot ─────────────────────────────────────────
            Circle()
                .fill(completed ? AppTheme.success : AppTheme.stroke)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.backgroundPrimary)
        .contentShape(Rectangle())
    }

    // MARK: Helpers

    private func resetFilters() {
        filterDifficulty = nil
        filterObjective  = nil
        filterStatus     = .all
    }
}
