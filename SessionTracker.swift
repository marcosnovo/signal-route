import Foundation

// MARK: - SessionTracker
/// Tracks session-level engagement metrics for analytics.
///
/// Lives for the duration of the app process — never reset between levels or missions.
/// Lightweight: only incremented by GameViewModel and GameView, read by MonetizationAnalytics.
///
/// Isolation contract:
///   - Reads NOTHING from EntitlementStore, ProgressionStore, or AdaptiveDifficultyManager.
///   - Pure event counter — no game logic or monetization decisions.
final class SessionTracker {

    static let shared = SessionTracker()
    private init() {}

    // ── Session time ──────────────────────────────────────────────────────────
    /// Wall-clock time when this app session began (process launch).
    let sessionStart = Date()

    var sessionDurationSeconds: Int {
        Int(Date().timeIntervalSince(sessionStart))
    }

    // ── Win streak ────────────────────────────────────────────────────────────
    /// Consecutive wins in this session without a loss or abandon in between.
    /// Resets to 0 on the first failure or abandon; increments on every win.
    private(set) var streakCount: Int = 0

    // ── Session failures ──────────────────────────────────────────────────────
    /// Total number of losses triggered since the session started (across all levels).
    private(set) var failuresInSession: Int = 0

    // MARK: - Recording

    func recordWin() {
        streakCount += 1
    }

    func recordFailure() {
        failuresInSession += 1
        streakCount = 0
    }

    func recordAbandon() {
        streakCount = 0
    }

    // ── Debug overrides ──────────────────────────────────────────────────────

    #if DEBUG
    /// Force-set failure count for dev scenario testing.
    func overrideFailuresInSession(_ count: Int) {
        failuresInSession = count
        if count > 0 { streakCount = 0 }
    }

    /// Force-set win streak count for dev scenario testing.
    func overrideStreakCount(_ count: Int) {
        streakCount = count
    }
    #endif
}
