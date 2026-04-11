import Foundation

// MARK: - DailyStore
/// Persists the player's result for the current daily mission in UserDefaults.
/// One result per calendar day, keyed by "daily-result-yyyy-MM-dd".
enum DailyStore {

    private static let defaults = UserDefaults.standard

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "daily-result-\(f.string(from: Date()))"
    }

    static var hasPlayedToday: Bool {
        defaults.object(forKey: todayKey) != nil
    }

    static func save(_ result: GameResult) {
        let dict: [String: Any] = [
            "success":        result.success,
            "movesUsed":      result.movesUsed,
            "efficiency":     Double(result.efficiency),
            "nodesActivated": result.nodesActivated,
            "totalNodes":     result.totalNodes,
            "score":          result.score
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
        return GameResult(
            success:        success,
            movesUsed:      movesUsed,
            efficiency:     Float(efficiency),
            nodesActivated: nodesActivated,
            totalNodes:     totalNodes,
            score:          dict["score"] as? Int ?? 0   // 0 for records saved before v1.1
        )
    }
}
