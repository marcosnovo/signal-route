import Foundation

// MARK: - DailyStore
/// Persists the player's result for the current daily mission in UserDefaults.
/// One result per calendar day, keyed by "daily-result-yyyy-MM-dd".
enum DailyStore {

    private static let defaults = UserDefaults.standard

    private static let dailyKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var todayKey: String {
        "daily-result-\(dailyKeyFormatter.string(from: Date()))"
    }

    static var hasPlayedToday: Bool {
        defaults.object(forKey: todayKey) != nil
    }

    static func save(_ result: GameResult) {
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
        defaults.set(dict, forKey: todayKey)
    }

    static var todayResult: GameResult? {
        guard let dict = defaults.dictionary(forKey: todayKey) else { return nil }
        guard
            let success        = dict["success"]        as? Bool,
            let movesUsed      = dict["movesUsed"]      as? Int,
            let efficiency     = dict["efficiency"]     as? Double,
            let nodesActivated = dict["nodesActivated"] as? Int,
            let totalNodes     = dict["totalNodes"]     as? Int
        else { return nil }
        // levelId defaults to the current daily level ID for entries saved before this field was added
        let levelId = dict["levelId"] as? Int ?? LevelGenerator.dailyLevel.id
        return GameResult(
            levelId:        levelId,
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
}
