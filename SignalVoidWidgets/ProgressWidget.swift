import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ProgressDisplayMode

enum ProgressDisplayMode: String, AppEnum {
    case percentage  = "percentage"
    case missions    = "missions"
    case score       = "score"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display Mode")
    static var caseDisplayRepresentations: [ProgressDisplayMode: DisplayRepresentation] = [
        .percentage: "Completion %",
        .missions:   "Missions",
        .score:      "Score",
    ]
}

// MARK: - Intent

struct ProgressWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Progress Display"
    static var description: IntentDescription = "Choose what the progress widget highlights."

    @Parameter(title: "Display")
    var displayMode: ProgressDisplayMode?
}

// MARK: - Entry

struct ProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
    let displayMode: ProgressDisplayMode
}

// MARK: - Provider

struct ProgressProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: .now, snapshot: PreviewSnapshots.sample, displayMode: .percentage)
    }

    func snapshot(for configuration: ProgressWidgetIntent, in context: Context) async -> ProgressEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return ProgressEntry(date: .now, snapshot: data, displayMode: configuration.displayMode ?? .percentage)
    }

    func timeline(for configuration: ProgressWidgetIntent, in context: Context) async -> Timeline<ProgressEntry> {
        let data = WidgetDataBridge.read()
        let entry = ProgressEntry(date: .now, snapshot: data, displayMode: configuration.displayMode ?? .percentage)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct ProgressWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.progress"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ProgressWidgetIntent.self, provider: ProgressProvider()) { entry in
            ProgressWidgetView(entry: entry)
                .containerBackground(WidgetTheme.sage, for: .widget)
        }
        .configurationDisplayName("Progress & Rank")
        .description("Track your mission progress and astronaut rank.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct ProgressWidgetView: View {
    let entry: ProgressEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemSmall:  ProgressSmall(snap: snap)
            case .systemMedium: ProgressMedium(snap: snap)
            case .systemLarge:  ProgressLarge(snap: snap)
            default:            ProgressSmall(snap: snap)
            }
        } else {
            WidgetEmptyState(icon: "antenna.radiowaves.left.and.right", message: S.playMission)
        }
    }
}

// MARK: - Small
// Hero: giant "28" + "%" split. MissionRail at bottom.

private struct ProgressSmall: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }
    private var missions: String {
        "\(String(format: "%03d", snap.completedMissions))/\(snap.totalMissions)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top meta
            HStack {
                Text("\u{25C8} \(S.campaign)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                Text("S\u{00B7}\(sectorIdx + 1)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
            }

            Spacer(minLength: 0)

            // Hero: "28" giant + "%" superscript
            HStack(alignment: .top, spacing: 2) {
                Text("\(snap.completionPercent)")
                    .font(WidgetTheme.sans(48, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sageInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("%")
                    .font(WidgetTheme.sans(18, weight: .bold))
                    .foregroundStyle(WidgetTheme.sageInk)
                    .offset(y: 4)
            }

            // Missions count
            Text("\(missions) \(S.missions)")
                .font(WidgetTheme.mono(8, weight: .bold))
                .tracking(2)
                .foregroundStyle(WidgetTheme.sageMid)
                .padding(.top, 2)

            Spacer(minLength: 4)

            // Mission rail (5-segment rank ladder)
            MissionRail(
                segments: 5,
                filled: rankIdx,
                currentPct: CGFloat(snap.levelProgress),
                color: WidgetTheme.sageInk
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

// MARK: - Medium
// Left dark block (rank + score), right sage panel (hero % + rail).

private struct ProgressMedium: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }
    private var missions: String {
        "\(String(format: "%03d", snap.completedMissions))/\(snap.totalMissions)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Dark left block
            VStack(alignment: .leading, spacing: 0) {
                Text("\u{25C8} \(S.rank) \(String(format: "%02d", rankIdx + 1))/\(String(format: "%02d", WidgetRanks.names.count))")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                    .padding(.bottom, 6)

                Text(S.rankName(snap.rankTitle))
                    .font(WidgetTheme.sans(18, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(WidgetTheme.sage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                Text(S.totalScore)
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Text(WidgetTheme.formattedScore(snap.leaderboardScore))
                    .font(WidgetTheme.sans(18, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(WidgetTheme.sage)
                    .padding(.top, 3)
            }
            .padding(14)
            .frame(width: 140)
            .frame(maxHeight: .infinity)
            .background(WidgetTheme.backgroundDark)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, -20)
            .padding(.vertical, -20)

            // Sage right panel
            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack {
                    Text("SV")
                        .font(WidgetTheme.sans(11, weight: .heavy))
                        .foregroundStyle(WidgetTheme.sageInk)
                    Spacer()
                    Text("S\u{00B7}\(sectorIdx + 1) / \(S.planetName(snap.currentPlanetName))")
                        .font(WidgetTheme.mono(7, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.sageMid)
                }

                Spacer(minLength: 0)

                // Hero %  + missions
                HStack(alignment: .bottom, spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("\(snap.completionPercent)")
                            .font(WidgetTheme.sans(42, weight: .heavy))
                            .foregroundStyle(WidgetTheme.sageInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text("%")
                            .font(WidgetTheme.sans(16, weight: .bold))
                            .foregroundStyle(WidgetTheme.sageInk)
                            .offset(y: 4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(S.missions)
                            .font(WidgetTheme.mono(7, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(WidgetTheme.sageMid)
                        Text(missions)
                            .font(WidgetTheme.mono(11, weight: .heavy))
                            .foregroundStyle(WidgetTheme.sageInk)
                    }
                    .padding(.bottom, 10)
                    .padding(.leading, 6)
                }

                Spacer(minLength: 4)

                // Mission rail
                MissionRail(
                    segments: 5,
                    filled: rankIdx,
                    currentPct: CGFloat(snap.levelProgress),
                    color: WidgetTheme.sageInk
                )
            }
            .padding(.leading, 14)
            .padding(.trailing, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "signalvoid://home"))
    }
}

// MARK: - Large
// Full career dashboard: rank title, rank ladder, hero %, sector strip, dark KPI strip.

private struct ProgressLarge: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }
    private var missions: String {
        "\(String(format: "%03d", snap.completedMissions))/\(snap.totalMissions)"
    }
    private var nextRank: String { WidgetRanks.nextRank(after: snap.rankTitle) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Top bar
            HStack {
                Text("\u{25C8} \(S.careerProgression)")
                    .font(WidgetTheme.mono(8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                Text("SV")
                    .font(WidgetTheme.mono(10, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sageInk)
            }
            .padding(.bottom, 2)

            // Separator
            Rectangle()
                .fill(WidgetTheme.sageInk.opacity(0.13))
                .frame(height: 0.5)

            // Rank title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(S.localizedRankTitle(snap.rankTitle))
                    .font(WidgetTheme.sans(32, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.sageInk)
                Text(S.rankSubtitle(rankIdx: rankIdx, sectorIdx: sectorIdx, planetName: snap.currentPlanetName))
                    .font(WidgetTheme.sans(12, weight: .bold))
                    .foregroundStyle(WidgetTheme.sageMid)
            }

            // 5-segment rank ladder with labels
            RankLadder(
                rankIndex: rankIdx,
                progress: CGFloat(snap.levelProgress),
                localizedNames: S.rankNames
            )

            // Giant % + campaign info
            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .top, spacing: 2) {
                    Text("\(snap.completionPercent)")
                        .font(WidgetTheme.sans(76, weight: .heavy))
                        .tracking(-3)
                        .foregroundStyle(WidgetTheme.sageInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("%")
                        .font(WidgetTheme.sans(22, weight: .bold))
                        .foregroundStyle(WidgetTheme.sageInk)
                        .offset(y: 8)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(S.campaignProgress)
                        .font(WidgetTheme.mono(7, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.sageMid)
                    Text("\(missions) \(S.missions)")
                        .font(WidgetTheme.mono(13, weight: .heavy))
                        .foregroundStyle(WidgetTheme.sageInk)
                    Text("\u{25B8} \(Int(snap.levelProgress * 100))% \(S.toRank(nextRank))")
                        .font(WidgetTheme.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.sageMid)
                }
                .padding(.bottom, 6)
            }

            // Sector strip
            VStack(alignment: .leading, spacing: 5) {
                Text("\(S.sectors) \u{00B7} \(sectorIdx + 1) / 8")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
                SectorStrip(
                    totalSectors: 8,
                    completedSectors: sectorIdx
                )
            }

            Spacer(minLength: 0)

            // Dark bottom KPI strip
            HStack(spacing: 0) {
                DarkDataCell(label: S.missions, value: String(format: "%03d", snap.completedMissions))
                DarkDataCell(label: S.score, value: WidgetTheme.shortScore(snap.leaderboardScore), highlight: true)
                DarkDataCell(label: S.bestEff, value: "\(snap.averageEfficiencyPercent)%")
            }
            .background(WidgetTheme.backgroundDark)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .widgetURL(URL(string: "signalvoid://missions"))
    }
}

// MARK: - Previews

#Preview("Progress Small", as: .systemSmall) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: .now, snapshot: PreviewSnapshots.sample, displayMode: .percentage)
}

#Preview("Progress Medium", as: .systemMedium) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: .now, snapshot: PreviewSnapshots.sample, displayMode: .percentage)
}

#Preview("Progress Large", as: .systemLarge) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: .now, snapshot: PreviewSnapshots.sample, displayMode: .percentage)
}
