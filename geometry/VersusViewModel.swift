import Combine
import SwiftUI

// MARK: - VersusViewModel
/// Bridges the local `GameViewModel` with the `VersusMatchmakingManager` network layer.
///
/// Responsibilities:
///   - Intercepts local taps → forwards to GameViewModel AND sends `.action` + `.state` to opponent.
///   - Listens for remote state updates → updates `matchState.remoteSnapshot`.
///   - Detects local win/loss → sends `.result` to opponent.
///   - Does NOT write to ProgressionStore, PassStore, StoryStore, or EntitlementStore.
///     Versus wins are cosmetic in V1 — they don't affect campaign progress.
@MainActor
final class VersusViewModel: ObservableObject {

    // ── Dependencies ─────────────────────────────────────────────────────
    let localGame:    GameViewModel
    let matchManager: VersusMatchmakingManager

    /// Convenience accessor for the shared match state.
    var matchState: VersusMatchState { matchManager.matchState }

    // ── Local state ──────────────────────────────────────────────────────
    @Published var level: Level?

    init(matchManager: VersusMatchmakingManager) {
        self.matchManager = matchManager
        // Create a placeholder GameViewModel — will be replaced when the level is ready
        self.localGame = GameViewModel(level: LevelGenerator.introLevel)

        // Wire up callbacks
        matchManager.onLevelReady = { [weak self] seed, config in
            self?.handleLevelReady(seed: seed, config: config)
        }
        matchManager.onRemoteState = { [weak self] snapshot in
            self?.matchState.remoteSnapshot = snapshot
        }
        matchManager.onRemoteResult = { [weak self] outcome in
            self?.matchState.remoteOutcome = outcome
        }
    }

    // MARK: - Level Setup

    private func handleLevelReady(seed: UInt64, config: VersusLevelConfig) {
        let versusLevel = VersusLevelFactory.makeLevel(seed: seed, config: config)
        level = versusLevel
        localGame.loadLevel(versusLevel)
    }

    // MARK: - Local Tap

    /// Called by the versus game view when the local player taps a tile.
    func handleLocalTap(row: Int, col: Int) {
        guard matchState.phase == .playing else { return }
        guard localGame.status == .playing else { return }

        // Execute locally
        localGame.tap(row: row, col: col)

        // Send action to opponent
        let action = VersusAction(
            row:        row,
            col:        col,
            moveNumber: localGame.movesUsed,
            timestamp:  Date().timeIntervalSince1970
        )
        matchManager.sendAction(action)

        // Send updated state snapshot
        sendLocalSnapshot()

        // Check if game ended
        checkLocalGameEnd()
    }

    // MARK: - State Sync

    private func sendLocalSnapshot() {
        let snapshot = VersusPlayerSnapshot(
            movesUsed:     localGame.movesUsed,
            movesLeft:     localGame.movesLeft,
            targetsOnline: localGame.targetsOnline,
            totalTargets:  localGame.targetsTotal,
            activeNodes:   localGame.activeNodes,
            status:        statusString(localGame.status)
        )
        matchManager.sendState(snapshot)
    }

    private func checkLocalGameEnd() {
        switch localGame.status {
        case .won:
            matchManager.sendResult(.won)
        case .lost:
            matchManager.sendResult(.lost)
        case .playing:
            break
        }
    }

    private func statusString(_ status: GameStatus) -> String {
        switch status {
        case .playing: return "playing"
        case .won:     return "won"
        case .lost:    return "lost"
        }
    }

    // MARK: - Cleanup

    func tearDown() {
        matchManager.onLevelReady  = nil
        matchManager.onRemoteState = nil
        matchManager.onRemoteResult = nil
    }
}
