import WidgetKit
import SwiftUI
import AppIntents

// MARK: - PassPickerEntity

struct PassPickerEntity: AppEntity {
    let id: String
    let planetName: String
    let planetIndex: Int

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Planet Pass")
    static var defaultQuery = PassPickerQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(planetName)")
    }
}

// MARK: - PassPickerQuery

struct PassPickerQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PassPickerEntity] {
        let snap = WidgetDataBridge.read()
        return (snap?.passes ?? []).filter { identifiers.contains($0.id.uuidString) }.map {
            PassPickerEntity(id: $0.id.uuidString, planetName: $0.planetName, planetIndex: $0.planetIndex)
        }
    }

    func suggestedEntities() async throws -> [PassPickerEntity] {
        let snap = WidgetDataBridge.read()
        return (snap?.passes ?? []).map {
            PassPickerEntity(id: $0.id.uuidString, planetName: $0.planetName, planetIndex: $0.planetIndex)
        }
    }

    func defaultResult() async -> PassPickerEntity? {
        // Return nil so the widget defaults to showing the current planet
        // (synced with the app). Users can still pick a specific pass via config.
        nil
    }
}

// MARK: - Intent

struct PlanetPassWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Planet Pass"
    static var description: IntentDescription = "Choose which planet pass to display."

    @Parameter(title: "Pass")
    var pass: PassPickerEntity?
}

// MARK: - Entry

struct PlanetPassEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot?
    let selectedPassID: String?
}

// MARK: - Provider

struct PlanetPassProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> PlanetPassEntry {
        PlanetPassEntry(date: .now, snapshot: PreviewSnapshots.sample, selectedPassID: nil)
    }

    func snapshot(for configuration: PlanetPassWidgetIntent, in context: Context) async -> PlanetPassEntry {
        let data = WidgetDataBridge.read() ?? PreviewSnapshots.sample
        return PlanetPassEntry(date: .now, snapshot: data, selectedPassID: configuration.pass?.id)
    }

    func timeline(for configuration: PlanetPassWidgetIntent, in context: Context) async -> Timeline<PlanetPassEntry> {
        let data = WidgetDataBridge.read()
        let entry = PlanetPassEntry(date: .now, snapshot: data, selectedPassID: configuration.pass?.id)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Widget

struct PlanetPassWidget: Widget {
    let kind = "com.marcosnovo.signalvoidgame.widget.planetpass"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PlanetPassWidgetIntent.self, provider: PlanetPassProvider()) { entry in
            PlanetPassWidgetView(entry: entry)
                .containerBackground(WidgetTheme.backgroundDark, for: .widget)
        }
        .configurationDisplayName("Planet Pass")
        .description("Display your earned sector clearance pass.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct PlanetPassWidgetView: View {
    let entry: PlanetPassEntry
    @Environment(\.widgetFamily) var family
    private var S: WidgetStrings { WidgetStrings(language: entry.snapshot?.language) }

    /// Explicit user selection via intent. Returns nil when no intent is set.
    private var intentSelectedPass: PassSnapshot? {
        guard let snap = entry.snapshot,
              let id = entry.selectedPassID,
              let match = snap.passes.first(where: { $0.id.uuidString == id }) else { return nil }
        return match
    }

    /// Current planet pass — matches what the app shows on the home screen.
    /// Prefers the earned pass if one exists for the current planet,
    /// otherwise synthesises an in-progress pass from profile data.
    private var currentPlanetPass: PassSnapshot? {
        guard let snap = entry.snapshot else { return nil }
        let idx = WidgetRanks.sectorIndex(for: snap.currentPlanetName)
        // Use earned pass if available (same data the app's PlanetTicketView shows)
        if let earned = snap.passes.first(where: { $0.planetIndex == idx }) {
            return earned
        }
        // Synthesise in-progress pass
        let code = String(snap.currentPlanetName.prefix(3)).uppercased()
        return PassSnapshot(
            id: UUID(),
            planetName: snap.currentPlanetName,
            planetIndex: idx,
            efficiencyPercent: snap.averageEfficiencyPercent,
            serialCode: "SR-\(String(format: "%04d", snap.completedMissions))-\(code)",
            missionCount: snap.completedMissions,
            timestamp: snap.updatedAt,
            planetColorHex: PlanetColors.hexByIndex[idx] ?? "FF6A3D"
        )
    }

    /// Intent selection takes priority; otherwise default to current planet (app sync).
    private var displayPass: PassSnapshot? {
        intentSelectedPass ?? currentPlanetPass
    }

    /// True when showing the current planet (not yet earned as a pass).
    private var isInProgress: Bool {
        guard let snap = entry.snapshot, let pass = displayPass else { return false }
        return !snap.passes.contains(where: { $0.id == pass.id })
    }

    var body: some View {
        if let pass = displayPass, let snap = entry.snapshot {
            switch family {
            case .systemSmall:  PassSmall(pass: pass, snap: snap)
            case .systemMedium: PassMedium(pass: pass, snap: snap, inProgress: isInProgress)
            case .systemLarge:  PassLarge(pass: pass, snap: snap, inProgress: isInProgress)
            default:            PassSmall(pass: pass, snap: snap)
            }
        } else {
            WidgetEmptyState(icon: "ticket", message: S.earnPass, darkBackground: true)
        }
    }
}

// MARK: - Small (compact — accent stripe + branding + planet name)

private struct PassSmall: View {
    let pass: PassSnapshot
    let snap: WidgetDataSnapshot
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var planetColor: Color { Color(hex: pass.planetColorHex) }

    var body: some View {
        HStack(spacing: 0) {
            // Left vertical accent stripe
            Rectangle()
                .fill(planetColor)
                .frame(width: 6)
                .padding(.vertical, -20)
                .padding(.leading, -20)

            VStack(alignment: .leading, spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SIGNAL VOID")
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(pass.serialCode)
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(S.planetPass)
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(S.difficulty(for: pass.planetIndex))
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                Spacer(minLength: 4)

                // Category subtitle
                Text(S.category(for: pass.planetIndex))
                    .font(WidgetTheme.mono(6.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(planetColor)
                    .padding(.bottom, 4)

                // Huge planet name
                let localName = S.planetName(pass.planetName)
                Text(localName.uppercased())
                    .font(WidgetTheme.sans(localName.count > 7 ? 26 : 34, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
        }
        .widgetURL(URL(string: "signalvoid://pass/\(pass.planetIndex)"))
    }
}

// MARK: - Medium (wide — planet left, efficiency right, bottom strip)

private struct PassMedium: View {
    let pass: PassSnapshot
    let snap: WidgetDataSnapshot
    var inProgress: Bool = false
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var planetColor: Color { Color(hex: pass.planetColorHex) }

    var body: some View {
        HStack(spacing: 0) {
            // Left vertical accent stripe
            Rectangle()
                .fill(planetColor)
                .frame(width: 6)
                .padding(.vertical, -20)
                .padding(.leading, -20)

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SIGNAL VOID")
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(pass.serialCode)
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(S.planetPass)
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(S.difficulty(for: pass.planetIndex))
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                Spacer(minLength: 4)

                // Body — planet name left, stats right
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(S.category(for: pass.planetIndex))
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(planetColor)
                            .padding(.bottom, 3)

                        let localName = S.planetName(pass.planetName)
                        Text(localName.uppercased())
                            .font(WidgetTheme.sans(32, weight: .heavy))
                            .tracking(-1.5)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text(S.accessAuthorized)
                            .font(WidgetTheme.mono(5.5, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Color.white.opacity(0.35))
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 8)

                    // Efficiency
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(S.missionEfficiency)
                            .font(WidgetTheme.mono(5.5, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.4))

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(pass.efficiencyPercent)")
                                .font(WidgetTheme.sans(36, weight: .heavy))
                                .tracking(-1)
                                .foregroundStyle(.white)
                            Text("%")
                                .font(WidgetTheme.sans(18, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 1)

                        DashedBar(pct: pass.efficiencyPercent, accent: planetColor)
                            .frame(width: 90)
                            .padding(.top, 3)
                    }
                }

                Spacer(minLength: 2)

                // Bottom strip — bleed to edges
                HStack(alignment: .center) {
                    Text(pass.serialCode)
                        .font(WidgetTheme.mono(7, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 14) {
                        PassFooterMini(label: "LVL", value: "\(PlanetInfo.info(for: pass.planetIndex).level)")
                        PassFooterMini(label: "MSN", value: String(format: "%04d", pass.missionCount))
                        PassFooterMini(label: "RNK", value: String((snap.rankTitle).prefix(3)))
                        PassFooterMini(label: "STS", value: inProgress ? S.activeShort : S.clearedShort, accent: planetColor)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(Color.black.opacity(0.6))
                .overlay(
                    Rectangle()
                        .fill(planetColor.opacity(0.25))
                        .frame(height: 1),
                    alignment: .top
                )
                .padding(.horizontal, -16)
                .padding(.bottom, -16)
            }
            .padding(.leading, 14)
        }
        .widgetURL(URL(string: "signalvoid://pass/\(pass.planetIndex)"))
    }
}

// MARK: - Large (full credential — efficiency, footer, bottom strip)

private struct PassLarge: View {
    let pass: PassSnapshot
    let snap: WidgetDataSnapshot
    var inProgress: Bool = false
    private var S: WidgetStrings { WidgetStrings(language: snap.language) }
    private var planetColor: Color { Color(hex: pass.planetColorHex) }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy"
        fmt.locale = Locale(identifier: snap.language ?? "en")
        return fmt.string(from: pass.timestamp).uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left vertical accent stripe
            Rectangle()
                .fill(planetColor)
                .frame(width: 6)
                .padding(.vertical, -20)
                .padding(.leading, -20)

            VStack(alignment: .leading, spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SIGNAL VOID")
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(pass.serialCode)
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(S.planetPass)
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.3)
                            .foregroundStyle(planetColor)
                        Text(S.difficulty(for: pass.planetIndex))
                            .font(WidgetTheme.mono(6, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                Spacer(minLength: 8)

                // Category subtitle
                Text(S.category(for: pass.planetIndex))
                    .font(WidgetTheme.mono(6.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(planetColor)
                    .padding(.bottom, 4)

                // Huge planet name
                let localName = S.planetName(pass.planetName)
                Text(localName.uppercased())
                    .font(WidgetTheme.sans(localName.count > 7 ? 44 : 56, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                // ACCESS AUTHORIZED
                Text(S.accessAuthorized)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(.top, 8)

                // MISSION EFFICIENCY
                Text(S.missionEfficiency)
                    .font(WidgetTheme.mono(6, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(.top, 6)

                // Big efficiency %
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(pass.efficiencyPercent)")
                        .font(WidgetTheme.sans(52, weight: .heavy))
                        .tracking(-1)
                        .foregroundStyle(.white)
                    Text("%")
                        .font(WidgetTheme.sans(28, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.top, 2)

                // Dashed efficiency bar
                DashedBar(pct: pass.efficiencyPercent, accent: planetColor)
                    .padding(.top, 6)

                Spacer(minLength: 8)

                // 4-col footer
                HStack(spacing: 4) {
                    PassFooterCell(label: S.level, value: "\(PlanetInfo.info(for: pass.planetIndex).level)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PassFooterCell(label: S.missions, value: String(format: "%04d", pass.missionCount))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PassFooterCell(label: S.rank, value: String(snap.rankTitle.prefix(7)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PassFooterCell(label: S.status, value: inProgress ? S.active : S.cleared, accent: planetColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 6)

                // Bottom dark strip
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pass.serialCode)
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Text(dateString)
                            .font(WidgetTheme.mono(5.5, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    Text(S.planetName(pass.planetName).uppercased())
                        .font(WidgetTheme.mono(6, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(planetColor.opacity(0.5))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.6))
                .overlay(
                    Rectangle()
                        .fill(planetColor.opacity(0.25))
                        .frame(height: 1),
                    alignment: .top
                )
                .padding(.horizontal, -16)
                .padding(.bottom, -16)
            }
            .padding(.leading, 12)
        }
        .widgetURL(URL(string: "signalvoid://pass/\(pass.planetIndex)"))
    }
}

// MARK: - Previews

#Preview("Planet Pass Small", as: .systemSmall) {
    PlanetPassWidget()
} timeline: {
    PlanetPassEntry(date: .now, snapshot: PreviewSnapshots.sample, selectedPassID: nil)
}

#Preview("Planet Pass Medium", as: .systemMedium) {
    PlanetPassWidget()
} timeline: {
    PlanetPassEntry(date: .now, snapshot: PreviewSnapshots.sample, selectedPassID: nil)
}

#Preview("Planet Pass Large", as: .systemLarge) {
    PlanetPassWidget()
} timeline: {
    PlanetPassEntry(date: .now, snapshot: PreviewSnapshots.sample, selectedPassID: nil)
}
