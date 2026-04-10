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

    // MARK: Level info (read-only from outside)
    private(set) var currentLevel: Level

    /// Grid dimension from current level (was hardcoded 4, now varies)
    var gridSize: Int { currentLevel.gridSize }

    /// Upper bound on adjacent pairs in a gs×gs grid. Used for the progress bar.
    var estimatedTotalPairs: Int { (gridSize - 1) * gridSize * 2 }

    // MARK: Init
    init(level: Level = LevelGenerator.levels[0]) {
        currentLevel = level
        setupLevel()
    }

    // MARK: - Public API

    func setupLevel() {
        let board = LevelGenerator.buildBoard(for: currentLevel)
        // Cache target count once — it never changes during play
        targetsTotal = board.flatMap { $0 }.filter { $0.role == .target }.count
        tiles = board
        movesLeft = currentLevel.maxMoves
        movesUsed = 0
        status = .playing
        connectedPairs = []
        targetsOnline = 0
        activeNodes = 0
        updateConnections()
    }

    func loadLevel(_ level: Level) {
        currentLevel = level
        setupLevel()
    }

    func tap(row: Int, col: Int) {
        guard status == .playing else { return }

        HapticsManager.light()

        let prevTargets = targetsOnline
        let prevActive  = activeNodes

        tiles[row][col].rotate()
        movesLeft -= 1
        movesUsed += 1
        updateConnections()

        if checkWin() {
            status = .won
            saveResultIfDaily(success: true)
        } else if movesLeft == 0 {
            status = .lost
            HapticsManager.error()
            saveResultIfDaily(success: false)
        } else if targetsOnline > prevTargets {
            // A target just came online — meaningful connection
            HapticsManager.medium()
        } else if activeNodes > prevActive {
            // New relay tile energized
            HapticsManager.selection()
        }
    }

    func isConnected(row: Int, col: Int, direction: Direction) -> Bool {
        connectedPairs.contains(pairKey(row: row, col: col, direction: direction))
    }

    /// Result snapshot available once the game is no longer in progress.
    var gameResult: GameResult? {
        guard status != .playing else { return nil }
        return GameResult(
            success:        status == .won,
            movesUsed:      movesUsed,
            efficiency:     Float(movesLeft) / Float(max(1, currentLevel.maxMoves)),
            nodesActivated: activeNodes,
            totalNodes:     gridSize * gridSize
        )
    }

    var score: Int {
        guard status == .won else { return 0 }
        return 1000 + movesLeft * 50
    }

    /// True when every target is powered — the win state.
    var networkOnline: Bool {
        targetsTotal > 0 && targetsOnline == targetsTotal
    }

    /// Short mission objective shown in the HUD.
    var objectiveText: String {
        targetsTotal > 1
            ? "ACTIVATE \(targetsTotal) TARGETS"
            : "CONNECT SOURCE TO TARGET"
    }

    // MARK: - Private

    private func updateConnections() {
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
                guard !local[nr][nc].isEnergized else { continue }
                local[nr][nc].isEnergized = true
                queue.append((nr, nc))
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

    /// Win: all targets energized. Uses cached counters — no extra grid scan needed.
    private func checkWin() -> Bool {
        if targetsTotal > 0 { return targetsOnline == targetsTotal }
        return allConnectionsValid()
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
        DailyStore.save(GameResult(
            success:        success,
            movesUsed:      movesUsed,
            efficiency:     Float(movesLeft) / Float(max(1, currentLevel.maxMoves)),
            nodesActivated: activeNodes,
            totalNodes:     gridSize * gridSize
        ))
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
