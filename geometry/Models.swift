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

    // MARK: — Gameplay Mechanics
    /// Non-nil = rotation is capped at this many player-initiated rotations.
    var maxRotations: Int? = nil
    /// How many times the player has rotated this tile this session.
    var rotationsUsed: Int = 0
    /// Non-nil = tile drifts +1 clockwise this many seconds after each player tap.
    var autoDriftDelay: Double? = nil
    /// True = tile requires 2 taps per rotation (arm then execute).
    var isOverloaded: Bool = false
    /// True = first tap received; awaiting the execute tap.
    var overloadArmed: Bool = false
    /// Canonical blocked inbound directions at rotation 0.
    /// Empty set (default) = no restriction — identical to current behavior.
    /// Set by the level generator for one-way relay tiles.
    var baseBlockedInboundDirections: Set<Direction> = []

    // MARK: — Fragile Tile mechanic (id ≥ 151)
    /// Non-nil = tile burns out after being energized this many player-move times.
    var fragileCharges: Int? = nil
    /// How many times this tile has been energized during player taps (fragile decay counter).
    var fragileChargesUsed: Int = 0
    /// True = tile has burned out; no longer conducts energy.
    var isBurned: Bool = false

    // MARK: — Charge Gate mechanic (id ≥ 164)
    /// Non-nil = tile only conducts energy outward after being charged this many times.
    var gateChargesRequired: Int? = nil
    /// How many charge cycles this gate has accumulated so far.
    var gateChargesReceived: Int = 0
    /// True = gate has accumulated enough charges and now conducts normally.
    var isGateOpen: Bool = false

    // MARK: — Interference Zone mechanic (id ≥ 171)
    /// True = visual static overlay applied; makes tile orientation harder to read.
    var hasInterference: Bool = false

    /// Directions (in grid space) from which energy cannot enter this tile at the current rotation.
    /// Derived by rotating `baseBlockedInboundDirections` by the tile's current rotation.
    /// This means the one-way constraint rotates with the tile as the player taps it.
    var blockedInboundDirections: Set<Direction> {
        Set(baseBlockedInboundDirections.map { $0.rotated(by: rotation) })
    }

    var isRotationLocked: Bool {
        guard let max = maxRotations else { return false }
        return rotationsUsed >= max
    }

    var rotationsRemaining: Int? {
        guard let max = maxRotations else { return nil }
        return Swift.max(0, max - rotationsUsed)
    }

    /// Remaining fragile charges before burn-out. Nil when not a fragile tile.
    var fragileChargesRemaining: Int? {
        guard let max = fragileCharges else { return nil }
        return Swift.max(0, max - fragileChargesUsed)
    }

    var connections: Set<Direction> {
        Set(type.baseConnections.map { $0.rotated(by: rotation) })
    }

    mutating func rotate() {
        rotation = (rotation + 1) % 4
    }
}

// MARK: - MechanicType
/// The progressive gameplay mechanics unlocked as the player advances.
enum MechanicType: String, CaseIterable, Codable {
    case rotationCap     // B — tiles with limited rotations (medium+)
    case overloaded      // D — tiles requiring two taps per rotation (hard+)
    case timeLimit       // A — mission must be completed under time pressure (hard+)
    case autoDrift       // C — tiles that drift back after a delay (expert)
    case oneWayRelay     // E — relay that only accepts signal from one direction (end-game)
    case fragileTile     // F — relay burns out after N energized turns (id ≥ 151)
    case chargeGate      // G — relay only conducts after N charge cycles (id ≥ 164)
    case interferenceZone // H — visual noise overlay on tiles (id ≥ 171)

    var unlockTitle: String {
        switch self {
        case .rotationCap:      return "ROTATION LIMIT"
        case .overloaded:       return "OVERLOADED RELAY"
        case .timeLimit:        return "TIME PRESSURE"
        case .autoDrift:        return "NODE DRIFT"
        case .oneWayRelay:      return "ONE-WAY RELAY"
        case .fragileTile:      return "FRAGILE RELAY"
        case .chargeGate:       return "CHARGE GATE"
        case .interferenceZone: return "INTERFERENCE"
        }
    }

    var unlockMessage: String {
        switch self {
        case .rotationCap:
            return "Your training is progressing fast. Some components are now unstable and can only be rotated a limited number of times. Plan every move carefully."
        case .overloaded:
            return "High-resistance nodes have been detected in the network. Some relays require two commands to rotate — arm first, then execute."
        case .timeLimit:
            return "You've shown remarkable routing skills. We believe time won't be a problem for you anymore. From now on, some missions must be completed under time pressure."
        case .autoDrift:
            return "Advanced systems are now entering the simulation. Some nodes won't hold their orientation for long. Stabilize the route before they shift again."
        case .oneWayRelay:
            return "Advanced routing protocols unlocked. Some relays now only accept signal from specific directions. Read the grid carefully."
        case .fragileTile:
            return "Network components are degrading. Some relays can only handle limited exposure to the energy field before burning out permanently. Route efficiently before they fail."
        case .chargeGate:
            return "Locked subsystems detected. Some relays require multiple charge cycles before they conduct. Keep the signal flowing until the gate opens."
        case .interferenceZone:
            return "Electromagnetic interference detected in the grid. Some sectors are compromised — visual readings may be distorted. Trust the signal, not your eyes."
        }
    }

    var iconName: String {
        switch self {
        case .rotationCap:      return "lock.rotation"
        case .overloaded:       return "bolt.circle"
        case .timeLimit:        return "timer"
        case .autoDrift:        return "arrow.clockwise.circle"
        case .oneWayRelay:      return "arrow.right.circle.fill"
        case .fragileTile:      return "bolt.slash.fill"
        case .chargeGate:       return "lock.open.fill"
        case .interferenceZone: return "waveform.path.ecg"
        }
    }
}

// MARK: - Game Status
enum GameStatus: Equatable {
    case playing, won, lost
}

// MARK: - GameResult
/// Snapshot of a completed game session.
struct GameResult {
    /// The level ID this result belongs to. Used by ProgressionStore to prevent
    /// double-counting when a player replays a level (only the best score counts).
    let levelId: Int
    let success: Bool
    let movesUsed: Int
    /// Composite mission quality 0–1. 1.0 only when every component is perfect.
    let efficiency: Float
    let nodesActivated: Int
    let totalNodes: Int
    let score: Int          // final score for this session

    // ── Component ratings (each 0–1) ──────────────────────────────────────
    /// Move efficiency: movesLeft / buffer, where buffer = maxMoves − minMoves.
    let moveRating: Float
    /// Energy quality: objective-specific (coverage ratio, saving ratio, or 1.0).
    let energyRating: Float
    /// Time quality: timeRemaining / timeLimit, or 1.0 for untimed levels.
    let timeRating: Float

    // ── Derived ───────────────────────────────────────────────────────────

    var efficiencyPercent: Int { Int(efficiency * 100) }
    /// Number of filled blocks (0–5) for the 5-cell efficiency bar.
    var filledBlocks: Int { max(0, min(5, Int((efficiency * 5).rounded()))) }

    var isOptimalRoute: Bool { efficiency >= 0.95 }

    var routeRating: String {
        switch efficiency {
        case 0.95...: return "OPTIMAL"
        case 0.80...: return "EFFICIENT"
        case 0.60...: return "ADEQUATE"
        default:      return "SUBOPTIMAL"
        }
    }

    var routeMessage: String {
        switch efficiency {
        case 0.95...: return "Optimal route achieved."
        case 0.80...: return "A more efficient route was possible."
        case 0.60...: return "Mission complete. A more efficient route was possible."
        default:      return "You completed the mission, but not with the most efficient network."
        }
    }

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
        QUALITY  \(bar)  \(efficiencyPercent)%  [\(routeRating)]
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
///
/// **Key concept — "quality mission":**
/// A level completion only counts toward the requirement when its efficiency
/// meets or exceeds `requiredAvgEfficiency`. Replaying a level doesn't double-count;
/// only the best score per level ID is stored and tested against this threshold.
///
/// **Exponential growth curve:**
/// - Required quality missions = ⌈5 × 1.38^(level−1)⌉
///   L1→L2:  5   L2→L3:  7   L3→L4: 10   L4→L5: 14   L5→L6: 19
///   L6→L7: 26   L7→L8: 36   L8→L9: 50   L9→L10: 69  L10→L11: 95 …
/// - Required efficiency = 60% + 2% per level, capped at 86%
///   Ensures later levels demand consistent quality, not just volume.
///
/// With 180 catalogue levels the practical ceiling is around level 11–12,
/// requiring nearly all levels completed at high efficiency.
struct ProgressionRule {
    /// Unique levels (best score ≥ requiredAvgEfficiency) needed to advance.
    let requiredMissions:      Int
    /// Minimum efficiency each mission must achieve to count as "quality".
    let requiredAvgEfficiency: Float   // 0–1

    var requiredEfficiencyPercent: Int { Int(requiredAvgEfficiency * 100) }

    var label: String {
        "\(requiredMissions) QUALITY MISSIONS  ·  ≥\(requiredEfficiencyPercent)% EACH"
    }

    /// Returns the rule governing level-up FROM `level` to `level+1`.
    /// Purely formula-driven — no hard-coded table, infinite by design.
    static func rule(for level: Int) -> ProgressionRule {
        let n = max(0, level - 1)   // steps above base level
        // Exponential mission count — each step multiplies by ~1.38
        let missions = max(1, Int(ceil(5.0 * pow(1.38, Double(n)))))
        // Linear efficiency ramp, capped so endgame doesn't require perfection
        let efficiency = min(0.86, 0.60 + Float(n) * 0.02)
        return ProgressionRule(requiredMissions: missions, requiredAvgEfficiency: efficiency)
    }
}

// MARK: - AstronautProfile
/// The player's persistent identity and progression state.
///
/// Progression is based on **unique** level completions — replaying a mission
/// only updates the stored score if the new result beats the previous best.
/// This prevents grinding the same easy level to farm progress.
struct AstronautProfile: Codable {
    var level:              Int   = 1
    var totalScore:         Int   = 0
    var currentPlanetIndex: Int   = 0

    /// Best efficiency achieved per level ID (key = String(level.id)).
    /// Only successful completions are stored. A replay replaces the entry
    /// only when the new efficiency strictly exceeds the previous best.
    var bestEfficiencyByLevel: [String: Float] = [:]

    // ── Computed — unique completion stats ────────────────────────────────

    /// Number of unique level IDs successfully completed (any quality).
    var uniqueCompletions: Int { bestEfficiencyByLevel.count }

    /// Alias kept for PassStore / legacy call sites.
    var completedMissions: Int { uniqueCompletions }

    /// Average efficiency across the best-per-level scores.
    /// Replaying a hard level and doing worse doesn't lower this — only bests count.
    var averageEfficiency: Float {
        guard !bestEfficiencyByLevel.isEmpty else { return 0 }
        return bestEfficiencyByLevel.values.reduce(0, +) / Float(bestEfficiencyByLevel.count)
    }
    var averageEfficiencyPercent: Int { Int(averageEfficiency * 100) }

    /// How many unique levels have been completed with efficiency ≥ `minEfficiency`.
    /// This is the core progression metric — grinding one easy level never inflates it.
    func qualityCompletions(minEfficiency: Float) -> Int {
        bestEfficiencyByLevel.values.filter { $0 >= minEfficiency }.count
    }

    // ── Computed — planetary destination ──────────────────────────────────

    var currentPlanet: Planet {
        Planet.catalog[min(currentPlanetIndex, Planet.catalog.count - 1)]
    }
    var nextPlanet: Planet? {
        let idx = currentPlanetIndex + 1
        return idx < Planet.catalog.count ? Planet.catalog[idx] : nil
    }

    // ── Progression gating ────────────────────────────────────────────────

    var progressionRule: ProgressionRule { ProgressionRule.rule(for: level) }

    /// True when the player has enough quality missions at the required efficiency.
    var canLevelUp: Bool {
        let rule = progressionRule
        return qualityCompletions(minEfficiency: rule.requiredAvgEfficiency) >= rule.requiredMissions
    }

    /// 0→1 progress toward the next level-up.
    /// Purely based on quality mission count — no averaging tricks.
    var levelProgress: Float {
        let rule = progressionRule
        let done = qualityCompletions(minEfficiency: rule.requiredAvgEfficiency)
        return min(1.0, Float(done) / Float(rule.requiredMissions))
    }

    /// Missions still needed at current quality threshold.
    var missionsRemaining: Int {
        let rule = progressionRule
        let done = qualityCompletions(minEfficiency: rule.requiredAvgEfficiency)
        return max(0, rule.requiredMissions - done)
    }

    // ── Mission unlock / map helpers ───────────────────────────────────────

    /// True when the player has at least one completion recorded for this level ID.
    func hasCompleted(levelId: Int) -> Bool {
        bestEfficiencyByLevel[String(levelId)] != nil
    }

    /// Sequential unlock: level N requires level N−1 to be completed first.
    /// Level 1 is always unlocked.
    func isLevelUnlocked(_ id: Int) -> Bool {
        if id <= 1 { return true }
        return hasCompleted(levelId: id - 1)
    }

    /// First unlocked level the player hasn't completed yet.
    /// This is the natural "continue" destination shown on the Home screen.
    var nextMission: Level? {
        LevelGenerator.levels.first { isLevelUnlocked($0.id) && !hasCompleted(levelId: $0.id) }
    }

    // ── Rank ──────────────────────────────────────────────────────────────

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

// MARK: - LevelObjectiveType
/// The win condition and scoring model for a level.
enum LevelObjectiveType: String, CaseIterable, Codable {
    /// Standard: energize all targets. Score by moves left.
    case normal
    /// Energize all targets AND score bonus for total active nodes.
    case maxCoverage
    /// Energize all targets with at most `solutionPathLength + 2` total active nodes.
    case energySaving

    var hudLabel: String {
        switch self {
        case .normal:       return "ACTIVATE TARGETS"
        case .maxCoverage:  return "MAXIMIZE ACTIVE GRID"
        case .energySaving: return "SAVE ENERGY"
        }
    }

    var iconName: String {
        switch self {
        case .normal:       return "scope"
        case .maxCoverage:  return "bolt.fill"
        case .energySaving: return "leaf.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .normal:       return Color(hex: "FF6A3D")   // orange
        case .maxCoverage:  return Color(hex: "FFB800")   // amber
        case .energySaving: return Color(hex: "4DB87A")   // sage green
        }
    }
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
    /// Theoretical minimum taps to solve this board with perfect knowledge.
    /// Used to compute the move budget and display difficulty accurately.
    let minimumRequiredMoves: Int
    let difficulty: DifficultyTier
    let gridSize: Int        // 4 = 4×4, 5 = 5×5
    let levelType: LevelType
    let numTargets: Int      // number of target nodes to energize
    /// Non-nil = time limit in seconds; the mission must be won before the clock hits zero.
    let timeLimit: Int?
    /// Win condition and scoring model for this level.
    let objectiveType: LevelObjectiveType
    /// Number of tiles on the solution path (source + relays + targets).
    /// Used for the energySaving win condition.
    let solutionPathLength: Int

    var displayID: String   { String(format: "%02d", id) }
    var displayName: String { id == 0 ? "INTRO MISSION" : "MISSION \(displayID)" }
    /// Slack over the theoretical minimum. Reflects how forgiving the move budget is.
    var moveBuffer: Int     { maxMoves - minimumRequiredMoves }
    /// Max allowed active nodes for energySaving levels (solution path + tolerance).
    var energySavingLimit: Int { solutionPathLength + 2 }
}

// MARK: - SpatialRegion
/// A named zone on the mission map, grouping levels by difficulty band.
/// Regions unlock progressively as the player's astronaut level rises.
struct SpatialRegion: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    /// Inclusive range of level IDs that belong to this region.
    let levelRange: ClosedRange<Int>
    /// Minimum astronaut level required to play levels in this region.
    let requiredPlayerLevel: Int
    let accentColor: Color

    /// All catalogue levels that belong to this region.
    var levels: [Level] { LevelGenerator.levels.filter { levelRange.contains($0.id) } }

    /// True when the player's astronaut level meets the entry requirement.
    func isUnlocked(for profile: AstronautProfile) -> Bool {
        profile.level >= requiredPlayerLevel
    }

    /// Number of levels in this region the player has completed at least once.
    func completedCount(in profile: AstronautProfile) -> Int {
        levels.filter { profile.hasCompleted(levelId: $0.id) }.count
    }

    /// The eight mission zones ordered outward from Earth.
    static let catalog: [SpatialRegion] = [
        SpatialRegion(id: 1, name: "EARTH ORBIT",    subtitle: "TRAINING ZONE",       levelRange: 1...30,   requiredPlayerLevel: 1,  accentColor: Color(hex: "4DB87A")),
        SpatialRegion(id: 2, name: "LUNAR APPROACH", subtitle: "PHASE 2 OPERATIONS",  levelRange: 31...50,  requiredPlayerLevel: 2,  accentColor: Color(hex: "D9E7D8")),
        SpatialRegion(id: 3, name: "MARS SECTOR",    subtitle: "RED PLANET OPS",      levelRange: 51...70,  requiredPlayerLevel: 3,  accentColor: Color(hex: "FF6A3D")),
        SpatialRegion(id: 4, name: "ASTEROID BELT",  subtitle: "DEBRIS FIELD",        levelRange: 71...90,  requiredPlayerLevel: 5,  accentColor: Color(hex: "FFB800")),
        SpatialRegion(id: 5, name: "JUPITER RELAY",  subtitle: "GAS GIANT COMMS",     levelRange: 91...110, requiredPlayerLevel: 7,  accentColor: Color(hex: "D4A055")),
        SpatialRegion(id: 6, name: "SATURN RING",    subtitle: "RING SYSTEM TRANSIT", levelRange: 111...130,requiredPlayerLevel: 10, accentColor: Color(hex: "E4C87A")),
        SpatialRegion(id: 7, name: "URANUS VOID",    subtitle: "ICE GIANT SURVEY",    levelRange: 131...150,requiredPlayerLevel: 14, accentColor: Color(hex: "7EC8E3")),
        SpatialRegion(id: 8, name: "NEPTUNE DEEP",   subtitle: "DEEP SPACE COMMS",    levelRange: 151...180,requiredPlayerLevel: 18, accentColor: Color(hex: "4B70DD")),
    ]
}
