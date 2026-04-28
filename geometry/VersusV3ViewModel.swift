import Combine
import SwiftUI

// MARK: - VersusBotDifficulty

enum VersusBotDifficulty: Int, CaseIterable, Identifiable {
    case easy = 1, medium = 2, hard = 3

    var id: Int { rawValue }

    var interval: TimeInterval {
        switch self {
        case .easy:   return 2.8
        case .medium: return 1.5
        case .hard:   return 0.6
        }
    }

    var botName: String {
        switch self {
        case .easy:   return "BOT EASY"
        case .medium: return "BOT MEDIUM"
        case .hard:   return "BOT HARD"
        }
    }
}

// MARK: - VersusV3ViewModel
/// Game logic for the standard 5×5 versus board.
///
/// Each player solves the same puzzle independently. First to connect source → target wins.
/// Bot simulates progress at configurable speed for solo testing.
@MainActor
final class VersusV3ViewModel: ObservableObject {

    // MARK: - Constants

    static let gridSize = VersusBoardGenerator.gridSize   // 5
    static let gameDuration = 30                           // seconds

    // MARK: - Published State

    @Published var tiles: [[Tile]] = []
    @Published var timeRemaining: Int = gameDuration
    @Published var gameStatus: GameStatus = .playing
    @Published var winner: VersusPlayer?

    @Published var localTapCount: Int = 0
    @Published var remoteTapCount: Int = 0

    // MARK: - Dependencies

    let matchManager: VersusMatchmakingManager

    var rivalProgressPercent: Int {
        let snapshot = matchManager.matchState.remoteSnapshot
        let totalTiles = Self.gridSize * Self.gridSize
        guard totalTiles > 0 else { return 0 }
        return min(100, snapshot.activeNodes * 100 / totalTiles)
    }

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var botCancellable: AnyCancellable?
    private var gameEnded = false
    private var botProgressTimer: AnyCancellable?
    private var botEnergizedFake: Int = 0

    // MARK: - Init

    init(matchManager: VersusMatchmakingManager) {
        self.matchManager = matchManager

        matchManager.onLevelReady = { [weak self] seed, config in
            self?.handleLevelReady(seed: seed, config: config)
        }
        matchManager.onGameStart = { [weak self] in
            self?.handleGameStart()
        }
        matchManager.onRemoteAction = nil
        matchManager.onRemoteState = { [weak self] snapshot in
            self?.matchManager.matchState.remoteSnapshot = snapshot
        }
        matchManager.onRemoteResult = { [weak self] outcome in
            self?.handleRemoteResult(outcome)
        }
        matchManager.onRemoteBoardReady = nil
        matchManager.onRemoteRematch = nil
    }

    // MARK: - Level Setup

    private func handleLevelReady(seed: UInt64, config: VersusLevelConfig) {
        let board = VersusBoardGenerator.buildBoard(seed: seed, config: config)
        tiles = board

        localTapCount = 0
        remoteTapCount = 0
        gameStatus = .playing
        winner = nil
        gameEnded = false
        timeRemaining = Self.gameDuration
        botEnergizedFake = 0

        propagateEnergy()
        matchManager.sendBoardReady()
    }

    private func handleGameStart() {
        VersusAnalytics.shared.trackMatchStarted(seed: matchManager.matchState.sharedSeed)
        startTimer()
        if matchManager.isSoloTest { startBot() }
    }

    // MARK: - Tap

    func tap(row: Int, col: Int) {
        guard gameStatus == .playing else { return }
        guard row >= 0, row < Self.gridSize, col >= 0, col < Self.gridSize else { return }

        let tile = tiles[row][col]
        guard tile.role != .source else { return }
        guard !tile.isBurned else { return }
        if tile.isRotationLocked { return }

        if tile.isOverloaded {
            if tile.overloadArmed {
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

        localTapCount += 1
        propagateEnergy()
        checkWin()

        let action = VersusAction(
            row: row, col: col,
            moveNumber: localTapCount,
            timestamp: Date().timeIntervalSince1970
        )
        matchManager.sendAction(action)
        sendLocalSnapshot()
    }

    // MARK: - Energy Propagation (standard BFS)

    private func propagateEnergy() {
        let size = Self.gridSize
        var energized = Array(repeating: Array(repeating: false, count: size), count: size)
        var queue: [(Int, Int)] = []

        for r in 0..<size {
            for c in 0..<size where tiles[r][c].role == .source {
                energized[r][c] = true
                queue.append((r, c))
            }
        }

        var visited = Set<Int>()
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            let key = r * size + c
            guard visited.insert(key).inserted else { continue }

            for dir in tiles[r][c].connections {
                let (nr, nc) = neighborPos(r, c, dir)
                guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                guard tiles[nr][nc].connections.contains(dir.opposite) else { continue }
                guard !tiles[nr][nc].isBurned else { continue }
                guard !tiles[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }
                guard !energized[nr][nc] else { continue }

                let isBlockedGate = tiles[nr][nc].gateChargesRequired != nil && !tiles[nr][nc].isGateOpen
                energized[nr][nc] = true
                if !isBlockedGate {
                    queue.append((nr, nc))
                }
            }
        }

        for r in 0..<size {
            for c in 0..<size {
                tiles[r][c].isEnergized = energized[r][c]
            }
        }
    }

    // MARK: - Win Detection

    private func checkWin() {
        guard !gameEnded else { return }
        let size = Self.gridSize
        for r in 0..<size {
            for c in 0..<size where tiles[r][c].role == .target {
                if tiles[r][c].isEnergized {
                    endGame(localWon: true)
                    return
                }
            }
        }
    }

    // MARK: - Remote Result

    private func handleRemoteResult(_ outcome: VersusOutcome) {
        guard !gameEnded else { return }
        switch outcome {
        case .disconnected:
            endGame(localWon: true)
        case .won:
            if winner == nil { endGame(localWon: false) }
        case .lost:
            break
        }
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

    private func resolveTimeout() {
        guard !gameEnded else { return }
        let localEnergized = tiles.flatMap { $0 }.filter(\.isEnergized).count
        let remoteEnergized = matchManager.matchState.remoteSnapshot.activeNodes
        if localEnergized > remoteEnergized {
            endGame(localWon: true)
        } else if remoteEnergized > localEnergized {
            endGame(localWon: false)
        } else {
            endGameDraw()
        }
    }

    // MARK: - End Game

    private func endGame(localWon: Bool) {
        guard !gameEnded else { return }
        gameEnded = true
        timerCancellable?.cancel()
        botCancellable?.cancel()
        botProgressTimer?.cancel()
        gameStatus = .won

        matchManager.sendResult(localWon ? .won : .lost)

        VersusAnalytics.shared.trackMatchCompleted(
            result: localWon ? "win" : "lose",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            seed: matchManager.matchState.sharedSeed,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.logResult(
            result: localWon ? "win" : "lose",
            localMoves: localTapCount,
            remoteMoves: remoteTapCount,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.endSession(result: localWon ? "win" : "lose")
    }

    private func endGameDraw() {
        guard !gameEnded else { return }
        gameEnded = true
        winner = nil
        timerCancellable?.cancel()
        botCancellable?.cancel()
        botProgressTimer?.cancel()
        gameStatus = .won

        matchManager.sendResult(.lost, soloRemoteOutcome: .lost)

        VersusAnalytics.shared.trackMatchCompleted(
            result: "draw", localMoves: localTapCount, remoteMoves: remoteTapCount,
            seed: matchManager.matchState.sharedSeed, timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.logResult(
            result: "draw", localMoves: localTapCount, remoteMoves: remoteTapCount,
            timeRemaining: timeRemaining
        )
        VersusTestHarness.shared.endSession(result: "draw")
    }

    // MARK: - Bot (Solo Test)

    private func startBot() {
        let difficulty = matchManager.soloBotDifficulty

        // Bot simulates progress: periodically increases fake energized count
        let progressInterval: TimeInterval
        let energizePerTick: Int
        switch difficulty {
        case .easy:
            progressInterval = 3.5
            energizePerTick = 1
        case .medium:
            progressInterval = 2.0
            energizePerTick = 2
        case .hard:
            progressInterval = 1.0
            energizePerTick = 3
        }

        let totalTiles = Self.gridSize * Self.gridSize
        botProgressTimer = Timer.publish(every: progressInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.gameStatus == .playing, !self.gameEnded else {
                    self?.botProgressTimer?.cancel()
                    return
                }
                self.botEnergizedFake = min(totalTiles, self.botEnergizedFake + energizePerTick)
                self.remoteTapCount += 1
                self.matchManager.matchState.remoteSnapshot = VersusPlayerSnapshot(
                    movesUsed: self.remoteTapCount,
                    movesLeft: 0,
                    targetsOnline: 0,
                    totalTargets: 1,
                    activeNodes: self.botEnergizedFake,
                    status: "playing"
                )
            }

        // Bot "solves" after a random time based on difficulty
        let solveTime: TimeInterval
        switch difficulty {
        case .easy:   solveTime = Double.random(in: 26...35)
        case .medium: solveTime = Double.random(in: 18...28)
        case .hard:   solveTime = Double.random(in: 10...18)
        }

        botCancellable?.cancel()
        botCancellable = Timer.publish(every: solveTime, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                guard let self, self.gameStatus == .playing, !self.gameEnded else { return }
                self.matchManager.matchState.remoteOutcome = .won
                self.matchManager.onRemoteResult?(.won)
            }
    }

    // MARK: - Snapshot

    private func sendLocalSnapshot() {
        let energizedCount = tiles.flatMap { $0 }.filter(\.isEnergized).count
        let targetHit = tiles.flatMap { $0 }.contains { $0.role == .target && $0.isEnergized }
        let snapshot = VersusPlayerSnapshot(
            movesUsed: localTapCount,
            movesLeft: 0,
            targetsOnline: targetHit ? 1 : 0,
            totalTargets: 1,
            activeNodes: energizedCount,
            status: gameEnded ? "finished" : "playing"
        )
        matchManager.sendState(snapshot)
    }

    // MARK: - Helpers

    private func neighborPos(_ r: Int, _ c: Int, _ dir: Direction) -> (Int, Int) {
        switch dir {
        case .north: return (r - 1, c)
        case .south: return (r + 1, c)
        case .east:  return (r, c + 1)
        case .west:  return (r, c - 1)
        }
    }

    // MARK: - Rematch

    func resetForRematch() {
        timerCancellable?.cancel()
        botCancellable?.cancel()
        botProgressTimer?.cancel()
        tiles = []
        timeRemaining = Self.gameDuration
        gameStatus = .playing
        winner = nil
        gameEnded = false
        localTapCount = 0
        remoteTapCount = 0
        botEnergizedFake = 0
    }

    // MARK: - Cleanup

    func tearDown() {
        timerCancellable?.cancel()
        botCancellable?.cancel()
        botProgressTimer?.cancel()
        matchManager.onLevelReady = nil
        matchManager.onGameStart = nil
        matchManager.onRemoteAction = nil
        matchManager.onRemoteState = nil
        matchManager.onRemoteResult = nil
        matchManager.onRemoteBoardReady = nil
        matchManager.onRemoteRematch = nil
    }
}
