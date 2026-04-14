import Foundation

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

// MARK: - AdaptiveDifficultyEngine
/// Translates a player skill score (0.0–1.0) into concrete level adjustments.
///
/// Skill bands:
///   < 0.30       struggling  → generous assistance (3 extra moves, 35% more time, 45% interference)
///   0.30–0.50    below avg   → moderate help       (2 extra moves, 20% more time, 65% interference)
///   0.50–0.65    average     → light touch          (1 extra move,  10% more time, 80% interference)
///   0.65–0.75    proficient  → full base difficulty (0 extra moves, base time,    100% interference)
///   > 0.75       expert      → hard mode invisible  (−2 moves,     90% time,      100% interference)
enum AdaptiveDifficultyEngine {

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
