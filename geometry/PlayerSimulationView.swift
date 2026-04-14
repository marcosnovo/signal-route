import SwiftUI

// MARK: - PlayerSimulationView

/// Full end-to-end player simulation tab inside DevMenuView.
/// Shows a live-streaming log of each step as the runner executes.
struct PlayerSimulationView: View {
    @ObservedObject var runner: PlayerSimulationRunner

    var body: some View {
        VStack(spacing: 0) {
            launchStrip
            TechDivider()
            if runner.isRunning {
                liveLog
            } else if let summary = runner.summary {
                summaryLog(summary)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Launch strip

    private var launchStrip: some View {
        HStack(spacing: 8) {
            Button {
                Task { await runner.run() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 9, weight: .bold))
                    Text("RUN PLAYER SIMULATION")
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.5)
                }
                .foregroundStyle(AppTheme.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(AppTheme.accentPrimary.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.28), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "figure.run")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.35))
                .padding(.bottom, 4)
            TechLabel(text: "NO SIMULATION RUN YET", color: AppTheme.textSecondary)
            TechLabel(text: "Tap RUN PLAYER SIMULATION to start",
                      color: AppTheme.textSecondary.opacity(0.50))
            Spacer()
        }
    }

    // MARK: - Live log (while running)

    private var liveLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let phase = runner.currentPhase {
                        phaseHeader(phase)
                        TechDivider()
                    }
                    ForEach(runner.steps) { step in
                        SimStepRow(step: step)
                        TechDivider().opacity(0.3)
                    }
                    // Live indicator
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(AppTheme.accentPrimary)
                        TechLabel(text: "SIMULATING…", color: AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .id("bottom")
                }
            }
            .onChange(of: runner.steps.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - Summary log (after completion)

    private func summaryLog(_ summary: SimSummary) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                globalBanner(summary)
                TechDivider()

                // Failures at top
                let failures = summary.steps.filter { $0.status == .fail }
                if !failures.isEmpty {
                    sectionLabel("FAILURES (\(failures.count))", color: SimStepStatus.fail.color)
                    TechDivider()
                    ForEach(failures) { step in
                        SimStepRow(step: step)
                        TechDivider().opacity(0.4)
                    }
                    TechDivider()
                }

                // Per-phase accordion
                ForEach(SimPhase.allCases, id: \.self) { phase in
                    let phaseSteps = summary.steps.filter { $0.phase == phase }
                    if !phaseSteps.isEmpty {
                        SimPhaseSection(phase: phase, steps: phaseSteps)
                        TechDivider()
                    }
                }
            }
        }
    }

    // MARK: - Global banner

    private func globalBanner(_ summary: SimSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: summary.overallStatus.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(summary.overallStatus.color)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    TechLabel(text: "PLAYER SIMULATION", color: AppTheme.accentPrimary)
                    statusPill(summary.overallStatus.icon == "checkmark.circle.fill"
                               ? "PASS" : summary.overallStatus == .warn ? "WARN" : "FAIL",
                               summary.overallStatus)
                }
                HStack(spacing: 6) {
                    statusPill("\(summary.passes) OK",   .ok)
                    statusPill("\(summary.warns) WARN",  .warn)
                    statusPill("\(summary.failures) FAIL", .fail)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                TechLabel(text: "\(summary.steps.count) steps", color: AppTheme.textSecondary)
                TechLabel(text: String(format: "%.2fs", summary.duration),
                          color: AppTheme.textSecondary.opacity(0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(summary.overallStatus.color.opacity(0.06))
    }

    // MARK: - Helpers

    private func phaseHeader(_ phase: SimPhase) -> some View {
        HStack(spacing: 6) {
            Image(systemName: phase.icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(phase.color)
            TechLabel(text: phase.rawValue, color: phase.color)
            Spacer()
            ProgressView().scaleEffect(0.5).tint(phase.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(phase.color.opacity(0.06))
    }

    private func sectionLabel(_ text: String, color: Color) -> some View {
        HStack {
            TechLabel(text: text, color: color)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(color.opacity(0.05))
    }

    private func statusPill(_ text: String, _ status: SimStepStatus) -> some View {
        Text(text)
            .font(AppTheme.mono(7, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - SimPhaseSection

struct SimPhaseSection: View {
    let phase: SimPhase
    let steps: [SimStep]

    @State private var expanded = false

    private var worst: SimStepStatus {
        if steps.contains(where: { $0.status == .fail }) { return .fail }
        if steps.contains(where: { $0.status == .warn }) { return .warn }
        return .ok
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: phase.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(worst.color)
                        .frame(width: 14)

                    TechLabel(text: phase.rawValue, color: AppTheme.textPrimary)
                    Spacer()

                    let fails  = steps.filter { $0.status == .fail  }.count
                    let warns  = steps.filter { $0.status == .warn  }.count
                    let passes = steps.filter { $0.status == .ok    }.count

                    if fails  > 0 { countBadge("\(fails) FAIL",  .fail)  }
                    if warns  > 0 { countBadge("\(warns) WARN",  .warn)  }
                    if passes > 0 { countBadge("\(passes) OK",   .ok)    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(steps) { step in
                    TechDivider().opacity(0.35)
                    SimStepRow(step: step)
                }
            }
        }
    }

    private func countBadge(_ text: String, _ status: SimStepStatus) -> some View {
        Text(text)
            .font(AppTheme.mono(6, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - SimStepRow

struct SimStepRow: View {
    let step: SimStep

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: step.status.icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(step.status.color)
                .frame(width: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(0.3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.detail)
                    .font(AppTheme.mono(7.5, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(step.status == .ok || step.status == .info
                    ? Color.clear
                    : step.status.color.opacity(0.04))
    }
}
