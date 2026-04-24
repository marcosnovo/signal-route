import Combine
import Foundation
import UIKit

// MARK: - MatchPhase
/// Lifecycle of a single versus match.
enum MatchPhase: Equatable {
    case idle           // No match active
    case searching      // GKMatchmaker is looking for an opponent
    case matched        // Both players connected, awaiting seed exchange
    case countdown      // Seed received, short pre-game countdown
    case playing        // Boards active, taps flowing
    case finished       // One or both players done
}

// MARK: - VersusMatchState
/// Observable state of the current versus match.
///
/// Owned by `VersusMatchmakingManager`; read by `VersusView` and `VersusViewModel`.
/// All writes happen on `@MainActor`.
@MainActor
final class VersusMatchState: ObservableObject {

    // ── Match lifecycle ──────────────────────────────────────────────────
    @Published var phase: MatchPhase = .idle

    // ── Shared level ─────────────────────────────────────────────────────
    @Published var sharedSeed:   UInt64 = 0
    @Published var sharedConfig: VersusLevelConfig?

    // ── Player snapshots ─────────────────────────────────────────────────
    @Published var localSnapshot:  VersusPlayerSnapshot = .idle
    @Published var remoteSnapshot: VersusPlayerSnapshot = .idle

    // ── Result ───────────────────────────────────────────────────────────
    @Published var localOutcome:  VersusOutcome?
    @Published var remoteOutcome: VersusOutcome?

    // ── Player info ──────────────────────────────────────────────────────
    @Published var localPlayerName: String = "YOU"
    @Published var localPlayerAvatar: UIImage?
    @Published var opponentDisplayName: String = "OPPONENT"
    @Published var opponentAvatar: UIImage?

    // ── Error ────────────────────────────────────────────────────────────
    @Published var error: String?

    // ── Board-ready sync ────────────────────────────────────────────────
    @Published var localBoardReady:    Bool = false
    @Published var remoteBoardReady:   Bool = false

    // ── Rematch ──────────────────────────────────────────────────────────
    @Published var localWantsRematch:  Bool = false
    @Published var remoteWantsRematch: Bool = false

    // ── Host election ────────────────────────────────────────────────────
    /// True when this device is responsible for generating and sending the seed.
    @Published var isHost: Bool = false

    // ── Sequence tracking (for DevMenu) ─────────────────────────────────
    @Published var lastRemoteMoveNumber: Int = 0

    // MARK: - Computed

    /// True when the match has a definitive winner.
    var isResolved: Bool {
        localOutcome != nil && remoteOutcome != nil
    }

    /// True when both sides have finished generating the board.
    var bothBoardReady: Bool {
        localBoardReady && remoteBoardReady
    }

    /// True when both players want a rematch.
    var bothWantRematch: Bool {
        localWantsRematch && remoteWantsRematch
    }

    /// The display result for the local player.
    var localResult: VersusLocalResult {
        guard let local = localOutcome else { return .pending }
        if remoteOutcome == .disconnected { return .winByDisconnect }
        if local == .disconnected         { return .loseByDisconnect }
        if local == .won                  { return .win }
        if local == .lost {
            // Both lost = draw (timeout with equal progress)
            if remoteOutcome == .lost { return .draw }
            return .lose
        }
        return .pending
    }

    // MARK: - Reset

    func reset() {
        phase               = .idle
        sharedSeed          = 0
        sharedConfig        = nil
        localSnapshot       = .idle
        remoteSnapshot      = .idle
        localOutcome        = nil
        remoteOutcome       = nil
        localBoardReady     = false
        remoteBoardReady    = false
        localWantsRematch   = false
        remoteWantsRematch  = false
        opponentDisplayName = "OPPONENT"
        opponentAvatar      = nil
        error               = nil
        isHost              = false
        lastRemoteMoveNumber = 0
        // localPlayerName and localPlayerAvatar persist across matches
    }
}

// MARK: - VersusLocalResult
/// Presentation-friendly outcome for the local player.
enum VersusLocalResult {
    case pending
    case win
    case lose
    case draw               // timeout with equal progress — very rare
    case winByDisconnect
    case loseByDisconnect
}
