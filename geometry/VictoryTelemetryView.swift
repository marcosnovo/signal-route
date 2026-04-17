import SwiftUI
import UIKit

// MARK: - VictoryTelemetryView
/// Full-screen telemetry dashboard modelled on the reference infographic:
///   LEFT  (dark)  — vertical bar chart, grid lines, one orange highlighted bar
///   RIGHT (sage)  — large title, huge count-up %, inline descriptor, 3 metrics
///   BOTTOM        — action strip spanning full width
struct VictoryTelemetryView: View {

    @ObservedObject var vm: GameViewModel
    let onRestart: () -> Void
    let onDismiss: () -> Void
    var onNextMission: (() -> Void)? = nil
    var onMissions: (() -> Void)?    = nil
    var onUpgrade: (() -> Void)?     = nil

    @EnvironmentObject private var settings:   SettingsStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @EnvironmentObject private var gcManager:  GameCenterManager
    private var S: AppStrings { AppStrings(lang: settings.language) }

    // ── Animation state ────────────────────────────────────────────────────
    @State private var panelVisible   = false
    @State private var displayedPct   = 0
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 8)
    @State private var metricsVisible = false
    @State private var ctaVisible     = false

    // ── Constants ──────────────────────────────────────────────────────────
    private static let mockFractions: [CGFloat] = [0.52, 0.38, 0.78, 0.45, 0.68, 0.31, 0.62]
    private static let chartH: CGFloat = 240

    // ── Sage-panel colour tokens ───────────────────────────────────────────
    private let sageBg      = Color(hex: "D9E7D8")
    private let sageInk     = Color(hex: "131B13")   // primary text on sage
    private let sageMid     = Color(hex: "415041")   // secondary text on sage
    private let sageFaint   = Color(hex: "8FA88F")   // tertiary / icons on sage
    private let sageDivider = Color(hex: "131B13").opacity(0.18)

    // ── Derived ────────────────────────────────────────────────────────────
    private var efficiency: Int { vm.gameResult?.efficiencyPercent ?? 0 }

    private var targetBarHeights: [CGFloat] {
        (Self.mockFractions + [CGFloat(efficiency) / 100])
            .map { $0 * Self.chartH }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Body
    // ══════════════════════════════════════════════════════════════════════

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                navStrip

                // ── Split panel ─────────────────────────────────────────
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        leftChartPanel
                            .frame(width: geo.size.width * 0.50)
                        rightKPIPanel
                            .frame(maxWidth: .infinity)
                    }
                }
                .opacity(panelVisible ? 1 : 0)
                .scaleEffect(panelVisible ? 1 : 0.97, anchor: .center)
                .animation(.easeOut(duration: 0.28), value: panelVisible)

                TechDivider()

                // ── CTA strip ───────────────────────────────────────────
                ctaStrip
                    .opacity(ctaVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.22), value: ctaVisible)
            }
        }
        .task { await runEntrance() }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Nav strip
    // ══════════════════════════════════════════════════════════════════════

    private var navStrip: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    TechLabel(text: S.home, color: AppTheme.sage)
                }
                .foregroundStyle(AppTheme.sage)
            }
            Spacer()
            TechLabel(text: vm.currentLevel.displayName,
                      color: AppTheme.sage.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Left: chart panel
    // ══════════════════════════════════════════════════════════════════════

    private var leftChartPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Decorative corner icon (mirrors reference's dotted-circle)
            Image(systemName: "circle.dotted")
                .font(.system(size: 13, weight: .ultraLight))
                .foregroundStyle(AppTheme.sage.opacity(0.65))
                .padding(.leading, 14)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            // Chart area: bars + grid + Y-axis
            HStack(alignment: .bottom, spacing: 0) {

                // Bars + horizontal grid lines
                ZStack(alignment: .bottom) {
                    Canvas { ctx, size in
                        // Horizontal grid lines at 25 / 50 / 75 %
                        for fraction: Double in [0.25, 0.50, 0.75] {
                            let y = size.height * (1 - fraction)
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(Color(hex: "C7D7C6").opacity(0.12)), lineWidth: 0.5)
                        }
                        // Baseline
                        var bl = Path()
                        bl.move(to: CGPoint(x: 0, y: size.height))
                        bl.addLine(to: CGPoint(x: size.width, y: size.height))
                        ctx.stroke(bl, with: .color(Color(hex: "C7D7C6").opacity(0.30)), lineWidth: 0.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.chartH, maxHeight: Self.chartH)

                    // Bars — anchored to bottom, grow upward
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<8, id: \.self) { i in
                            let isNow = i == 7
                            Rectangle()
                                .fill(isNow
                                      ? AppTheme.accentPrimary
                                      : Color.white.opacity(0.19))
                                .frame(maxWidth: .infinity)
                                .frame(height: max(2, barHeights[i]))
                                .shadow(color: isNow
                                        ? AppTheme.accentPrimary.opacity(0.45) : .clear,
                                        radius: 7)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: Self.chartH)

                // Y-axis labels: 100 → 0 top-to-bottom
                VStack(spacing: 0) {
                    Text("100").frame(maxWidth: .infinity)
                    Spacer()
                    Text("50").frame(maxWidth: .infinity)
                    Spacer()
                    Text("0").frame(maxWidth: .infinity)
                }
                .font(AppTheme.mono(6))
                .foregroundStyle(AppTheme.sage.opacity(0.60))
                .frame(width: 22, height: Self.chartH)
            }
            .padding(.horizontal, 10)

            // X-axis labels
            let xLabels = ["M1","M2","M3","M4","M5","M6","M7","NOW"]
            HStack(spacing: 4) {
                ForEach(Array(xLabels.enumerated()), id: \.offset) { idx, lbl in
                    Text(lbl)
                        .font(AppTheme.mono(6, weight: idx == 7 ? .bold : .regular))
                        .foregroundStyle(idx == 7 ? AppTheme.accentPrimary : AppTheme.sage.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 5)
            .padding(.bottom, 12)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundPrimary)
        // Right edge separator between panels
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.sage.opacity(0.20)).frame(width: 0.5)
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Right: KPI panel (sage green)
    // ══════════════════════════════════════════════════════════════════════

    private var rightKPIPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Brand row ────────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.3x3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(sageMid)
                Text("SIGNAL ROUTE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(sageMid)
            }
            .padding(.top, 16)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // ── Large title (mirrors "Planetary Telemetry Results") ──────
            Text(S.missionDebrief)
                .font(.system(size: 24, weight: .black, design: .default))
                .foregroundStyle(sageInk)
                .lineSpacing(-2)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)

            // ── Huge KPI ─────────────────────────────────────────────
            // VStack layout guarantees "100%" never wraps regardless of
            // panel width — the number gets the full row to itself.
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(displayedPct)")
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(sageInk)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppTheme.accentPrimary)
                        .lineLimit(1)
                        .offset(y: -3)
                }
                Text(S.missionQuality)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(sageMid)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            // ── Horizontal divider ───────────────────────────────────────
            Rectangle()
                .fill(sageDivider)
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            // ── Route rating + message ───────────────────────────────────
            if let result = vm.gameResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text(S.routeRating(result.efficiency))
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(result.isOptimalRoute ? sageInk : sageMid)
                        .tracking(2.0)
                    Text(S.routeMessage(result.efficiency))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(sageMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            // ── Rank feedback badge ───────────────────────────────────────
            if let feedback = gcManager.rankFeedback {
                HStack(spacing: 5) {
                    Image(systemName: feedback == .newRecord ? "trophy.fill" : "globe")
                        .font(.system(size: 8, weight: .bold))
                    Text(rankFeedbackLabel(feedback))
                        .font(AppTheme.mono(8, weight: .bold))
                        .tracking(1.2)
                }
                .foregroundStyle(feedback == .newRecord ? AppTheme.accentPrimary : sageInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(feedback == .newRecord
                              ? AppTheme.accentPrimary.opacity(0.12)
                              : sageInk.opacity(0.08))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.90, anchor: .leading)))
            }

            Spacer(minLength: 0)

            // ── Bottom metrics row ───────────────────────────────────────
            VStack(spacing: 0) {
                Rectangle().fill(sageDivider).frame(height: 0.5)

                HStack(spacing: 0) {
                    SageMetric(
                        icon:  "scope",
                        label: S.score,
                        value: "\(vm.score)",
                        ink:   sageInk,
                        sub:   sageFaint
                    )
                    Rectangle().fill(sageDivider).frame(width: 0.5)
                    SageMetric(
                        icon:  "waveform",
                        label: S.usedMin,
                        value: "\(vm.movesUsed)/\(vm.currentLevel.minimumRequiredMoves)",
                        ink:   sageInk,
                        sub:   sageFaint
                    )
                    Rectangle().fill(sageDivider).frame(width: 0.5)
                    objectiveMetric
                }
            }
            .opacity(metricsVisible ? 1 : 0)
            .offset(y: metricsVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.30), value: metricsVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sageBg)
    }

    // ── Objective-specific third metric ─────────────────────────────────

    @ViewBuilder
    private var objectiveMetric: some View {
        switch vm.currentLevel.objectiveType {
        case .maxCoverage:
            SageMetric(
                icon:  "bolt.fill",
                label: S.coverage,
                value: "\(vm.gridCoveragePercent)%",
                ink:   sageInk,
                sub:   sageFaint
            )
        case .energySaving:
            SageMetric(
                icon:  "leaf.fill",
                label: S.waste,
                value: "\(vm.energyWaste)",
                ink:   sageInk,
                sub:   sageFaint
            )
        case .normal:
            SageMetric(
                icon:  "cpu",
                label: S.activeNodes,
                value: "\(vm.activeNodes)",
                ink:   sageInk,
                sub:   sageFaint
            )
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - CTA strip
    // ══════════════════════════════════════════════════════════════════════

    /// True when the player has exhausted their free intro quota — upgrade banner becomes relevant.
    private var isLunarOrBeyond: Bool {
        !EntitlementStore.shared.isInIntroPhase
    }

    /// The level immediately after the one just completed.
    private var nextMission: Level? {
        guard onNextMission != nil else { return nil }
        let levels = LevelGenerator.levels
        guard let idx = levels.firstIndex(where: { $0.id == vm.currentLevel.id }),
              idx + 1 < levels.count else { return nil }
        return levels[idx + 1]
    }

    /// True when the player may immediately start the next mission.
    /// False when the daily limit has been reached — tapping the primary CTA opens the paywall.
    /// Reads published EntitlementStore properties directly to avoid side-effectful canPlay(_:).
    private var canContinue: Bool {
        guard nextMission != nil else { return false }
        return !entitlement.dailyLimitReached
    }

    private var ctaStrip: some View {
        VStack(spacing: 0) {

            // ── FASE 2: When blocked, premium CTA is the dominant element ─────
            if !canContinue, let onUpgrade, let next = nextMission {
                Button(action: onUpgrade) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(S.unlockUnlimitedAccess)
                                .font(AppTheme.mono(13, weight: .black))
                                .foregroundStyle(.white)
                                .kerning(1)
                            Text(S.keepPlayingWithoutWaiting)
                                .font(AppTheme.mono(9, weight: .regular))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.leading, 20)
                        Spacer()
                        ZStack {
                            Color.black.opacity(0.16).frame(width: 56)
                            Image(systemName: "infinity")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppTheme.accentPrimary)
                }
                .breathingCTA()

                // Subordinate: locked next-mission row with countdown
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    let remaining = entitlement.remainingCooldown
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(S.nextMissionLabel(next.displayID))
                                .font(AppTheme.mono(8, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                                .kerning(1.5)
                            Text(remaining > 0 ? S.backIn(formatCooldown(remaining)) : S.play)
                                .font(AppTheme.mono(11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.backgroundSecondary.opacity(0.35))
                }

                TechDivider()
            }

            // ── Primary: NEXT MISSION — only when free to play ───────────────
            if canContinue, let next = nextMission {
                Button(action: { onNextMission?() }) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(S.nextMissionLabel(next.displayID))
                                .font(AppTheme.mono(9, weight: .regular))
                                .foregroundStyle(.white.opacity(0.55))
                                .kerning(2)
                            Text(S.nextMission)
                                .font(AppTheme.mono(16, weight: .black))
                                .foregroundStyle(.white)
                                .kerning(1)
                        }
                        .padding(.leading, 20)
                        Spacer()
                        ZStack {
                            Color.black.opacity(0.16).frame(width: 56)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppTheme.accentPrimary)
                }
                .breathingCTA()

                TechDivider()
            }

            // ── Secondary row: RETRY / SHARE / MAP / HOME ──────────────
            HStack(spacing: 0) {
                Button(action: onRestart) {
                    secondaryButton(icon: "arrow.counterclockwise", label: S.retryLabel,
                                    color: AppTheme.textPrimary)
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 22)

                Button(action: shareTicket) {
                    secondaryButton(icon: "square.and.arrow.up", label: S.shareLabel,
                                    color: AppTheme.textSecondary)
                }

                if onMissions != nil {
                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 22)

                    Button(action: { onMissions?() }) {
                        secondaryButton(icon: "map", label: S.mapLabel,
                                        color: AppTheme.sage.opacity(0.75))
                    }
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 22)

                Button(action: onDismiss) {
                    secondaryButton(icon: "house", label: S.home,
                                    color: AppTheme.sage.opacity(0.55))
                }
            }
            .background(AppTheme.surface)

            // ── Upgrade banner — free users on Lunar+, only when not already blocked ──
            // When canContinue is false the locked primary CTA already serves as the paywall gate.
            if !entitlement.isPremium && isLunarOrBeyond, let onUpgrade, canContinue {
                Button(action: onUpgrade) {
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                            .font(.system(size: 10, weight: .bold))
                        Text(S.continueWithoutLimits)
                            .font(AppTheme.mono(9, weight: .bold))
                            .kerning(1.5)
                        Spacer()
                        Text(S.upgradeLabel)
                            .font(AppTheme.mono(8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .padding(.horizontal, 16)
                    .background(AppTheme.accentPrimary.opacity(0.09))
                    .foregroundStyle(AppTheme.accentPrimary)
                }
                .overlay(alignment: .top) { TechDivider() }
            }
        }
    }

    private func formatCooldown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    @ViewBuilder
    private func secondaryButton(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foregroundStyle(color)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Entrance sequence
    // ══════════════════════════════════════════════════════════════════════

    private func runEntrance() async {
        // ── 1. Panel scales / fades in ───────────────────────────────────
        panelVisible = true
        HapticsManager.medium()
        try? await Task.sleep(nanoseconds: 250_000_000)

        // ── 2. Bars grow + count-up start concurrently ───────────────────
        for (i, h) in targetBarHeights.enumerated() {
            withAnimation(
                .spring(response: 0.50, dampingFraction: 0.78)
                .delay(Double(i) * 0.08)
            ) {
                barHeights[i] = h
            }
        }
        await countUp(to: efficiency)
        HapticsManager.light()

        // ── 3. Wait for bars to fully settle ────────────────────────────
        try? await Task.sleep(nanoseconds: 500_000_000)
        HapticsManager.light()

        // ── 4. Metrics row ───────────────────────────────────────────────
        metricsVisible = true
        try? await Task.sleep(nanoseconds: 420_000_000)

        // ── 5. CTA ───────────────────────────────────────────────────────
        ctaVisible = true
        HapticsManager.success()

        // ── 6. Auto-paywall at peak emotional moment ─────────────────────
        // Player just won but can't continue — surface the upgrade immediately
        // without requiring them to tap anything.
        guard !canContinue, let onUpgrade else { return }
        try? await Task.sleep(nanoseconds: 500_000_000)
        onUpgrade()
    }

    /// Eased count-up: fast at the start, decelerates near the target.
    private func rankFeedbackLabel(_ feedback: GameCenterManager.RankFeedback) -> String {
        switch feedback {
        case .newRecord:          return "NEW RECORD  #1 GLOBAL"
        case .topPercent(let n):  return "TOP \(n)%  GLOBAL"
        case .ranked(let r):      return "RANK  #\(r)  GLOBAL"
        }
    }

    private func countUp(to target: Int) async {
        guard target > 0 else { return }
        let steps   = min(target, 80)
        let stepNs  = UInt64(1_100_000_000) / UInt64(steps)
        for step in 1...steps {
            try? await Task.sleep(nanoseconds: stepNs)
            let t = Double(step) / Double(steps)
            displayedPct = Int(Double(target) * (1 - pow(1 - t, 1.7)))
        }
        displayedPct = target
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Share ticket
    // ══════════════════════════════════════════════════════════════════════

    /// Builds an ephemeral PlanetPass from the current game result + profile.
    /// Not persisted — exists only for rendering the share image.
    private func makeEphemeralPass() -> PlanetPass {
        let profile = ProgressionStore.profile
        let planet  = profile.currentPlanet
        return PlanetPass(
            id:              UUID(),
            planetName:      planet.name,
            planetIndex:     planet.id,
            levelReached:    profile.level,
            efficiencyScore: vm.gameResult?.efficiency ?? 0,
            missionCount:    profile.completedMissions,
            timestamp:       Date()
        )
    }

    /// Renders a ticket image on a background thread, then presents the system share sheet.
    private func shareTicket() {
        let profile = ProgressionStore.profile
        let pass    = makeEphemeralPass()
        HapticsManager.light()

        Task {
            // Heavy CG draw (1080×1080) happens off the main actor.
            let image = await Task.detached(priority: .userInitiated) {
                TicketRenderer.render(pass: pass, profile: profile)
            }.value

            // Back on main actor for UIKit presentation.
            let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)

            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            vc.popoverPresentationController?.sourceView = rootVC.view
            vc.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.maxY - 80,
                width: 0, height: 0
            )

            rootVC.present(vc, animated: true)
        }
    }
}

// MARK: - SageMetric
/// One metric cell in the sage-panel bottom row.
private struct SageMetric: View {
    let icon:  String
    let label: String
    let value: String
    let ink:   Color   // primary text
    let sub:   Color   // icon + label

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(sub)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(sub)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }
}
