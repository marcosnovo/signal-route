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
