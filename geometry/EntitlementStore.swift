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
//     The first 8 game sessions are always free, regardless of outcome.
//     `freeIntroCompleted` tracks this (0–8); once it reaches 8, Phase 2 begins.
//     Both WON and FAILED sessions (with ≥1 tap) increment the counter.
//
//   Phase 2 — 24h rolling gate:
//     After the intro quota is exhausted a 24-hour cooldown starts immediately.
//     `nextPlayableDate` tracks when the player may play again.
//     When the cooldown expires the player gets 3 plays, which arms a new 24h cooldown.
//     Both WON and FAILED sessions arm the cooldown (if the player made ≥1 tap).
//
//   Premium:
//     No limits — `canPlay` always returns true.

/// Tracks the player's monetization state and enforces the mission limit.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    // ── Product constants ──────────────────────────────────────────────────
    /// Lifetime free game sessions before the 24h gate begins.
    static let freeIntroLimit = 8
    /// Plays allowed per 24h window in Phase 2.
    static let dailyLimit     = 3

    // ── Persistence keys ──────────────────────────────────────────────────
    private enum Key {
        static let isPremium          = "entitlement.isPremium"
        static let freeIntroCompleted = "entitlement.freeIntroCompleted"
        static let nextPlayableDate   = "entitlement.nextPlayableDate"
        static let dailyPlaysUsed     = "entitlement.dailyPlaysUsed"
        static let dailyWindowStart   = "entitlement.dailyWindowStart"
        static let premiumByCode      = "entitlement.premiumByCode"
        static let activeCodeID       = "entitlement.activeCodeID"
        static let cooldownArmedUptime = "entitlement.cooldownArmedUptime"
        static let dailyWindowStartUptime = "entitlement.dailyWindowStartUptime"
    }

    // ── Published state ───────────────────────────────────────────────────
    @Published private(set) var isPremium:          Bool
    /// Lifetime game sessions played during the intro grace period (caps at freeIntroLimit).
    /// Both wins and fails with ≥1 tap increment this counter.
    @Published private(set) var freeIntroCompleted: Int
    /// When set, the player must wait until this date to play again.
    @Published private(set) var nextPlayableDate:   Date?
    /// Plays used in the current 24h window (0…dailyLimit). Resets when window expires.
    @Published private(set) var dailyPlaysUsed:     Int
    /// When the current 24h window started (nil if no play yet this window).
    private var dailyWindowStart: Date?
    /// True when premium was granted via an unlock code (not a StoreKit purchase).
    @Published private(set) var premiumByCode: Bool
    /// The code string that activated premium, if applicable.
    @Published private(set) var activeCodeID:  String?

    // ── Clock-manipulation resistance ────────────────────────────────────
    /// System uptime (monotonic, user-uncontrollable) when the 24h cooldown was armed.
    /// Used to cross-check wall-clock expiry and detect clock-forward manipulation.
    /// Resets to nil when the cooldown is cleared. Stored as 0 when nil.
    private var cooldownArmedUptime: TimeInterval?
    /// System uptime when the current daily window started (partial-window protection).
    private var dailyWindowStartUptime: TimeInterval?

    // ── Init ──────────────────────────────────────────────────────────────

    private init() {
        let d              = UserDefaults.standard
        isPremium          = d.bool(forKey: Key.isPremium)
        freeIntroCompleted = d.integer(forKey: Key.freeIntroCompleted)
        nextPlayableDate   = d.object(forKey: Key.nextPlayableDate) as? Date
        dailyPlaysUsed     = d.integer(forKey: Key.dailyPlaysUsed)
        dailyWindowStart   = d.object(forKey: Key.dailyWindowStart) as? Date
        premiumByCode      = d.bool(forKey: Key.premiumByCode)
        activeCodeID       = d.string(forKey: Key.activeCodeID)
        let rawCooldownUptime = d.double(forKey: Key.cooldownArmedUptime)
        cooldownArmedUptime = rawCooldownUptime > 0 ? rawCooldownUptime : nil
        let rawWindowUptime = d.double(forKey: Key.dailyWindowStartUptime)
        dailyWindowStartUptime = rawWindowUptime > 0 ? rawWindowUptime : nil
        // Schedule automatic unlock if a cooldown was persisted from a previous session
        if nextPlayableDate != nil { scheduleUnlock() }
    }

    // MARK: - Derived state

    /// True while the player still has intro quota remaining (lifetime < 8).
    var isInIntroPhase: Bool { freeIntroCompleted < Self.freeIntroLimit }

    /// True when the cooldown has legitimately expired (or was never set).
    /// Uses monotonic uptime to cross-check wall-clock, preventing clock-forward bypass.
    var canPlayNow: Bool {
        Self.isCooldownExpired(
            nextPlayableDate: nextPlayableDate,
            cooldownArmedUptime: cooldownArmedUptime,
            now: Date(),
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
    }

    /// Seconds remaining until the 24h cooldown expires (0 when can play).
    /// Returns uptime-based remaining time when clock manipulation is detected.
    var remainingCooldown: TimeInterval {
        Self.cooldownRemaining(
            nextPlayableDate: nextPlayableDate,
            cooldownArmedUptime: cooldownArmedUptime,
            now: Date(),
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
    }

    // ── Clock-hardened pure decision functions (testable) ─────────────────

    /// Returns true if the cooldown has legitimately expired.
    ///
    /// Cross-checks wall-clock (`Date()`) against monotonic system uptime to detect
    /// clock-forward manipulation. If the wall clock says "expired" but insufficient
    /// real uptime has elapsed since the cooldown was armed, the cooldown stays active.
    ///
    /// Falls back to wall-clock only when:
    ///   - No uptime was recorded (legacy data from before this hardening)
    ///   - Device was rebooted (uptime < armedUptime — uptime counter reset)
    ///
    /// This is a pure function with no side effects — safe for unit testing.
    nonisolated static func isCooldownExpired(
        nextPlayableDate: Date?,
        cooldownArmedUptime: TimeInterval?,
        now: Date,
        systemUptime: TimeInterval
    ) -> Bool {
        guard let target = nextPlayableDate else { return true }
        guard now >= target else { return false }
        // Wall clock says expired — verify with monotonic uptime
        if let armedUptime = cooldownArmedUptime {
            if systemUptime >= armedUptime {
                // Same boot session: require real elapsed time
                return (systemUptime - armedUptime) >= 86_400
            }
            // Device rebooted (uptime < armedUptime): fall back to wall clock
        }
        // Legacy (no uptime recorded) or reboot: trust wall clock
        return true
    }

    /// Returns seconds until cooldown legitimately expires (0 when can play).
    /// Uses uptime-based calculation when clock manipulation is detected.
    ///
    /// This is a pure function with no side effects — safe for unit testing.
    nonisolated static func cooldownRemaining(
        nextPlayableDate: Date?,
        cooldownArmedUptime: TimeInterval?,
        now: Date,
        systemUptime: TimeInterval
    ) -> TimeInterval {
        guard let target = nextPlayableDate else { return 0 }
        if isCooldownExpired(
            nextPlayableDate: target,
            cooldownArmedUptime: cooldownArmedUptime,
            now: now,
            systemUptime: systemUptime
        ) { return 0 }
        // Cooldown still active — calculate remaining
        if let armedUptime = cooldownArmedUptime, systemUptime >= armedUptime {
            // Same boot session: use uptime for accurate remaining
            return max(0, 86_400 - (systemUptime - armedUptime))
        }
        // Fallback to wall-clock remaining
        return max(0, target.timeIntervalSince(now))
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
    /// - During intro phase: both WON and FAILED increment `freeIntroCompleted`.
    ///   When the last intro session is played the 24h cooldown is armed immediately.
    /// - After intro phase: both WON and FAILED consume a daily play.
    ///   When `dailyLimit` plays are consumed a 24h cooldown is armed.
    func recordAttempt(_ level: Level, didWin: Bool) {
        guard !isPremium else {
            #if DEBUG
            print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=\(didWin)) → skipped (premium)")
            #endif
            return
        }
        if isInIntroPhase {
            // Both wins and fails consume an intro slot (player had ≥1 tap — caller contract).
            freeIntroCompleted = min(freeIntroCompleted + 1, Self.freeIntroLimit)
            #if DEBUG
            print("[ENTITLEMENT] recordAttempt(id=\(level.id), win=\(didWin)) → intro consumed: \(freeIntroCompleted)/\(Self.freeIntroLimit)")
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
                if dailyWindowStart == nil {
                    dailyWindowStart       = Date()
                    dailyWindowStartUptime = ProcessInfo.processInfo.systemUptime
                }
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

    // MARK: - Cloud sync

    /// Snapshot of the current entitlement state for cloud save.
    var currentSnapshot: EntitlementSnapshot {
        EntitlementSnapshot(
            isPremium:          isPremium,
            premiumByCode:      premiumByCode,
            activeCodeID:       activeCodeID,
            freeIntroCompleted: freeIntroCompleted,
            dailyPlaysUsed:     dailyPlaysUsed,
            nextPlayableDate:   nextPlayableDate,
            dailyWindowStart:   dailyWindowStart
        )
    }

    /// Apply a merged entitlement snapshot from the cloud.
    ///
    /// The caller (`CloudSaveManager`) has already merged local and cloud snapshots
    /// using `mergeEntitlements(local:cloud:)`, so this method simply applies the result.
    ///
    /// Device-specific uptime fields are cleared since the cloud values would be
    /// from a different device's monotonic clock.
    func applyCloudState(_ snapshot: EntitlementSnapshot) {
        isPremium          = snapshot.isPremium
        premiumByCode      = snapshot.premiumByCode
        activeCodeID       = snapshot.activeCodeID
        freeIntroCompleted = snapshot.freeIntroCompleted
        dailyPlaysUsed     = snapshot.dailyPlaysUsed
        nextPlayableDate   = snapshot.nextPlayableDate
        dailyWindowStart   = snapshot.dailyWindowStart

        // Uptime fields are device-specific — clear them so we fall back to wall-clock
        cooldownArmedUptime    = nil
        dailyWindowStartUptime = nil

        save()

        // Re-schedule automatic unlock if a cooldown is now active
        if nextPlayableDate != nil { scheduleUnlock() }

        #if DEBUG
        print("[ENTITLEMENT] applyCloudState → premium=\(isPremium) intro=\(freeIntroCompleted) plays=\(dailyPlaysUsed) cooldown=\(nextPlayableDate?.description ?? "nil")")
        #endif
    }

    // MARK: - Unlock code activation

    /// Grant premium access via an unlock code.
    ///
    /// Sets `isPremium = true`, records the source code, clears any active cooldown,
    /// and cancels pending cooldown notifications. Safe to call when the player already
    /// has premium via a real purchase — it will not downgrade or change the source flag
    /// in that case (StoreKit-granted premium takes precedence).
    func activateByCode(_ codeID: String) {
        guard !isPremium else { return }   // real purchase already active — no-op
        isPremium     = true
        premiumByCode = true
        activeCodeID  = codeID
        save()
        clearCooldown()   // also cancels cooldown notifications
        #if DEBUG
        print("[ENTITLEMENT] activateByCode(\(codeID)) → premium granted via unlock code")
        #endif
    }

    /// Remove code-granted premium. Only valid when `premiumByCode == true`.
    /// Has no effect if premium was granted by a real StoreKit purchase.
    func revokeCodePremium() {
        guard premiumByCode else { return }
        isPremium     = false
        premiumByCode = false
        activeCodeID  = nil
        save()
        #if DEBUG
        print("[ENTITLEMENT] revokeCodePremium → code premium removed")
        #endif
    }

    // MARK: - Dev helpers

    /// Set premium state from a StoreKit purchase (or dev toggle).
    ///
    /// When granting premium (`true`):
    ///   - Clears code-premium flags (purchase supersedes code-granted premium)
    ///   - Clears any active cooldown (premium removes all gates)
    ///   - Cancels pending cooldown notification
    ///
    /// When revoking premium (`false`):
    ///   - Clears code-premium flags (avoids stale state)
    ///
    /// This ensures the premium source is always unambiguous:
    ///   `isPremium && !premiumByCode` = StoreKit purchase
    ///   `isPremium && premiumByCode`  = unlock code
    func setPremium(_ value: Bool) {
        isPremium     = value
        premiumByCode = false
        activeCodeID  = nil
        save()
        if value { clearCooldown() }
    }

    /// Clear any active cooldown (equivalent to old resetDailyCount).
    func resetDailyCount() {
        clearCooldown()
    }

    /// Reset the lifetime intro counter to 0 (returns player to Phase 1).
    func resetIntroCount() {
        freeIntroCompleted  = 0
        nextPlayableDate    = nil
        cooldownArmedUptime = nil
        save()
    }

    /// Set the intro counter to an explicit value (clamped 0…freeIntroLimit).
    /// Automatically clears any cooldown when returning to intro phase.
    func setFreeIntroCompleted(_ value: Int) {
        freeIntroCompleted = max(0, min(value, Self.freeIntroLimit))
        if freeIntroCompleted < Self.freeIntroLimit {
            nextPlayableDate    = nil  // back in intro — no cooldown
            cooldownArmedUptime = nil
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
            dailyPlaysUsed   = Self.dailyLimit
            dailyWindowStart = dailyWindowStart ?? Date()
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
        nextPlayableDate       = nil
        cooldownArmedUptime    = nil
        dailyPlaysUsed         = 0
        dailyWindowStart       = nil
        dailyWindowStartUptime = nil
        save()
        NotificationManager.shared.cancelCooldown()
    }

    /// If the stored cooldown date has legitimately passed, clear it so `canPlayNow` returns true.
    /// Also resets the daily counter if the 24h window (partial or full) has legitimately expired.
    /// Uses monotonic uptime to prevent clock-forward bypass.
    /// Call this on app foreground / view appear to handle offline expiry.
    func checkExpiry() {
        let now    = Date()
        let uptime = ProcessInfo.processInfo.systemUptime

        // Full cooldown expired (player hit the daily limit)
        if nextPlayableDate != nil {
            if Self.isCooldownExpired(
                nextPlayableDate: nextPlayableDate,
                cooldownArmedUptime: cooldownArmedUptime,
                now: now,
                systemUptime: uptime
            ) {
                nextPlayableDate       = nil
                cooldownArmedUptime    = nil
                dailyPlaysUsed         = 0
                dailyWindowStart       = nil
                dailyWindowStartUptime = nil
                save()
                #if DEBUG
                print("[ENTITLEMENT] checkExpiry → cooldown legitimately expired, cleared")
                #endif
            } else {
                #if DEBUG
                print("[ENTITLEMENT] checkExpiry → wall clock says expired but uptime disagrees — cooldown kept")
                #endif
            }
            return
        }
        // Partial window expired (player used 1–2 plays but never hit the limit)
        if let windowStart = dailyWindowStart {
            let windowExpired: Bool
            if let windowUptime = dailyWindowStartUptime, uptime >= windowUptime {
                // Same boot: check both wall clock and uptime
                windowExpired = now >= windowStart.addingTimeInterval(86_400)
                    && (uptime - windowUptime) >= 86_400
            } else {
                // Rebooted or legacy: trust wall clock
                windowExpired = now >= windowStart.addingTimeInterval(86_400)
            }
            if windowExpired {
                dailyPlaysUsed         = 0
                dailyWindowStart       = nil
                dailyWindowStartUptime = nil
                save()
            }
        }
    }

    // MARK: - Private

    private func armCooldown() {
        nextPlayableDate    = Date().addingTimeInterval(86_400)   // 24 hours
        cooldownArmedUptime = ProcessInfo.processInfo.systemUptime
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
        d.set(premiumByCode,      forKey: Key.premiumByCode)
        d.set(activeCodeID,       forKey: Key.activeCodeID)
        d.set(cooldownArmedUptime ?? 0,    forKey: Key.cooldownArmedUptime)
        d.set(dailyWindowStartUptime ?? 0, forKey: Key.dailyWindowStartUptime)
    }

    // MARK: - Dev diagnostics (DEBUG only)

    #if DEBUG
    /// Diagnostic snapshot for DevMenuView — shows clock-hardening state.
    struct ClockDiagnostics {
        let wallClockNow: Date
        let systemUptime: TimeInterval
        let cooldownTarget: Date?
        let armedUptime: TimeInterval?
        let uptimeElapsed: TimeInterval?
        let wallClockSaysExpired: Bool
        let uptimeSaysExpired: Bool
        let effectiveDecision: Bool
        let clockManipulationSuspected: Bool
    }

    var clockDiagnostics: ClockDiagnostics {
        let now    = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let wallExpired = nextPlayableDate.map { now >= $0 } ?? true
        let uptimeExpired: Bool
        let manipulation: Bool
        if let armed = cooldownArmedUptime, let _ = nextPlayableDate {
            if uptime >= armed {
                uptimeExpired = (uptime - armed) >= 86_400
                manipulation = wallExpired && !uptimeExpired
            } else {
                // Rebooted — can't verify
                uptimeExpired = wallExpired
                manipulation = false
            }
        } else {
            uptimeExpired = wallExpired
            manipulation = false
        }
        return ClockDiagnostics(
            wallClockNow: now,
            systemUptime: uptime,
            cooldownTarget: nextPlayableDate,
            armedUptime: cooldownArmedUptime,
            uptimeElapsed: cooldownArmedUptime.map { uptime >= $0 ? uptime - $0 : nil } ?? nil,
            wallClockSaysExpired: wallExpired,
            uptimeSaysExpired: uptimeExpired,
            effectiveDecision: canPlayNow,
            clockManipulationSuspected: manipulation
        )
    }
    #endif
}
