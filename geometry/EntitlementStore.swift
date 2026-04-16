import SwiftUI
import Combine

// MARK: - MonetizationGateManager (EntitlementStore)
//
// This is the ONLY place in the codebase that makes free/premium decisions.
//
// Isolation contract:
//   - Reads ONLY: isPremium, dailyCompleted, lastPlayDate, level sector.
//   - Does NOT read skillScore, extraMoves, hints, or any adaptive-difficulty state.
//   - Difficulty is NEVER made harder for free users or easier for premium users.
//   - All adaptive difficulty flows through AdaptiveDifficultyManager, which is blind to monetization.

/// Tracks the player's monetization state and enforces the daily mission limit.
///
/// ## Rules
/// - Earth Orbit (sector 1, levels 1–30) is always free.
/// - Lunar and beyond: free users get 6 missions on their first day, then 2 per day.
/// - Premium users have no limit.
/// - The daily counter resets automatically at the first check after midnight.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    // ── Persistence keys ──────────────────────────────────────────────────
    private enum Key {
        static let isPremium      = "entitlement.isPremium"
        static let dailyCompleted = "entitlement.dailyCompleted"
        static let lastPlayDate   = "entitlement.lastPlayDate"
        static let firstPlayDate  = "entitlement.firstPlayDate"
    }

    // ── Published state ───────────────────────────────────────────────────
    @Published private(set) var isPremium:      Bool
    @Published private(set) var dailyCompleted: Int

    private var lastPlayDate: Date

    /// Date of the player's first mission outside Earth Orbit (nil if none yet).
    private var firstPlayDate: Date?

    /// First-day limit (generous trial) vs subsequent-day limit.
    static let firstDayLimit   = 6
    static let standardLimit   = 2

    /// Current daily limit — 6 on the first day, 2 on every subsequent day.
    var dailyLimit: Int {
        guard let first = firstPlayDate else { return Self.firstDayLimit }
        return Calendar.current.isDate(first, inSameDayAs: Date()) ? Self.firstDayLimit : Self.standardLimit
    }

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        let d          = UserDefaults.standard
        isPremium      = d.bool(forKey: Key.isPremium)
        dailyCompleted = d.integer(forKey: Key.dailyCompleted)
        lastPlayDate   = (d.object(forKey: Key.lastPlayDate) as? Date) ?? Date()
        firstPlayDate  = d.object(forKey: Key.firstPlayDate) as? Date
    }

    // MARK: - Computed

    var remainingToday: Int {
        isPremium ? Int.max : max(0, dailyLimit - dailyCompleted)
    }

    var dailyLimitReached: Bool {
        !isPremium && dailyCompleted >= dailyLimit
    }

    // MARK: - Public API

    /// Returns `true` if the player is allowed to start this level right now.
    /// Earth Orbit (sector 1) is always permitted.
    func canPlay(_ level: Level) -> Bool {
        resetIfNewDay()
        let sectorID = SpatialRegion.catalog
            .first { $0.levelRange.contains(level.id) }?.id ?? 1
        if sectorID == 1 { return true }   // Earth Orbit — always free
        return !dailyLimitReached
    }

    /// Returns `true` if the player is allowed to start the mission that follows `level`.
    /// Convenience wrapper around `canPlay(_:)` for sequential campaign flow.
    func canPlayNextMission(after level: Level) -> Bool {
        let nextId = level.id + 1
        guard let next = LevelGenerator.levels.first(where: { $0.id == nextId }) else {
            return false    // no next level — campaign complete
        }
        return canPlay(next)
    }

    /// Call when a non-intro mission outside Earth Orbit is won.
    /// Increments the daily counter for free users.
    func recordMissionCompleted(_ level: Level) {
        guard !isPremium else { return }
        let sectorID = SpatialRegion.catalog
            .first { $0.levelRange.contains(level.id) }?.id ?? 1
        guard sectorID > 1 else { return }  // Earth Orbit doesn't consume quota
        resetIfNewDay()
        // Record the very first play date (sets the "first day" generous limit)
        if firstPlayDate == nil {
            firstPlayDate = Date()
        }
        dailyCompleted += 1
        save()
    }

    // MARK: - Dev / StoreKit stub

    /// Toggle premium (dev menu + future StoreKit receipt validation).
    func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: Key.isPremium)
    }

    /// Reset the daily counter to zero (dev helper).
    func resetDailyCount() {
        dailyCompleted = 0
        lastPlayDate   = Date()
        save()
    }

    // MARK: - Private

    @discardableResult
    private func resetIfNewDay() -> Bool {
        guard !Calendar.current.isDate(lastPlayDate, inSameDayAs: Date()) else {
            return false
        }
        dailyCompleted = 0
        lastPlayDate   = Date()
        save()
        return true
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(isPremium,      forKey: Key.isPremium)
        d.set(dailyCompleted, forKey: Key.dailyCompleted)
        d.set(lastPlayDate,   forKey: Key.lastPlayDate)
        if let first = firstPlayDate {
            d.set(first, forKey: Key.firstPlayDate)
        }
    }
}
