import Foundation

// MARK: - VersusBoardGenerator
/// Generates the 5-row × 9-column versus split-board from a shared seed.
///
/// Layout:
///   cols 0-3:  Player 1 zone (host)
///   col 4:     Center objective column (shared beacon targets)
///   cols 5-8:  Player 2 zone (guest) — horizontally mirrored from P1
///
/// Deterministic: same seed → identical board on both devices.
enum VersusBoardGenerator {

    static let rows = 5
    static let cols = 9
    static let p1Range = 0...3
    static let centerCol = 4
    static let p2Range = 5...8
    static let panelCols = 4

    /// Mechanics eligible for versus (fast-game-friendly only).
    private static let versusMechanics: [MechanicType] = [
        .rotationCap, .overloaded, .oneWayRelay, .interferenceZone
    ]

    // MARK: - Public API

    /// Build the full 5×9 board from a seed and config.
    static func buildBoard(seed: UInt64, config: VersusLevelConfig) -> [[Tile]] {
        var rng = SeededRNG(seed: seed)

        // Step 1: Generate P1's 5×4 panel (source at col 0, path toward col 3)
        let p1Panel = generatePanel(rng: &rng)

        // Step 2: Mirror P1 → P2
        let p2Panel = mirrorPanel(p1Panel)

        // Step 3: Build center column
        let center = buildCenterColumn()

        // Step 4: Assemble the 5×9 grid
        var grid: [[Tile]] = []
        for row in 0..<rows {
            var fullRow: [Tile] = []
            // P1 zone (cols 0-3)
            for col in 0..<panelCols {
                var tile = p1Panel[row][col]
                tile.owner = .p1
                fullRow.append(tile)
            }
            // Center (col 4)
            fullRow.append(center[row])
            // P2 zone (cols 5-8)
            for col in 0..<panelCols {
                var tile = p2Panel[row][col]
                tile.owner = .p2
                fullRow.append(tile)
            }
            grid.append(fullRow)
        }

        // Step 5: Apply versus-safe mechanics symmetrically
        applyVersusMechanics(to: &grid, rng: &rng)

        // Step 6: Verify not already solved (rescue if needed)
        rescueIfSolved(&grid, rng: &rng)

        return grid
    }

    // MARK: - Panel Generation (5×4)

    /// Generate one player's 5×4 panel.
    /// Source is placed on the left edge (col 0), DFS path carves toward the right edge (col 3).
    /// The right-edge tile gets an East connection so it can reach the center column.
    private static func generatePanel(rng: inout SeededRNG) -> [[Tile]] {
        let sourceRow = rng.nextInt(rows)
        let exitRow = rng.nextInt(rows)

        var connMap = Array(repeating: Array(repeating: Set<Direction>(), count: panelCols), count: rows)
        var roleMap = Array(repeating: Array(repeating: NodeRole.relay, count: panelCols), count: rows)
        roleMap[sourceRow][0] = .source

        // DFS path from source to exit
        let path = panelDFS(
            from: (sourceRow, 0), to: (exitRow, panelCols - 1),
            rows: rows, cols: panelCols, rng: &rng
        )
        applyPathConnections(path: path, to: &connMap)

        // The exit tile needs an East connection toward the center column
        connMap[exitRow][panelCols - 1].insert(.east)

        // Build tile grid
        var panel: [[Tile]] = []
        for r in 0..<rows {
            var row: [Tile] = []
            for c in 0..<panelCols {
                let conns = connMap[r][c]
                let role = roleMap[r][c]

                if conns.isEmpty {
                    row.append(noiseTile(rng: &rng))
                } else {
                    let (type, solvedRot) = tileSpec(for: conns)
                    let scramble = (role == .source) ? 0 : (rng.nextInt(3) + 1)
                    let curRot = (solvedRot + scramble) % 4
                    var tile = Tile(type: type, rotation: curRot)
                    tile.role = role
                    row.append(tile)
                }
            }
            panel.append(row)
        }

        return panel
    }

    // MARK: - Mirror

    /// Mirror a 5×4 panel horizontally: col c → col (3-c), swap E↔W connections.
    private static func mirrorPanel(_ panel: [[Tile]]) -> [[Tile]] {
        panel.map { row in
            row.reversed().map { mirrorTileHorizontally($0) }
        }
    }

    /// Mirror a single tile's orientation horizontally (E↔W swap).
    /// Finds the rotation producing the E↔W-swapped connection set for the same tile type.
    private static func mirrorTileHorizontally(_ tile: Tile) -> Tile {
        var result = tile
        let currentConns = tile.connections
        // Swap east ↔ west
        let mirroredConns: Set<Direction> = Set(currentConns.map { dir in
            switch dir {
            case .east:  return .west
            case .west:  return .east
            default:     return dir
            }
        })
        // Find the rotation that produces mirroredConns for this tile type
        if let rotations = TileType.rotatedConnections[tile.type] {
            for rot in 0..<4 {
                if rotations[rot] == mirroredConns {
                    result.rotation = rot
                    break
                }
            }
        }
        // Mirror blocked inbound directions (for one-way relay)
        if !tile.baseBlockedInboundDirections.isEmpty {
            result.baseBlockedInboundDirections = Set(tile.baseBlockedInboundDirections.map { dir in
                switch dir {
                case .east:  return .west
                case .west:  return .east
                default:     return dir
                }
            })
            result._recomputeBlockedCache()
        }
        // Mirror source role → stays source, relay → relay
        return result
    }

    // MARK: - Center Column

    /// 5 fixed beacon tiles: E+W connections, role = .target, non-rotatable.
    private static func buildCenterColumn() -> [Tile] {
        (0..<rows).map { _ in
            var tile = Tile(type: .straight, rotation: 1) // rotation 1 = E+W
            tile.role = .target
            tile.maxRotations = 0 // non-rotatable
            return tile
        }
    }

    // MARK: - Mechanics

    private static func applyVersusMechanics(to grid: inout [[Tile]], rng: inout SeededRNG) {
        // Pick 0-2 mechanics from the eligible set
        var pool = versusMechanics
        let count = rng.nextInt(3) // 0, 1, or 2
        var selected: [MechanicType] = []
        for _ in 0..<count {
            guard !pool.isEmpty else { break }
            let idx = rng.nextInt(pool.count)
            selected.append(pool.remove(at: idx))
        }

        // Apply each mechanic to both panels symmetrically
        for mechanic in selected {
            applyMechanicToPanel(mechanic, grid: &grid, colRange: p1Range, rng: &rng)
            // Use a fresh RNG branch for P2 so the placement mirrors P1's pattern
            var p2Rng = rng
            applyMechanicToPanel(mechanic, grid: &grid, colRange: p2Range, rng: &p2Rng)
        }
    }

    private static func applyMechanicToPanel(
        _ mechanic: MechanicType,
        grid: inout [[Tile]],
        colRange: ClosedRange<Int>,
        rng: inout SeededRNG
    ) {
        // Collect relay tiles in this panel
        var relays: [(Int, Int)] = []
        for r in 0..<rows {
            for c in colRange where grid[r][c].role == .relay {
                relays.append((r, c))
            }
        }
        guard !relays.isEmpty else { return }

        // Seeded shuffle
        for i in stride(from: relays.count - 1, through: 1, by: -1) {
            relays.swapAt(i, rng.nextInt(i + 1))
        }

        switch mechanic {
        case .rotationCap:
            let n = min(2, relays.count)
            for i in 0..<n {
                let (r, c) = relays[i]
                grid[r][c].maxRotations = 3
            }
        case .overloaded:
            if let (r, c) = relays.first {
                grid[r][c].isOverloaded = true
            }
        case .oneWayRelay:
            if let idx = relays.firstIndex(where: { grid[$0.0][$0.1].connections.count == 2 }) {
                let (r, c) = relays[idx]
                let conns = grid[r][c].connections
                if let exitDir = conns.first(where: { $0 == .east || $0 == .west }) {
                    let (_, solvedRot) = tileSpec(for: conns)
                    let baseDir = exitDir.rotated(by: (4 - solvedRot) % 4)
                    grid[r][c].baseBlockedInboundDirections = [baseDir]
                    grid[r][c]._recomputeBlockedCache()
                }
            }
        case .interferenceZone:
            let n = min(2, relays.count)
            for i in 0..<n {
                let (r, c) = relays[i]
                grid[r][c].hasInterference = true
            }
        default:
            break
        }
    }

    // MARK: - Starts-Solved Rescue

    /// If either panel already connects source to center at initial state, rotate a relay to break it.
    private static func rescueIfSolved(_ grid: inout [[Tile]], rng: inout SeededRNG) {
        func isConnected(player: VersusPlayer, in grid: [[Tile]]) -> Bool {
            let sourceRange = player == .p1 ? p1Range : p2Range
            let allowedCols = player == .p1 ? 0...centerCol : centerCol...8
            var energized = Array(repeating: Array(repeating: false, count: cols), count: rows)
            var queue: [(Int, Int)] = []
            for r in 0..<rows {
                for c in sourceRange where grid[r][c].role == .source {
                    energized[r][c] = true
                    queue.append((r, c))
                }
            }
            var visited = Set<Int>()
            while !queue.isEmpty {
                let (r, c) = queue.removeFirst()
                let key = r * cols + c
                guard visited.insert(key).inserted else { continue }
                if c == centerCol { return true }
                for dir in grid[r][c].connections {
                    let (nr, nc) = neighborPos(r, c, dir)
                    guard nr >= 0, nr < rows, nc >= 0, nc < cols else { continue }
                    guard allowedCols.contains(nc) else { continue }
                    guard grid[nr][nc].connections.contains(dir.opposite) else { continue }
                    guard !energized[nr][nc] else { continue }
                    energized[nr][nc] = true
                    if nc != centerCol { queue.append((nr, nc)) }
                }
            }
            return false
        }

        // Rescue P1 if already connected
        if isConnected(player: .p1, in: grid) {
            for r in 0..<rows {
                for c in p1Range where grid[r][c].role == .relay {
                    grid[r][c].rotation = (grid[r][c].rotation + 1) % 4
                    if !isConnected(player: .p1, in: grid) { break }
                }
                if !isConnected(player: .p1, in: grid) { break }
            }
        }

        // Mirror the rescue for P2
        if isConnected(player: .p2, in: grid) {
            for r in 0..<rows {
                for c in p2Range where grid[r][c].role == .relay {
                    grid[r][c].rotation = (grid[r][c].rotation + 1) % 4
                    if !isConnected(player: .p2, in: grid) { break }
                }
                if !isConnected(player: .p2, in: grid) { break }
            }
        }
    }

    // MARK: - DFS Path Finding

    private static func panelDFS(
        from start: (Int, Int), to end: (Int, Int),
        rows: Int, cols: Int,
        rng: inout SeededRNG
    ) -> [(Int, Int)] {
        var visited = Array(repeating: Array(repeating: false, count: cols), count: rows)
        var path: [(Int, Int)] = []
        var r = rng

        func dfs(_ cell: (Int, Int)) -> Bool {
            guard !visited[cell.0][cell.1] else { return false }
            visited[cell.0][cell.1] = true
            path.append(cell)
            if cell.0 == end.0 && cell.1 == end.1 { return true }

            var offsets = [(-1, 0), (0, 1), (1, 0), (0, -1)]
            for i in stride(from: offsets.count - 1, through: 1, by: -1) {
                offsets.swapAt(i, r.nextInt(i + 1))
            }

            for (dr, dc) in offsets {
                let nr = cell.0 + dr, nc = cell.1 + dc
                if nr >= 0, nr < rows, nc >= 0, nc < cols {
                    if dfs((nr, nc)) { return true }
                }
            }

            path.removeLast()
            return false
        }

        _ = dfs(start)
        rng = r
        return path
    }

    // MARK: - Helpers (duplicated from LevelGenerator — those are private)

    private static func applyPathConnections(
        path: [(Int, Int)],
        to connMap: inout [[Set<Direction>]]
    ) {
        for i in 0..<path.count {
            let cell = path[i]
            if i > 0 {
                let prev = path[i - 1]
                connMap[cell.0][cell.1].insert(dirFrom(cell, to: prev))
            }
            if i < path.count - 1 {
                let next = path[i + 1]
                connMap[cell.0][cell.1].insert(dirFrom(cell, to: next))
            }
        }
    }

    private static func dirFrom(_ a: (Int, Int), to b: (Int, Int)) -> Direction {
        switch (b.0 - a.0, b.1 - a.1) {
        case (-1,  0): return .north
        case ( 1,  0): return .south
        case ( 0,  1): return .east
        default:       return .west
        }
    }

    private static func tileSpec(for conns: Set<Direction>) -> (TileType, Int) {
        if conns == [.north, .south]         { return (.straight, 0) }
        if conns == [.east, .west]           { return (.straight, 1) }
        if conns == [.north, .east]          { return (.curve, 0) }
        if conns == [.east, .south]          { return (.curve, 1) }
        if conns == [.south, .west]          { return (.curve, 2) }
        if conns == [.north, .west]          { return (.curve, 3) }
        if conns == [.north, .east, .west]   { return (.tShape, 0) }
        if conns == [.north, .east, .south]  { return (.tShape, 1) }
        if conns == [.east, .south, .west]   { return (.tShape, 2) }
        if conns == [.north, .south, .west]  { return (.tShape, 3) }
        if conns == [.north] || conns == [.south] { return (.straight, 0) }
        if conns == [.east]  || conns == [.west]  { return (.straight, 1) }
        return (.cross, 0)
    }

    private static func noiseTile(rng: inout SeededRNG) -> Tile {
        let types: [TileType] = [.straight, .curve, .tShape, .cross]
        return Tile(type: types[rng.nextInt(types.count)], rotation: rng.nextInt(4))
    }

    private static func neighborPos(_ r: Int, _ c: Int, _ dir: Direction) -> (Int, Int) {
        switch dir {
        case .north: return (r - 1, c)
        case .south: return (r + 1, c)
        case .east:  return (r, c + 1)
        case .west:  return (r, c - 1)
        }
    }
}
