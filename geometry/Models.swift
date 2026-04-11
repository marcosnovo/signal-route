import SwiftUI

// MARK: - Direction
enum Direction: CaseIterable, Hashable {
    case north, east, south, west

    var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east:  return .west
        case .west:  return .east
        }
    }

    /// Rotate clockwise by `steps` quarter-turns
    func rotated(by steps: Int) -> Direction {
        let all: [Direction] = [.north, .east, .south, .west]
        let idx = all.firstIndex(of: self)!
        return all[((idx + steps) % 4 + 4) % 4]
    }
}

// MARK: - TileType
enum TileType {
    case straight   // N-S
    case curve      // N-E
    case tShape     // N-E-W
    case cross      // all four

    var baseConnections: Set<Direction> {
        switch self {
        case .straight: return [.north, .south]
        case .curve:    return [.north, .east]
        case .tShape:   return [.north, .east, .west]
        case .cross:    return [.north, .east, .south, .west]
        }
    }
}

// MARK: - NodeRole
/// Functional role of a tile in the energy network.
enum NodeRole {
    case source   // emits energy; always energized
    case target   // must receive energy to win
    case relay    // normal conduit
    case none     // inert / blocked (reserved)
}

// MARK: - Tile
struct Tile: Identifiable {
    let id = UUID()
    var type: TileType
    var rotation: Int = 0      // 0–3, each step = 90° clockwise
    var role: NodeRole = .relay
    var isEnergized: Bool = false

    var connections: Set<Direction> {
        Set(type.baseConnections.map { $0.rotated(by: rotation) })
    }

    mutating func rotate() {
        rotation = (rotation + 1) % 4
    }
}

// MARK: - Game Status
enum GameStatus: Equatable {
    case playing, won, lost
}

// MARK: - GameResult
/// Snapshot of a completed game session.
struct GameResult {
    let success: Bool
    let movesUsed: Int
    let efficiency: Float   // movesLeft / maxMoves at moment of completion
    let nodesActivated: Int
    let totalNodes: Int
    let score: Int          // final score for this session

    var efficiencyPercent: Int { Int(efficiency * 100) }
    /// Number of filled blocks (0–5) for the 5-cell efficiency bar.
    var filledBlocks: Int { max(0, min(5, Int((efficiency * 5).rounded()))) }

    /// Wordle-style share text.
    var shareText: String {
        let dateStr: String = {
            let f = DateFormatter()
            f.dateFormat = "dd MMM yyyy"
            return f.string(from: Date()).uppercased()
        }()
        let filled = max(0, min(5, Int((efficiency * 5).rounded())))
        let bar = String(repeating: "█", count: filled)
                + String(repeating: "░", count: 5 - filled)
        return """
        SIGNAL ROUTE · \(dateStr)
        \(success ? "SUCCESS ✓" : "FAILURE ✗")
        EFFICIENCY  \(bar)  \(efficiencyPercent)%
        NODES  \(nodesActivated)/\(totalNodes)
        MOVES  \(movesUsed)
        """
    }
}

// MARK: - Planet
/// A destination in the astronaut's progression journey.
struct Planet: Identifiable {
    let id:            Int        // matches distanceIndex for Identifiable conformance
    let name:          String
    let missionBrief:  String     // short flavour text
    let difficulty:    DifficultyTier
    let color:         Color      // accent colour used throughout the UI
    let requiredLevel: Int        // astronaut level needed to reach this planet

    /// The full ordered solar-system catalog.
    static let catalog: [Planet] = [
        Planet(id: 0, name: "EARTH ORBIT",    missionBrief: "TRAINING ZONE",       difficulty: .easy,   color: Color(hex: "4DB87A"), requiredLevel: 1),
        Planet(id: 1, name: "MOON",           missionBrief: "LUNAR APPROACH",       difficulty: .easy,   color: Color(hex: "D9E7D8"), requiredLevel: 2),
        Planet(id: 2, name: "MARS",           missionBrief: "RED PLANET OPS",       difficulty: .medium, color: Color(hex: "FF6A3D"), requiredLevel: 3),
        Planet(id: 3, name: "ASTEROID BELT",  missionBrief: "DEBRIS FIELD",         difficulty: .medium, color: Color(hex: "FFB800"), requiredLevel: 5),
        Planet(id: 4, name: "JUPITER",        missionBrief: "GAS GIANT RELAY",      difficulty: .hard,   color: Color(hex: "D4A055"), requiredLevel: 7),
        Planet(id: 5, name: "SATURN",         missionBrief: "RING SYSTEM TRANSIT",  difficulty: .hard,   color: Color(hex: "E4C87A"), requiredLevel: 10),
        Planet(id: 6, name: "URANUS",         missionBrief: "ICE GIANT SURVEY",     difficulty: .expert, color: Color(hex: "7EC8E3"), requiredLevel: 14),
        Planet(id: 7, name: "NEPTUNE",        missionBrief: "DEEP SPACE COMMS",     difficulty: .expert, color: Color(hex: "4B70DD"), requiredLevel: 18),
    ]
}

// MARK: - ProgressionRule
/// Requirements to advance from `level` to `level + 1`.
struct ProgressionRule {
    let requiredMissions:        Int
    let requiredAvgEfficiency:   Float   // 0–1

    var requiredEfficiencyPercent: Int { Int(requiredAvgEfficiency * 100) }
    var label: String {
        "\(requiredMissions) MISSIONS  ·  \(requiredEfficiencyPercent)% AVG"
    }

    /// Defined rules for levels 1–8. Beyond that, extrapolated automatically.
    private static let defined: [ProgressionRule] = [
        ProgressionRule(requiredMissions: 3,  requiredAvgEfficiency: 0.60), // L1 → L2
        ProgressionRule(requiredMissions: 5,  requiredAvgEfficiency: 0.65), // L2 → L3
        ProgressionRule(requiredMissions: 8,  requiredAvgEfficiency: 0.70), // L3 → L4
        ProgressionRule(requiredMissions: 12, requiredAvgEfficiency: 0.72), // L4 → L5
        ProgressionRule(requiredMissions: 17, requiredAvgEfficiency: 0.75), // L5 → L6
        ProgressionRule(requiredMissions: 23, requiredAvgEfficiency: 0.77), // L6 → L7
        ProgressionRule(requiredMissions: 30, requiredAvgEfficiency: 0.80), // L7 → L8
        ProgressionRule(requiredMissions: 38, requiredAvgEfficiency: 0.82), // L8 → L9
    ]

    /// Returns the rule that governs levelling up FROM `level` to `level+1`.
    static func rule(for level: Int) -> ProgressionRule {
        let idx = level - 1
        guard idx >= 0 else { return defined[0] }
        if idx < defined.count { return defined[idx] }
        // Extrapolate beyond the defined table: +6 missions, +1% per step
        let base  = defined.last!
        let extra = idx - defined.count + 1
        return ProgressionRule(
            requiredMissions:      base.requiredMissions + extra * 6,
            requiredAvgEfficiency: min(0.95, base.requiredAvgEfficiency + Float(extra) * 0.01)
        )
    }
}

// MARK: - AstronautProfile
/// The player's persistent identity and progression state.
struct AstronautProfile: Codable {
    var level:              Int   = 1
    var totalScore:         Int   = 0
    var completedMissions:  Int   = 0
    var totalEfficiency:    Float = 0   // sum of per-mission efficiencies
    var currentPlanetIndex: Int   = 0

    // ── Computed ──────────────────────────────────────────────────────────

    var averageEfficiency: Float {
        guard completedMissions > 0 else { return 0 }
        return totalEfficiency / Float(completedMissions)
    }
    var averageEfficiencyPercent: Int { Int(averageEfficiency * 100) }

    var currentPlanet: Planet {
        Planet.catalog[min(currentPlanetIndex, Planet.catalog.count - 1)]
    }
    var nextPlanet: Planet? {
        let idx = currentPlanetIndex + 1
        return idx < Planet.catalog.count ? Planet.catalog[idx] : nil
    }

    var progressionRule: ProgressionRule { ProgressionRule.rule(for: level) }

    /// True when this profile satisfies the requirements to advance one level.
    var canLevelUp: Bool {
        let rule = progressionRule
        return completedMissions >= rule.requiredMissions
            && averageEfficiency  >= rule.requiredAvgEfficiency
    }

    /// Composite 0→1 progress toward the next level-up (for UI progress bars).
    var levelProgress: Float {
        let rule = progressionRule
        let mp = Float(completedMissions) / Float(rule.requiredMissions)
        let ep = completedMissions > 0
            ? averageEfficiency / rule.requiredAvgEfficiency
            : 0
        return min(1.0, (mp + ep) / 2)
    }

    /// Human-readable rank title based on current level.
    var rankTitle: String {
        switch level {
        case 1...2:  return "CADET"
        case 3...4:  return "PILOT"
        case 5...6:  return "NAVIGATOR"
        case 7...9:  return "COMMANDER"
        default:     return "ADMIRAL"
        }
    }
}

// MARK: - LevelType
/// Structural family of a level – controls source/target layout and path character.
enum LevelType: String, CaseIterable {
    case singlePath  = "LINEAR"
    case branching   = "BRANCH"
    case multiTarget = "MULTI-NODE"
    case dense       = "DENSE"
    case sparse      = "SPARSE"
}

// MARK: - Difficulty Tier
enum DifficultyTier: Int, CaseIterable, Identifiable {
    case easy   = 1
    case medium = 2
    case hard   = 3
    case expert = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .easy:   return "EASY"
        case .medium: return "MED"
        case .hard:   return "HARD"
        case .expert: return "XPRT"
        }
    }

    var fullLabel: String {
        switch self {
        case .easy:   return "EASY"
        case .medium: return "MEDIUM"
        case .hard:   return "HARD"
        case .expert: return "EXPERT"
        }
    }

    var stars: Int { rawValue }

    var color: Color {
        switch self {
        case .easy:   return Color(hex: "4DB87A")
        case .medium: return Color(hex: "FFB800")
        case .hard:   return Color(hex: "FF6A3D")
        case .expert: return Color(hex: "E84040")
        }
    }
}

// MARK: - PlanetPass
/// A collectible access pass issued when the player unlocks a new planet destination.
/// Represents real progression — one pass per planet, never duplicated.
struct PlanetPass: Codable, Identifiable {
    let id: UUID
    let planetName: String      // e.g. "MARS"
    let planetIndex: Int        // position in Planet.catalog
    let levelReached: Int       // astronaut level at time of unlock
    let efficiencyScore: Float  // average efficiency at time of unlock
    let missionCount: Int       // total completed missions at unlock
    let timestamp: Date

    /// Formatted serial code for display/share, e.g. "SR-0007-MAR"
    var serialCode: String {
        let abbrev = String(planetName.prefix(3)).replacingOccurrences(of: " ", with: "_")
        return String(format: "SR-%04d-%@", missionCount, abbrev)
    }
}

// MARK: - Level
struct Level: Identifiable {
    let id: Int
    let seed: UInt64
    let maxMoves: Int
    let difficulty: DifficultyTier
    let gridSize: Int        // 4 = 4×4, 5 = 5×5
    let levelType: LevelType
    let numTargets: Int      // number of target nodes to energize

    var displayID: String   { String(format: "%02d", id) }
    var displayName: String { id == 0 ? "INTRO MISSION" : "MISSION \(displayID)" }
}
