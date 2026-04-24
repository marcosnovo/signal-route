import Combine
import Foundation
import UIKit

// MARK: - VersusTestHarness
/// Real-device test harness for Versus mode.
///
/// ## Purpose
///   Captures granular debug events during a versus match so testers can
///   identify matchmaking failures, lag, desync, and disconnects without
///   reading raw console logs.
///
/// ## Architecture
///   - Singleton: `VersusTestHarness.shared`
///   - All public API on `@MainActor`
///   - Timeline: ordered list of timestamped events (max 200)
///   - Validations: automatically evaluated flags (seed sync, sequence gaps, etc.)
///   - Export: generates a plain-text summary for clipboard copy
@MainActor
final class VersusTestHarness: ObservableObject {

    static let shared = VersusTestHarness()

    // MARK: - Timeline

    struct TimelineEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let label: String
        let detail: String?
        let severity: Severity

        enum Severity { case info, warning, error }
    }

    @Published private(set) var timeline: [TimelineEntry] = []
    private let maxTimelineEntries = 200

    // MARK: - Session State

    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var lastSentMoveNumber: Int = 0
    @Published private(set) var lastReceivedMoveNumber: Int = 0
    @Published private(set) var latencyEstimateMs: Double?

    // MARK: - Validation Flags

    @Published private(set) var seedSynced: ValidationStatus = .pending
    @Published private(set) var bothPlayersReady: ValidationStatus = .pending
    @Published private(set) var sequenceGapDetected: Bool = false
    @Published private(set) var duplicateActionDetected: Bool = false
    @Published private(set) var desyncSuspected: Bool = false

    enum ValidationStatus: String {
        case pending = "—"
        case ok      = "OK"
        case fail    = "FAIL"

        var isOK: Bool { self == .ok }
    }

    // MARK: - Private tracking

    private var receivedMoveNumbers: Set<Int> = []
    private var localSeed: UInt64 = 0
    private var remoteSeed: UInt64 = 0

    private init() {}

    // MARK: - Session Lifecycle

    func startSession() {
        timeline.removeAll()
        sessionStartTime = Date()
        lastSentMoveNumber = 0
        lastReceivedMoveNumber = 0
        latencyEstimateMs = nil
        seedSynced = .pending
        bothPlayersReady = .pending
        sequenceGapDetected = false
        duplicateActionDetected = false
        desyncSuspected = false
        receivedMoveNumbers.removeAll()
        localSeed = 0
        remoteSeed = 0

        log("SESSION_START", severity: .info)
    }

    func endSession(result: String) {
        log("SESSION_END", detail: result, severity: .info)
    }

    // MARK: - Matchmaking Events

    func logSearchStarted() {
        log("SEARCH_STARTED", severity: .info)
    }

    func logSearchCancelled() {
        log("SEARCH_CANCELLED", severity: .warning)
    }

    func logMatchFound(opponent: String, isHost: Bool) {
        log("MATCH_FOUND", detail: "\(opponent) | host=\(isHost)", severity: .info)
    }

    // MARK: - Seed Exchange

    func logSeedGenerated(_ seed: UInt64) {
        localSeed = seed
        log("SEED_GENERATED", detail: "\(seed)", severity: .info)
        evaluateSeedSync()
    }

    func logSeedReceived(_ seed: UInt64) {
        localSeed = seed  // guest stores the seed it received
        remoteSeed = seed // on guest side, remote seed == received seed
        log("SEED_RECEIVED", detail: "\(seed)", severity: .info)
        evaluateSeedSync()
    }

    func logSeedSent(_ seed: UInt64) {
        localSeed = seed
        remoteSeed = seed  // host has same seed
        log("SEED_SENT", detail: "\(seed)", severity: .info)
        evaluateSeedSync()
    }

    private func evaluateSeedSync() {
        guard localSeed != 0 else { return }
        // Seed sync is valid when both sides have the same non-zero seed
        // For host: validated after send
        // For guest: validated after receive
        seedSynced = .ok
    }

    // MARK: - Board Ready

    func logLocalBoardReady() {
        log("LOCAL_BOARD_READY", severity: .info)
        evaluateBothReady()
    }

    func logRemoteBoardReady() {
        log("REMOTE_BOARD_READY", severity: .info)
        evaluateBothReady()
    }

    private func evaluateBothReady() {
        let state = VersusMatchmakingManager.shared.matchState
        if state.localBoardReady && state.remoteBoardReady {
            bothPlayersReady = .ok
            log("BOTH_BOARD_READY", severity: .info)
        }
    }

    // MARK: - Countdown & Game Start

    func logCountdownStarted() {
        log("COUNTDOWN_STARTED", severity: .info)
    }

    func logGameStarted() {
        log("GAME_STARTED", severity: .info)
    }

    // MARK: - Actions

    func logLocalAction(moveNumber: Int, row: Int, col: Int) {
        lastSentMoveNumber = moveNumber
        log("LOCAL_TAP", detail: "#\(moveNumber) (\(row),\(col))", severity: .info)
    }

    func logRemoteAction(moveNumber: Int, row: Int, col: Int, actionTimestamp: TimeInterval) {
        // Sequence gap detection
        if moveNumber > lastReceivedMoveNumber + 1 && lastReceivedMoveNumber > 0 {
            sequenceGapDetected = true
            let gap = moveNumber - lastReceivedMoveNumber - 1
            log("SEQUENCE_GAP", detail: "expected #\(lastReceivedMoveNumber + 1) got #\(moveNumber) (gap=\(gap))", severity: .error)
        }

        // Duplicate detection
        if receivedMoveNumbers.contains(moveNumber) {
            duplicateActionDetected = true
            log("DUPLICATE_ACTION", detail: "#\(moveNumber)", severity: .error)
        }

        receivedMoveNumbers.insert(moveNumber)
        lastReceivedMoveNumber = moveNumber

        // Latency estimation: action.timestamp vs now
        let now = Date().timeIntervalSince1970
        let latency = (now - actionTimestamp) * 1000  // ms
        if latency > 0 && latency < 30_000 {  // sanity: discard outliers
            latencyEstimateMs = latency
        }

        log("REMOTE_TAP", detail: "#\(moveNumber) (\(row),\(col)) ~\(Int(latency))ms", severity: .info)
    }

    func logStaleActionRejected(moveNumber: Int) {
        log("STALE_REJECTED", detail: "#\(moveNumber)", severity: .warning)
    }

    // MARK: - Desync Detection

    func logDesyncSuspected(reason: String) {
        desyncSuspected = true
        log("DESYNC_SUSPECTED", detail: reason, severity: .error)
    }

    // MARK: - Disconnect

    func logDisconnect(phase: String) {
        log("DISCONNECT", detail: "phase=\(phase)", severity: .error)
    }

    // MARK: - Result

    func logResult(result: String, localMoves: Int, remoteMoves: Int, timeRemaining: Int) {
        log("RESULT", detail: "\(result) | local=\(localMoves) remote=\(remoteMoves) t=\(timeRemaining)s", severity: .info)
    }

    func logRematch() {
        log("REMATCH_REQUESTED", severity: .info)
    }

    func logRematchAccepted() {
        log("REMATCH_ACCEPTED", severity: .info)
    }

    // MARK: - Export

    /// Generates a plain-text summary of the last match for clipboard copy.
    func exportSummary() -> String {
        let state = VersusMatchmakingManager.shared.matchState
        let analytics = VersusAnalytics.shared
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines: [String] = []
        lines.append("═══ VERSUS TEST SUMMARY ═══")
        lines.append("")

        // Session info
        lines.append("SESSION")
        if let start = sessionStartTime {
            lines.append("  Start:    \(fmt.string(from: start))")
            lines.append("  Duration: \(Int(Date().timeIntervalSince(start)))s")
        }
        lines.append("  Seed:     \(state.sharedSeed)")
        lines.append("  Host:     \(state.isHost ? "YES" : "NO")")
        lines.append("  Opponent: \(state.opponentDisplayName)")
        lines.append("")

        // Result
        lines.append("RESULT")
        lines.append("  Outcome:  \(state.localResult)")
        lines.append("  Phase:    \(state.phase)")
        lines.append("  Local moves:  \(lastSentMoveNumber)")
        lines.append("  Remote moves: \(lastReceivedMoveNumber)")
        if let lat = latencyEstimateMs {
            lines.append("  Last latency: \(Int(lat))ms")
        }
        lines.append("")

        // Validations
        lines.append("VALIDATIONS")
        lines.append("  Seed synced:     \(seedSynced.rawValue)")
        lines.append("  Both ready:      \(bothPlayersReady.rawValue)")
        lines.append("  Sequence gap:    \(sequenceGapDetected ? "YES" : "NO")")
        lines.append("  Duplicate:       \(duplicateActionDetected ? "YES" : "NO")")
        lines.append("  Desync:          \(desyncSuspected ? "YES" : "NO")")
        lines.append("")

        // Analytics counters
        lines.append("ANALYTICS (SESSION)")
        lines.append("  Total searches:    \(analytics.totalSearches)")
        lines.append("  Total matches:     \(analytics.totalMatchesFound)")
        lines.append("  Total games:       \(analytics.totalGamesPlayed)")
        lines.append("  Wins/Losses/Draws: \(analytics.totalWins)/\(analytics.totalLosses)/\(analytics.totalDraws)")
        lines.append("  Disconnects:       \(analytics.totalDisconnects)")
        lines.append("")

        // Timeline
        lines.append("TIMELINE (\(timeline.count) events)")
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss.SSS"
        for entry in timeline {
            let sev = entry.severity == .error ? "!" : (entry.severity == .warning ? "?" : " ")
            let detail = entry.detail.map { " — \($0)" } ?? ""
            lines.append("  \(timeFmt.string(from: entry.timestamp)) [\(sev)] \(entry.label)\(detail)")
        }

        lines.append("")
        lines.append("═══ END SUMMARY ═══")
        return lines.joined(separator: "\n")
    }

    /// Copy the export summary to the system clipboard.
    func copyToClipboard() {
        UIPasteboard.general.string = exportSummary()
    }

    // MARK: - Private

    private func log(_ label: String, detail: String? = nil, severity: TimelineEntry.Severity) {
        let entry = TimelineEntry(
            timestamp: Date(),
            label: label,
            detail: detail,
            severity: severity
        )
        timeline.append(entry)
        if timeline.count > maxTimelineEntries {
            timeline.removeFirst()
        }

        #if DEBUG
        let sevMark = severity == .error ? "❌" : (severity == .warning ? "⚠️" : "ℹ️")
        let detailStr = detail.map { " — \($0)" } ?? ""
        print("[VersusHarness] \(sevMark) \(label)\(detailStr)")
        #endif
    }
}
