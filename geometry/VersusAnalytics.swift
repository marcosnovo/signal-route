import Foundation
import os.log

// MARK: - VersusAnalytics
/// Lightweight analytics for Versus mode — isolated from campaign analytics.
///
/// ## Architecture
///   - Singleton: `VersusAnalytics.shared`
///   - All events written to `os_log` with category "versus"
///   - In-memory event log (last 50) for DevMenu inspection
///   - Pluggable backend via `VersusAnalyticsBackend` protocol
///   - Zero writes to game stores — read-only context capture
///
/// ## Threading
///   All public API on `@MainActor`.
@MainActor
final class VersusAnalytics {

    static let shared = VersusAnalytics()

    // ── Backend ──────────────────────────────────────────────────────────
    var backend: VersusAnalyticsBackend = ConsoleVersusBackend()

    // ── In-memory event log (DevMenu) ────────────────────────────────────
    private(set) var recentEvents: [(name: String, timestamp: Date, properties: [String: Any])] = []
    private let maxRecentEvents = 50

    // ── Aggregate counters ───────────────────────────────────────────────
    private(set) var totalSearches: Int = 0
    private(set) var totalMatchesFound: Int = 0
    private(set) var totalGamesPlayed: Int = 0
    private(set) var totalWins: Int = 0
    private(set) var totalLosses: Int = 0
    private(set) var totalDraws: Int = 0
    private(set) var totalDisconnects: Int = 0

    // ── Timing ───────────────────────────────────────────────────────────
    private var searchStartTime: Date?
    private var gameStartTime: Date?

    private init() {}

    // MARK: - Event API

    /// User tapped "FIND MATCH" button on lobby.
    func trackCTATap(gcAuthenticated: Bool) {
        track("versus_cta_tap", [
            "game_center_authenticated": gcAuthenticated
        ])
    }

    /// Matchmaking search began.
    func trackMatchmakingStarted() {
        searchStartTime = Date()
        totalSearches += 1
        track("versus_matchmaking_started", [:])
    }

    /// User cancelled matchmaking search.
    func trackMatchmakingCancelled() {
        let duration = searchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        searchStartTime = nil
        track("versus_matchmaking_cancelled", [
            "matchmaking_duration_seconds": round(duration * 10) / 10
        ])
    }

    /// Match found — opponent connected.
    func trackMatchFound(seed: UInt64, isHost: Bool, opponent: String) {
        let duration = searchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        searchStartTime = nil
        totalMatchesFound += 1
        track("versus_match_found", [
            "matchmaking_duration_seconds": round(duration * 10) / 10,
            "seed": seed,
            "is_host": isHost,
            "opponent": opponent
        ])
    }

    /// Gameplay started (30s clock running).
    func trackMatchStarted(seed: UInt64) {
        gameStartTime = Date()
        totalGamesPlayed += 1
        track("versus_match_started", [
            "seed": seed
        ])
    }

    /// Match completed with a definitive result.
    func trackMatchCompleted(result: String, localMoves: Int, remoteMoves: Int, seed: UInt64, timeRemaining: Int) {
        let duration = gameStartTime.map { Date().timeIntervalSince($0) } ?? 0
        gameStartTime = nil

        switch result {
        case "win", "win_by_disconnect":  totalWins += 1
        case "lose", "lose_by_disconnect": totalLosses += 1
        case "draw": totalDraws += 1
        default: break
        }

        track("versus_match_completed", [
            "result": result,
            "match_duration_seconds": round(duration * 10) / 10,
            "local_moves": localMoves,
            "remote_moves": remoteMoves,
            "seed": seed,
            "time_remaining": timeRemaining
        ])
    }

    /// Opponent disconnected mid-match.
    func trackMatchDisconnected(phase: String, seed: UInt64) {
        totalDisconnects += 1
        track("versus_match_disconnected", [
            "disconnect_phase": phase,
            "seed": seed
        ])
    }

    /// Local player requested a rematch.
    func trackRematchRequested() {
        track("versus_rematch_requested", [:])
    }

    /// Both players agreed to rematch — new round starting.
    func trackRematchAccepted() {
        track("versus_rematch_accepted", [:])
    }

    // MARK: - Computed

    var winRate: Double {
        let total = totalWins + totalLosses + totalDraws
        guard total > 0 else { return 0 }
        return Double(totalWins) / Double(total)
    }

    // MARK: - Private

    private func track(_ event: String, _ properties: [String: Any]) {
        recentEvents.append((name: event, timestamp: Date(), properties: properties))
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst()
        }
        backend.track(event: event, properties: properties)
    }
}

// MARK: - Backend Protocol

protocol VersusAnalyticsBackend {
    func track(event: String, properties: [String: Any])
}

// MARK: - Console Backend (DEBUG)

struct ConsoleVersusBackend: VersusAnalyticsBackend {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.signalvoid", category: "versus")

    func track(event: String, properties: [String: Any]) {
        #if DEBUG
        let propsStr = properties.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " | ")
        logger.info("[VersusAnalytics] \(event) { \(propsStr) }")
        #endif
    }
}
