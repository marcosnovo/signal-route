import WidgetKit
import SwiftUI
import AppIntents

// MARK: - LeaderboardBoard

enum LeaderboardBoard: String, AppEnum {
    case total  = "total"
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"
    case expert = "expert"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Leaderboard")
    static var caseDisplayRepresentations: [LeaderboardBoard: DisplayRepresentation] = [
        .total:  "Total Score",
        .easy:   "Easy Tier",
        .medium: "Medium Tier",
        .hard:   "Hard Tier",
        .expert: "Expert Tier",
    ]

    var displayLabel: String {
        switch self {
        case .total:  return "TOTAL SCORE"
        case .easy:   return "EASY TIER"
        case .medium: return "MEDIUM TIER"
        case .hard:   return "HARD TIER"
        case .expert: return "EXPERT TIER"
        }
    }

    var shortLabel: String {
        switch self {
        case .total:  return "TOTAL"
        case .easy:   return "EASY"
        case .medium: return "MEDIUM"
        case .hard:   return "HARD"
        case .expert: return "EXPERT"
        }
    }
}

// MARK: - Intent

struct LeaderboardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Leaderboard"
    static var description: IntentDescription = "Choose which leaderboard to display."

    @Parameter(title: "Board")
    var board: LeaderboardBoard?
}

// MARK: - Entry

struct LeaderboardEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
    let board: LeaderboardBoard
}

// MARK: - Provider

struct LeaderboardProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> LeaderboardEntry {
        LeaderboardEntry(date: .now, snapshot: PreviewSnapshots.sample, board: .total)
    }

    func snapshot(for configuration: LeaderboardWidgetIntent, in context: Context) async -> LeaderboardEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return LeaderboardEntry(date: .now, snapshot: data, board: configuration.board ?? .total)
    }

    func timeline(for configuration: LeaderboardWidgetIntent, in context: Context) async -> Timeline<LeaderboardEntry> {
        let data = WidgetDataBridge.read()
        let entry = LeaderboardEntry(date: .now, snapshot: data, board: configuration.board ?? .total)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct LeaderboardWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.leaderboard"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LeaderboardWidgetIntent.self, provider: LeaderboardProvider()) { entry in
            LeaderboardWidgetView(entry: entry)
                .containerBackground(WidgetTheme.sage, for: .widget)
        }
        .configurationDisplayName("Leaderboards")
        .description("See your Game Center ranking.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct LeaderboardWidgetView: View {
    let entry: LeaderboardEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot, snap.playerRank != nil {
            switch family {
            case .systemSmall:  LeaderboardSmall(snap: snap, board: entry.board)
            case .systemMedium: LeaderboardMedium(snap: snap, board: entry.board)
            case .systemLarge:  LeaderboardLarge(snap: snap, board: entry.board)
            default:            LeaderboardSmall(snap: snap, board: entry.board)
            }
        } else {
            WidgetEmptyState(icon: "trophy", message: S.connectGC)
        }
    }
}

// MARK: - Small
// Giant orange rank number dominates. Score at bottom.

private struct LeaderboardSmall: View {
    let snap: WidgetDataSnapshot
    let board: LeaderboardBoard
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header label
            Text("\u{25C8} \(S.leaderboard) \u{00B7} \(S.boardLabel(board.shortLabel))")
                .font(WidgetTheme.mono(7, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(WidgetTheme.sageMid)

            Spacer(minLength: 0)

            // Hero rank: "#" small dark + number giant orange
            HStack(alignment: .top, spacing: -2) {
                Text("#")
                    .font(WidgetTheme.sans(34, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sageInk)
                    .offset(y: 6)
                Text("\(snap.playerRank ?? 0)")
                    .font(WidgetTheme.sans(86, weight: .heavy))
                    .foregroundStyle(WidgetTheme.accentOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }

            Spacer(minLength: 0)

            // Score
            Text(S.yourScore)
                .font(WidgetTheme.mono(7, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(WidgetTheme.sageMid)
            Text(WidgetTheme.formattedScore(snap.leaderboardScore))
                .font(WidgetTheme.sans(18, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(WidgetTheme.sageInk)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://leaderboards"))
    }
}

// MARK: - Medium
// Bar chart with score labels, user bar orange. Position badge top-right.

private struct LeaderboardMedium: View {
    let snap: WidgetDataSnapshot
    let board: LeaderboardBoard
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(alignment: .center) {
                Text("\u{25C8} \(S.leaderboard) \u{00B7} \(S.boardLabel(board.shortLabel))")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(S.position)
                        .font(WidgetTheme.mono(7, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.sageMid)
                    Text("#\(snap.playerRank ?? 0)")
                        .font(WidgetTheme.sans(22, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(WidgetTheme.accentOrange)
                }
            }

            Spacer(minLength: 6)

            // Bar chart
            LeaderboardBarChart(entries: snap.leaderboardEntries, showNames: true, maxBarHeight: 70)

            Spacer(minLength: 2)
        }
        .widgetURL(URL(string: "signalvoid://leaderboards"))
    }
}

// MARK: - Large
// Editorial: giant rank, commander class, bar chart with names, dark KPI strip.

private struct LeaderboardLarge: View {
    let snap: WidgetDataSnapshot
    let board: LeaderboardBoard
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top header
            HStack {
                Text("\u{25C8} \(S.globalLeaderboard) \u{00B7} \(S.boardLabel(board.shortLabel))")
                    .font(WidgetTheme.mono(8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                Text("\u{2606} SV|\(snap.totalPlayers ?? 0)")
                    .font(WidgetTheme.mono(10, weight: .bold))
                    .foregroundStyle(WidgetTheme.sageInk)
            }

            // Separator
            Rectangle()
                .fill(WidgetTheme.sageInk.opacity(0.15))
                .frame(height: 0.5)
                .padding(.top, 8)

            Spacer(minLength: 4)

            // Hero rank row
            HStack(alignment: .top, spacing: 12) {
                // "#3" giant
                HStack(alignment: .top, spacing: -6) {
                    Text("#")
                        .font(WidgetTheme.sans(40, weight: .heavy))
                        .foregroundStyle(WidgetTheme.sageInk)
                        .offset(y: 8)
                    Text("\(snap.playerRank ?? 0)")
                        .font(WidgetTheme.sans(96, weight: .heavy))
                        .foregroundStyle(WidgetTheme.accentOrange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }

                // Class + stats
                VStack(alignment: .leading, spacing: 6) {
                    Text(S.classLabel(snap.rankTitle))
                        .font(WidgetTheme.sans(22, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(WidgetTheme.sageInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let total = snap.totalPlayers, let rank = snap.playerRank, total > 0 {
                        let pct = max(1, Int(Double(rank) / Double(total) * 100))
                        Text("TOP \(pct)% \u{00B7} GLOBAL")
                            .font(WidgetTheme.mono(8, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(WidgetTheme.sageMid)
                    }

                    if let change = snap.weeklyRankChange {
                        Text("\u{25B2} \(change) \(S.thisWeek)")
                            .font(WidgetTheme.mono(8, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(WidgetTheme.sageMid)
                    }
                }
                .padding(.top, 12)
            }

            Spacer(minLength: 6)

            // Bar chart with player names
            LeaderboardBarChart(entries: snap.leaderboardEntries, showNames: true, maxBarHeight: 70)

            Spacer(minLength: 8)

            // Dark bottom KPI strip
            HStack(spacing: 0) {
                DarkDataCell(label: S.score, value: WidgetTheme.formattedScore(snap.leaderboardScore))
                DarkDataCell(label: S.missions, value: "\(snap.completedMissions)+")
                DarkDataCell(
                    label: snap.streak != nil ? S.streak : S.efficiency,
                    value: snap.streak.map { "\($0)" } ?? "\(snap.averageEfficiencyPercent)%"
                )
            }
            .background(WidgetTheme.backgroundDark)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .widgetURL(URL(string: "signalvoid://leaderboards"))
    }
}

// MARK: - Previews

#Preview("Leaderboard Small", as: .systemSmall) {
    LeaderboardWidget()
} timeline: {
    LeaderboardEntry(date: .now, snapshot: PreviewSnapshots.sample, board: .hard)
}

#Preview("Leaderboard Medium", as: .systemMedium) {
    LeaderboardWidget()
} timeline: {
    LeaderboardEntry(date: .now, snapshot: PreviewSnapshots.sample, board: .hard)
}

#Preview("Leaderboard Large", as: .systemLarge) {
    LeaderboardWidget()
} timeline: {
    LeaderboardEntry(date: .now, snapshot: PreviewSnapshots.sample, board: .hard)
}
