import SwiftUI
import Combine

// MARK: - GameViewModel
@MainActor
class GameViewModel: ObservableObject {

    // MARK: Published state
    @Published var tiles: [[Tile]] = []
    @Published var movesLeft: Int = 0
    @Published var movesUsed: Int = 0
    @Published var status: GameStatus = .playing
    @Published var connectedPairs: Set<String> = []

    // Cached energy counters — updated once per propagation, not recomputed per access
    @Published private(set) var targetsOnline: Int = 0
    @Published private(set) var activeNodes: Int = 0
    private(set) var targetsTotal: Int = 0

    /// BFS traversal order of energized tiles from source → targets.
    /// Populated when the game is won; used by GameView to animate the signal sweep.
    private(set) var signalPath: [(Int, Int)] = []

    // MARK: Mechanics — time limit
    @Published var timeRemaining: Int? = nil

    // MARK: Mechanics — announcement
    /// Set when the player first encounters a new mechanic. Cleared after acknowledgement.
    @Published var pendingMechanicAnnouncement: MechanicType? = nil

    // MARK: Sector completion
    /// Set when completing a level causes ALL missions in the sector to be done for the first time.
    /// Cleared by GameView after the banner is displayed.
    @Published var pendingPassGrant: PlanetPass? = nil

    /// The LevelUpEvent from the most recent win. Nil before first win or after a loss/restart.
    /// Read by ContentView's onWin callback to surface rank-up and pass story beats.
    private(set) var lastLevelUpEvent: LevelUpEvent? = nil

    // MARK: Level info (read-only from outside)
    private(set) var currentLevel: Level

    /// Grid dimension from current level
    var gridSize: Int { currentLevel.gridSize }

    /// Upper bound on adjacent pairs in a gs×gs grid. Used for the progress bar.
    var estimatedTotalPairs: Int { (gridSize - 1) * gridSize * 2 }

    // MARK: Private — async tasks
    private var countdownTask: Task<Void, Never>? = nil
    private var driftTasks: [String: Task<Void, Never>] = [:]

    // MARK: Init
    init(level: Level) {
        currentLevel = level
        setupLevel()
    }

    // MARK: - Public API

    func setupLevel() {
        // Cancel any in-flight mechanic tasks before rebuilding the board
        countdownTask?.cancel()
        countdownTask = nil
        for task in driftTasks.values { task.cancel() }
        driftTasks = [:]

        let board = LevelGenerator.buildBoard(for: currentLevel)
        // Cache target count once — it never changes during play
        targetsTotal = board.flatMap { $0 }.filter { $0.role == .target }.count
        tiles = board
        movesLeft = currentLevel.maxMoves
        movesUsed = 0
        status = .playing
        signalPath = []
        connectedPairs = []
        targetsOnline = 0
        activeNodes = 0
        pendingPassGrant = nil
        lastLevelUpEvent = nil
        timeRemaining = currentLevel.timeLimit
        updateConnections()

        // Start countdown if this level has a time limit
        if let tl = currentLevel.timeLimit {
            startCountdown(seconds: tl)
        }

        // Show mechanic unlock message if this is the player's first encounter
        checkMechanicAnnouncements(for: board)
    }

    func loadLevel(_ level: Level) {
        currentLevel = level
        setupLevel()
    }

    func tap(row: Int, col: Int) {
        guard status == .playing else { return }

        // Locked tile — rotation cap exhausted; reject with error haptic
        guard !tiles[row][col].isRotationLocked else {
            HapticsManager.error()
            SoundManager.play(.tileLocked)
            return
        }

        HapticsManager.light()

        // Overloaded tile — first tap arms, second tap rotates
        if tiles[row][col].isOverloaded && !tiles[row][col].overloadArmed {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
                tiles[row][col].overloadArmed = true
            }
            SoundManager.play(.overloadArm)
            movesLeft -= 1
            movesUsed += 1
            if movesLeft == 0 {
                status = .lost
                HapticsManager.error()
                SoundManager.play(.lose)
                countdownTask?.cancel()
                saveResultIfDaily(success: false)
            }
            return
        }

        let prevTargets = targetsOnline
        let prevActive  = activeNodes

        // Clear arm state on overloaded execute tap
        if tiles[row][col].isOverloaded {
            tiles[row][col].overloadArmed = false
        }

        tiles[row][col].rotate()
        tiles[row][col].rotationsUsed += 1
        SoundManager.play(.tileRotate)
        movesLeft -= 1
        movesUsed += 1

        // Schedule auto-drift if this tile has it
        if let delay = tiles[row][col].autoDriftDelay {
            scheduleDrift(row: row, col: col, delay: delay)
        }

        updateConnections(processMechanics: true)

        if checkWin() {
            status = .won
            signalPath = computeSignalPath()
            countdownTask?.cancel()
            saveResultIfDaily(success: true)
            if let result = gameResult {
                let event = ProgressionStore.record(result)
                lastLevelUpEvent = event
                if let newPass = event?.newPass {
                    pendingPassGrant = newPass
                }
            }
        } else if movesLeft == 0 {
            status = .lost
            HapticsManager.error()
            SoundManager.play(.lose)
            countdownTask?.cancel()
            saveResultIfDaily(success: false)
        } else if targetsOnline > prevTargets {
            // A target just came online — meaningful connection
            HapticsManager.medium()
            SoundManager.play(.targetOnline)
        } else if activeNodes > prevActive {
            // New relay tile energized
            HapticsManager.selection()
            SoundManager.play(.relayEnergized)
        }
    }

    func isConnected(row: Int, col: Int, direction: Direction) -> Bool {
        connectedPairs.contains(pairKey(row: row, col: col, direction: direction))
    }

    /// Result snapshot available once the game is no longer in progress.
    var gameResult: GameResult? {
        guard status != .playing else { return nil }

        let buffer = max(1, currentLevel.maxMoves - currentLevel.minimumRequiredMoves)
        let moveRating = min(1.0, Float(movesLeft) / Float(buffer))

        let energyRating: Float
        switch currentLevel.objectiveType {
        case .normal:
            energyRating = 1.0
        case .maxCoverage:
            energyRating = Float(activeNodes) / Float(max(1, gridSize * gridSize))
        case .energySaving:
            let waste = max(0, activeNodes - currentLevel.solutionPathLength)
            energyRating = max(0.0, Float(3 - waste) / 3.0)
        }

        let timeRating: Float
        if let remaining = timeRemaining, let limit = currentLevel.timeLimit {
            timeRating = Float(remaining) / Float(max(1, limit))
        } else {
            timeRating = 1.0
        }

        let objectiveQuality: Float
        switch currentLevel.objectiveType {
        case .normal:       objectiveQuality = moveRating
        case .maxCoverage:  objectiveQuality = moveRating * 0.55 + energyRating * 0.45
        case .energySaving: objectiveQuality = moveRating * 0.65 + energyRating * 0.35
        }

        let quality: Float
        if currentLevel.timeLimit != nil {
            quality = objectiveQuality * 0.70 + timeRating * 0.30
        } else {
            quality = objectiveQuality
        }

        let computedScore = status == .won ? 1000 + Int(quality * 2000) : 0

        return GameResult(
            levelId:        currentLevel.id,
            success:        status == .won,
            movesUsed:      movesUsed,
            efficiency:     status == .won ? quality : 0,
            nodesActivated: activeNodes,
            totalNodes:     gridSize * gridSize,
            score:          computedScore,
            moveRating:     moveRating,
            energyRating:   energyRating,
            timeRating:     timeRating
        )
    }

    var score: Int { gameResult?.score ?? 0 }

    /// True when every target is powered — the win state.
    var networkOnline: Bool {
        targetsTotal > 0 && targetsOnline == targetsTotal
    }

    /// Short mission objective shown in the HUD.
    var objectiveText: String {
        switch currentLevel.objectiveType {
        case .normal:
            return targetsTotal > 1 ? "ACTIVATE \(targetsTotal) TARGETS" : "CONNECT SOURCE TO TARGET"
        case .maxCoverage:
            return "MAXIMIZE ACTIVE GRID"
        case .energySaving:
            return "SAVE ENERGY"
        }
    }

    // MARK: - Objective-specific live metrics

    /// Active grid coverage as a percentage (0–100). Relevant for maxCoverage.
    var gridCoveragePercent: Int {
        let total = gridSize * gridSize
        guard total > 0 else { return 0 }
        return Int(Float(activeNodes) / Float(total) * 100)
    }

    /// Extra nodes beyond the solution path. Relevant for energySaving.
    var energyWaste: Int {
        max(0, activeNodes - currentLevel.solutionPathLength)
    }

    /// True when energySaving constraint is violated (too many nodes energized).
    var energyWasteExceeded: Bool {
        currentLevel.objectiveType == .energySaving
            && energyWaste > 2
    }

    // MARK: - Private: Countdown timer

    private func startCountdown(seconds: Int) {
        countdownTask = Task { @MainActor in
            var remaining = seconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                guard status == .playing else { return }
                remaining -= 1
                timeRemaining = remaining
                if remaining > 0 && remaining <= 10 {
                    HapticsManager.light()  // tick on last 10 s
                    SoundManager.play(.timerTick)
                }
                if remaining == 0 {
                    status = .lost
                    HapticsManager.error()
                    SoundManager.play(.lose)
                    saveResultIfDaily(success: false)
                    return
                }
            }
        }
    }

    // MARK: - Private: Auto-drift

    private func scheduleDrift(row: Int, col: Int, delay: Double) {
        let key = "\(row),\(col)"
        driftTasks[key]?.cancel()
        driftTasks[key] = Task { @MainActor in
            let nanos = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            guard status == .playing else { return }

            // Drift +1 clockwise — automatic, does NOT count as a move or use rotationsUsed
            tiles[row][col].rotate()
            updateConnections(processMechanics: true)
            HapticsManager.light()
            SoundManager.play(.drift)

            // Drift can complete the circuit if the player set everything else up correctly
            if checkWin() {
                status = .won
                signalPath = computeSignalPath()
                countdownTask?.cancel()
                saveResultIfDaily(success: true)
                if let result = gameResult {
                    ProgressionStore.record(result)
                }
            }
        }
    }

    // MARK: - Private: Mechanic announcements

    private func checkMechanicAnnouncements(for board: [[Tile]]) {
        let allTiles = board.flatMap { $0 }

        // Announce in unlock order: B rotationCap → D overloaded → A timeLimit → C autoDrift
        if allTiles.contains(where: { $0.maxRotations != nil })
            && !MechanicUnlockStore.hasAnnounced(.rotationCap) {
            pendingMechanicAnnouncement = .rotationCap
            return
        }
        if allTiles.contains(where: { $0.isOverloaded })
            && !MechanicUnlockStore.hasAnnounced(.overloaded) {
            pendingMechanicAnnouncement = .overloaded
            return
        }
        if currentLevel.timeLimit != nil
            && !MechanicUnlockStore.hasAnnounced(.timeLimit) {
            pendingMechanicAnnouncement = .timeLimit
            return
        }
        if allTiles.contains(where: { $0.autoDriftDelay != nil })
            && !MechanicUnlockStore.hasAnnounced(.autoDrift) {
            pendingMechanicAnnouncement = .autoDrift
            return
        }
        if allTiles.contains(where: { !$0.baseBlockedInboundDirections.isEmpty })
            && !MechanicUnlockStore.hasAnnounced(.oneWayRelay) {
            pendingMechanicAnnouncement = .oneWayRelay
            return
        }
        if allTiles.contains(where: { $0.fragileCharges != nil })
            && !MechanicUnlockStore.hasAnnounced(.fragileTile) {
            pendingMechanicAnnouncement = .fragileTile
            return
        }
        if allTiles.contains(where: { $0.gateChargesRequired != nil })
            && !MechanicUnlockStore.hasAnnounced(.chargeGate) {
            pendingMechanicAnnouncement = .chargeGate
            return
        }
        if allTiles.contains(where: { $0.hasInterference })
            && !MechanicUnlockStore.hasAnnounced(.interferenceZone) {
            pendingMechanicAnnouncement = .interferenceZone
            return
        }
    }

    // MARK: - Private: Signal path

    /// BFS from all source tiles mirroring propagateEnergy logic, but recording
    /// the visit order rather than updating tile state.
    /// Returns tiles in the order energy would travel through the circuit.
    private func computeSignalPath() -> [(Int, Int)] {
        var path: [(Int, Int)] = []
        var visited = Set<Int>()
        var queue: [(Int, Int)] = []

        for r in 0..<gridSize {
            for c in 0..<gridSize where tiles[r][c].role == .source {
                visited.insert(r * gridSize + c)
                path.append((r, c))
                queue.append((r, c))
            }
        }

        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            for dir in tiles[r][c].connections {
                let (nr, nc) = neighborPos(row: r, col: c, dir: dir)
                guard nr >= 0, nr < gridSize, nc >= 0, nc < gridSize else { continue }
                guard tiles[nr][nc].connections.contains(dir.opposite) else { continue }
                guard !tiles[nr][nc].isBurned else { continue }
                guard !tiles[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }
                let key = nr * gridSize + nc
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

    // MARK: - Private: Energy propagation

    private func updateConnections(processMechanics: Bool = false) {
        var pairs = Set<String>()
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let tile = tiles[row][col]
                if col + 1 < gridSize {
                    let right = tiles[row][col + 1]
                    if tile.connections.contains(.east) && right.connections.contains(.west) {
                        pairs.insert("\(row),\(col)-\(row),\(col+1)")
                    }
                }
                if row + 1 < gridSize {
                    let below = tiles[row + 1][col]
                    if tile.connections.contains(.south) && below.connections.contains(.north) {
                        pairs.insert("\(row),\(col)-\(row+1),\(col)")
                    }
                }
            }
        }
        connectedPairs = pairs
        propagateEnergy()

        // After propagation, process fragile decay and charge gate logic.
        // If any tile state changes (burn-out or gate opening), re-propagate.
        if processMechanics {
            if applyFragileDecay() || applyGateCharges() {
                propagateEnergy()
            }
        }
    }

    /// BFS from all source tiles. Only tiles reachable via matched connections are energized.
    private func propagateEnergy() {
        var local = tiles
        for r in 0..<gridSize { for c in 0..<gridSize { local[r][c].isEnergized = false } }

        var queue: [(Int, Int)] = []
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if local[r][c].role == .source {
                    local[r][c].isEnergized = true
                    queue.append((r, c))
                }
            }
        }

        // Int key (r * gridSize + c) avoids string interpolation overhead in the hot loop
        var visited = Set<Int>()
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            let key = r * gridSize + c
            guard visited.insert(key).inserted else { continue }
            for dir in local[r][c].connections {
                let (nr, nc) = neighborPos(row: r, col: c, dir: dir)
                guard nr >= 0, nr < gridSize, nc >= 0, nc < gridSize else { continue }
                guard local[nr][nc].connections.contains(dir.opposite) else { continue }
                // Burned fragile tiles block energy entirely.
                guard !local[nr][nc].isBurned else { continue }
                // One-way relay check: `dir.opposite` is the side energy enters the neighbor from.
                // If that entry direction is blocked, the relay rejects the signal.
                guard !local[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }
                guard !local[nr][nc].isEnergized else { continue }
                local[nr][nc].isEnergized = true
                // Charge gate: tile is energized (accumulates a charge) but does NOT propagate
                // energy outward until it has received enough charges to open.
                let isBlockedGate = local[nr][nc].gateChargesRequired != nil && !local[nr][nc].isGateOpen
                if !isBlockedGate {
                    queue.append((nr, nc))
                }
            }
        }

        // Update cached counters from local — single pass, no extra flatMap
        var onlineTargets = 0
        var onlineNodes = 0
        for row in local {
            for tile in row {
                if tile.isEnergized {
                    onlineNodes += 1
                    if tile.role == .target { onlineTargets += 1 }
                }
            }
        }
        targetsOnline = onlineTargets
        activeNodes   = onlineNodes

        withAnimation(.easeOut(duration: 0.15)) {
            tiles = local
        }
    }

    /// Win: all targets energized, plus objective-specific constraints.
    private func checkWin() -> Bool {
        // First check that all targets are energized (universal requirement)
        let targetsReached = targetsTotal > 0
            ? targetsOnline == targetsTotal
            : allConnectionsValid()
        guard targetsReached else { return false }

        // energySaving: also require total active nodes ≤ solutionPathLength + 2
        if currentLevel.objectiveType == .energySaving {
            return activeNodes <= currentLevel.energySavingLimit
        }
        return true
    }

    private func allConnectionsValid() -> Bool {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                for dir in tiles[row][col].connections {
                    let (nr, nc) = neighborPos(row: row, col: col, dir: dir)
                    if nr < 0 || nr >= gridSize || nc < 0 || nc >= gridSize { return false }
                    if !tiles[nr][nc].connections.contains(dir.opposite) { return false }
                }
            }
        }
        return true
    }

    private func neighborPos(row: Int, col: Int, dir: Direction) -> (Int, Int) {
        switch dir {
        case .north: return (row - 1, col)
        case .south: return (row + 1, col)
        case .east:  return (row, col + 1)
        case .west:  return (row, col - 1)
        }
    }

    /// Saves the result only when playing the current daily level.
    private func saveResultIfDaily(success: Bool) {
        guard currentLevel.id == LevelGenerator.dailyLevel.id else { return }
        // Use the computed gameResult when available; fall back to a minimal record on loss.
        let result = gameResult ?? GameResult(
            levelId:        currentLevel.id,
            success:        false,
            movesUsed:      movesUsed,
            efficiency:     0,
            nodesActivated: activeNodes,
            totalNodes:     gridSize * gridSize,
            score:          0,
            moveRating:     0,
            energyRating:   0,
            timeRating:     0
        )
        DailyStore.save(result)
    }

    // MARK: - Private: Fragile tile decay

    /// Increments fragile charge counters for every currently-energized fragile tile.
    /// Burns out tiles that hit their charge limit.
    /// Returns true if any tile was burned (caller should re-propagate).
    @discardableResult
    private func applyFragileDecay() -> Bool {
        var burned = false
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard tiles[r][c].fragileCharges != nil,
                      tiles[r][c].isEnergized,
                      !tiles[r][c].isBurned else { continue }
                tiles[r][c].fragileChargesUsed += 1
                if tiles[r][c].fragileChargesUsed >= tiles[r][c].fragileCharges! {
                    tiles[r][c].isBurned = true
                    burned = true
                    SoundManager.play(.tileLocked)
                    HapticsManager.error()
                }
            }
        }
        return burned
    }

    // MARK: - Private: Charge gate logic

    /// Increments charge counters for every currently-energized, not-yet-open gate tile.
    /// Opens gates that reach their required charge count.
    /// Returns true if any gate was opened (caller should re-propagate).
    @discardableResult
    private func applyGateCharges() -> Bool {
        var opened = false
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard let required = tiles[r][c].gateChargesRequired,
                      tiles[r][c].isEnergized,
                      !tiles[r][c].isGateOpen else { continue }
                tiles[r][c].gateChargesReceived += 1
                if tiles[r][c].gateChargesReceived >= required {
                    tiles[r][c].isGateOpen = true
                    opened = true
                    SoundManager.play(.relayEnergized)
                    HapticsManager.medium()
                }
            }
        }
        return opened
    }

    private func pairKey(row: Int, col: Int, direction: Direction) -> String {
        switch direction {
        case .east:  return "\(row),\(col)-\(row),\(col+1)"
        case .south: return "\(row),\(col)-\(row+1),\(col)"
        case .west:  return "\(row),\(col-1)-\(row),\(col)"
        case .north: return "\(row-1),\(col)-\(row),\(col)"
        }
    }
}
