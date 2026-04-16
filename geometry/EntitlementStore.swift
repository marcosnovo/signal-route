import SwiftUI
import Combine

// MARK: - EntitlementStore
//
// This is the ONLY place in the codebase that makes free/premium decisions.
//
// Isolation contract:
//   - Reads ONLY: isPremium, freeIntroCompleted, dailyCompleted, lastPlayDate.
//   - Does NOT read skillScore, extraMoves, hints, sector ID, or any adaptive-difficulty state.
//   - Difficulty is NEVER made harder for free users or easier for premium users.
//   - All adaptive difficulty flows through AdaptiveDifficultyManager, which is blind to monetization.
//
// ## Free-user access model
//   Phase 1 — Intro (lifetime):
//     The first 5 missions ever completed are always free, regardless of time.
//     `freeIntroCompleted` tracks this (0–5); once it reaches 5, Phase 2 begins.
//
//   Phase 2 — Daily gate:
//     After the intro quota is exhausted, free users can complete up to 3 missions per day.
//     `dailyCompleted` tracks this and resets at midnight.
//
//   Premium:
//     No limits — `canPlay` always returns true.

/// Tracks the player's monetization state and enforces the mission limit.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    // ── Product constants ──────────────────────────────────────────────────
    /// Lifetime free missions before daily gating begins.
    static let freeIntroLimit = 5
    /// Max missions per day once the intro quota is exhausted.
    static let dailyLimit     = 3

    // ── Persistence keys ──────────────────────────────────────────────────
    private enum Key {
        static let isPremium          = "entitlement.isPremium"
        static let freeIntroCompleted = "entitlement.freeIntroCompleted"
        static let dailyCompleted     = "entitlement.dailyCompleted"
        static let lastPlayDate       = "entitlement.lastPlayDate"
    }

    // ── Published state ───────────────────────────────────────────────────
    @Published private(set) var isPremium:          Bool
    /// Lifetime missions completed during the intro grace period (caps at freeIntroLimit).
    @Published private(set) var freeIntroCompleted: Int
    /// Missions completed today, counted after the intro quota is exhausted.
    @Published private(set) var dailyCompleted:     Int

    private var lastPlayDate: Date

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        let d               = UserDefaults.standard
        isPremium           = d.bool(forKey: Key.isPremium)
        freeIntroCompleted  = d.integer(forKey: Key.freeIntroCompleted)
        dailyCompleted      = d.integer(forKey: Key.dailyCompleted)
        lastPlayDate        = (d.object(forKey: Key.lastPlayDate) as? Date) ?? Date()
    }

    // MARK: - Derived state

    /// True while the player still has intro quota remaining (lifetime < 5).
    var isInIntroPhase: Bool { freeIntroCompleted < Self.freeIntroLimit }

    /// Remaining plays before the gate fires.
    /// During intro: slots left in the intro quota.
    /// After intro: slots remaining today.
    var remainingToday: Int {
        if isPremium { return Int.max }
        if isInIntroPhase { return Self.freeIntroLimit - freeIntroCompleted }
        return max(0, Self.dailyLimit - dailyCompleted)
    }

    /// True when the free player cannot play another mission right now.
    var dailyLimitReached: Bool {
        guard !isPremium else { return false }
        if isInIntroPhase { return false }   // intro never blocks
        return dailyCompleted >= Self.dailyLimit
    }

    /// Human-readable reason why the player is blocked (nil if they can play).
    var reasonBlocked: String? {
        guard !isPremium, dailyLimitReached else { return nil }
        return "Daily limit (\(Self.dailyLimit)/day)"
    }

    // MARK: - Public API

    /// Returns `true` if the player may start any mission right now.
    /// Gate is purely count-based — no sector exception.
    func canPlay(_ level: Level) -> Bool {
        resetIfNewDay()
        if isPremium {
            #if DEBUG
            print("[ENTITLEMENT] canPlay(id=\(level.id)) → ALLOWED (premium)")
            #endif
            return true
        }
        if isInIntroPhase {
            #if DEBUG
            print("[ENTITLEMENT] canPlay(id=\(level.id)) → ALLOWED (intro: \(freeIntroCompleted)/\(Self.freeIntroLimit))")
            #endif
            return true
        }
        let blocked = dailyLimitReached
        #if DEBUG
        print("[ENTITLEMENT] canPlay(id=\(level.id)) → \(blocked ? "BLOCKED" : "ALLOWED") (daily: \(dailyCompleted)/\(Self.dailyLimit))")
        #endif
        return !blocked
    }

    /// Convenience: can the player start the mission that follows `level`?
    func canPlayNextMission(after level: Level) -> Bool {
        let nextId = level.id + 1
        guard let next = LevelGenerator.levels.first(where: { $0.id == nextId }) else {
            return false    // no next level — campaign complete
        }
        return canPlay(next)
    }

    /// Call when a non-intro mission is successfully completed.
    /// Increments the correct counter: intro quota first, then daily.
    func recordMissionCompleted(_ level: Level) {
        guard !isPremium else {
            #if DEBUG
            print("[ENTITLEMENT] recordCompleted(id=\(level.id)) → skipped (premium)")
            #endif
            return
        }
        if isInIntroPhase {
            freeIntroCompleted = min(freeIntroCompleted + 1, Self.freeIntroLimit)
            #if DEBUG
            print("[ENTITLEMENT] recordCompleted(id=\(level.id)) → intro consumed: \(freeIntroCompleted)/\(Self.freeIntroLimit)")
            #endif
        } else {
            resetIfNewDay()
            dailyCompleted += 1
            #if DEBUG
            print("[ENTITLEMENT] recordCompleted(id=\(level.id)) → daily consumed: \(dailyCompleted)/\(Self.dailyLimit) | limitReached=\(dailyLimitReached)")
            #endif
        }
        save()
    }

    // MARK: - Dev helpers

    /// Toggle premium state.
    func setPremium(_ value: Bool) {
        isPremium = value
        save()
    }

    /// Reset the daily counter to 0.
    func resetDailyCount() {
        dailyCompleted = 0
        lastPlayDate   = Date()
        save()
    }

    /// Reset the lifetime intro counter to 0 (returns player to Phase 1).
    func resetIntroCount() {
        freeIntroCompleted = 0
        save()
    }

    /// Set the intro counter to an explicit value (clamped 0…freeIntroLimit).
    func setFreeIntroCompleted(_ value: Int) {
        freeIntroCompleted = max(0, min(value, Self.freeIntroLimit))
        save()
    }

    /// Set the daily counter to an explicit value (clamped 0…dailyLimit).
    func setDailyCompleted(_ value: Int) {
        resetIfNewDay()
        dailyCompleted = max(0, min(value, Self.dailyLimit))
        save()
    }

    // MARK: - Private

    @discardableResult
    private func resetIfNewDay() -> Bool {
        guard !Calendar.current.isDate(lastPlayDate, inSameDayAs: Date()) else { return false }
        dailyCompleted = 0
        lastPlayDate   = Date()
        save()
        return true
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(isPremium,          forKey: Key.isPremium)
        d.set(freeIntroCompleted, forKey: Key.freeIntroCompleted)
        d.set(dailyCompleted,     forKey: Key.dailyCompleted)
        d.set(lastPlayDate,       forKey: Key.lastPlayDate)
    }
}
