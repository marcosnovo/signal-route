import SwiftUI

// MARK: - HatchedStrip
/// Diagonal hatched accent strip used in the Planet Pass widget.
struct HatchedStrip: View {
    var color: Color = WidgetTheme.accentOrange
    var width: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let spacing: CGFloat = 4
            let count = Int(h / spacing) + 4

            Path { path in
                for i in 0..<count {
                    let y = CGFloat(i) * spacing - spacing
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y + width))
                }
            }
            .stroke(color.opacity(0.6), lineWidth: 1)
        }
        .frame(width: width)
        .clipped()
    }
}

// MARK: - KPICell (sage background)
/// Compact label + value cell used in widget KPI strips.
struct KPICell: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(WidgetTheme.mono(7, weight: .semibold))
                .tracking(1)
                .foregroundStyle(WidgetTheme.sageInk.opacity(0.45))
            Text(value)
                .font(WidgetTheme.mono(13, weight: .bold))
                .foregroundStyle(WidgetTheme.sageInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - DarkDataCell
/// Data cell for dark background strips. Supports orange highlight variant.
struct DarkDataCell: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WidgetTheme.mono(6.5, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(highlight ? WidgetTheme.sageInk.opacity(0.7) : WidgetTheme.onDarkSub)
            Text(value)
                .font(WidgetTheme.sans(17, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(highlight ? WidgetTheme.sageInk : WidgetTheme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? WidgetTheme.accentOrange : .clear)
    }
}

// MARK: - RankBadge
/// Small rank badge with level number and title.
struct RankBadge: View {
    let title: String
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(WidgetTheme.sans(18, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(WidgetTheme.sageInk)
            Text(String(format: "RANK %02d", level))
                .font(WidgetTheme.mono(8, weight: .semibold))
                .tracking(1)
                .foregroundStyle(WidgetTheme.sageMid)
        }
    }
}

// MARK: - MissionRail
/// 5-segment rank progress bar. Filled = completed ranks, current = partial orange.
struct MissionRail: View {
    var segments: Int = 5
    var filled: Int = 2
    var currentPct: CGFloat = 0.4
    var color: Color = WidgetTheme.sageInk
    var accent: Color = WidgetTheme.accentOrange
    var height: CGFloat = 6

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                ZStack(alignment: .leading) {
                    if i < filled {
                        Rectangle().fill(color)
                    } else if i == filled {
                        Rectangle().stroke(color, lineWidth: 1)
                        GeometryReader { geo in
                            Rectangle()
                                .fill(accent)
                                .frame(width: geo.size.width * currentPct)
                        }
                    } else {
                        Rectangle().stroke(color, lineWidth: 1)
                    }
                }
                .frame(height: height)
            }
        }
    }
}

// MARK: - RankLadder
/// 5-segment rank ladder with labels below (for Progress Large).
struct RankLadder: View {
    let rankIndex: Int
    let progress: CGFloat
    var height: CGFloat = 16
    var localizedNames: [String]? = nil

    private var names: [String] { localizedNames ?? WidgetRanks.names }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                ForEach(0..<names.count, id: \.self) { i in
                    ZStack(alignment: .leading) {
                        if i < rankIndex {
                            Rectangle().fill(WidgetTheme.sageInk)
                        } else if i == rankIndex {
                            Rectangle().stroke(WidgetTheme.sageInk, lineWidth: 1)
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(WidgetTheme.accentOrange)
                                    .frame(width: geo.size.width * progress)
                            }
                        } else {
                            Rectangle().stroke(WidgetTheme.sageInk, lineWidth: 1)
                        }
                    }
                    .frame(height: height)
                }
            }
            HStack(spacing: 3) {
                ForEach(0..<names.count, id: \.self) { i in
                    Text(names[i])
                        .font(WidgetTheme.mono(7, weight: i == rankIndex ? .heavy : .bold))
                        .tracking(1.3)
                        .foregroundStyle(
                            i == rankIndex ? WidgetTheme.accentOrange
                            : i < rankIndex ? WidgetTheme.sageInk
                            : WidgetTheme.sageInk.opacity(0.2)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - SectorStrip
/// 8-segment sector completion strip. Completed = dark, current = orange, future = outline.
struct SectorStrip: View {
    var totalSectors: Int = 8
    var completedSectors: Int = 2
    var height: CGFloat = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<totalSectors, id: \.self) { i in
                if i < completedSectors {
                    Rectangle().fill(WidgetTheme.sageInk)
                } else if i == completedSectors {
                    Rectangle().fill(WidgetTheme.accentOrange)
                } else {
                    Rectangle().stroke(WidgetTheme.sageInk, lineWidth: 1)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - DashedBar
/// Segmented efficiency bar for Planet Pass credential widgets.
struct DashedBar: View {
    var pct: Int = 99
    var accent: Color = WidgetTheme.accentOrange
    var totalSegments: Int = 14
    var height: CGFloat = 3

    var body: some View {
        let filled = Int((Float(pct) / 100.0) * Float(totalSegments) + 0.5)
        HStack(spacing: 3) {
            ForEach(0..<totalSegments, id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? accent : Color.white.opacity(0.15))
            }
        }
        .frame(height: height)
    }
}

// MARK: - WidgetRanks
/// Rank name constants and lookup helpers.
enum WidgetRanks {
    static let names = ["CADET", "PILOT", "NAVIGATOR", "COMMANDER", "ADMIRAL"]

    static func index(for rankTitle: String) -> Int {
        names.firstIndex(of: rankTitle.uppercased()) ?? 0
    }

    static func nextRank(after rankTitle: String) -> String {
        let idx = index(for: rankTitle)
        return idx < names.count - 1 ? names[idx + 1] : names.last!
    }

    static let planetOrder = ["EARTH ORBIT", "MOON", "MARS", "ASTEROID BELT", "JUPITER", "SATURN", "NEPTUNE", "DEEP SPACE"]

    static func sectorIndex(for planetName: String) -> Int {
        planetOrder.firstIndex(of: planetName.uppercased()) ?? 0
    }
}

// MARK: - PlanetInfo
/// Planet metadata for credential cards.
enum PlanetInfo {
    struct Info {
        let category: String
        let difficulty: String
        let level: Int
    }

    static func info(for planetIndex: Int) -> Info {
        switch planetIndex {
        case 0:  return Info(category: "TRAINING ZONE",       difficulty: "EASY",   level: 6)
        case 1:  return Info(category: "LUNAR OPERATIONS",    difficulty: "EASY",   level: 8)
        case 2:  return Info(category: "RED PLANET OPS",      difficulty: "MEDIUM", level: 10)
        case 3:  return Info(category: "ASTEROID FIELD",      difficulty: "MEDIUM", level: 11)
        case 4:  return Info(category: "GAS GIANT RELAY",     difficulty: "HARD",   level: 12)
        case 5:  return Info(category: "RING SYSTEM TRANSIT", difficulty: "HARD",   level: 13)
        case 6:  return Info(category: "ICE GIANT PATROL",    difficulty: "EXPERT", level: 14)
        case 7:  return Info(category: "DEEP VOID",           difficulty: "EXPERT", level: 15)
        default: return Info(category: "UNKNOWN SECTOR",      difficulty: "\u{2014}",      level: 0)
        }
    }
}

// MARK: - PassFooterCell
/// 4-column footer cell for Planet Pass Large widget.
struct PassFooterCell: View {
    let label: String
    let value: String
    var accent: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WidgetTheme.mono(5.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(WidgetTheme.mono(10, weight: .heavy))
                .tracking(0.3)
                .foregroundStyle(accent ?? .white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - PassFooterMini
/// Compact inline footer stat for Planet Pass Medium widget.
struct PassFooterMini: View {
    let label: String
    let value: String
    var accent: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(WidgetTheme.mono(5.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(WidgetTheme.mono(8, weight: .heavy))
                .foregroundStyle(accent ?? .white)
        }
    }
}

// MARK: - ProgressBarView
/// Thin horizontal progress bar.
struct ProgressBarView: View {
    let progress: Float
    var height: CGFloat = 4
    var trackColor: Color = WidgetTheme.sageInk.opacity(0.12)
    var fillColor: Color = WidgetTheme.accentOrange

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

// MARK: - LeaderboardBarChart
/// Vertical bar chart for leaderboard widgets.
struct LeaderboardBarChart: View {
    let entries: [LeaderboardEntrySnapshot]
    var showNames: Bool = false
    var maxBarHeight: CGFloat = 80

    var body: some View {
        let items = Array(entries.prefix(5))
        let maxScore = items.map(\.score).max() ?? 1

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(items) { entry in
                    let h = max(4, CGFloat(entry.score) / CGFloat(maxScore) * maxBarHeight)
                    VStack(spacing: 3) {
                        Text(WidgetTheme.shortScore(entry.score))
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(entry.isLocalPlayer ? WidgetTheme.accentOrange : WidgetTheme.sageMid)
                        Rectangle()
                            .fill(entry.isLocalPlayer ? WidgetTheme.accentOrange : WidgetTheme.sageInk)
                            .frame(height: h)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Rectangle()
                .fill(WidgetTheme.sageInk)
                .frame(height: 1)

            HStack(spacing: 6) {
                ForEach(items) { entry in
                    Text(showNames
                         ? entry.displayName.replacingOccurrences(of: "_", with: "\u{00B7}")
                         : "#\(entry.rank)")
                        .font(WidgetTheme.mono(6.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(entry.isLocalPlayer ? WidgetTheme.accentOrange : WidgetTheme.sageMid)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - WidgetEmptyState
/// Placeholder shown when no data is available.
struct WidgetEmptyState: View {
    let icon: String
    let message: String
    var darkBackground: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(darkBackground ? WidgetTheme.textSecondary.opacity(0.6) : WidgetTheme.sageMid)
            Text(message)
                .font(WidgetTheme.mono(8, weight: .semibold))
                .tracking(1)
                .foregroundStyle(darkBackground ? WidgetTheme.textSecondary : WidgetTheme.sageInk.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview Snapshot
/// Sample data for widget previews and placeholder states.
enum PreviewSnapshots {

    static let sample = WidgetDataSnapshot(
        playerLevel: 5,
        rankTitle: "NAVIGATOR",
        completedMissions: 50,
        totalMissions: 180,
        averageEfficiencyPercent: 93,
        leaderboardScore: 142850,
        currentPlanetName: "MARS",
        currentSectorName: "SECTOR 3",
        levelProgress: 0.42,
        missionsRemaining: 8,
        isPremium: true,
        leaderboardEntries: [
            LeaderboardEntrySnapshot(rank: 1, displayName: "CMD_ARIA", score: 184290, isLocalPlayer: false),
            LeaderboardEntrySnapshot(rank: 2, displayName: "NAV_KAI", score: 176040, isLocalPlayer: false),
            LeaderboardEntrySnapshot(rank: 3, displayName: "You", score: 142850, isLocalPlayer: true),
            LeaderboardEntrySnapshot(rank: 4, displayName: "PLT_REESE", score: 138220, isLocalPlayer: false),
            LeaderboardEntrySnapshot(rank: 5, displayName: "CDT_NOVA", score: 129680, isLocalPlayer: false),
        ],
        playerRank: 3,
        totalPlayers: 350,
        passes: [
            PassSnapshot(id: UUID(), planetName: "EARTH ORBIT", planetIndex: 0, efficiencyPercent: 83, serialCode: "SR-0031-EAR", missionCount: 31, timestamp: Date().addingTimeInterval(-86400 * 45), planetColorHex: "4ADE80"),
            PassSnapshot(id: UUID(), planetName: "MARS", planetIndex: 2, efficiencyPercent: 99, serialCode: "SR-0071-MAR", missionCount: 71, timestamp: Date().addingTimeInterval(-86400 * 20), planetColorHex: "E8542E"),
            PassSnapshot(id: UUID(), planetName: "JUPITER", planetIndex: 4, efficiencyPercent: 99, serialCode: "SR-0111-JUP", missionCount: 111, timestamp: Date().addingTimeInterval(-86400 * 5), planetColorHex: "E8B24A"),
        ],
        streak: 12,
        weeklyRankChange: 240,
        language: "en",
        updatedAt: Date()
    )
}
