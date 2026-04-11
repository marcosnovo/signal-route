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
                    TechLabel(text: "HOME")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            TechLabel(text: vm.currentLevel.displayName,
                      color: AppTheme.textSecondary)
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
                .foregroundStyle(AppTheme.textSecondary)
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
                            ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                        }
                        // Baseline
                        var bl = Path()
                        bl.move(to: CGPoint(x: 0, y: size.height))
                        bl.addLine(to: CGPoint(x: size.width, y: size.height))
                        ctx.stroke(bl, with: .color(.white.opacity(0.22)), lineWidth: 0.5)
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
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 22, height: Self.chartH)
            }
            .padding(.horizontal, 10)

            // X-axis labels
            let xLabels = ["M1","M2","M3","M4","M5","M6","M7","NOW"]
            HStack(spacing: 4) {
                ForEach(Array(xLabels.enumerated()), id: \.offset) { idx, lbl in
                    Text(lbl)
                        .font(AppTheme.mono(6, weight: idx == 7 ? .bold : .regular))
                        .foregroundStyle(idx == 7 ? AppTheme.accentPrimary : AppTheme.textSecondary)
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
            Rectangle().fill(AppTheme.stroke).frame(width: 0.5)
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
            Text("MISSION\nDEBRIEF")
                .font(.system(size: 24, weight: .black, design: .default))
                .foregroundStyle(sageInk)
                .lineSpacing(-2)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)

            // ── Huge KPI + inline descriptor ────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Number + %
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(displayedPct)")
                        .font(.system(size: 60, weight: .black))
                        .foregroundStyle(sageInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppTheme.accentPrimary)
                        .offset(y: -4)
                }
                // Descriptor beside the number (like "Successful\nLaunches Rate")
                VStack(alignment: .leading, spacing: 1) {
                    Text("NETWORK")
                    Text("EFFICIENCY")
                }
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(sageMid)
                .offset(y: 4)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            // ── Horizontal divider ───────────────────────────────────────
            Rectangle()
                .fill(sageDivider)
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            // ── Bottom metrics row ───────────────────────────────────────
            VStack(spacing: 0) {
                Rectangle().fill(sageDivider).frame(height: 0.5)

                HStack(spacing: 0) {
                    SageMetric(
                        icon:     "scope",
                        label:    "SCORE",
                        value:    "\(vm.score)",
                        ink:      sageInk,
                        sub:      sageFaint
                    )
                    Rectangle().fill(sageDivider).frame(width: 0.5)
                    SageMetric(
                        icon:     "cpu",
                        label:    "NODES",
                        value:    "\(vm.activeNodes)",
                        ink:      sageInk,
                        sub:      sageFaint
                    )
                    Rectangle().fill(sageDivider).frame(width: 0.5)
                    SageMetric(
                        icon:     "waveform",
                        label:    "MOVES",
                        value:    "\(vm.movesUsed)",
                        ink:      sageInk,
                        sub:      sageFaint
                    )
                }
            }
            .opacity(metricsVisible ? 1 : 0)
            .offset(y: metricsVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.30), value: metricsVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sageBg)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - CTA strip
    // ══════════════════════════════════════════════════════════════════════

    private var ctaStrip: some View {
        HStack(spacing: 0) {
            Button(action: onRestart) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("RETRY")
                        .font(AppTheme.mono(11, weight: .bold))
                        .kerning(1.5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.success)
                .foregroundStyle(.white)
            }

            Rectangle()
                .fill(AppTheme.stroke)
                .frame(width: 0.5, height: 24)

            Button(action: shareTicket) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("SHARE")
                        .font(AppTheme.mono(10, weight: .bold))
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(AppTheme.textPrimary)
            }

            Rectangle()
                .fill(AppTheme.stroke)
                .frame(width: 0.5, height: 24)

            Button(action: onDismiss) {
                Text("HOME")
                    .font(AppTheme.mono(10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .background(AppTheme.surface)
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
    }

    /// Eased count-up: fast at the start, decelerates near the target.
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

    /// Renders a ticket image and presents the system share sheet.
    private func shareTicket() {
        let profile = ProgressionStore.profile
        let pass    = makeEphemeralPass()
        let image   = TicketRenderer.render(pass: pass, profile: profile)

        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        // Find the key window's root view controller
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // iPad requires a source rect for the popover
        vc.popoverPresentationController?.sourceView = rootVC.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: rootVC.view.bounds.midX,
            y: rootVC.view.bounds.maxY - 80,
            width: 0, height: 0
        )

        rootVC.present(vc, animated: true)
        HapticsManager.light()
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
