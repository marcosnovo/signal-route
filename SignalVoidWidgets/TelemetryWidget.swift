import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct TelemetryWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Telemetry Dashboard"
    static var description: IntentDescription = "Performance analytics and efficiency tracking."
}

// MARK: - Entry

struct TelemetryEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
}

// MARK: - Provider

struct TelemetryProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> TelemetryEntry {
        TelemetryEntry(date: .now, snapshot: PreviewSnapshots.sample)
    }

    func snapshot(for configuration: TelemetryWidgetIntent, in context: Context) async -> TelemetryEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return TelemetryEntry(date: .now, snapshot: data)
    }

    func timeline(for configuration: TelemetryWidgetIntent, in context: Context) async -> Timeline<TelemetryEntry> {
        let data = WidgetDataBridge.read()
        let entry = TelemetryEntry(date: .now, snapshot: data)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct TelemetryWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.telemetry"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TelemetryWidgetIntent.self, provider: TelemetryProvider()) { entry in
            TelemetryWidgetView(entry: entry)
                .containerBackground(WidgetTheme.backgroundDark, for: .widget)
        }
        .configurationDisplayName("Telemetry Dashboard")
        .description("Track your efficiency and performance analytics.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct TelemetryWidgetView: View {
    let entry: TelemetryEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot {
            if snap.isPremium {
                switch family {
                case .systemSmall:  TelemetrySmall(snap: snap)
                case .systemMedium: TelemetryMedium(snap: snap)
                case .systemLarge:  TelemetryLarge(snap: snap)
                default:            TelemetrySmall(snap: snap)
                }
            } else {
                PremiumLockedView(widgetName: S.telemetry, darkBackground: true)
                    .widgetURL(URL(string: "signalvoid://paywall"))
            }
        } else {
            WidgetEmptyState(icon: "waveform.path.ecg", message: S.playMission, darkBackground: true)
        }
    }
}

// MARK: - Small
// Watch-face: HUGE efficiency %, rank tag, level tag, dashed bar.

private struct TelemetrySmall: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var effColor: Color { WidgetTheme.efficiencyColor(snap.averageEfficiencyPercent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: label + level tag
            HStack {
                Text(S.telemetry)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text("LV\(String(format: "%02d", snap.playerLevel))")
                    .font(WidgetTheme.mono(7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)
            }

            Spacer(minLength: 0)

            // HERO: giant efficiency
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(snap.averageEfficiencyPercent)")
                    .font(WidgetTheme.sans(56, weight: .heavy))
                    .tracking(-3)
                    .foregroundStyle(effColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("%")
                    .font(WidgetTheme.sans(20, weight: .bold))
                    .foregroundStyle(effColor.opacity(0.6))
            }

            // Rank label
            Text(S.rankName(snap.rankTitle))
                .font(WidgetTheme.mono(8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(WidgetTheme.onDarkSub)

            Spacer(minLength: 6)

            // Dashed bar
            DashedBar(pct: snap.averageEfficiencyPercent, accent: effColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

// MARK: - Medium
// Left: hero efficiency + rank + dashed bar. Right: compact KPI cards.

private struct TelemetryMedium: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var effColor: Color { WidgetTheme.efficiencyColor(snap.averageEfficiencyPercent) }

    var body: some View {
        HStack(spacing: 0) {
            // Left: efficiency hero
            VStack(alignment: .leading, spacing: 0) {
                Text(S.avgEfficiency)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(WidgetTheme.onDarkSub)

                Spacer(minLength: 2)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(snap.averageEfficiencyPercent)")
                        .font(WidgetTheme.sans(48, weight: .heavy))
                        .tracking(-2)
                        .foregroundStyle(effColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("%")
                        .font(WidgetTheme.sans(18, weight: .bold))
                        .foregroundStyle(effColor.opacity(0.6))
                }

                // Rank in orange
                Text(S.rankName(snap.rankTitle))
                    .font(WidgetTheme.mono(8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.accentOrange)

                Spacer(minLength: 4)

                DashedBar(pct: snap.averageEfficiencyPercent, accent: effColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: KPI rows
            VStack(spacing: 3) {
                TelemetryKPI(
                    label: S.score,
                    value: WidgetTheme.shortScore(snap.leaderboardScore),
                    accent: true
                )
                TelemetryKPI(
                    label: S.position,
                    value: snap.playerRank.map { "#\($0)" } ?? "\u{2014}",
                    accent: false
                )
                TelemetryKPI(
                    label: S.streak,
                    value: snap.streak.map { "\($0)d" } ?? "\u{2014}",
                    accent: false
                )
            }
            .frame(width: 110)
        }
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

/// Compact KPI row for Telemetry medium (matches NavigatorKPI style).
private struct TelemetryKPI: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(WidgetTheme.mono(6, weight: .semibold))
                .tracking(1)
                .foregroundStyle(WidgetTheme.onDarkSub)
            Spacer()
            Text(value)
                .font(WidgetTheme.mono(11, weight: .heavy))
                .foregroundStyle(accent ? WidgetTheme.accentOrange : WidgetTheme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(WidgetTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Large
// Full dashboard: hero efficiency, rank/level, 2×3 KPI grid, sector strip, serial + time.

private struct TelemetryLarge: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var effColor: Color { WidgetTheme.efficiencyColor(snap.averageEfficiencyPercent) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: snap.updatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("\u{2B21} \(S.telemetryDashboard)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text("SV")
                    .font(WidgetTheme.mono(10, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sage)
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

            // Hero: efficiency + rank/level right
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(snap.averageEfficiencyPercent)")
                            .font(WidgetTheme.sans(60, weight: .heavy))
                            .tracking(-3)
                            .foregroundStyle(effColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text("%")
                            .font(WidgetTheme.sans(22, weight: .bold))
                            .foregroundStyle(effColor.opacity(0.6))
                    }
                    DashedBar(pct: snap.averageEfficiencyPercent, accent: effColor, height: 4)
                        .padding(.top, 2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(S.rankName(snap.rankTitle))
                        .font(WidgetTheme.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.onDarkSub)
                    Text("LV\(String(format: "%02d", snap.playerLevel))")
                        .font(WidgetTheme.sans(22, weight: .heavy))
                        .foregroundStyle(WidgetTheme.accentOrange)
                }
                .padding(.bottom, 8)
            }

            // 2×3 KPI grid
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    TelemetryCell(label: S.missions, value: "\(snap.completedMissions)", color: WidgetTheme.sage)
                    TelemetryCell(label: S.score, value: WidgetTheme.shortScore(snap.leaderboardScore), color: WidgetTheme.accentOrange)
                    TelemetryCell(label: S.position, value: snap.playerRank.map { "#\($0)" } ?? "\u{2014}", color: WidgetTheme.sage)
                }
                HStack(spacing: 4) {
                    TelemetryCell(label: S.sectors, value: "\(sectorIdx + 1)/10", color: WidgetTheme.sage)
                    TelemetryCell(label: S.streak, value: snap.streak.map { "\($0)d" } ?? "\u{2014}", color: WidgetTheme.sage)
                    TelemetryCell(label: S.weekly, value: snap.weeklyRankChange.map { $0 >= 0 ? "\u{25B2} \($0)" : "\u{25BC} \(abs($0))" } ?? "\u{2014}", color: snap.weeklyRankChange.map { $0 >= 0 ? WidgetTheme.success : WidgetTheme.danger } ?? WidgetTheme.textSecondary)
                }
            }
            .background(WidgetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Sector strip + label
            VStack(alignment: .leading, spacing: 4) {
                DarkSectorStrip(totalSectors: 10, completedSectors: sectorIdx)
                Text(S.sectorCompletion)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(WidgetTheme.onDarkSub)
            }

            Spacer(minLength: 0)

            // Bottom: serial + time
            HStack {
                Text("SR-\(String(format: "%04d", snap.completedMissions))")
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.25))
                Spacer()
                Text(timeString)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

// MARK: - Previews

#Preview("Telemetry Small", as: .systemSmall) {
    TelemetryWidget()
} timeline: {
    TelemetryEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Telemetry Medium", as: .systemMedium) {
    TelemetryWidget()
} timeline: {
    TelemetryEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Telemetry Large", as: .systemLarge) {
    TelemetryWidget()
} timeline: {
    TelemetryEntry(date: .now, snapshot: PreviewSnapshots.sample)
}
