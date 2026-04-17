import SwiftUI
import Combine

// MARK: - EntitlementStore
//
// This is the ONLY place in the codebase that makes free/premium decisions.
//
// Isolation contract:
//   - Reads ONLY: isPremium, freeIntroCompleted, nextPlayableDate.
//   - Does NOT read skillScore, extraMoves, hints, sector ID, or any adaptive-difficulty state.
//   - Difficulty is NEVER made harder for free users or easier for premium users.
//   - All adaptive difficulty flows through AdaptiveDifficultyManager, which is blind to monetization.
//
// ## Free-user access model
//   Phase 1 — Intro (lifetime):
//     The first 3 missions won are always free, regardless of time.
//     `freeIntroCompleted` tracks this (0–3); once it reaches 3, Phase 2 begins.
//     During this phase only WON sessions increment the counter; FAILs are free.
//
//   Phase 2 — 24h rolling gate:
//     After the intro quota is exhausted a 24-hour cooldown starts immediately.
//     `nextPlayableDate` tracks when the player may play again.
//     When the cooldown expires the player gets one more play, which arms a new 24h cooldown.
//     Both WON and FAILED sessions arm the cooldown (if the player made ≥1 tap).
//
//   Premium:
//     No limits — `canPlay` always returns true.

/// Tracks the player's monetization state and enforces the mission limit.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    // ── Product constants ──────────────────────────────────────────────────
    /// Lifetime free missions before the 24h gate begins.
    static let freeIntroLimit = 3
    /// Plays allowed per 24h window in Phase 2.
    static let dailyLimit     = 3

    // ── Persistence keys ──────────────────────────────────────────────────
    private enum Key {
        static let isPremium          = "entitlement.isPremium"
        static let freeIntroCompleted = "entitlement.freeIntroCompleted"
        static let nextPlayableDate   = "entitlement.nextPlayableDate"
        static let dailyPlaysUsed     = "entitlement.dailyPlaysUsed"
        static let dailyWindowStart   = "entitlement.dailyWindowStart"
    }

    // ── Published state ───────────────────────────────────────────────────
    @Published private(set) var isPremium:          Bool
    /// Lifetime missions won during the intro grace period (caps at freeIntroLimit).
    @Published private(set) var freeIntroCompleted: Int
    /// When set, the player must wait until this date to play again.
    @Published private(set) var nextPlayableDate:   Date?
    /// Plays used in the current 24h window (0…dailyLimit). Resets when window expires.
    @Published private(set) var dailyPlaysUsed:     Int
    /// When the current 24h window started (nil if no play yet this window).
    private var dailyWindowStart: Date?

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        let d              = UserDefaults.standard
        isPremium          = d.bool(forKey: Key.isPremium)
        freeIntroCompleted = d.integer(forKey: Key.freeIntroCompleted)
        nextPlayableDate   = d.object(forKey: Key.nextPlayableDate) as? Date
        dailyPlaysUsed     = d.integer(forKey: Key.dailyPlaysUsed)
        dailyWindowStart   = d.object(forKey: Key.dailyWindowStart) as? Date
        // Schedule automatic unlock if a cooldown was persisted from a previous session
        if nextPlayableDate != nil { scheduleUnlock() }
    }

    // MARK: - Derived state

    /// True while the player still has intro quota remaining (lifetime < 3).
    var isInIntroPhase: Bool { freeIntroCompleted < Self.freeIntroLimit }

    /// True when the cooldown has not yet expired (or was never set).
    var canPlayNow: Bool {
        guard let date = nextPlayableDate else { return true }
        return Date() >= date
    }

    /// Seconds remaining until the 24h cooldown expires (0 when can play).
    var remainingCooldown: TimeInterval {
        guard let date = nextPlayableDate else { return 0 }
        return max(0, date.timeIntervalSinceNow)
    }

    // ── Backward-compat derived state (kept for existing call sites) ───────

    /// How many plays have been used in the current daily window (0…dailyLimit).
    var dailyAttemptsUsed: Int {
        guard !isPremium, !isInIntroPhase else { return 0 }
        return dailyPlaysUsed
    }

    /// Remaining plays before the daily gate fires.
    var remainingToday: Int {
        if isPremium { return Int.max }
        if isInIntroPhase { return Self.freeIntroLimit - freeIntroCompleted }
        return max(0, Self.dailyLimit - dailyPlaysUsed)
    }

    /// True when the free player cannot play another mission right now.
    var dailyLimitReached: Bool {
        guard !isPremium else { return false }
        if isInIntroPhase { return false }
        return !canPlayNow
    }

    /// Human-readable reason why the player is blocked (nil if they can play).
    var reasonBlocked: String? {
        guard !isPremium, dailyLimitReached else { return nil }
        return "24h cooldown active"
    }

    // MARK: - Public API

    /// Returns `true` if the player may start any mission right now.
    func canPlay(_ level: Level) -> Bool {
        checkExpiry()
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
        let allowed = canPlayNow
        #if DEBUG
        print("[ENTITLEMENT] canPlay(id=\(level.id)) → \(allowed ? "ALLOWED" : "BLOCKED") (cooldown: \(allowed ? "expired" : "active"))")
        #endif
        return allowed
    }

    /// Convenience: can the player start the mission that follows `level`?
    func canPlayNextMission(after level: Level) -> Bool {
        let nextId = level.id + 1
        guard let next = LevelGenerator.levels.first(where: { $0.id == nextId }) else {
            return false
        }
        return canPlay(next)
    }

    /// Call when a game session ends (WON or FAILED) and the player made ≥1 tap.
    ///
    /// - During intro phase: only `didWin == true` increments `freeIntroCompleted`.
    ///   When the last intro mission is won the 24h cooldown is armed immediately.
    /// - After intro phase: both WON and FAILED arm a new 24h cooldown.
    func recordAttempt(_ level: Level, didWin: Bool) {
        guard !isPremium else {
            #if DEBUG
            print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=\(didWin)) → skipped (premium)")
            #endif
            return
        }
        if isInIntroPhase {
            guard didWin else {
                #if DEBUG
                print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=false) → intro phase, failure is free")
                #endif
                return
            }
            freeIntroCompleted = min(freeIntroCompleted + 1, Self.freeIntroLimit)
            #if DEBUG
            print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=true) → intro consumed: \(freeIntroCompleted)/\(Self.freeIntroLimit)")
            #endif
            if freeIntroCompleted >= Self.freeIntroLimit {
                // Intro exhausted — arm the first 24h gate immediately
                armCooldown()
                #if DEBUG
                print("[ENTITLEMENT] Intro complete → 24h cooldown armed until \(nextPlayableDate!)")
                #endif
            } else {
                save()
            }
        } else {
            checkExpiry()
            if canPlayNow {
                // Start the daily window on the first play
                if dailyWindowStart == nil { dailyWindowStart = Date() }
                dailyPlaysUsed = min(dailyPlaysUsed + 1, Self.dailyLimit)
                #if DEBUG
                print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=\(didWin)) → daily play \(dailyPlaysUsed)/\(Self.dailyLimit)")
                #endif
                if dailyPlaysUsed >= Self.dailyLimit {
                    // All daily plays consumed — arm 24h cooldown
                    armCooldown()
                    #if DEBUG
                    print("[ENTITLEMENT] Daily limit reached → cooldown until \(nextPlayableDate!)")
                    #endif
                } else {
                    save()
                }
            } else {
                #if DEBUG
                print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=\(didWin)) → cooldown active, skipped")
                #endif
            }
        }
    }

    // MARK: - Dev helpers

    /// Toggle premium state.
    func setPremium(_ value: Bool) {
        isPremium = value
        save()
        // Premium removes all gates — cancel any pending "playable again" notification
        if value { NotificationManager.shared.cancelCooldown() }
    }

    /// Clear any active cooldown (equivalent to old resetDailyCount).
    func resetDailyCount() {
        clearCooldown()
    }

    /// Reset the lifetime intro counter to 0 (returns player to Phase 1).
    func resetIntroCount() {
        freeIntroCompleted = 0
        nextPlayableDate   = nil
        save()
    }

    /// Set the intro counter to an explicit value (clamped 0…freeIntroLimit).
    /// Automatically clears any cooldown when returning to intro phase.
    func setFreeIntroCompleted(_ value: Int) {
        freeIntroCompleted = max(0, min(value, Self.freeIntroLimit))
        if freeIntroCompleted < Self.freeIntroLimit {
            nextPlayableDate = nil  // back in intro — no cooldown
        }
        save()
    }

    /// Set the daily-attempts counter to an explicit value for dev/test simulation.
    ///
    /// - 0: clears cooldown and resets counter (player can play again today)
    /// - 1…(dailyLimit-1): sets counter without arming cooldown (player has plays left today)
    /// - ≥ dailyLimit: arms a 24h cooldown (player is blocked)
    ///
    /// Automatically promotes to Phase 2 when value > 0 (daily plays are Phase-2 only).
    func setDailyAttemptsUsed(_ value: Int) {
        let clamped = max(0, min(value, Self.dailyLimit))
        // Daily plays only exist in Phase 2 — promote if needed
        if clamped > 0 && freeIntroCompleted < Self.freeIntroLimit {
            freeIntroCompleted = Self.freeIntroLimit
        }
        if clamped >= Self.dailyLimit {
            armCooldown()
        } else if clamped == 0 {
            clearCooldown()
        } else {
            // Intermediate: set counter directly, no cooldown armed
            dailyPlaysUsed   = clamped
            dailyWindowStart = Date()
            nextPlayableDate = nil
            save()
        }
    }

    /// Force-arm a 24h cooldown right now (dev / simulation helper).
    func forceCooldown() {
        setFreeIntroCompleted(Self.freeIntroLimit)  // ensure Phase 2
        armCooldown()
    }

    /// Clear any active cooldown and reset the daily counter so the player can play immediately.
    func clearCooldown() {
        nextPlayableDate = nil
        dailyPlaysUsed   = 0
        dailyWindowStart = nil
        save()
        NotificationManager.shared.cancelCooldown()
    }

    /// If the stored cooldown date has passed, clear it so `canPlayNow` returns true.
    /// Also resets the daily counter if the 24h window (partial or full) has expired.
    /// Call this on app foreground / view appear to handle offline expiry.
    func checkExpiry() {
        let now = Date()
        // Full cooldown expired (player hit the daily limit)
        if let date = nextPlayableDate, now >= date {
            nextPlayableDate = nil
            dailyPlaysUsed   = 0
            dailyWindowStart = nil
            save()
            return
        }
        // Partial window expired (player used 1–2 plays but never hit the limit)
        if let windowStart = dailyWindowStart,
           now >= windowStart.addingTimeInterval(86_400) {
            dailyPlaysUsed   = 0
            dailyWindowStart = nil
            save()
        }
    }

    // MARK: - Private

    private func armCooldown() {
        nextPlayableDate = Date().addingTimeInterval(86_400)   // 24 hours
        save()
        scheduleUnlock()
        // Schedule local notification for when the cooldown lifts
        NotificationManager.shared.scheduleCooldown(
            at: nextPlayableDate!,
            language: SettingsStore.shared.language
        )
    }

    /// Schedules an async task that clears the cooldown when it expires.
    /// Safe to call multiple times — each call targets the current `nextPlayableDate`.
    private func scheduleUnlock() {
        guard let date = nextPlayableDate else { return }
        let delay = max(0, date.timeIntervalSinceNow)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.checkExpiry()
        }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(isPremium,          forKey: Key.isPremium)
        d.set(freeIntroCompleted, forKey: Key.freeIntroCompleted)
        d.set(nextPlayableDate,   forKey: Key.nextPlayableDate)
        d.set(dailyPlaysUsed,     forKey: Key.dailyPlaysUsed)
        d.set(dailyWindowStart,   forKey: Key.dailyWindowStart)
    }
}
