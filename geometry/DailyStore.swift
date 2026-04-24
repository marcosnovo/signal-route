import Foundation

// MARK: - DailyStore
/// Persists the player's daily challenge state and results.
///
/// Uses the 8 AM Madrid boundary (via `DailyChallengeConfig`) instead of local
/// midnight so all players worldwide share the same challenge window.
enum DailyStore {

    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private static func resultKey(for dayKey: String) -> String {
        "daily-result-\(dayKey)"
    }
    private static let cumulativeScoreKey = "daily-cumulative-score"
    private static let lastPlayedDayKey   = "daily-last-played-day"

    // MARK: - Today's state

    /// Whether the player has played (or started) today's challenge.
    static var hasPlayedToday: Bool {
        let dayKey = DailyChallengeConfig.activeDayKey
        return defaults.string(forKey: lastPlayedDayKey) == dayKey
            || defaults.object(forKey: resultKey(for: dayKey)) != nil
    }

    /// Mark that the player has started today's challenge (even before result).
    /// Called when entering the daily challenge game view to lock out re-entry.
    static func markStarted() {
        defaults.set(DailyChallengeConfig.activeDayKey, forKey: lastPlayedDayKey)
    }

    /// Save the result of today's daily challenge.
    static func save(_ result: GameResult) {
        let dayKey = DailyChallengeConfig.activeDayKey
        let dict: [String: Any] = [
            "levelId":        result.levelId,
            "success":        result.success,
            "movesUsed":      result.movesUsed,
            "efficiency":     Double(result.efficiency),
            "nodesActivated": result.nodesActivated,
            "totalNodes":     result.totalNodes,
            "score":          result.score,
            "moveRating":     Double(result.moveRating),
            "energyRating":   Double(result.energyRating),
            "timeRating":     Double(result.timeRating),
            "attemptCount":   result.attemptCount
        ]
        defaults.set(dict, forKey: resultKey(for: dayKey))
        defaults.set(dayKey, forKey: lastPlayedDayKey)

        // Accumulate score for the cumulative leaderboard (wins only)
        if result.success {
            let current = defaults.integer(forKey: cumulativeScoreKey)
            defaults.set(current + result.score, forKey: cumulativeScoreKey)
        }
    }

    /// Today's result, if any.
    static var todayResult: GameResult? {
        let dayKey = DailyChallengeConfig.activeDayKey
        guard let dict = defaults.dictionary(forKey: resultKey(for: dayKey)) else { return nil }
        guard
            let success        = dict["success"]        as? Bool,
            let movesUsed      = dict["movesUsed"]      as? Int,
            let efficiency     = dict["efficiency"]     as? Double,
            let nodesActivated = dict["nodesActivated"] as? Int,
            let totalNodes     = dict["totalNodes"]     as? Int
        else { return nil }
        return GameResult(
            levelId:        dict["levelId"] as? Int ?? DailyChallengeConfig.levelID,
            success:        success,
            movesUsed:      movesUsed,
            efficiency:     Float(efficiency),
            nodesActivated: nodesActivated,
            totalNodes:     totalNodes,
            score:          dict["score"] as? Int ?? 0,
            moveRating:     Float(dict["moveRating"]   as? Double ?? 0),
            energyRating:   Float(dict["energyRating"] as? Double ?? 0),
            timeRating:     Float(dict["timeRating"]   as? Double ?? 1),
            attemptCount:   dict["attemptCount"] as? Int ?? 1
        )
    }

    // MARK: - Cumulative score (for leaderboard)

    /// Total score accumulated across all daily challenge wins ever.
    static var cumulativeScore: Int {
        defaults.integer(forKey: cumulativeScoreKey)
    }

    /// Today's daily score (for the single-day leaderboard). 0 if not played or lost.
    static var todayScore: Int {
        todayResult?.score ?? 0
    }

    // MARK: - Dev reset

    /// Clears today's played state so the challenge can be replayed.
    /// Does NOT affect cumulative score — only removes the day key and result.
    static func resetToday() {
        let dayKey = DailyChallengeConfig.activeDayKey
        defaults.removeObject(forKey: lastPlayedDayKey)
        defaults.removeObject(forKey: resultKey(for: dayKey))
    }
}
