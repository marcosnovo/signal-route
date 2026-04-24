import Foundation
import SwiftUI

// MARK: - WidgetDataSnapshot
/// Atomic data packet written by the main app and read by the widget extension.
/// All widget data is captured in a single Codable struct to avoid partial reads.
struct WidgetDataSnapshot: Codable {

    // ── Progress & Rank ──────────────────────────────────────────────────
    let playerLevel: Int
    let rankTitle: String
    let completedMissions: Int
    let totalMissions: Int
    let averageEfficiencyPercent: Int
    let leaderboardScore: Int
    let currentPlanetName: String
    let currentSectorName: String
    let levelProgress: Float
    let missionsRemaining: Int
    let isPremium: Bool

    // ── Leaderboard ──────────────────────────────────────────────────────
    let leaderboardEntries: [LeaderboardEntrySnapshot]
    let playerRank: Int?
    let totalPlayers: Int?

    // ── Planet Passes ────────────────────────────────────────────────────
    let passes: [PassSnapshot]

    // ── Leaderboard extras (nil until tracked) ──────────────────────────
    let streak: Int?
    let weeklyRankChange: Int?

    // ── Metadata ─────────────────────────────────────────────────────────
    let language: String?
    let updatedAt: Date

    // MARK: - Derived

    var completionPercent: Int {
        guard totalMissions > 0 else { return 0 }
        return Int((Float(completedMissions) / Float(totalMissions) * 100).rounded())
    }
}

// MARK: - LeaderboardEntrySnapshot

struct LeaderboardEntrySnapshot: Codable, Identifiable {
    var id: Int { rank }
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

// MARK: - PassSnapshot

struct PassSnapshot: Codable, Identifiable {
    let id: UUID
    let planetName: String
    let planetIndex: Int
    let efficiencyPercent: Int
    let serialCode: String
    let missionCount: Int
    let timestamp: Date
    let planetColorHex: String
}

// MARK: - PlanetColors
/// Maps planet index to its accent color hex. Shared between main app and widget.
enum PlanetColors {
    static let hexByIndex: [Int: String] = [
        0: "4DB87A", // Earth
        1: "D9E7D8", // Moon
        2: "FF6A3D", // Mars
        3: "FFB800", // Asteroid Belt
        4: "D4A055", // Jupiter
        5: "E4C87A", // Saturn
        6: "7EC8E3", // Uranus
        7: "4B70DD", // Neptune
    ]

    static func color(for index: Int) -> Color {
        // Color(hex:) is defined in Theme.swift (main app) and WidgetTheme.swift (widget)
        Color(hex: hexByIndex[index] ?? "FF6A3D")
    }
}
