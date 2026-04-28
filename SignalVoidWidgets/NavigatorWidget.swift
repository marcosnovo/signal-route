import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct NavigatorWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Navigator Status"
    static var description: IntentDescription = "Show your astronaut rank and status."
}

// MARK: - Entry

struct NavigatorEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
}

// MARK: - Provider

struct NavigatorProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> NavigatorEntry {
        NavigatorEntry(date: .now, snapshot: PreviewSnapshots.sample)
    }

    func snapshot(for configuration: NavigatorWidgetIntent, in context: Context) async -> NavigatorEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return NavigatorEntry(date: .now, snapshot: data)
    }

    func timeline(for configuration: NavigatorWidgetIntent, in context: Context) async -> Timeline<NavigatorEntry> {
        let data = WidgetDataBridge.read()
        let entry = NavigatorEntry(date: .now, snapshot: data)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct NavigatorWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.navigator"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NavigatorWidgetIntent.self, provider: NavigatorProvider()) { entry in
            NavigatorWidgetView(entry: entry)
                .containerBackground(WidgetTheme.backgroundDark, for: .widget)
        }
        .configurationDisplayName("Navigator Status")
        .description("Your astronaut rank and career dashboard.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct NavigatorWidgetView: View {
    let entry: NavigatorEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot {
            if snap.isPremium {
                switch family {
                case .systemSmall:  NavigatorSmall(snap: snap)
                case .systemMedium: NavigatorMedium(snap: snap)
                case .systemLarge:  NavigatorLarge(snap: snap)
                default:            NavigatorSmall(snap: snap)
                }
            } else {
                PremiumLockedView(widgetName: S.navigatorStatus, darkBackground: true)
                    .widgetURL(URL(string: "signalvoid://paywall"))
            }
        } else {
            WidgetEmptyState(icon: "person.circle", message: S.playMission, darkBackground: true)
        }
    }
}

// MARK: - Small
// Watch-face style: HUGE level number, rank as subtitle, planet + target icon as metadata.

private struct NavigatorSmall: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: sector + target
            HStack(alignment: .center, spacing: 4) {
                Text("S\u{00B7}\(sectorIdx + 1)")
                    .font(WidgetTheme.mono(7, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text(S.planetName(snap.currentPlanetName).uppercased())
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // HERO: giant level number
            Text(String(format: "%02d", snap.playerLevel))
                .font(WidgetTheme.sans(64, weight: .heavy))
                .tracking(-3)
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Rank name in orange
            Text(S.rankName(snap.rankTitle))
                .font(WidgetTheme.mono(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(WidgetTheme.accentOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer(minLength: 6)

            // Progress bar
            ProgressBarView(
                progress: snap.levelProgress,
                height: 3,
                trackColor: Color.white.opacity(0.08),
                fillColor: WidgetTheme.accentOrange
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

// MARK: - Medium
// Left: huge level + rank. Right: compact KPI strip + sector.

private struct NavigatorMedium: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    var body: some View {
        HStack(spacing: 0) {
            // Left hero block
            VStack(alignment: .leading, spacing: 0) {
                // Sector tag
                Text("S\u{00B7}\(sectorIdx + 1) \u{00B7} \(S.planetName(snap.currentPlanetName).uppercased())")
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Giant level
                Text(String(format: "%02d", snap.playerLevel))
                    .font(WidgetTheme.sans(52, weight: .heavy))
                    .tracking(-3)
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                // Rank in orange
                Text(S.rankName(snap.rankTitle))
                    .font(WidgetTheme.mono(9, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.accentOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: 4)

                // Progress bar
                ProgressBarView(
                    progress: snap.levelProgress,
                    height: 3,
                    trackColor: Color.white.opacity(0.08),
                    fillColor: WidgetTheme.accentOrange
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right KPI column
            VStack(spacing: 3) {
                NavigatorKPI(label: S.missions, value: "\(snap.completedMissions)", accent: false)
                NavigatorKPI(label: S.score, value: WidgetTheme.shortScore(snap.leaderboardScore), accent: true)
                NavigatorKPI(label: S.efficiency, value: "\(snap.averageEfficiencyPercent)%", accent: false)
            }
            .frame(width: 100)
        }
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

/// Compact KPI row for Navigator medium.
private struct NavigatorKPI: View {
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
// Full dashboard: hero level, rank ladder, KPI strip, sector strip.

private struct NavigatorLarge: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }
    private var nextRank: String { WidgetRanks.nextRank(after: snap.rankTitle) }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: snap.updatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("\u{2B21} \(S.navigatorStatus)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text("SV")
                    .font(WidgetTheme.mono(10, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sage)
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

            // Hero: rank + huge level
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(S.rankName(snap.rankTitle))
                        .font(WidgetTheme.sans(22, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(WidgetTheme.textPrimary)
                    Text(String(format: "%02d", snap.playerLevel))
                        .font(WidgetTheme.sans(56, weight: .heavy))
                        .tracking(-3)
                        .foregroundStyle(WidgetTheme.accentOrange)
                        .lineLimit(1)
                }
                Spacer()
                // Sector + planet
                VStack(alignment: .trailing, spacing: 2) {
                    Text("S\u{00B7}\(sectorIdx + 1)")
                        .font(WidgetTheme.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.onDarkSub)
                    Text(S.planetName(snap.currentPlanetName).uppercased())
                        .font(WidgetTheme.mono(7, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.sage.opacity(0.6))
                }
                .padding(.bottom, 8)
            }

            // Progress bar + TO label
            VStack(alignment: .leading, spacing: 3) {
                ProgressBarView(
                    progress: snap.levelProgress,
                    height: 5,
                    trackColor: Color.white.opacity(0.08),
                    fillColor: WidgetTheme.accentOrange
                )
                Text("\u{25B8} \(Int(snap.levelProgress * 100))% \(S.toRank(nextRank))")
                    .font(WidgetTheme.mono(7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)
            }

            // 3-column KPI
            HStack(spacing: 0) {
                TelemetryCell(label: S.missions, value: String(format: "%03d", snap.completedMissions), color: WidgetTheme.sage)
                TelemetryCell(label: S.score, value: WidgetTheme.shortScore(snap.leaderboardScore), color: WidgetTheme.accentOrange)
                TelemetryCell(label: S.avgEff, value: "\(snap.averageEfficiencyPercent)%", color: WidgetTheme.efficiencyColor(snap.averageEfficiencyPercent))
            }
            .background(WidgetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Sector strip
            DarkSectorStrip(totalSectors: 8, completedSectors: sectorIdx)

            Spacer(minLength: 0)

            // Bottom strip
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

#Preview("Navigator Small", as: .systemSmall) {
    NavigatorWidget()
} timeline: {
    NavigatorEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Navigator Medium", as: .systemMedium) {
    NavigatorWidget()
} timeline: {
    NavigatorEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Navigator Large", as: .systemLarge) {
    NavigatorWidget()
} timeline: {
    NavigatorEntry(date: .now, snapshot: PreviewSnapshots.sample)
}
