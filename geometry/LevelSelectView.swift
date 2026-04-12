import SwiftUI

// MARK: - MissionMapView
/// The primary level-select screen. Displays all 180 missions grouped into
/// 8 spatial regions that unlock progressively with the player's astronaut level.
/// Missions unlock sequentially: completing level N unlocks level N+1.
struct MissionMapView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void

    private var profile: AstronautProfile { ProgressionStore.profile }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    #if DEBUG
    @State private var auditRunning = false
    #endif

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(SpatialRegion.catalog) { region in
                                regionSection(region)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        scrollToNextMission(proxy: proxy)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    TechLabel(text: "BACK")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("MISSION MAP")
                    .font(AppTheme.mono(13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(2)
                TechLabel(
                    text: "\(profile.uniqueCompletions) / \(LevelGenerator.levels.count) COMPLETE",
                    color: AppTheme.accentPrimary
                )
            }

            Spacer()

            #if DEBUG
            HStack(spacing: 10) {
                Button(action: { runAudit(useSolver: false) }) {
                    TechLabel(
                        text: auditRunning ? "…" : "AUDIT",
                        color: auditRunning ? AppTheme.textSecondary : AppTheme.accentPrimary
                    )
                }
                .disabled(auditRunning)
                Button(action: { runAudit(useSolver: true) }) {
                    TechLabel(
                        text: auditRunning ? "…" : "SOLVE",
                        color: auditRunning ? AppTheme.textSecondary : AppTheme.accentSecondary
                    )
                }
                .disabled(auditRunning)
            }
            #else
            Color.clear.frame(width: 60)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Region section

    private func regionSection(_ region: SpatialRegion) -> some View {
        let isUnlocked  = region.isUnlocked(for: profile)
        let completed   = region.completedCount(in: profile)
        let total       = region.levels.count
        let progress    = total > 0 ? Float(completed) / Float(total) : 0

        return VStack(spacing: 0) {
            regionHeader(region,
                         isUnlocked: isUnlocked,
                         completed: completed,
                         total: total,
                         progress: progress)

            if isUnlocked {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(region.levels) { level in
                        MissionCell(
                            level: level,
                            state: cellState(for: level)
                        ) {
                            onSelect(level)
                        }
                        .id(level.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                lockedRegionBody(region)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            }

            TechDivider()
        }
        .id("region-\(region.id)")
    }

    private func regionHeader(_ region: SpatialRegion,
                               isUnlocked: Bool,
                               completed: Int,
                               total: Int,
                               progress: Float) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isUnlocked
                          ? region.accentColor
                          : AppTheme.textSecondary.opacity(0.25))
                    .frame(width: 3, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(region.name)
                        .font(AppTheme.mono(14, weight: .bold))
                        .foregroundStyle(isUnlocked
                                         ? AppTheme.textPrimary
                                         : AppTheme.textSecondary.opacity(0.4))
                        .kerning(1)
                    Text(region.subtitle)
                        .font(AppTheme.mono(9, weight: .regular))
                        .foregroundStyle(isUnlocked
                                         ? region.accentColor.opacity(0.65)
                                         : AppTheme.textSecondary.opacity(0.25))
                        .kerning(2)
                }

                Spacer()

                if isUnlocked {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(completed)/\(total)")
                            .font(AppTheme.mono(13, weight: .bold))
                            .foregroundStyle(completed == total ? AppTheme.success : AppTheme.textPrimary)
                        Text("MISSIONS")
                            .font(AppTheme.mono(8))
                            .foregroundStyle(AppTheme.textSecondary)
                            .kerning(1)
                    }
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("LVL \(region.requiredPlayerLevel)")
                            .font(AppTheme.mono(10, weight: .bold))
                            .kerning(1)
                    }
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(AppTheme.stroke.opacity(0.5), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Completion progress bar (unlocked regions only)
            if isUnlocked {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(AppTheme.backgroundSecondary)
                        Rectangle()
                            .fill(progress >= 1 ? AppTheme.success : region.accentColor)
                            .frame(width: geo.size.width * CGFloat(progress))
                            .animation(.easeOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 2)
            }
        }
        .background(AppTheme.backgroundSecondary.opacity(0.35))
    }

    private func lockedRegionBody(_ region: SpatialRegion) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.2))
            VStack(alignment: .leading, spacing: 4) {
                Text("LOCKED  ·  \(region.levels.count) MISSIONS")
                    .font(AppTheme.mono(11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.35))
                    .kerning(1)
                Text("REACH ASTRONAUT LEVEL \(region.requiredPlayerLevel) TO UNLOCK")
                    .font(AppTheme.mono(8))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.25))
                    .kerning(1)
            }
            Spacer()
        }
    }

    // MARK: - Cell state helper

    private func cellState(for level: Level) -> MissionCell.CellState {
        if profile.hasCompleted(levelId: level.id) { return .completed }
        if !profile.isLevelUnlocked(level.id)      { return .locked }
        if level.id == profile.nextMission?.id      { return .next }
        return .available
    }

    // MARK: - Auto-scroll

    private func scrollToNextMission(proxy: ScrollViewProxy) {
        guard let next = profile.nextMission else { return }
        let region = SpatialRegion.catalog.first { $0.levelRange.contains(next.id) }
        guard let region else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                proxy.scrollTo("region-\(region.id)", anchor: .top)
            }
        }
    }

    // MARK: - Debug audit

    #if DEBUG
    private func runAudit(useSolver: Bool) {
        auditRunning = true
        let reports = LevelValidationRunner.validateAll(useSolver: useSolver)
        LevelValidationRunner.printReport(reports)
        auditRunning = false
    }
    #endif
}

// MARK: - MissionCell
/// A single level button in the mission map grid.
/// Visual state reflects completion, unlock, or next-mission status.
struct MissionCell: View {
    enum CellState { case completed, next, available, locked }

    let level: Level
    let state: CellState
    let onTap: () -> Void

    private var accentColor: Color {
        switch state {
        case .completed: return AppTheme.success
        case .next:      return AppTheme.accentPrimary
        case .available: return level.difficulty.color
        case .locked:    return AppTheme.textSecondary.opacity(0.2)
        }
    }

    private var borderColor: Color {
        switch state {
        case .completed: return AppTheme.success.opacity(0.45)
        case .next:      return AppTheme.accentPrimary
        case .available: return AppTheme.stroke
        case .locked:    return AppTheme.stroke.opacity(0.25)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background fill
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(state == .completed
                          ? AppTheme.success.opacity(0.08)
                          : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(borderColor, lineWidth: state == .next ? 1.0 : 0.5)
                    )

                // Content
                VStack(spacing: 3) {
                    // Top indicator
                    Group {
                        switch state {
                        case .completed:
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(AppTheme.success.opacity(0.75))
                        case .locked:
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.2))
                        default:
                            Circle()
                                .fill(level.difficulty.color.opacity(0.65))
                                .frame(width: 4, height: 4)
                        }
                    }

                    // Level number
                    Text(level.displayID)
                        .font(AppTheme.mono(12, weight: state == .next ? .black : .bold))
                        .foregroundStyle(
                            state == .locked
                            ? AppTheme.textSecondary.opacity(0.25)
                            : (state == .next ? AppTheme.accentPrimary : AppTheme.textPrimary)
                        )

                    // Bottom label
                    if state == .next {
                        Text("NEXT")
                            .font(AppTheme.mono(6, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary)
                            .kerning(0.5)
                    } else {
                        Color.clear.frame(height: 8)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .disabled(state == .locked)
    }
}
