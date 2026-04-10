import Foundation

// MARK: - Seeded RNG (Xorshift64)
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 2654435761 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextInt(_ n: Int) -> Int {
        Int(next() % UInt64(n))
    }
}

// MARK: - LevelGenerator
struct LevelGenerator {

    // MARK: - Level catalogue (50 levels, genuinely varied)
    static let levels: [Level] = buildCatalogue()

    // MARK: - Daily challenge
    static var dailyLevel: Level {
        let c = Calendar.current
        let n = Date()
        let y = c.component(.year,  from: n)
        let m = c.component(.month, from: n)
        let d = c.component(.day,   from: n)
        let idx = abs(y * 10000 + m * 100 + d) % levels.count
        return levels[idx]
    }

    // MARK: - Board building
    /// Generates a unique, solvable board for `level` using seeded randomness.
    ///
    /// Algorithm:
    ///   1. Place source + target(s) at grid corners (position varies by seed & type)
    ///   2. Carve seeded-DFS paths from source to every target
    ///   3. Derive tile types from accumulated connection sets
    ///   4. Fill remaining cells with noise tiles
    ///   5. Scramble relay tiles (source/target orientation is fixed)
    static func buildBoard(for level: Level) -> [[Tile]] {
        let gs = level.gridSize
        var rng = SeededRNG(seed: level.seed)

        // 1. Source and target positions
        let (source, targets) = sourceAndTargets(for: level, rng: &rng)

        // 2. Connection accumulator: each cell collects directions from path(s) that pass through it
        var connMap = Array(repeating: Array(repeating: Set<Direction>(), count: gs), count: gs)
        var roleMap = Array(repeating: Array(repeating: NodeRole.relay, count: gs), count: gs)
        roleMap[source.r][source.c] = .source
        for t in targets { roleMap[t.r][t.c] = .target }

        // 3. Carve a seeded-DFS path from source to each target
        for target in targets {
            let path = dfsFindPath(from: source, to: target, gs: gs, rng: &rng)
            applyPathConnections(path: path, to: &connMap)
        }

        // 4. Build Tile grid
        var grid: [[Tile]] = []
        for r in 0..<gs {
            var row: [Tile] = []
            for c in 0..<gs {
                let conns = connMap[r][c]
                let role  = roleMap[r][c]

                if conns.isEmpty {
                    // Cell not on any path → noise tile (random, adds visual complexity)
                    row.append(noiseTile(rng: &rng))
                } else {
                    let (type, solvedRot) = tileSpec(for: conns)
                    // Source and target keep correct orientation; relays are scrambled
                    let scramble = (role == .source || role == .target) ? 0 : rng.nextInt(3) + 1
                    var tile = Tile(type: type, rotation: (solvedRot + scramble) % 4)
                    tile.role = role
                    row.append(tile)
                }
            }
            grid.append(row)
        }
        return grid
    }

    // MARK: - Private: Path carving

    /// DFS with seeded random neighbour ordering. Guaranteed to find a path on an open grid.
    private static func dfsFindPath(
        from start: Cell,
        to end: Cell,
        gs: Int,
        rng: inout SeededRNG
    ) -> [Cell] {
        // Capture rng as a local var so the nested func can mutate it
        var r = rng
        var visited = Array(repeating: Array(repeating: false, count: gs), count: gs)
        var path: [Cell] = []

        func dfs(_ cell: Cell) -> Bool {
            guard !visited[cell.r][cell.c] else { return false }
            visited[cell.r][cell.c] = true
            path.append(cell)
            if cell == end { return true }

            // Shuffle neighbour directions
            var offsets = [(dr: -1, dc: 0), (dr: 0, dc: 1), (dr: 1, dc: 0), (dr: 0, dc: -1)]
            for i in stride(from: offsets.count - 1, through: 1, by: -1) {
                offsets.swapAt(i, r.nextInt(i + 1))
            }

            for off in offsets {
                let nr = cell.r + off.dr, nc = cell.c + off.dc
                if nr >= 0, nr < gs, nc >= 0, nc < gs {
                    if dfs(Cell(nr, nc)) { return true }
                }
            }

            path.removeLast()
            return false
        }

        _ = dfs(start)
        rng = r  // write back RNG state advances
        return path
    }

    /// Writes directional connections for consecutive cells in `path` into `connMap`.
    /// Cells shared by multiple paths accumulate connections (creating T/cross junctions).
    private static func applyPathConnections(path: [Cell], to connMap: inout [[Set<Direction>]]) {
        for i in 0..<path.count {
            let cell = path[i]
            if i > 0 {
                let prev = path[i - 1]
                connMap[cell.r][cell.c].insert(dirFrom(cell, to: prev))
            }
            if i < path.count - 1 {
                let next = path[i + 1]
                connMap[cell.r][cell.c].insert(dirFrom(cell, to: next))
            }
        }
    }

    // MARK: - Private: Tile spec

    /// Maps a set of connections to the matching TileType + base rotation.
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
        return (.cross, 0)  // 4 connections
    }

    /// Noise tile: random type + rotation, already at final state (no "correct" orientation).
    private static func noiseTile(rng: inout SeededRNG) -> Tile {
        let types: [TileType] = [.straight, .curve, .tShape, .cross]
        return Tile(type: types[rng.nextInt(types.count)], rotation: rng.nextInt(4))
    }

    // MARK: - Private: Position selection

    /// Returns source and target cells for a level based on type + seed.
    private static func sourceAndTargets(
        for level: Level,
        rng: inout SeededRNG
    ) -> (Cell, [Cell]) {
        let gs = level.gridSize
        let corners: [Cell] = [
            Cell(0, 0),           // top-left
            Cell(0, gs - 1),      // top-right
            Cell(gs - 1, 0),      // bottom-left
            Cell(gs - 1, gs - 1)  // bottom-right
        ]

        // Source: any corner, seeded
        let si = rng.nextInt(4)
        let source = corners[si]

        if level.numTargets == 2 {
            // Two targets: the two corners that are NOT source and NOT the diagonal opposite
            let opposite = (si + 2) % 4
            let tgts = corners.enumerated()
                .filter { i, _ in i != si && i != opposite }
                .map { $0.element }
            return (source, tgts)
        } else {
            // Single target: corner diagonally opposite to source
            return (source, [corners[(si + 2) % 4]])
        }
    }

    // MARK: - Private: Helpers

    private static func dirFrom(_ a: Cell, to b: Cell) -> Direction {
        switch (b.r - a.r, b.c - a.c) {
        case (-1,  0): return .north
        case ( 1,  0): return .south
        case ( 0,  1): return .east
        default:       return .west
        }
    }

    // MARK: - Catalogue (50 levels, varied by type + grid size)

    private static func buildCatalogue() -> [Level] {
        // Each entry: (difficulty, count, gridSize, type, numTargets)
        let specs: [(DifficultyTier, Int, Int, LevelType, Int)] = [
            // Easy — 4×4, single path, 1 target (15 levels)
            (.easy, 15, 4, .singlePath, 1),

            // Medium — 4×4, branching or multi-target (15 levels)
            (.medium,  8, 4, .branching,   1),
            (.medium,  7, 4, .multiTarget, 2),

            // Hard — 5×5, single path + branching (12 levels)
            (.hard, 6, 5, .singlePath, 1),
            (.hard, 6, 5, .branching,  1),

            // Expert — 5×5, multi-target + dense (8 levels)
            (.expert, 4, 5, .multiTarget, 2),
            (.expert, 4, 5, .dense,       1),
        ]

        var catalogue: [Level] = []
        var id = 1

        for (diff, count, gs, type, nTargets) in specs {
            for _ in 0..<count {
                let seed    = UInt64(id) &* 6364136223846793005 &+ 1442695040888963407
                let maxMov  = maxMoves(gridSize: gs, difficulty: diff, numTargets: nTargets)
                catalogue.append(
                    Level(id: id, seed: seed, maxMoves: maxMov,
                          difficulty: diff, gridSize: gs,
                          levelType: type, numTargets: nTargets)
                )
                id += 1
            }
        }
        return catalogue
    }

    /// Move budget: sized so a focused player can win with reasonable efficiency.
    private static func maxMoves(gridSize gs: Int, difficulty: DifficultyTier, numTargets: Int) -> Int {
        let base: Int
        switch (gs, difficulty) {
        case (4, .easy):   base = 26
        case (4, .medium): base = 20
        case (4, .hard):   base = 18  // unused but covered for safety
        case (5, .hard):   base = 34
        case (5, .expert): base = 26
        default:           base = gs * gs
        }
        // Multi-target levels need more moves (two paths to carve)
        return numTargets > 1 ? base + 6 : base
    }
}

// MARK: - Cell helper (row/col value type)
private struct Cell: Equatable {
    let r: Int
    let c: Int
    init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}
