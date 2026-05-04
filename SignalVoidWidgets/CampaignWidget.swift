import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct CampaignWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Campaign Overview"
    static var description: IntentDescription = "Track your campaign completion progress."
}

// MARK: - Entry

struct CampaignEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
}

// MARK: - Provider

struct CampaignProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> CampaignEntry {
        CampaignEntry(date: .now, snapshot: PreviewSnapshots.sample)
    }

    func snapshot(for configuration: CampaignWidgetIntent, in context: Context) async -> CampaignEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return CampaignEntry(date: .now, snapshot: data)
    }

    func timeline(for configuration: CampaignWidgetIntent, in context: Context) async -> Timeline<CampaignEntry> {
        let data = WidgetDataBridge.read()
        let entry = CampaignEntry(date: .now, snapshot: data)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct CampaignWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.campaign"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CampaignWidgetIntent.self, provider: CampaignProvider()) { entry in
            CampaignWidgetView(entry: entry)
                .containerBackground(WidgetTheme.sage, for: .widget)
        }
        .configurationDisplayName("Campaign Overview")
        .description("Track your mission completion and sector progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct CampaignWidgetView: View {
    let entry: CampaignEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot {
            if snap.isPremium {
                switch family {
                case .systemSmall:  CampaignSmall(snap: snap)
                case .systemMedium: CampaignMedium(snap: snap)
                case .systemLarge:  CampaignLarge(snap: snap)
                default:            CampaignSmall(snap: snap)
                }
            } else {
                PremiumLockedView(widgetName: S.campaign, darkBackground: false)
                    .widgetURL(URL(string: "signalvoid://paywall"))
            }
        } else {
            WidgetEmptyState(icon: "map", message: S.playMission)
        }
    }
}

// MARK: - Small
// Watch-face: giant %, mission count, 10-segment sector strip at bottom.

private struct CampaignSmall: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: campaign label + sector
            HStack {
                Text(S.campaign)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                Text("\(snap.completedMissions)/\(snap.totalMissions)")
                    .font(WidgetTheme.mono(7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.sageMid)
            }

            Spacer(minLength: 0)

            // HERO: giant percentage
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(snap.completionPercent)")
                    .font(WidgetTheme.sans(56, weight: .heavy))
                    .tracking(-3)
                    .foregroundStyle(WidgetTheme.sageInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("%")
                    .font(WidgetTheme.sans(20, weight: .bold))
                    .foregroundStyle(WidgetTheme.sageInk.opacity(0.5))
            }

            Spacer(minLength: 6)

            // 10-segment sector strip (more distinctive than 5-segment rail)
            SectorStrip(totalSectors: 10, completedSectors: sectorIdx)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://missions"))
    }
}

// MARK: - Medium
// Left dark card: planet + missions remaining. Right sage: big %, sector strip, rank.

private struct CampaignMedium: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    var body: some View {
        HStack(spacing: 0) {
            // Dark left block — planet + progress
            VStack(alignment: .leading, spacing: 0) {
                Text("S\u{00B7}\(sectorIdx + 1)")
                    .font(WidgetTheme.mono(8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.accentOrange)

                Spacer(minLength: 2)

                // Completed hero
                Text("\(snap.completedMissions)")
                    .font(WidgetTheme.sans(36, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                Text("/\(snap.totalMissions) \(S.missions)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)

                Spacer(minLength: 4)

                // Planet name
                Text(S.planetName(snap.currentPlanetName).uppercased())
                    .font(WidgetTheme.mono(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.sage.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(14)
            .frame(width: 130)
            .frame(maxHeight: .infinity)
            .background(WidgetTheme.backgroundDark)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, -20)
            .padding(.vertical, -20)

            // Sage right panel
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(S.campaign)
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.sageMid)
                    Spacer()
                }

                Spacer(minLength: 0)

                // Hero %
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(snap.completionPercent)")
                        .font(WidgetTheme.sans(36, weight: .heavy))
                        .tracking(-2)
                        .foregroundStyle(WidgetTheme.sageInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("%")
                        .font(WidgetTheme.sans(14, weight: .bold))
                        .foregroundStyle(WidgetTheme.sageInk.opacity(0.5))
                }

                // Sector strip
                SectorStrip(totalSectors: 10, completedSectors: sectorIdx)
                    .padding(.top, 8)

                Spacer(minLength: 4)

                // Rank label
                Text(S.rankName(snap.rankTitle))
                    .font(WidgetTheme.mono(8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.sageMid)
            }
            .padding(.leading, 14)
            .padding(.trailing, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "signalvoid://missions"))
    }
}

// MARK: - Large
// Full overview: big %, rank badge, 10-sector strip, sector detail, dark KPI footer.

private struct CampaignLarge: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var rankIdx: Int { WidgetRanks.index(for: snap.rankTitle) }
    private var sectorIdx: Int { WidgetRanks.sectorIndex(for: snap.currentPlanetName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("\u{25C8} \(S.campaignOverview)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.sageMid)
                Spacer()
                Text("SV")
                    .font(WidgetTheme.mono(10, weight: .heavy))
                    .foregroundStyle(WidgetTheme.sageInk)
            }

            Rectangle().fill(WidgetTheme.sageInk.opacity(0.13)).frame(height: 0.5)

            // Top: giant % + rank badge
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(snap.completionPercent)")
                        .font(WidgetTheme.sans(72, weight: .heavy))
                        .tracking(-4)
                        .foregroundStyle(WidgetTheme.sageInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("%")
                        .font(WidgetTheme.sans(24, weight: .bold))
                        .foregroundStyle(WidgetTheme.sageInk.opacity(0.4))
                }
                Spacer()
                RankBadge(title: S.rankName(snap.rankTitle), level: snap.playerLevel)
            }

            // 10-segment sector strip + label
            VStack(alignment: .leading, spacing: 4) {
                SectorStrip(totalSectors: 10, completedSectors: sectorIdx)
                HStack {
                    Text(S.sectorCompletion)
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(WidgetTheme.sageMid)
                    Spacer()
                    Text("\(sectorIdx + 1)/10")
                        .font(WidgetTheme.mono(8, weight: .heavy))
                        .foregroundStyle(WidgetTheme.sageInk)
                }
            }

            // Current sector detail
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(S.planetName(snap.currentPlanetName).uppercased())
                        .font(WidgetTheme.mono(9, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.sageInk)
                    Text(S.category(for: sectorIdx))
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.sageMid)
                }
                Spacer()
                Text(S.difficulty(for: sectorIdx))
                    .font(WidgetTheme.mono(7, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.accentOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetTheme.accentOrange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer(minLength: 0)

            // Dark footer
            HStack(spacing: 0) {
                DarkDataCell(label: S.completed, value: "\(snap.completedMissions)")
                DarkDataCell(label: S.remaining, value: "\(snap.missionsRemaining)")
                DarkDataCell(label: S.avgEff, value: "\(snap.averageEfficiencyPercent)%", highlight: true)
            }
            .background(WidgetTheme.backgroundDark)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .widgetURL(URL(string: "signalvoid://missions"))
    }
}

// MARK: - Previews

#Preview("Campaign Small", as: .systemSmall) {
    CampaignWidget()
} timeline: {
    CampaignEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Campaign Medium", as: .systemMedium) {
    CampaignWidget()
} timeline: {
    CampaignEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Campaign Large", as: .systemLarge) {
    CampaignWidget()
} timeline: {
    CampaignEntry(date: .now, snapshot: PreviewSnapshots.sample)
}
