import SwiftUI

// MARK: - MissionMapView
/// Campaign-style mission map. Sectors scroll vertically; only the active sector
/// shows its level grid. Completed sectors are compact with an optional expand toggle.
/// Locked sectors show unlock requirements only.
struct MissionMapView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void
    var onUpgrade: (() -> Void)? = nil

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private var profile: AstronautProfile { ProgressionStore.profile }


    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(SpatialRegion.catalog.enumerated()), id: \.element.id) { idx, region in
                                SectorCard(
                                    region: region,
                                    profile: profile,
                                    onSelect: onSelect,
                                    onUpgrade: onUpgrade,
                                    appearDelay: Double(idx) * 0.055
                                )
                                .id("region-\(region.id)")

                                // Journey connector between sectors
                                if idx < SpatialRegion.catalog.count - 1 {
                                    let nextRegion = SpatialRegion.catalog[idx + 1]
                                    RouteConnector(dimmed: !nextRegion.isUnlocked(for: profile))
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        scrollToActiveSector(proxy: proxy)
                    }
                }
            }
        }


    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    TechLabel(text: S.close)
                }
                .foregroundStyle(AppTheme.textPrimary.opacity(0.65))
            }

            Spacer()

            VStack(spacing: 2) {
                TechLabel(text: S.missionMapTitle, color: AppTheme.sage)
                TechLabel(
                    text: S.missionsComplete(done: profile.uniqueCompletions, total: LevelGenerator.levels.count),
                    color: AppTheme.accentPrimary
                )
            }

            Spacer()

            // Balance spacer (invisible mirror of close button)
            HStack(spacing: 5) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                TechLabel(text: S.close)
            }.opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Auto-scroll

    private func scrollToActiveSector(proxy: ScrollViewProxy) {
        guard let next = profile.nextMission else { return }
        let region = SpatialRegion.catalog.first { $0.levelRange.contains(next.id) }
        guard let region else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                proxy.scrollTo("region-\(region.id)", anchor: .top)
            }
        }
    }

}

// MARK: - StarMapBackground
/// Very subtle twinkling star field layered behind the mission map content.
/// Uses a TimelineView at 8 fps for minimal CPU cost.
private struct StarMapBackground: View {

    private struct StarSpec {
        let x, y, r: CGFloat
        let phase: Double
        let speed: Double
    }

    // Deterministic positions via a simple LCG — no randomness on each launch.
    private static let specs: [StarSpec] = {
        var seed: UInt64 = 0xA7_B3_C1_D9
        func rnd() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<50).map { _ in
            StarSpec(
                x:     CGFloat(rnd()),
                y:     CGFloat(rnd()),
                r:     CGFloat(0.5 + rnd() * 1.1),
                phase: rnd() * .pi * 2,
                speed: 0.4 + rnd() * 0.9
            )
        }
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in Self.specs {
                    let opacity = 0.05 + 0.045 * sin(t * star.speed + star.phase)
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: star.x * size.width  - star.r,
                            y: star.y * size.height - star.r,
                            width:  star.r * 2,
                            height: star.r * 2
                        )),
                        with: .color(.white.opacity(max(0, opacity)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - RouteConnector
/// A vertical journey separator between sector cards.
/// Active (unlocked next sector): dashed orange line with a travelling pulse dot.
/// Dimmed (locked next sector): very faint grey line only.
private struct RouteConnector: View {
    let dimmed: Bool

    @State private var dotY: CGFloat = -16

    private static let height: CGFloat = 36

    var body: some View {
        ZStack {
            // Dashed centre line
            Canvas { ctx, size in
                let x = size.width / 2
                var path = Path()
                path.move(to:    CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let color: Color = dimmed
                    ? AppTheme.textSecondary.opacity(0.14)
                    : AppTheme.accentPrimary.opacity(0.28)
                ctx.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
                )
            }

            // Travelling pulse dot — active connectors only
            if !dimmed {
                Circle()
                    .fill(AppTheme.accentPrimary.opacity(0.70))
                    .frame(width: 4, height: 4)
                    .offset(y: dotY)
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .task {
            guard !dimmed else { return }
            await runPulse()
        }
    }

    private func runPulse() async {
        let half = Self.height / 2
        while !Task.isCancelled {
            dotY = -half
            withAnimation(.easeInOut(duration: 1.3)) { dotY = half }
            try? await Task.sleep(nanoseconds: 2_300_000_000)
        }
    }
}

// MARK: - SectorCard
/// A campaign block representing one spatial region.
/// Animates in from below with an index-based stagger delay.
private struct SectorCard: View {
    let region:      SpatialRegion
    let profile:     AstronautProfile
    let onSelect:    (Level) -> Void
    var onUpgrade:   (() -> Void)? = nil
    let appearDelay: Double

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var entitlement: EntitlementStore

    @State private var appeared     = false
    @State private var gridExpanded = false

    private var S: AppStrings { AppStrings(lang: settings.language) }

    private enum DisplayState { case active, completed, locked }

    private var displayState: DisplayState {
        let isUnlocked = region.isUnlocked(for: profile)
        let total      = region.levels.count
        let completed  = region.completedCount(in: profile)
        let isActive   = region.levels.contains { $0.id == profile.nextMission?.id }

        if isActive                                  { return .active }
        if isUnlocked && completed == total && total > 0 { return .completed }
        return .locked
    }

    /// Average best efficiency across all completed levels in this sector.
    private var avgEfficiency: Float? {
        let effs = region.levels.compactMap { profile.bestEfficiencyByLevel[String($0.id)] }
        guard !effs.isEmpty else { return nil }
        return effs.reduce(0, +) / Float(effs.count)
    }

    private var accentColor: Color {
        switch displayState {
        case .active:    return AppTheme.accentPrimary
        case .completed: return AppTheme.success
        case .locked:    return AppTheme.danger.opacity(0.40)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            if displayState == .active || (displayState == .completed && gridExpanded) {
                levelGrid
            }
            if displayState == .completed {
                expandToggle
            }
            // Upgrade nudge — free users on locked sectors beyond Earth Orbit
            if displayState == .locked && region.id > 1 && !entitlement.isPremium, let onUpgrade {
                upgradeNudge(onUpgrade: onUpgrade)
            }
        }
        .background(cardBackground)
        .overlay(alignment: .leading) { leftAccentBar }
        // Entrance animation — slides up and fades in with stagger
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.42).delay(appearDelay), value: appeared)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }

    // MARK: Card header

    private var cardHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    statusBadge
                    Text(S.regionName(region.name))
                        .font(AppTheme.mono(18, weight: .black))
                        .foregroundStyle(displayState == .locked
                                         ? AppTheme.textSecondary.opacity(0.40)
                                         : AppTheme.textPrimary)
                        .kerning(1)
                    Text(S.zoneBrief(region.subtitle))
                        .font(AppTheme.mono(9, weight: .regular))
                        .foregroundStyle(displayState == .locked
                                         ? AppTheme.textSecondary.opacity(0.30)
                                         : region.accentColor.opacity(0.72))
                        .kerning(2)
                }

                Spacer()

                rightInfo
            }

            if displayState == .active {
                activeProgressBar
            }
        }
        .padding(.leading, 28)    // space for the left accent bar
        .padding(.trailing, 20)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch displayState {
        case .active:
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.accentPrimary)
                    .frame(width: 5, height: 5)
                    .pulsingGlow(color: AppTheme.accentPrimary, duration: 1.4)
                TechLabel(text: S.activeSector, color: AppTheme.accentPrimary)
            }
        case .completed:
            TechLabel(text: S.sectorComplete, color: AppTheme.success)
        case .locked:
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AppTheme.danger.opacity(0.70))
                TechLabel(text: S.lockedLabel, color: AppTheme.danger.opacity(0.70))
            }
        }
    }

    @ViewBuilder
    private var rightInfo: some View {
        let total     = region.levels.count
        let completed = region.completedCount(in: profile)

        switch displayState {
        case .active:
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(completed)/\(total)")
                    .font(AppTheme.mono(18, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                TechLabel(text: S.missionsLabel, color: AppTheme.textSecondary)
            }

        case .completed:
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.success)
                    Text("\(total)")
                        .font(AppTheme.mono(16, weight: .black))
                        .foregroundStyle(AppTheme.success)
                        .monospacedDigit()
                }
                TechLabel(text: S.missionsLabel, color: AppTheme.textSecondary)
                if let eff = avgEfficiency {
                    TechLabel(
                        text: "\(S.avgEfficiency)  \(Int(eff * 100))%",
                        color: AppTheme.success.opacity(0.70)
                    )
                }
            }

        case .locked:
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.danger.opacity(0.50))
                Text("\(total) \(S.missionsCount)")
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                    .kerning(1)
            }
        }
    }

    private var activeProgressBar: some View {
        let total     = region.levels.count
        let completed = region.completedCount(in: profile)
        let progress  = total > 0 ? CGFloat(completed) / CGFloat(total) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.backgroundPrimary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accentPrimary)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeOut(duration: 0.55), value: progress)
            }
        }
        .frame(height: 3)
    }

    // MARK: Level grid

    private var levelGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        return LazyVGrid(columns: columns, spacing: 6) {
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
        .padding(.top, 4)
        .padding(.bottom, displayState == .completed ? 4 : 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Expand / collapse for completed sectors

    private var expandToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                gridExpanded.toggle()
            }
        }) {
            HStack(spacing: 6) {
                TechLabel(
                    text: gridExpanded ? S.hideMissions : S.viewMissions,
                    color: AppTheme.success.opacity(0.70)
                )
                Image(systemName: gridExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppTheme.success.opacity(0.60))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: Upgrade nudge (locked sectors, free users)

    private func upgradeNudge(onUpgrade: @escaping () -> Void) -> some View {
        Button(action: onUpgrade) {
            HStack(spacing: 6) {
                Image(systemName: "infinity")
                    .font(.system(size: 9, weight: .bold))
                Text(S.unlimitedAccess)
                    .font(AppTheme.mono(8, weight: .bold))
                    .kerning(1.5)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.accentPrimary.opacity(0.65))
        }
        .overlay(alignment: .top) { TechDivider() }
    }

    // MARK: Left accent bar

    private var leftAccentBar: some View {
        Rectangle()
            .fill(accentColor)
            .frame(width: displayState == .active ? 3 : 2)
            // Glow only on the active sector bar
            .shadow(
                color:  displayState == .active ? AppTheme.accentPrimary.opacity(0.55) : .clear,
                radius: 5, x: 3, y: 0
            )
            .padding(.vertical, 10)
    }

    // MARK: Card background

    private var cardBackground: Color {
        switch displayState {
        case .active:    return AppTheme.backgroundSecondary.opacity(0.78)
        case .completed: return AppTheme.backgroundSecondary.opacity(0.45)
        case .locked:    return AppTheme.danger.opacity(0.04)
        }
    }

    // MARK: Cell state helper

    private func cellState(for level: Level) -> MissionCell.CellState {
        if profile.hasCompleted(levelId: level.id) { return .completed }
        if !profile.isLevelUnlocked(level.id)      { return .locked }
        if level.id == profile.nextMission?.id      { return .next }
        return .available
    }
}

// MARK: - MissionCell

/// A single level button used inside the active / expanded sector grid.
struct MissionCell: View {
    enum CellState { case completed, next, available, locked }

    let level: Level
    let state: CellState
    let onTap: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private var cellBackground: Color {
        switch state {
        case .completed: return AppTheme.success.opacity(0.12)
        case .next:      return AppTheme.accentPrimary.opacity(0.15)
        case .available: return AppTheme.surface
        case .locked:    return AppTheme.backgroundSecondary
        }
    }

    private var borderColor: Color {
        switch state {
        case .completed: return AppTheme.success.opacity(0.45)
        case .next:      return AppTheme.accentPrimary
        case .available: return AppTheme.stroke
        case .locked:    return AppTheme.stroke.opacity(0.35)
        }
    }

    private var numberColor: Color {
        switch state {
        case .completed: return AppTheme.success
        case .next:      return AppTheme.accentPrimary
        case .available: return AppTheme.textPrimary
        case .locked:    return AppTheme.textSecondary.opacity(0.45)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(cellBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(borderColor, lineWidth: state == .next ? 1.5 : 0.5)
                    )

                VStack(spacing: 3) {
                    Group {
                        switch state {
                        case .completed:
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                        case .locked:
                            Image(systemName: "lock.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                        default:
                            Circle()
                                .fill(level.difficulty.color.opacity(state == .next ? 0.90 : 0.60))
                                .frame(width: 4, height: 4)
                        }
                    }

                    Text(level.displayID)
                        .font(AppTheme.mono(12, weight: state == .next ? .black : .bold))
                        .foregroundStyle(numberColor)

                    if state == .next {
                        Text(S.next)
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
