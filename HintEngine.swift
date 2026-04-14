import Foundation

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
