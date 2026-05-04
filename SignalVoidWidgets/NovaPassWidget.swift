import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct NovaPassWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Nova Pass Collection"
    static var description: IntentDescription = "Showcase your earned planet passes."
}

// MARK: - Entry

struct NovaPassEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
}

// MARK: - Provider

struct NovaPassProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> NovaPassEntry {
        NovaPassEntry(date: .now, snapshot: PreviewSnapshots.sample)
    }

    func snapshot(for configuration: NovaPassWidgetIntent, in context: Context) async -> NovaPassEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return NovaPassEntry(date: .now, snapshot: data)
    }

    func timeline(for configuration: NovaPassWidgetIntent, in context: Context) async -> Timeline<NovaPassEntry> {
        let data = WidgetDataBridge.read()
        let entry = NovaPassEntry(date: .now, snapshot: data)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct NovaPassWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.novapass"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NovaPassWidgetIntent.self, provider: NovaPassProvider()) { entry in
            NovaPassWidgetView(entry: entry)
                .containerBackground(WidgetTheme.backgroundDark, for: .widget)
        }
        .configurationDisplayName("Nova Pass Collection")
        .description("Showcase your earned sector clearance passes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct NovaPassWidgetView: View {
    let entry: NovaPassEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    var body: some View {
        if let snap = entry.snapshot {
            if snap.isPremium {
                switch family {
                case .systemSmall:  NovaPassSmall(snap: snap)
                case .systemMedium: NovaPassMedium(snap: snap)
                case .systemLarge:  NovaPassLarge(snap: snap)
                default:            NovaPassSmall(snap: snap)
                }
            } else {
                PremiumLockedView(widgetName: S.novaPass, darkBackground: true)
                    .widgetURL(URL(string: "signalvoid://paywall"))
            }
        } else {
            WidgetEmptyState(icon: "ticket", message: S.earnPass, darkBackground: true)
        }
    }
}

// MARK: - Small
// Credential face: HUGE earned count, 10 planet dots, clear status.

private struct NovaPassSmall: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var earnedCount: Int { snap.passes.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: label + status
            HStack {
                Text(S.novaPass)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text(S.earned)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)
            }

            Spacer(minLength: 0)

            // HERO: earned count
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%02d", earnedCount))
                    .font(WidgetTheme.sans(56, weight: .heavy))
                    .tracking(-3)
                    .foregroundStyle(WidgetTheme.accentOrange)
                    .lineLimit(1)
                Text("/10")
                    .font(WidgetTheme.sans(20, weight: .bold))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }

            Spacer(minLength: 6)

            // 10 planet dots — earned = planet color, locked = dim outline
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    let isEarned = snap.passes.contains(where: { $0.planetIndex == i })
                    Circle()
                        .fill(isEarned ? PlanetColors.color(for: i) : Color.white.opacity(0.08))
                        .frame(width: 10, height: 10)
                        .overlay(
                            isEarned ? nil : Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "signalvoid://pass/0"))
    }
}

// MARK: - Medium
// Left: big count + planet dots. Right: credential cards with serial codes.

private struct NovaPassMedium: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var earnedCount: Int { snap.passes.count }
    private var displayPasses: [PassSnapshot] { Array(snap.passes.prefix(4)) }

    var body: some View {
        HStack(spacing: 0) {
            // Left: hero count
            VStack(alignment: .leading, spacing: 0) {
                Text(S.novaPass)
                    .font(WidgetTheme.mono(6, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.accentOrange)

                Spacer(minLength: 2)

                Text(String(format: "%02d", earnedCount))
                    .font(WidgetTheme.sans(44, weight: .heavy))
                    .tracking(-2)
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                Text("/10 \(S.earned)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.onDarkSub)

                Spacer(minLength: 0)

                // 10 planet dots
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { i in
                        let isEarned = snap.passes.contains(where: { $0.planetIndex == i })
                        Circle()
                            .fill(isEarned ? PlanetColors.color(for: i) : Color.white.opacity(0.08))
                            .frame(width: 8, height: 8)
                            .overlay(
                                isEarned ? nil : Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                }
            }
            .frame(width: 100)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 4)

            // Right: credential cards
            VStack(spacing: 3) {
                ForEach(displayPasses) { pass in
                    CredentialRow(pass: pass, snap: snap)
                }
                if snap.passes.count > 4 {
                    Text(S.more(snap.passes.count - 4))
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.onDarkSub)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.leading, 10)
            .frame(maxWidth: .infinity)
        }
        .widgetURL(URL(string: "signalvoid://pass/0"))
    }
}

/// Compact credential row with serial code for medium widget.
private struct CredentialRow: View {
    let pass: PassSnapshot
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var planetColor: Color { Color(hex: pass.planetColorHex) }

    var body: some View {
        HStack(spacing: 0) {
            // Color strip
            RoundedRectangle(cornerRadius: 1)
                .fill(planetColor)
                .frame(width: 3)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(S.planetName(pass.planetName).uppercased())
                        .font(WidgetTheme.mono(7, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(pass.serialCode)
                        .font(WidgetTheme.mono(5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                Spacer(minLength: 4)
                Text("\(pass.efficiencyPercent)%")
                    .font(WidgetTheme.mono(9, weight: .heavy))
                    .foregroundStyle(WidgetTheme.efficiencyColor(pass.efficiencyPercent))
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 5)
        .background(WidgetTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Large
// Full credential gallery: header, 2×5 grid, footer stats, time.

private struct NovaPassLarge: View {
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }

    private var earnedCount: Int { snap.passes.count }
    private var planetSlots: [(index: Int, pass: PassSnapshot?)] {
        (0..<10).map { i in (i, snap.passes.first(where: { $0.planetIndex == i })) }
    }
    private var totalMissions: Int { snap.passes.reduce(0) { $0 + $1.missionCount } }
    private var bestEfficiency: Int { snap.passes.map(\.efficiencyPercent).max() ?? 0 }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: snap.updatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("\u{2B21} \(S.novaPassCollection)")
                    .font(WidgetTheme.mono(7, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.onDarkSub)
                Spacer()
                Text("\(earnedCount)/10")
                    .font(WidgetTheme.mono(10, weight: .heavy))
                    .foregroundStyle(WidgetTheme.accentOrange)
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

            // 2×5 credential grid
            let rows = [Array(planetSlots.prefix(5)), Array(planetSlots.suffix(5))]
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 5) {
                    ForEach(rows[rowIdx], id: \.index) { slot in
                        CredentialCard(
                            planetIndex: slot.index,
                            pass: slot.pass,
                            snap: snap
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            // Footer: stats + time
            HStack {
                HStack(spacing: 4) {
                    Text(S.missions)
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.onDarkSub)
                    Text("\(totalMissions)")
                        .font(WidgetTheme.mono(10, weight: .heavy))
                        .foregroundStyle(WidgetTheme.sage)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(S.bestEff)
                        .font(WidgetTheme.mono(6, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.onDarkSub)
                    Text("\(bestEfficiency)%")
                        .font(WidgetTheme.mono(10, weight: .heavy))
                        .foregroundStyle(WidgetTheme.efficiencyColor(bestEfficiency))
                }
                Spacer()
                Text(timeString)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .widgetURL(URL(string: "signalvoid://pass/0"))
    }
}

/// Credential card for the 2×5 grid — earned shows full data, locked shows dim state.
private struct CredentialCard: View {
    let planetIndex: Int
    let pass: PassSnapshot?
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var planetColor: Color { PlanetColors.color(for: planetIndex) }
    private var isEarned: Bool { pass != nil }
    private var planetName: String {
        WidgetRanks.planetOrder.indices.contains(planetIndex)
            ? WidgetRanks.planetOrder[planetIndex]
            : "UNKNOWN"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Color strip
            RoundedRectangle(cornerRadius: 1)
                .fill(isEarned ? planetColor : planetColor.opacity(0.15))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(S.planetName(planetName).uppercased())
                    .font(WidgetTheme.mono(6, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isEarned ? WidgetTheme.textPrimary : WidgetTheme.textSecondary.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)

                if let p = pass {
                    Text(p.serialCode)
                        .font(WidgetTheme.mono(5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.2))
                    Text("\(p.efficiencyPercent)%")
                        .font(WidgetTheme.mono(9, weight: .heavy))
                        .foregroundStyle(WidgetTheme.efficiencyColor(p.efficiencyPercent))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.15))
                        .padding(.top, 1)
                }
            }
            .padding(.leading, 5)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isEarned ? WidgetTheme.surface : WidgetTheme.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Previews

#Preview("Nova Pass Small", as: .systemSmall) {
    NovaPassWidget()
} timeline: {
    NovaPassEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Nova Pass Medium", as: .systemMedium) {
    NovaPassWidget()
} timeline: {
    NovaPassEntry(date: .now, snapshot: PreviewSnapshots.sample)
}

#Preview("Nova Pass Large", as: .systemLarge) {
    NovaPassWidget()
} timeline: {
    NovaPassEntry(date: .now, snapshot: PreviewSnapshots.sample)
}
