import Foundation

// MARK: - LeaderboardCache
/// Caches Game Center leaderboard data for widget consumption.
/// Written by GameCenterManager after score submission, read by ProgressionStore
/// when building widget snapshots.
enum LeaderboardCache {

    private static let entriesKey = "leaderboard-cache-entries-v1"
    private static let rankKey    = "leaderboard-cache-rank-v1"
    private static let totalKey   = "leaderboard-cache-total-v1"

    /// Cached top-5 leaderboard entries.
    static var entries: [LeaderboardEntrySnapshot] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([LeaderboardEntrySnapshot].self, from: data)
        else { return [] }
        return decoded
    }

    /// Local player's rank (nil if not yet fetched).
    static var playerRank: Int? {
        let val = UserDefaults.standard.integer(forKey: rankKey)
        return val > 0 ? val : nil
    }

    /// Total number of players on the leaderboard (nil if not yet fetched).
    static var totalPlayers: Int? {
        let val = UserDefaults.standard.integer(forKey: totalKey)
        return val > 0 ? val : nil
    }

    /// Update the cache with fresh GC data.
    static func update(entries: [LeaderboardEntrySnapshot], playerRank: Int?, totalPlayers: Int?) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
        if let rank = playerRank {
            UserDefaults.standard.set(rank, forKey: rankKey)
        }
        if let total = totalPlayers {
            UserDefaults.standard.set(total, forKey: totalKey)
        }
    }
}
