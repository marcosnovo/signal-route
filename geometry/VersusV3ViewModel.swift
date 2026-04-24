import Combine
import SwiftUI

// MARK: - VersusV3ViewModel
/// Game logic for the 5×9 split-board versus mode.
///
/// Responsibilities:
///   - Generates the shared board from seed + config via `VersusBoardGenerator`
///   - Runs dual BFS (one per player) after every tap
///   - Manages the 30-second countdown timer
///   - Detects win (first to reach center), timeout (tiebreaker), and draw
///   - Coordinate remapping for guest (display ↔ canonical)
///   - Sends actions + snapshots over the network via `VersusMatchmakingManager`
///
/// Does NOT interact with campaign stores (ProgressionStore, PassStore, etc.).
@MainActor
final class VersusV3ViewModel: ObservableObject {

    // MARK: - Constants

    static let rows = VersusBoardGenerator.rows        // 5
    static let cols = VersusBoardGenerator.cols        // 9
    static let gameDuration = 30                       // seconds
    static let centerCol = VersusBoardGenerator.centerCol  // 4

    // MARK: - Published State

    /// The canonical 5×9 grid. Both devices hold the same grid.
    @Published var tiles: [[Tile]] = []

    /// Seconds remaining on the game clock.
    @Published var timeRemaining: Int = gameDuration

    /// Current game status.
    @Published var gameStatus: GameStatus = .playing

    /// The winner of the match (nil while playing).
    @Published var winner: VersusPlayer?

    /// Dual energy masks — which tiles are energized by each player's BFS.
    @Published var p1EnergizedMask: [[Bool]] = []
    @Published var p2EnergizedMask: [[Bool]] = []

    /// Which center-column rows each player has reached.
    @Published var p1CenterReached: Set<Int> = []
    @Published var p2CenterReached: Set<Int> = []

    /// Per-player energized tile count (for timeout tiebreaker display).
    @Published var p1EnergizedCount: Int = 0
    @Published var p2EnergizedCount: Int = 0

    /// Per-player tap count (for HUD display).
    @Published var localTapCount: Int = 0
    @Published var remoteTapCount: Int = 0

    // MARK: - Dependencies

    let matchManager: VersusMatchmakingManager
    let localPlayer: VersusPlayer   // .p1 if host, .p2 if guest

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var gameEnded = false
    /// Last received remote move number — used to reject duplicate/stale actions.
    private var lastRemoteMoveNumber: Int = 0

    // MARK: - Init

    init(matchManager: VersusMatchmakingManager) {
        self.matchManager = matchManager
        self.localPlayer = matchManager.matchState.isHost ? .p1 : .p2

        // Wire up callbacks
        matchManager.onLevelReady = { [weak self] seed, config in
            self?.handleLevelReady(seed: seed, config: config)
        }
        matchManager.onGameStart = { [weak self] in
            self?.handleGameStart()
        }
        matchManager.onRemoteAction = { [weak self] action in
            self?.handleRemoteAction(action)
        }
        matchManager.onRemoteState = { [weak self] snapshot in
            self?.matchManager.matchState.remoteSnapshot = snapshot
        }
        matchManager.onRemoteResult = { [weak self] outcome in
            self?.handleRemoteResult(outcome)
        }
        matchManager.onRemoteBoardReady = nil   // Manager handles internally
        matchManager.onRemoteRematch = nil      // Manager handles internally
    }

    // MARK: - Level Setup

    /// Called when the seed is ready. Builds the board and signals readiness.
    /// Timer does NOT start here — it starts in handleGameStart() after both boards are ready.
    private func handleLevelReady(seed: UInt64, config: VersusLevelConfig) {
        let board = VersusBoardGenerator.buildBoard(seed: seed, config: config)
        tiles = board

        // Initialize energy masks
        let emptyMask = Array(repeating: Array(repeating: false, count: Self.cols), count: Self.rows)
        p1EnergizedMask = emptyMask
        p2EnergizedMask = emptyMask
        p1CenterReached = []
        p2CenterReached = []
        p1EnergizedCount = 0
        p2EnergizedCount = 0
        localTapCount = 0
        remoteTapCount = 0
        lastRemoteMoveNumber = 0
        gameStatus = .playing
        winner = nil
        gameEnded = false
        timeRemaining = Self.gameDuration

        // Run initial BFS (sources are always energized)
        propagateEnergy()

        // Signal board-ready to the manager — countdown starts when both sides confirm
        matchManager.sendBoardReady()
    }

    /// Called when both boards are ready and the countdown completes. Starts the 30s game clock.
    private func handleGameStart() {
        VersusAnalytics.shared.trackMatchStarted(seed: matchManager.matchState.sharedSeed)
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.gameStatus == .playing else { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.resolveTimeout()
                }
            }
    }

    // MARK: - Local Tap

    /// Called when the local player taps a tile at display coordinates.
    func handleLocalTap(displayRow: Int, displayCol: Int) {
        guard gameStatus == .playing else { return }

        // Convert display → canonical
        let (row, col) = displayToCanonical(row: displayRow, col: displayCol)

        // Ownership check: local player can only tap their own tiles
        guard isOwnedByLocal(col: col) else { return }

        // Don't allow tapping center column
        guard col != Self.centerCol else { return }

        // Perform rotation
        guard canRotate(row: row, col: col) else { return }
        rotateTile(row: row, col: col)
        localTapCount += 1

        // BFS + win check
        propagateEnergy()
        checkWin()

        // Send action in canonical coords
        let action = VersusAction(
            row: row, col: col,
            moveNumber: localTapCount,
            timestamp: Date().timeIntervalSince1970
        )
        matchManager.sendAction(action)
        VersusTestHarness.shared.logLocalAction(moveNumber: localTapCount, row: row, col: col)

        // Send updated snapshot
        sendLocalSnapshot()
    }

    // MARK: - Remote Action

    private func handleRemoteAction(_ action: VersusAction) {
        guard gameStatus == .playing else { return }

        // Dedup: reject stale or duplicate actions
        guard action.moveNumber > lastRemoteMoveNumber else {
            #if DEBUG
            print("[VersusV3] Rejected stale action: moveNumber=\(action.moveNumber) lastRemote=\(lastRemoteMoveNumber)")
            #endif
            VersusTestHarness.shared.logStaleActionRejected(moveNumber: action.moveNumber)
            return
        }
        lastRemoteMoveNumber = action.moveNumber
        matchManager.matchState.lastRemoteMoveNumber = action.moveNumber

        // Action arrives in canonical coordinates — apply directly
        let row = action.row, col = action.col
        guard row >= 0, row < Self.rows, col >= 0, col < Self.cols else { return }

        // Ownership check: opponent can only rotate tiles in their own zone
        let opponentRange = localPlayer == .p1 ? VersusBoardGenerator.p2Range : VersusBoardGenerator.p1Range
        guard opponentRange.contains(col) else {
            #if DEBUG
            print("[VersusV3] Rejected action: col=\(col) not in opponent range \(opponentRange)")
            #endif
            return
        }

        rotateTile(row: row, col: col)
        remoteTapCount += 1
        VersusTestHarness.shared.logRemoteAction(
            moveNumber: action.moveNumber,
            row: row, col: col,
            actionTimestamp: action.timestamp
        )

        // BFS + win check
        propagateEnergy()
        checkWin()
    }

    // MARK: - Remote Result

    private func handleRemoteResult(_ outcome: VersusOutcome) {
        guard !gameEnded else { return }

        switch outcome {
        case .disconnected:
            // Opponent disconnected — local player wins by forfeit
            endGame(winner: localPlayer)
        case .won:
            // Opponent reports win — if we haven't detected a win yet, we lose
            if winner == nil {
                endGame(winner: localPlayer == .p1 ? .p2 : .p1)
            }
        case .lost:
            // Opponent reports loss — no action needed; our win detection handles it
            break
        }
    }

    // MARK: - Tile Rotation

    private func canRotate(row: Int, col: Int) -> Bool {
        let tile = tiles[row][col]
        guard tile.role != .source else { return false }
        guard tile.role != .none else { return false }
        guard !tile.isBurned else { return false }
        if tile.isRotationLocked { return false }
        return true
    }

    private func rotateTile(row: Int, col: Int) {
        if tiles[row][col].isOverloaded {
            if tiles[row][col].overloadArmed {
                tiles[row][col].rotate()
                tiles[row][col].rotationsUsed += 1
                tiles[row][col].overloadArmed = false
            } else {
                tiles[row][col].overloadArmed = true
            }
        } else {
            tiles[row][col].rotate()
            if tiles[row][col].maxRotations != nil {
                tiles[row][col].rotationsUsed += 1
            }
        }
    }

    // MARK: - Energy Propagation (Dual BFS)

    /// Runs two independent BFS passes — one per player — and updates energy state.
    func propagateEnergy() {
        let p1Mask = bfs(for: .p1)
        let p2Mask = bfs(for: .p2)
        p1EnergizedMask = p1Mask
        p2EnergizedMask = p2Mask

        // Update tile isEnergized (union of both BFS results)
        var p1Count = 0, p2Count = 0
        var p1Center = Set<Int>(), p2Center = Set<Int>()
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let e1 = p1Mask[r][c]
                let e2 = p2Mask[r][c]
                tiles[r][c].isEnergized = e1 || e2

                if e1 {
                    p1Count += 1
                    if c == Self.centerCol { p1Center.insert(r) }
                }
                if e2 {
                    p2Count += 1
                    if c == Self.centerCol { p2Center.insert(r) }
                }
            }
        }
        p1EnergizedCount = p1Count
        p2EnergizedCount = p2Count
        p1CenterReached = p1Center
        p2CenterReached = p2Center
    }

    /// BFS from a player's source(s), bounded by their allowed columns.
    /// - P1: cols 0...4 (can reach center but not cross)
    /// - P2: cols 4...8 (can reach center but not cross)
    private func bfs(for player: VersusPlayer) -> [[Bool]] {
        var energized = Array(repeating: Array(repeating: false, count: Self.cols), count: Self.rows)
        var queue: [(Int, Int)] = []

        let sourceRange = player == .p1 ? VersusBoardGenerator.p1Range : VersusBoardGenerator.p2Range
        let minCol = player == .p1 ? 0 : Self.centerCol
        let maxCol = player == .p1 ? Self.centerCol : Self.cols - 1

        // Seed from sources
        for r in 0..<Self.rows {
            for c in sourceRange where tiles[r][c].role == .source {
                energized[r][c] = true
                queue.append((r, c))
            }
        }

        var visited = Set<Int>()
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            let key = r * Self.cols + c
            guard visited.insert(key).inserted else { continue }

            for dir in tiles[r][c].connections {
                let (nr, nc) = neighborPos(r, c, dir)
                guard nr >= 0, nr < Self.rows else { continue }
                guard nc >= minCol, nc <= maxCol else { continue }

                // Neighbor must have a matching connection back
                guard tiles[nr][nc].connections.contains(dir.opposite) else { continue }

                // Burned tiles block energy
                guard !tiles[nr][nc].isBurned else { continue }

                // One-way relay check
                guard !tiles[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }

                guard !energized[nr][nc] else { continue }
                energized[nr][nc] = true

                // Center tiles absorb energy but do NOT propagate outward
                if nc == Self.centerCol { continue }

                // Charge gate: energized but doesn't propagate until open
                let isBlockedGate = tiles[nr][nc].gateChargesRequired != nil && !tiles[nr][nc].isGateOpen
                if !isBlockedGate {
                    queue.append((nr, nc))
                }
            }
        }

        return energized
    }

    private func neighborPos(_ r: Int, _ c: Int, _ dir: Direction) -> (Int, Int) {
        switch dir {
        case .north: return (r - 1, c)
        case .south: return (r + 1, c)
        case .east:  return (r, c + 1)
        case .west:  return (r, c - 1)
        }
    }

    // MARK: - Win Detection

    private func checkWin() {
        guard !gameEnded else { return }

        // Win: first player to reach ANY center tile
        let p1Won = !p1CenterReached.isEmpty
        let p2Won = !p2CenterReached.isEmpty

        if p1Won && p2Won {
            // Both reached center on the same tap — active tapper wins
            // (since we check after each tap, the local tapper gets priority)
            endGame(winner: localPlayer)
        } else if p1Won {
            endGame(winner: .p1)
        } else if p2Won {
            endGame(winner: .p2)
        }
    }

    // MARK: - Timeout Resolution

    private func resolveTimeout() {
        guard !gameEnded else { return }

        // Count energized tiles per player (excluding center column)
        var p1Score = 0, p2Score = 0
        var p1ClosestDist = Int.max, p2ClosestDist = Int.max

        for r in 0..<Self.rows {
            for c in VersusBoardGenerator.p1Range where p1EnergizedMask[r][c] {
                p1Score += 1
                let dist = Self.centerCol - c  // distance to center
                p1ClosestDist = min(p1ClosestDist, dist)
            }
            for c in VersusBoardGenerator.p2Range where p2EnergizedMask[r][c] {
                p2Score += 1
                let dist = c - Self.centerCol
                p2ClosestDist = min(p2ClosestDist, dist)
            }
        }

        // Also count center tiles reached
        p1Score += p1CenterReached.count
        p2Score += p2CenterReached.count

        if p1Score > p2Score {
            endGame(winner: .p1)
        } else if p2Score > p1Score {
            endGame(winner: .p2)
        } else if p1ClosestDist < p2ClosestDist {
            endGame(winner: .p1)
        } else if p2ClosestDist < p1ClosestDist {
            endGame(winner: .p2)
        } else {
            // Extremely rare: true draw
            endGameDraw()
        }
    }

    // MARK: - End Game

    private func endGame(winner: VersusPlayer) {
        guard !gameEnded else { return }
        gameEnded = true
        self.winner = winner
        timerCancellable?.cancel()
        gameStatus = .won  // just marks game as over

        let didLocalWin = winner == localPlayer
        matchManager.sendResult(didLocalWin ? .won : .lost)

        VersusAnalytics.shared.trackMatchCompleted(
            result: didLocalWin ? "win" : "lose",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            seed: matchManager.matchState.sharedSeed,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.logResult(
            result: didLocalWin ? "win" : "lose",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.endSession(result: didLocalWin ? "win" : "lose")
    }

    private func endGameDraw() {
        guard !gameEnded else { return }
        gameEnded = true
        winner = nil
        timerCancellable?.cancel()
        gameStatus = .won  // game is over

        // Both sides report loss — match state handles .draw
        matchManager.sendResult(.lost)

        VersusAnalytics.shared.trackMatchCompleted(
            result: "draw",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            seed: matchManager.matchState.sharedSeed,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.logResult(
            result: "draw",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.endSession(result: "draw")
    }

    // MARK: - Coordinate Remapping

    /// Whether a canonical column belongs to the local player.
    private func isOwnedByLocal(col: Int) -> Bool {
        switch localPlayer {
        case .p1: return VersusBoardGenerator.p1Range.contains(col)
        case .p2: return VersusBoardGenerator.p2Range.contains(col)
        }
    }

    /// Convert display coordinates to canonical coordinates.
    /// Host (P1): identity mapping — local panel is on left (cols 0-3).
    /// Guest (P2): horizontal flip — display col 0 maps to canonical col 8.
    func displayToCanonical(row: Int, col: Int) -> (Int, Int) {
        if localPlayer == .p1 {
            return (row, col)
        } else {
            return (row, Self.cols - 1 - col)
        }
    }

    /// Convert canonical coordinates to display coordinates.
    func canonicalToDisplay(row: Int, col: Int) -> (Int, Int) {
        if localPlayer == .p1 {
            return (row, col)
        } else {
            return (row, Self.cols - 1 - col)
        }
    }

    /// Returns tiles arranged for display: host sees canonical order,
    /// guest sees horizontally flipped so their panel is always on the left.
    func displayTiles() -> [[Tile]] {
        if localPlayer == .p1 {
            return tiles
        } else {
            return tiles.map { $0.reversed() }
        }
    }

    /// Returns the display-space energy mask for a given player.
    func displayEnergizedMask(for player: VersusPlayer) -> [[Bool]] {
        let mask = player == .p1 ? p1EnergizedMask : p2EnergizedMask
        if localPlayer == .p1 {
            return mask
        } else {
            return mask.map { $0.reversed() }
        }
    }

    /// Returns center-reached set in display-space row indices.
    func displayCenterReached(for player: VersusPlayer) -> Set<Int> {
        // Center rows don't change with horizontal flip — row indices are the same
        player == .p1 ? p1CenterReached : p2CenterReached
    }

    // MARK: - Snapshot

    private func sendLocalSnapshot() {
        let playerRange = localPlayer == .p1 ? VersusBoardGenerator.p1Range : VersusBoardGenerator.p2Range
        var energizedInZone = 0
        for r in 0..<Self.rows {
            for c in playerRange {
                let mask = localPlayer == .p1 ? p1EnergizedMask : p2EnergizedMask
                if mask[r][c] { energizedInZone += 1 }
            }
        }
        let centerReached = localPlayer == .p1 ? p1CenterReached : p2CenterReached
        let snapshot = VersusPlayerSnapshot(
            movesUsed: localTapCount,
            movesLeft: 0,  // V3 has no move limit
            targetsOnline: centerReached.count,
            totalTargets: Self.rows,  // 5 center beacons
            activeNodes: energizedInZone,
            status: gameEnded ? "finished" : "playing"
        )
        matchManager.sendState(snapshot)
    }

    // MARK: - Rematch

    /// Resets all game state for a new round, keeping the match alive.
    /// Called when both players agree to rematch.
    func resetForRematch() {
        timerCancellable?.cancel()
        tiles = []
        timeRemaining = Self.gameDuration
        gameStatus = .playing
        winner = nil
        gameEnded = false
        p1EnergizedMask = []
        p2EnergizedMask = []
        p1CenterReached = []
        p2CenterReached = []
        p1EnergizedCount = 0
        p2EnergizedCount = 0
        localTapCount = 0
        remoteTapCount = 0
        lastRemoteMoveNumber = 0
    }

    // MARK: - Cleanup

    func tearDown() {
        timerCancellable?.cancel()
        matchManager.onLevelReady = nil
        matchManager.onGameStart = nil
        matchManager.onRemoteAction = nil
        matchManager.onRemoteState = nil
        matchManager.onRemoteResult = nil
        matchManager.onRemoteBoardReady = nil
        matchManager.onRemoteRematch = nil
    }
}
