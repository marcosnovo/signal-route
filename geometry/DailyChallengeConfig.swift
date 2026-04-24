import Foundation

// MARK: - DailyChallengeConfig
/// Centralized constants, seed computation, and timezone boundary logic for the daily challenge.
enum DailyChallengeConfig {

    /// Daily challenge levels always use id: -2
    static let levelID: Int = -2

    /// Always 5×5 grid
    static let gridSize: Int = 5

    /// Madrid timezone for the 8:00 AM boundary
    static let timezone = TimeZone(identifier: "Europe/Madrid")!

    /// Hour at which the daily challenge resets (08:00)
    static let resetHour: Int = 8

    // MARK: - Day boundary computation

    /// Returns the "daily challenge day" identifier string (yyyy-MM-dd) for the
    /// current moment, using the 8 AM Madrid boundary.
    ///
    /// Before 8:00 AM Madrid → the active day is YESTERDAY.
    /// At 8:00 AM Madrid or later → the active day is TODAY.
    static var activeDayKey: String {
        dayKey(for: Date())
    }

    /// Testable: returns the day key for an arbitrary date.
    static func dayKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)

        // Before 8 AM Madrid → the active challenge is yesterday's
        if comps.hour! < resetHour {
            let yesterday = cal.date(byAdding: .day, value: -1, to: date)!
            comps = cal.dateComponents([.year, .month, .day], from: yesterday)
        }
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }

    // MARK: - Deterministic seed

    /// Deterministic seed for the daily challenge, identical worldwide.
    /// Uses the day key to derive a UInt64 seed via FNV-1a hash.
    static var todaySeed: UInt64 {
        seed(for: activeDayKey)
    }

    /// Testable: seed for a given day key string.
    static func seed(for dayKey: String) -> UInt64 {
        // FNV-1a 64-bit hash of the day key string
        var hash: UInt64 = 14695981039346656037 // FNV offset basis
        for byte in dayKey.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211 // FNV prime
        }
        return hash
    }

    // MARK: - Next challenge countdown

    /// Date of the next 8:00 AM Madrid (the start of the next daily challenge).
    static var nextChallengeDate: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        let now = Date()
        let comps = cal.dateComponents([.hour], from: now)

        var target = cal.date(bySettingHour: resetHour, minute: 0, second: 0, of: now)!
        if comps.hour! >= resetHour {
            target = cal.date(byAdding: .day, value: 1, to: target)!
        }
        return target
    }

    /// Seconds remaining until the next daily challenge.
    static var secondsUntilNext: TimeInterval {
        max(0, nextChallengeDate.timeIntervalSinceNow)
    }
}
