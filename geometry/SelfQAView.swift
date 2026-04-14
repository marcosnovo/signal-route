import SwiftUI

// MARK: - SelfQAView
/// QA tab content embedded inside DevMenuView.
struct SelfQAView: View {
    @ObservedObject var runner: SelfQARunner
    let onJumpToLevel: (Level) -> Void

    var body: some View {
        VStack(spacing: 0) {
            launchStrip
            TechDivider()
            if runner.isRunning {
                runningState
            } else if let summary = runner.summary {
                summaryView(summary)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Launch strip

    private var launchStrip: some View {
        HStack(spacing: 8) {
            qaButton("RUN QUICK QA", icon: "bolt.fill", color: AppTheme.sage) {
                Task { await runner.runQuick() }
            }
            qaButton("RUN FULL QA", icon: "checklist", color: AppTheme.accentPrimary) {
                Task { await runner.runFull() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - States

    private var runningState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(AppTheme.accentPrimary)
            TechLabel(text: "RUNNING QA…", color: AppTheme.textSecondary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.35))
                .padding(.bottom, 4)
            TechLabel(text: "NO QA RUN YET", color: AppTheme.textSecondary)
            TechLabel(text: "Tap RUN QUICK QA to start", color: AppTheme.textSecondary.opacity(0.50))
            Spacer()
        }
    }

    // MARK: - Summary

    private func summaryView(_ s: QASummary) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                globalBanner(s)
                TechDivider()

                if !s.nonPassing.isEmpty {
                    sectionLabel("ISSUES (\(s.nonPassing.count))")
                    TechDivider()
                    ForEach(s.nonPassing) { result in
                        QAResultRow(result: result, onJump: onJumpToLevel)
                        TechDivider().opacity(0.4)
                    }
                    TechDivider()
                }

                ForEach(QACategory.allCases, id: \.self) { cat in
                    let catResults = s.results(for: cat)
                    if !catResults.isEmpty {
                        QACategorySection(category: cat, results: catResults, onJump: onJumpToLevel)
                        TechDivider()
                    }
                }
            }
        }
    }

    // MARK: - Global banner

    private func globalBanner(_ s: QASummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: s.overallStatus.systemIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(s.overallStatus.color)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    TechLabel(text: s.mode + " QA", color: AppTheme.accentPrimary)
                    statusPill(s.overallStatus.label, s.overallStatus)
                }
                HStack(spacing: 6) {
                    statusPill("\(s.passes) PASS",   .pass)
                    statusPill("\(s.warnings) WARN", .warning)
                    statusPill("\(s.failures) FAIL", .fail)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                TechLabel(text: "\(s.total) checks", color: AppTheme.textSecondary)
                TechLabel(text: String(format: "%.2fs", s.duration),
                          color: AppTheme.textSecondary.opacity(0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(s.overallStatus.color.opacity(0.06))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            TechLabel(text: text, color: AppTheme.accentPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AppTheme.accentPrimary.opacity(0.05))
    }

    private func statusPill(_ text: String, _ status: QAStatus) -> some View {
        Text(text)
            .font(AppTheme.mono(7, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func qaButton(
        _ label: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(label).font(AppTheme.mono(9, weight: .bold)).kerning(0.5)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(color.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.28), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .disabled(runner.isRunning)
    }
}

// MARK: - QACategorySection

struct QACategorySection: View {
    let category: QACategory
    let results:  [QAResult]
    let onJump:   (Level) -> Void

    @State private var expanded = false

    private var worst: QAStatus { results.map { $0.status }.max() ?? .pass }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(worst.color)
                        .frame(width: 14)

                    TechLabel(text: category.rawValue, color: AppTheme.textPrimary)

                    Spacer()

                    let fails    = results.filter { $0.status == .fail    }.count
                    let warns    = results.filter { $0.status == .warning }.count
                    let passings = results.filter { $0.status == .pass    }.count

                    if fails > 0    { countBadge("\(fails) FAIL",  .fail)    }
                    if warns > 0    { countBadge("\(warns) WARN",  .warning) }
                    if passings > 0 { countBadge("\(passings) OK", .pass)    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(results) { result in
                    TechDivider().opacity(0.35)
                    QAResultRow(result: result, onJump: onJump)
                }
            }
        }
    }

    private func countBadge(_ text: String, _ status: QAStatus) -> some View {
        Text(text)
            .font(AppTheme.mono(6, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - QAResultRow

struct QAResultRow: View {
    let result: QAResult
    let onJump: (Level) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: result.status.systemIcon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(result.status.color)
                    .frame(width: 14)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(0.3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(result.detail)
                        .font(AppTheme.mono(7.5, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let fix = result.suggestion {
                        Text("→ " + fix)
                            .font(AppTheme.mono(7.5, weight: .regular))
                            .foregroundStyle(result.status.color.opacity(0.85))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let levelID = result.linkedLevelID,
                       let level = LevelGenerator.levels.first(where: { $0.id == levelID }) {
                        Button {
                            onJump(level)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 7))
                                Text("JUMP TO L\(String(format: "%03d", levelID))")
                                    .font(AppTheme.mono(7, weight: .bold))
                                    .kerning(0.4)
                            }
                            .foregroundStyle(AppTheme.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(result.status == .pass ? Color.clear : result.status.color.opacity(0.03))
    }
}
