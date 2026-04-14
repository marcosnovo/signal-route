import Foundation

// MARK: - PlayerSkillStore
/// Tracks player skill across missions and exposes a smoothed skill score (0.0–1.0).
///
/// Score meaning:
///   0.0 — player is struggling (many retries, low efficiency)
///   0.5 — baseline on first launch (neutral)
///   1.0 — expert (solves first try with optimal moves)
///
/// Updated after every win (recordWin) or mid-game abandon (recordAbandon).
/// Smoothed with an exponential moving average (α = 0.25) to prevent jarring swings.
/// Persisted to UserDefaults.
final class PlayerSkillStore {
    static let shared = PlayerSkillStore()
    private init() {}

    private let udKey = "playerSkillScore"
    private let α     = 0.25

    // ── Public output ────────────────────────────────────────────────────────

    /// Smoothed player skill score. 0.0 = struggling, 1.0 = expert.
    private(set) var skillScore: Double {
        get { (UserDefaults.standard.object(forKey: udKey) as? Double) ?? 0.5 }
        set { UserDefaults.standard.set(newValue, forKey: udKey) }
    }

    // ── Win recording ────────────────────────────────────────────────────────

    /// Call after a successful level completion.
    /// - Parameters:
    ///   - efficiency: 0.0–1.0 quality from GameResult (moves, energy, time combined)
    ///   - movesUsed: moves the player made
    ///   - minimumMoves: minimum moves to solve this level
    ///   - attempts: how many times the player attempted this level (1 = first try)
    func recordWin(efficiency: Float, movesUsed: Int, minimumMoves: Int, attempts: Int) {
        let levelScore = computeLevelScore(
            efficiency:   efficiency,
            movesUsed:    movesUsed,
            minimumMoves: minimumMoves,
            attempts:     attempts
        )
        update(toward: levelScore)
    }

    // ── Abandon recording ────────────────────────────────────────────────────

    /// Call when the player exits a level mid-game without winning or losing.
    func recordAbandon() {
        update(toward: 0.10)
    }

    // ── Score computation ────────────────────────────────────────────────────

    private func computeLevelScore(efficiency: Float,
                                   movesUsed: Int,
                                   minimumMoves: Int,
                                   attempts: Int) -> Double {
        // Attempts: 1 attempt = 1.0; each extra costs 0.25 (≥5 = 0.0)
        let attemptsScore = max(0.0, 1.0 - Double(attempts - 1) * 0.25)

        // Efficiency: quality score from the game result (already 0.0–1.0)
        let efficiencyScore = Double(min(1.0, max(0.0, efficiency)))

        // Move economy: ratio of minimum moves to moves used (1.0 = optimal)
        let ratio     = Double(max(1, movesUsed)) / Double(max(1, minimumMoves))
        let moveScore = min(1.0, 1.0 / max(1.0, ratio))

        return (attemptsScore * 0.40 + efficiencyScore * 0.35 + moveScore * 0.25)
            .clamped(to: 0...1)
    }

    // ── EMA update ───────────────────────────────────────────────────────────

    private func update(toward target: Double) {
        skillScore = (skillScore * (1 - α) + target * α).clamped(to: 0...1)
    }
}

// MARK: - Helpers
private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
