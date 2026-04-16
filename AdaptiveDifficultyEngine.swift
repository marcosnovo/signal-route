import Foundation

// MARK: - AdaptiveDifficultyManager
//
// Single file for all adaptive difficulty logic.
// Contains three cooperating types:
//
//   DifficultyAdjustments   — value type describing one level's tuned parameters
//   AdaptiveDifficultyManager — maps skillScore → DifficultyAdjustments (pure, no state)
//   HintEngine              — decides whether hints are active and which tile to highlight
//
// Isolation contract:
//   - Reads ONLY: PlayerSkillTracker.skillScore, attemptCount, tile grid state.
//   - Does NOT read isPremium, dailyCompleted, or any monetization state.
//   - Difficulty is driven purely by player performance. Premium status has zero influence.

// MARK: - DifficultyAdjustments

/// Set of adjustments applied to a level based on the player's skill score.
/// Computed once per level session (first attempt) and stable across retries.
///
/// Design contract:
///   - Never changes the puzzle solution or tile layout.
///   - Only adjusts margin, pressure, and visual friction.
struct DifficultyAdjustments {
    /// Extra moves added on top of the level's maxMoves.
    /// Negative values tighten the limit (hard mode). Always clamped to ≥ minimumRequiredMoves.
    let extraMoves: Int
    /// Multiplier applied to the level's timeLimit (if any). 1.0 = base time.
    let timeFactor: Double
    /// Opacity multiplier for the interference zone static overlay.
    /// 1.0 = full visual noise, lower = reduced distortion for struggling players.
    let interferenceScale: Double

    /// True when the player is skilled enough to receive harder constraints.
    /// Drives the optional par-target display in the moves HUD.
    var isHardMode: Bool { extraMoves < 0 }

    /// No adjustments — full difficulty as designed.
    static let none = DifficultyAdjustments(extraMoves: 0, timeFactor: 1.0, interferenceScale: 1.0)
}

// MARK: - AdaptiveDifficultyManager

/// Translates a player skill score (0.0–1.0) into concrete level adjustments.
///
/// Skill bands:
///   < 0.30       struggling  → generous assistance (3 extra moves, 35% more time, 45% interference)
///   0.30–0.50    below avg   → moderate help       (2 extra moves, 20% more time, 65% interference)
///   0.50–0.65    average     → light touch          (1 extra move,  10% more time, 80% interference)
///   0.65–0.75    proficient  → full base difficulty (0 extra moves, base time,    100% interference)
///   > 0.75       expert      → hard mode invisible  (−2 moves,     90% time,      100% interference)
enum AdaptiveDifficultyManager {

    static func adjustments(for skillScore: Double) -> DifficultyAdjustments {
        switch skillScore {
        case ..<0.30:
            return DifficultyAdjustments(extraMoves:  3, timeFactor: 1.35, interferenceScale: 0.45)
        case 0.30..<0.50:
            return DifficultyAdjustments(extraMoves:  2, timeFactor: 1.20, interferenceScale: 0.65)
        case 0.50..<0.65:
            return DifficultyAdjustments(extraMoves:  1, timeFactor: 1.10, interferenceScale: 0.80)
        case 0.65..<0.75:
            return .none
        default: // > 0.75 — expert, invisible hard mode
            return DifficultyAdjustments(extraMoves: -2, timeFactor: 0.90, interferenceScale: 1.0)
        }
    }
}

// MARK: - HintEngine

/// Pure logic for the soft hint system.
///
/// Hints are intentionally subtle — they guide without revealing.
/// The player should feel they discovered the answer themselves.
///
/// Activation criteria (either condition triggers hints):
///   • playerSkillScore < 0.40  (struggling player)
///   • attemptCount ≥ 3         (3+ attempts on the same level)
enum HintEngine {

    // MARK: - Activation

    /// Whether the hint system should be active for this player/attempt combination.
    static func isActive(skillScore: Double, attemptCount: Int) -> Bool {
        skillScore < 0.40 || attemptCount >= 3
    }

    // MARK: - Frontier tile

    /// Returns the position of the best tile to softly hint.
    ///
    /// Strategy: find the first unenergized relay tile that is adjacent to
    /// the current signal frontier (an energized tile). This tile is the
    /// most natural "next place to look" without revealing the full solution.
    ///
    /// Returns nil when every tile is energized (win imminent) or no relay
    /// candidates exist adjacent to the current signal.
    static func frontierTile(in tiles: [[Tile]]) -> (row: Int, col: Int)? {
        let n = tiles.count
        var seen = Set<Int>()   // packed key: row * 100 + col

        for row in 0..<n {
            for col in 0..<n {
                guard tiles[row][col].isEnergized else { continue }

                for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let nr = row + dr, nc = col + dc
                    guard nr >= 0, nr < n, nc >= 0, nc < n else { continue }

                    let key = nr * 100 + nc
                    guard seen.insert(key).inserted else { continue }

                    let neighbor = tiles[nr][nc]
                    // Only hint relay tiles — source/target roles are already visually distinct
                    guard !neighbor.isEnergized,
                          neighbor.role == .relay,
                          !neighbor.isBurned,
                          !neighbor.isRotationLocked
                    else { continue }

                    return (nr, nc)
                }
            }
        }
        return nil
    }
}
