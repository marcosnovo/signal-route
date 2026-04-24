import Foundation
import SwiftUI
import WidgetKit

// MARK: - Shared types duplicated for the widget extension target.
// These must stay in sync with the main app's versions in:
//   geometry/geometry/WidgetDataSnapshot.swift
//   geometry/geometry/WidgetDataBridge.swift
//   geometry/geometry/LeaderboardCache.swift

// MARK: - WidgetDataSnapshot

struct WidgetDataSnapshot: Codable {
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
    let leaderboardEntries: [LeaderboardEntrySnapshot]
    let playerRank: Int?
    let totalPlayers: Int?
    let passes: [PassSnapshot]
    let streak: Int?
    let weeklyRankChange: Int?
    let language: String?
    let updatedAt: Date

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

// MARK: - WidgetDataBridge

enum WidgetDataBridge {
    static let appGroupID = "group.com.marcosnovo.signalvoidgame"
    private static let snapshotKey = "widget-data-snapshot-v1"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> WidgetDataSnapshot? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDataSnapshot.self, from: data)
    }
}

// MARK: - PlanetColors

enum PlanetColors {
    static let hexByIndex: [Int: String] = [
        0: "4DB87A", 1: "D9E7D8", 2: "FF6A3D", 3: "FFB800",
        4: "D4A055", 5: "E4C87A", 6: "7EC8E3", 7: "4B70DD",
    ]

    static func color(for index: Int) -> Color {
        Color(hex: hexByIndex[index] ?? "FF6A3D")
    }
}
