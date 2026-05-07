import Foundation

// MARK: - VersusBoardGenerator
/// Generates a standard 5×5 versus board from a shared seed.
///
/// Both players get the same board and solve it independently.
/// Layout is identical to a campaign level: source on one edge, target(s) on the other.
///
/// Deterministic: same seed → identical board on both devices.
enum VersusBoardGenerator {

    private static let versusMechanics: [MechanicType] = []

    // MARK: - Public API

    /// Build a solvable board from a seed and config. Grid size comes from config (4, 5, or 6).
    static func buildBoard(seed: UInt64, config: VersusLevelConfig) -> [[Tile]] {
        let size = config.gridSize
        for attempt in 0..<10 {
            let grid = buildBoardAttempt(seed: seed &+ UInt64(attempt), config: config, size: size)
            if verifySolvable(grid, size: size) {
                #if DEBUG
                print("[VersusBoard] Attempt \(attempt) solvable ✓ (\(size)×\(size))")
                #endif
                return grid
            }
            #if DEBUG
            print("[VersusBoard] Attempt \(attempt) unsolvable — retrying")
            #endif
        }
        return buildBoardAttempt(seed: seed, config: config, size: size)
    }

    // MARK: - Board Generation

    private static func buildBoardAttempt(seed: UInt64, config: VersusLevelConfig, size: Int) -> [[Tile]] {
        var rng = SeededRNG(seed: seed)

        let sourceRow = rng.nextInt(size)
        let targetRow = rng.nextInt(size)

        var connMap = Array(repeating: Array(repeating: Set<Direction>(), count: size), count: size)
        var roleMap = Array(repeating: Array(repeating: NodeRole.relay, count: size), count: size)
        roleMap[sourceRow][0] = .source
        roleMap[targetRow][size - 1] = .target

        // DFS path from source to target
        let path = dfs(
            from: (sourceRow, 0), to: (targetRow, size - 1),
            size: size, rng: &rng
        )
        applyPathConnections(path: path, to: &connMap)

        // Build tile grid
        var grid: [[Tile]] = []
        for r in 0..<size {
            var row: [Tile] = []
            for c in 0..<size {
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
            grid.append(row)
        }

        // Apply mechanics based on difficulty
        let difficulty = DifficultyTier(rawValue: config.difficultyRaw) ?? .medium
        applyMechanics(to: &grid, size: size, rng: &rng, difficulty: difficulty)

        // Place linked tiles on path relays (versus-exclusive)
        placeLinkedTiles(in: &grid, size: size, pathConnMap: connMap, rng: &rng, difficulty: difficulty)

        // Rescue if already solved at initial state
        rescueIfSolved(&grid, size: size, rng: &rng)

        return grid
    }

    // MARK: - Solvability Verification

    private static func verifySolvable(_ grid: [[Tile]], size: Int) -> Bool {
        var test = grid
        var solved = Set<Int>()

        for r in 0..<size {
            for c in 0..<size where test[r][c].role == .source {
                solved.insert(r * size + c)
            }
        }

        var changed = true
        while changed {
            changed = false
            for r in 0..<size {
                for c in 0..<size {
                    let key = r * size + c
                    guard !solved.contains(key) else { continue }
                    guard test[r][c].role == .relay || test[r][c].role == .target else { continue }

                    for dir in Direction.allCases {
                        let (nr, nc) = neighborPos(r, c, dir)
                        guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                        let nkey = nr * size + nc
                        guard solved.contains(nkey) else { continue }
                        guard test[nr][nc].connections.contains(dir.opposite) else { continue }

                        for rot in 0..<4 {
                            test[r][c].rotation = rot
                            guard test[r][c].connections.contains(dir) else { continue }
                            let others = test[r][c].connections.subtracting([dir])
                            let valid = others.allSatisfy { d in
                                let (onr, onc) = neighborPos(r, c, d)
                                guard onr >= 0, onr < size, onc >= 0, onc < size else { return false }
                                return test[onr][onc].role != .none
                            }
                            if valid {
                                solved.insert(key)
                                changed = true
                                break
                            }
                        }
                        if solved.contains(key) { break }
                    }
                }
            }
        }

        // Check all targets are solvable
        for r in 0..<size {
            for c in 0..<size where test[r][c].role == .target {
                if !solved.contains(r * size + c) { return false }
            }
        }
        return true
    }

    // MARK: - Mechanics

    private static func applyMechanics(to grid: inout [[Tile]], size: Int, rng: inout SeededRNG, difficulty: DifficultyTier) {
        var pool = versusMechanics
        let count: Int
        switch difficulty {
        case .easy:   count = 0
        case .medium: count = rng.nextInt(2)
        case .hard:   count = 1 + rng.nextInt(2)
        case .expert: count = 2 + min(1, rng.nextInt(2))
        }
        var selected: [MechanicType] = []
        for _ in 0..<count {
            guard !pool.isEmpty else { break }
            let idx = rng.nextInt(pool.count)
            selected.append(pool.remove(at: idx))
        }

        for mechanic in selected {
            applyMechanic(mechanic, grid: &grid, size: size, rng: &rng)
        }
    }

    private static func applyMechanic(_ mechanic: MechanicType, grid: inout [[Tile]], size: Int, rng: inout SeededRNG) {
        var relays: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size where grid[r][c].role == .relay {
                relays.append((r, c))
            }
        }
        guard !relays.isEmpty else { return }

        for i in stride(from: relays.count - 1, through: 1, by: -1) {
            relays.swapAt(i, rng.nextInt(i + 1))
        }

        switch mechanic {
        case .rotationCap:
            let n = min(2, relays.count)
            for i in 0..<n { grid[relays[i].0][relays[i].1].maxRotations = 3 }
        case .overloaded:
            if let (r, c) = relays.first { grid[r][c].isOverloaded = true }
        case .interferenceZone:
            let n = min(2, relays.count)
            for i in 0..<n { grid[relays[i].0][relays[i].1].hasInterference = true }
        default:
            break
        }
    }

    // MARK: - Linked Tiles (versus-exclusive)

    private static func placeLinkedTiles(
        in grid: inout [[Tile]],
        size: Int,
        pathConnMap: [[Set<Direction>]],
        rng: inout SeededRNG,
        difficulty: DifficultyTier
    ) {
        let count: Int
        switch difficulty {
        case .easy:   count = 0
        case .medium: count = 1
        case .hard:   count = 1 + rng.nextInt(2)
        case .expert: count = 2
        }
        guard count > 0 else { return }

        var candidates: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size {
                guard !pathConnMap[r][c].isEmpty && grid[r][c].role == .relay else { continue }
                guard grid[r][c].maxRotations == nil
                    && !grid[r][c].isOverloaded
                    && !grid[r][c].hasInterference
                else { continue }
                candidates.append((r, c))
            }
        }

        for i in stride(from: candidates.count - 1, through: 1, by: -1) {
            candidates.swapAt(i, rng.nextInt(i + 1))
        }

        let placed = min(count, candidates.count)
        for i in 0..<placed {
            grid[candidates[i].0][candidates[i].1].isLinked = true
        }
        #if DEBUG
        if placed > 0 {
            let positions = (0..<placed).map { "(\(candidates[$0].0),\(candidates[$0].1))" }.joined(separator: ", ")
            print("[VersusBoard] Placed \(placed) linked tile(s) at \(positions)")
        }
        #endif
    }

    // MARK: - Rescue (break starts-solved boards)

    private static func rescueIfSolved(_ grid: inout [[Tile]], size: Int, rng: inout SeededRNG) {
        guard isSolvedAtInitialState(grid, size: size) else { return }
        for r in 0..<size {
            for c in 0..<size where grid[r][c].role == .relay {
                grid[r][c].rotation = (grid[r][c].rotation + 1) % 4
                if !isSolvedAtInitialState(grid, size: size) { return }
            }
        }
    }

    private static func isSolvedAtInitialState(_ grid: [[Tile]], size: Int) -> Bool {
        var energized = Array(repeating: Array(repeating: false, count: size), count: size)
        var queue: [(Int, Int)] = []

        for r in 0..<size {
            for c in 0..<size where grid[r][c].role == .source {
                energized[r][c] = true
                queue.append((r, c))
            }
        }

        var visited = Set<Int>()
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            let key = r * size + c
            guard visited.insert(key).inserted else { continue }

            for dir in grid[r][c].connections {
                let (nr, nc) = neighborPos(r, c, dir)
                guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                guard grid[nr][nc].connections.contains(dir.opposite) else { continue }
                guard !energized[nr][nc] else { continue }
                energized[nr][nc] = true
                queue.append((nr, nc))
            }
        }

        for r in 0..<size {
            for c in 0..<size where grid[r][c].role == .target {
                if energized[r][c] { return true }
            }
        }
        return false
    }

    // MARK: - DFS Path Finding

    private static func dfs(
        from start: (Int, Int), to end: (Int, Int),
        size: Int,
        rng: inout SeededRNG
    ) -> [(Int, Int)] {
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)
        var path: [(Int, Int)] = []
        var r = rng

        func search(_ cell: (Int, Int)) -> Bool {
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
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if search((nr, nc)) { return true }
                }
            }

            path.removeLast()
            return false
        }

        _ = search(start)
        rng = r
        return path
    }

    // MARK: - Helpers

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
        let types: [TileType] = [.straight, .curve]
        let type = types[rng.nextInt(types.count)]
        let rotation = rng.nextInt(4)
        var tile = Tile(type: type, rotation: rotation)
        tile.role = .relay
        return tile
    }

    /// FNV-1a hash of the board layout for cross-device verification.
    static func boardHash(_ grid: [[Tile]]) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for row in grid {
            for tile in row {
                let typeOrd: UInt64 = switch tile.type {
                case .straight: 0
                case .curve: 1
                case .tShape: 2
                case .cross: 3
                }
                let roleOrd: UInt64 = switch tile.role {
                case .source: 0
                case .target: 1
                case .relay: 2
                case .none: 3
                }
                h ^= typeOrd &+ UInt64(tile.rotation) &* 7 &+ roleOrd &* 31
                h &*= 1099511628211
            }
        }
        return h
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
