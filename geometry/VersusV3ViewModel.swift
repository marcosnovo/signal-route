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

    var botIcon: String {
        switch self {
        case .easy:   return "antenna.radiowaves.left.and.right"
        case .medium: return "network"
        case .hard:   return "bolt.shield.fill"
        }
    }

    var botAvatarImage: UIImage? {
        let color: UIColor = switch self {
        case .easy:   UIColor(Color(hex: "4DB87A"))
        case .medium: UIColor(Color(hex: "FF6A3D"))
        case .hard:   UIColor(Color(hex: "E84040"))
        }
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color]))
        return UIImage(systemName: botIcon, withConfiguration: config)
    }
}

// MARK: - VersusScoring

enum VersusScoring {
    static func winPoints(timeRemaining: Int, tapCount: Int) -> Int {
        let base = 1000
        let timeBonus = timeRemaining * 50
        let moveBonus = max(0, (20 - tapCount) * 25)
        return base + timeBonus + moveBonus
    }

    private static let cumulativeKey = "versus.cumulativeScore"
    private static let streakKey = "versus.winStreak"

    static var cumulativeScore: Int {
        get { UserDefaults.standard.integer(forKey: cumulativeKey) }
        set { UserDefaults.standard.set(newValue, forKey: cumulativeKey) }
    }

    static var winStreak: Int {
        get { UserDefaults.standard.integer(forKey: streakKey) }
        set { UserDefaults.standard.set(newValue, forKey: streakKey) }
    }

    static func streakMultiplier(for streak: Int) -> Double {
        switch streak {
        case 0...1: return 1.0
        case 2:     return 1.5
        case 3...4: return 2.0
        default:    return 3.0
        }
    }

    static func recordWin(timeRemaining: Int, tapCount: Int) -> (base: Int, multiplier: Double, total: Int) {
        winStreak += 1
        let base = winPoints(timeRemaining: timeRemaining, tapCount: tapCount)
        let mult = streakMultiplier(for: winStreak)
        let total = Int(Double(base) * mult)
        cumulativeScore += total
        return (base, mult, total)
    }

    static func recordLoss() {
        winStreak = 0
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

    static let defaultGridSize = 5
    static let gameDuration = 30

    static func gameDuration(for gridSize: Int) -> Int {
        switch gridSize {
        case 4:  return 20
        case 6:  return 45
        default: return 30
        }
    }

    // MARK: - Published State

    @Published var tiles: [[Tile]] = []
    @Published var timeRemaining: Int = gameDuration
    @Published var gameStatus: GameStatus = .playing
    @Published var winner: VersusPlayer?

    @Published var localTapCount: Int = 0
    @Published var remoteTapCount: Int = 0
    @Published var winScore: Int = 0
    @Published var winStreakMultiplier: Double = 1.0
    @Published var currentStreak: Int = 0
    @Published var isOvertime: Bool = false

    // MARK: - Win Animation

    @Published var winPulse: Bool = false
    @Published var signalFrontRow: Int = -1
    @Published var signalFrontCol: Int = -1
    @Published var showingWinAnimation: Bool = false

    // MARK: - Grid Size (dynamic)

    @Published var gridSize: Int = defaultGridSize

    // MARK: - Rival Ghost

    @Published var ghostRow: Int = -1
    @Published var ghostCol: Int = -1
    private var ghostClearTask: Task<Void, Never>?

    // MARK: - Rival Danger

    @Published var rivalDanger: Bool = false
    @Published var rivalCritical: Bool = false
    private var lastDangerThreshold: Int = 0

    // MARK: - Power-ups

    @Published var isTimerFrozen: Bool = false
    @Published var rushFlash: Bool = false
    @Published var activePowerUps: [VersusPowerUpType] = []
    private var freezeTask: Task<Void, Never>?

    // MARK: - Dependencies

    let matchManager: VersusMatchmakingManager

    var rivalProgressPercent: Int {
        let snapshot = matchManager.matchState.remoteSnapshot
        let totalTiles = gridSize * gridSize
        guard totalTiles > 0 else { return 0 }
        return min(100, snapshot.activeNodes * 100 / totalTiles)
    }

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var botCancellable: AnyCancellable?
    private(set) var localBoardHash: UInt64 = 0
    private var gameEnded = false
    private var overtimeUsed = false
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
        matchManager.onRemoteAction = { [weak self] action in
            self?.handleRemoteAction(action)
        }
        matchManager.onRemoteState = { [weak self] snapshot in
            self?.matchManager.matchState.remoteSnapshot = snapshot
            self?.checkRivalDanger()
        }
        matchManager.onRemoteResult = { [weak self] outcome in
            self?.handleRemoteResult(outcome)
        }
        matchManager.onRemotePowerUp = { [weak self] type in
            self?.handleRemotePowerUp(type)
        }
        matchManager.onRemoteBoardReady = nil
        matchManager.onRemoteRematch = nil
    }

    // MARK: - Level Setup

    private func handleLevelReady(seed: UInt64, config: VersusLevelConfig) {
        gridSize = config.gridSize
        let board = VersusBoardGenerator.buildBoard(seed: seed, config: config)
        tiles = board
        localBoardHash = VersusBoardGenerator.boardHash(board)

        localTapCount = 0
        remoteTapCount = 0
        gameStatus = .playing
        winner = nil
        gameEnded = false
        timeRemaining = Self.gameDuration(for: gridSize)
        botEnergizedFake = 0

        #if DEBUG
        print("[Versus] Board built — seed=\(seed) hash=\(localBoardHash)")
        #endif

        propagateEnergy()
        matchManager.sendBoardReady(boardHash: localBoardHash)
    }

    private func handleGameStart() {
        VersusAnalytics.shared.trackMatchStarted(seed: matchManager.matchState.sharedSeed)
        if VersusFeatureFlag.isPowerUpsEnabled {
            activePowerUps = VersusPowerUpInventory.items
        }
        startTimer()
        if matchManager.isSoloTest { startBot() }
    }

    // MARK: - Tap

    func tap(row: Int, col: Int) {
        guard gameStatus == .playing else { return }
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }

        let tile = tiles[row][col]
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

    // MARK: - Remote Action (linked tiles)

    private func handleRemoteAction(_ action: VersusAction) {
        guard gameStatus == .playing else { return }
        let row = action.row, col = action.col
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }

        // Rival ghost overlay
        if VersusFeatureFlag.isRivalGhostEnabled {
            ghostRow = row
            ghostCol = col
            ghostClearTask?.cancel()
            ghostClearTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                ghostRow = -1
                ghostCol = -1
            }
        }

        // Linked tile sync
        guard tiles[row][col].isLinked else {
            remoteTapCount = action.moveNumber
            return
        }

        tiles[row][col].rotate()
        if tiles[row][col].maxRotations != nil {
            tiles[row][col].rotationsUsed += 1
        }
        remoteTapCount = action.moveNumber
        propagateEnergy()
        checkWin()
    }

    // MARK: - Energy Propagation (standard BFS)

    private func propagateEnergy() {
        let size = gridSize
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
        let size = gridSize
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
                if self.isTimerFrozen { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.resolveTimeout()
                }
            }
    }

    static let overtimeDuration = 10

    private func resolveTimeout() {
        guard !gameEnded else { return }
        let localEnergized = tiles.flatMap { $0 }.filter(\.isEnergized).count
        let remoteEnergized = matchManager.matchState.remoteSnapshot.activeNodes
        let diff = abs(localEnergized - remoteEnergized)

        if !overtimeUsed && diff <= 2 {
            overtimeUsed = true
            isOvertime = true
            timeRemaining = Self.overtimeDuration
            HapticsManager.heavy()
            return
        }

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

        if localWon {
            let result = VersusScoring.recordWin(timeRemaining: timeRemaining, tapCount: localTapCount)
            winScore = result.total
            winStreakMultiplier = result.multiplier
            currentStreak = VersusScoring.winStreak
            let cumulative = VersusScoring.cumulativeScore
            #if DEBUG
            print("[Versus] Win! score=\(result.total) cumulative=\(cumulative) auth=\(GameCenterManager.shared.isAuthenticated)")
            #endif
            Task { await GameCenterManager.shared.submitVersusScore(cumulative) }

            let targetEnergized = tiles.flatMap { $0 }.contains { $0.role == .target && $0.isEnergized }
            if targetEnergized {
                SoundManager.play(.win)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    HapticsManager.heavy()
                }
                playWinAnimation()
            }
        } else {
            VersusScoring.recordLoss()
            SoundManager.play(.lose)
            HapticsManager.heavy()
        }

        winner = localWon ? .p1 : .p2
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

        let totalTiles = gridSize * gridSize
        botProgressTimer = Timer.publish(every: progressInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.gameStatus == .playing, !self.gameEnded else {
                    self?.botProgressTimer?.cancel()
                    return
                }
                self.botEnergizedFake = min(totalTiles, self.botEnergizedFake + energizePerTick)
                self.remoteTapCount += 1

                // Simulate a bot tap for rival ghost
                if VersusFeatureFlag.isRivalGhostEnabled {
                    let size = self.gridSize
                    let fakeAction = VersusAction(
                        row: Int.random(in: 0..<size),
                        col: Int.random(in: 0..<size),
                        moveNumber: self.remoteTapCount,
                        timestamp: Date().timeIntervalSince1970
                    )
                    self.handleRemoteAction(fakeAction)
                }

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

    // MARK: - Win Animation

    private func playWinAnimation() {
        showingWinAnimation = true
        let path = computeSignalPath()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)

            guard !path.isEmpty else {
                winPulse = true
                HapticsManager.medium()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                showingWinAnimation = false
                return
            }

            let stepMs = min(110, max(40, 900 / path.count))
            let stepNs = UInt64(stepMs) * 1_000_000

            for pos in path {
                signalFrontRow = pos.0
                signalFrontCol = pos.1
                if tiles[pos.0][pos.1].role == .target {
                    HapticsManager.light()
                }
                try? await Task.sleep(nanoseconds: stepNs)
            }

            signalFrontRow = -1
            signalFrontCol = -1

            winPulse = true
            HapticsManager.success()

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            showingWinAnimation = false
        }
    }

    private func computeSignalPath() -> [(Int, Int)] {
        let size = gridSize
        var path: [(Int, Int)] = []
        var visited = Set<Int>()
        var queue: [(Int, Int)] = []

        for r in 0..<size {
            for c in 0..<size where tiles[r][c].role == .source {
                visited.insert(r * size + c)
                path.append((r, c))
                queue.append((r, c))
            }
        }

        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            for dir in tiles[r][c].connections {
                let (nr, nc) = neighborPos(r, c, dir)
                guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                guard tiles[nr][nc].connections.contains(dir.opposite) else { continue }
                guard !tiles[nr][nc].isBurned else { continue }
                guard !tiles[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }
                let key = nr * size + nc
                guard visited.insert(key).inserted else { continue }
                path.append((nr, nc))
                let isBlockedGate = tiles[nr][nc].gateChargesRequired != nil && !tiles[nr][nc].isGateOpen
                if !isBlockedGate {
                    queue.append((nr, nc))
                }
            }
        }

        return path
    }

    // MARK: - Power-ups

    func usePowerUp(_ type: VersusPowerUpType) {
        guard gameStatus == .playing, !gameEnded else { return }
        guard let idx = activePowerUps.firstIndex(of: type) else { return }
        activePowerUps.remove(at: idx)
        _ = VersusPowerUpInventory.use(type)

        switch type {
        case .freeze:
            isTimerFrozen = true
            HapticsManager.medium()
            SoundManager.play(.tapPrimary)
            freezeTask?.cancel()
            freezeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                isTimerFrozen = false
            }

        case .rush:
            matchManager.sendPowerUp(type)
            HapticsManager.heavy()
            SoundManager.play(.tapPrimary)
        }
    }

    private func handleRemotePowerUp(_ type: VersusPowerUpType) {
        guard gameStatus == .playing, !gameEnded else { return }
        switch type {
        case .rush:
            timeRemaining = max(0, timeRemaining - 5)
            rushFlash = true
            HapticsManager.heavy()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                rushFlash = false
            }
            if timeRemaining <= 0 { resolveTimeout() }
        case .freeze:
            break
        }
    }

    // MARK: - Rival Danger Detection

    private func checkRivalDanger() {
        let percent = rivalProgressPercent
        let wasDanger = rivalDanger

        rivalDanger = percent >= 65
        rivalCritical = percent >= 85

        if !wasDanger && rivalDanger {
            HapticsManager.heavy()
        } else if percent >= 85 && lastDangerThreshold < 85 {
            HapticsManager.heavy()
        }
        lastDangerThreshold = percent
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
        freezeTask?.cancel()
        ghostClearTask?.cancel()
        tiles = []
        timeRemaining = Self.gameDuration(for: gridSize)
        gameStatus = .playing
        winner = nil
        gameEnded = false
        overtimeUsed = false
        isOvertime = false
        localTapCount = 0
        remoteTapCount = 0
        winScore = 0
        winStreakMultiplier = 1.0
        currentStreak = 0
        botEnergizedFake = 0
        winPulse = false
        signalFrontRow = -1
        signalFrontCol = -1
        showingWinAnimation = false
        ghostRow = -1
        ghostCol = -1
        rivalDanger = false
        rivalCritical = false
        lastDangerThreshold = 0
        isTimerFrozen = false
        rushFlash = false
        activePowerUps = []
    }

    // MARK: - Cleanup

    func tearDown() {
        timerCancellable?.cancel()
        botCancellable?.cancel()
        botProgressTimer?.cancel()
        freezeTask?.cancel()
        ghostClearTask?.cancel()
        matchManager.onLevelReady = nil
        matchManager.onGameStart = nil
        matchManager.onRemoteAction = nil
        matchManager.onRemoteState = nil
        matchManager.onRemoteResult = nil
        matchManager.onRemotePowerUp = nil
        matchManager.onRemoteBoardReady = nil
        matchManager.onRemoteRematch = nil
    }
}
