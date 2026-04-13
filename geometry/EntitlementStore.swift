import SwiftUI
import Combine

// MARK: - EntitlementStore

/// Tracks the player's monetization state and enforces the daily mission limit.
///
/// ## Rules
/// - Earth Orbit (sector 1, levels 1–30) is always free.
/// - Lunar and beyond: free users may complete up to 3 missions per calendar day.
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
    }

    // ── Published state ───────────────────────────────────────────────────
    @Published private(set) var isPremium:      Bool
    @Published private(set) var dailyCompleted: Int

    private var lastPlayDate: Date

    /// Maximum missions per day for free users (Lunar sector and beyond).
    static let dailyLimit = 3

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        let d          = UserDefaults.standard
        isPremium      = d.bool(forKey: Key.isPremium)
        dailyCompleted = d.integer(forKey: Key.dailyCompleted)
        lastPlayDate   = (d.object(forKey: Key.lastPlayDate) as? Date) ?? Date()
    }

    // MARK: - Computed

    var remainingToday: Int {
        isPremium ? Int.max : max(0, Self.dailyLimit - dailyCompleted)
    }

    var dailyLimitReached: Bool {
        !isPremium && dailyCompleted >= Self.dailyLimit
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

    /// Call when a non-intro mission outside Earth Orbit is won.
    /// Increments the daily counter for free users.
    func recordMissionCompleted(_ level: Level) {
        guard !isPremium else { return }
        let sectorID = SpatialRegion.catalog
            .first { $0.levelRange.contains(level.id) }?.id ?? 1
        guard sectorID > 1 else { return }  // Earth Orbit doesn't consume quota
        resetIfNewDay()
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
    }
}
