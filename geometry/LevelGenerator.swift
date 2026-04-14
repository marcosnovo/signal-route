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

    // MARK: - Level catalogue (180 levels, curated progression)
    static let levels: [Level] = buildCatalogue()

    // MARK: - Intro / tutorial level (id = 0, 3×3 handcrafted)
    /// One-tap puzzle: source–relay–target in the middle row.
    /// Relay starts rotated N+S; one tap aligns it E+W and completes the circuit.
    static let introLevel = Level(
        id: 0, seed: 0, maxMoves: 5, minimumRequiredMoves: 1,
        difficulty: .easy, gridSize: 3,
        levelType: .singlePath, numTargets: 1, timeLimit: nil,
        objectiveType: .normal, solutionPathLength: 3
    )

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

    // MARK: - Board building (public API — gameplay entry point)
    /// Returns a pre-built intro board for id == 0, otherwise generates algorithmically.
    static func buildBoard(for level: Level) -> [[Tile]] {
        buildBoardInternal(for: level).board
    }

    // MARK: - Private: Internal board builder
    /// Returns the board AND the minimum taps required to solve it from perfect play.
    ///
    /// Algorithm:
    ///   1. Place source + target(s) at grid corners (position varies by seed & type)
    ///   2. Carve seeded-DFS paths from source to every target
    ///   3. Derive tile types from accumulated connection sets
    ///   4. Fill remaining cells with noise tiles
    ///   5. Scramble relay tiles (source/target orientation is fixed)
    ///   6. Sum minimum taps over all on-path relay tiles → minimumRequiredMoves
    ///   7. Apply tile mechanics to a seeded-random subset of relay path tiles
    private static func buildBoardInternal(for level: Level) -> (board: [[Tile]], minMoves: Int, solutionPathLength: Int) {
        if level.id == 0 { return (buildIntroBoard(), 1, 3) }
        let gs = level.gridSize
        var rng = SeededRNG(seed: level.seed)

        // 1. Source and target positions
        let (source, targets) = sourceAndTargets(for: level, rng: &rng)

        // 2. Connection accumulator
        var connMap = Array(repeating: Array(repeating: Set<Direction>(), count: gs), count: gs)
        var roleMap = Array(repeating: Array(repeating: NodeRole.relay, count: gs), count: gs)
        roleMap[source.r][source.c] = .source
        for t in targets { roleMap[t.r][t.c] = .target }

        // 3. Carve a seeded-DFS path from source to each target.
        //    Simultaneously record the "approach direction" for each relay tile:
        //    the direction at that tile pointing back toward the source.
        //    This is used by the one-way relay mechanic to guarantee solvability.
        var approachDirMap: [Int: Direction] = [:]   // key: r * gs + c

        for target in targets {
            let path = dfsFindPath(from: source, to: target, gs: gs, rng: &rng)
            applyPathConnections(path: path, to: &connMap)
            for i in 1..<path.count {
                let cell = path[i]
                guard roleMap[cell.r][cell.c] == .relay else { continue }
                let key = cell.r * gs + cell.c
                if approachDirMap[key] == nil {
                    // Direction FROM this cell BACK TO the previous cell on the path
                    approachDirMap[key] = dirFrom(Cell(cell.r, cell.c), to: path[i - 1])
                }
            }
        }

        // 4–6. Build tile grid + accumulate minimum moves; track relay path tiles for mechanics.
        //      Each entry also records solved connections + approach direction for the
        //      one-way relay mechanic assignment.
        var minMoves = 0
        var grid: [[Tile]] = []
        var relayPathInfo: [(r: Int, c: Int, minTaps: Int,
                             solvedConns: Set<Direction>, approachDir: Direction?)] = []

        for r in 0..<gs {
            var row: [Tile] = []
            for c in 0..<gs {
                let conns = connMap[r][c]
                let role  = roleMap[r][c]

                if conns.isEmpty {
                    // Not on any path → noise tile
                    row.append(noiseTile(rng: &rng))
                } else {
                    let (type, solvedRot) = tileSpec(for: conns)
                    // Source/target keep correct orientation; relays are scrambled 1–3 steps
                    let scramble = (role == .source || role == .target) ? 0 : rng.nextInt(3) + 1
                    let curRot   = (solvedRot + scramble) % 4
                    var tile = Tile(type: type, rotation: curRot)
                    tile.role = role
                    row.append(tile)

                    if role == .relay {
                        let taps = minTapsToSolve(type: type, from: curRot, solvedRot: solvedRot)
                        minMoves += taps
                        relayPathInfo.append((
                            r: r, c: c, minTaps: taps,
                            solvedConns: conns,
                            approachDir: approachDirMap[r * gs + c]
                        ))
                    }
                }
            }
            grid.append(row)
        }

        // 7. Apply progressive tile mechanics based on level ID
        applyMechanics(for: level.id, to: &grid, relayPath: relayPathInfo,
                       rng: &rng, minMoves: &minMoves)

        // Count tiles on any solution path (source + relays + targets)
        let solutionPathLength = (0..<gs).reduce(0) { sum, r in
            sum + (0..<gs).reduce(0) { s, c in s + (connMap[r][c].isEmpty ? 0 : 1) }
        }

        return (grid, minMoves, solutionPathLength)
    }

    // MARK: - Private: Tile mechanics assignment
    ///
    /// Applies mechanics to a seeded-random subset of relay path tiles.
    /// Guaranteed safe: maxRotations is always ≥ minTaps + 1, so the puzzle remains solvable.
    ///
    /// Mechanic unlock thresholds (scaled for a real 1→180 difficulty curve):
    ///   rotationCap  — id ≥  31 (1 cap) → id ≥  61 (2) → id ≥ 111 (3) → id ≥ 151 (4)
    ///   overloaded   — id ≥  81 (1 tile) → id ≥ 111 (2) → id ≥ 156 (3)
    ///   timeLimit    — set on Level, not tiles (handled in buildCatalogue)
    ///   autoDrift    — id ≥ 121 (4.0 s), id ≥ 141 (3.5 s); 2nd tile id ≥ 156
    ///   oneWayRelay  — id ≥ 136 (was 146); blocks one inbound direction per tile
    ///                  Applied to 2-connection tiles only; blocked direction = exit side at
    ///                  solved rotation → solvable from source approach direction, but
    ///                  reverse-flow through the relay is impossible.
    private static func applyMechanics(
        for levelId: Int,
        to grid: inout [[Tile]],
        relayPath: [(r: Int, c: Int, minTaps: Int,
                     solvedConns: Set<Direction>, approachDir: Direction?)],
        rng: inout SeededRNG,
        minMoves: inout Int
    ) {
        guard levelId >= 31 else { return }

        // Only relay path tiles that actually require rotation are mechanic candidates
        var candidates = relayPath.filter { $0.minTaps >= 1 }
        guard !candidates.isEmpty else { return }

        // Seeded shuffle for determinism
        for i in stride(from: candidates.count - 1, through: 1, by: -1) {
            candidates.swapAt(i, rng.nextInt(i + 1))
        }

        // ── Reserve mandatory mechanic slots before early mechanics consume candidates ──
        // Fragile (id ≥ 146) and charge gate (id ≥ 158) are load-bearing for their
        // level segments. Without reservation, cap + ovl + drift + oneWay can exhaust
        // all candidates, silently skipping fragile and gate (mechanic starvation).
        //
        // Fix: split the shuffled pool into two disjoint halves —
        //   earlyPool     → cap, ovl, drift, oneWay consume from here
        //   mandatoryPool → fragile and gate guaranteed slots from here
        // mandatoryPool is taken from the end of the shuffled array; the split is
        // deterministic and does not affect earlier mechanic assignments.

        let fragileNeeded: Int = {
            guard levelId >= 146 else { return 0 }
            if levelId >= 165 { return 3 }   // was 168; moved earlier so L165–167 warm up 3-fragile without interference
            if levelId >= 156 { return 2 }
            return 1
        }()
        let gateNeeded: Int = {
            guard levelId >= 158 else { return 0 }
            return levelId >= 171 ? 2 : 1
        }()
        let mandatoryNeeded = fragileNeeded + gateNeeded

        let splitPoint    = max(0, candidates.count - mandatoryNeeded)
        var earlyPool     = Array(candidates.prefix(splitPoint))
        let mandatoryPool = Array(candidates.suffix(candidates.count - splitPoint))

        // Rotation Cap — medium+ (id ≥ 31)
        // 1 cap, scaling to 4 caps by endgame. maxRotations = minTaps + 1 → 1 slack, always solvable.
        if !earlyPool.isEmpty {
            let capCount: Int
            if levelId >= 151      { capCount = min(4, earlyPool.count) }
            else if levelId >= 111 { capCount = min(3, earlyPool.count) }
            else if levelId >= 61  { capCount = min(2, earlyPool.count) }
            else                   { capCount = 1 }
            for i in 0..<capCount {
                let info = earlyPool[i]
                grid[info.r][info.c].maxRotations = info.minTaps + 1
            }
            earlyPool.removeFirst(capCount)
        }

        // Overloaded Relay — mid-hard+ (id ≥ 81, was 91)
        // First tap arms, second tap rotates. Costs 2 moves per rotation.
        // Scales to 3 tiles at id ≥ 156.
        if levelId >= 81 {
            let overloadCount: Int
            if levelId >= 156      { overloadCount = min(3, earlyPool.count) }
            else if levelId >= 111 { overloadCount = min(2, earlyPool.count) }
            else                   { overloadCount = min(1, earlyPool.count) }
            for _ in 0..<overloadCount {
                guard !earlyPool.isEmpty else { break }
                let info = earlyPool.removeFirst()
                grid[info.r][info.c].isOverloaded = true
                minMoves += info.minTaps
            }
        }

        // Auto-Drift — expert mid-tier (id ≥ 121, was 131)
        // Tile drifts +1 clockwise after a delay; player must sequence timing.
        // Delay tightens at id ≥ 141. Second drifting tile added at id ≥ 156.
        if levelId >= 121 && !earlyPool.isEmpty {
            let driftCount = levelId >= 156 ? min(2, earlyPool.count) : 1
            for _ in 0..<driftCount {
                guard !earlyPool.isEmpty else { break }
                let info = earlyPool.removeFirst()
                let delay: Double = levelId >= 141 ? 3.5 : 4.0
                grid[info.r][info.c].autoDriftDelay = delay
            }
        }

        // One-Way Relay — expert (id ≥ 136, was 146)
        // Blocks energy entry from the exit side at the solved rotation, making
        // reverse-flow impossible. Only applied to 2-connection relay tiles
        // (straight/curve) where the approach direction is known, guaranteeing
        // the puzzle remains solvable via the intended source-side path.
        if levelId >= 136 {
            // Find the first eligible 2-connection relay with a known approach dir
            if let idx = earlyPool.firstIndex(where: {
                $0.solvedConns.count == 2 && $0.approachDir != nil
            }) {
                let info = earlyPool.remove(at: idx)
                let approachDir = info.approachDir!
                // Exit direction = the solved connection that is NOT the approach direction
                if let exitDir = info.solvedConns.first(where: { $0 != approachDir }) {
                    // Unrotate exitDir to the canonical (rotation-0) frame so that
                    // blockedInboundDirections == [exitDir] at the solved rotation.
                    let (_, solvedRot) = tileSpec(for: info.solvedConns)
                    let baseDir = exitDir.rotated(by: (4 - solvedRot) % 4)
                    grid[info.r][info.c].baseBlockedInboundDirections = [baseDir]
                }
            }
        }

        // Fragile Tile — expert late (id ≥ 146, was 151)
        // Tile burns out after being on the energized network for 3 player taps.
        // Two fragile tiles at id ≥ 156 (was 158); three at id ≥ 165 (was 168).
        // Guaranteed placement via mandatoryPool reservation above.
        if levelId >= 146 {
            let fragileCount = min(fragileNeeded, mandatoryPool.count)
            for i in 0..<fragileCount {
                grid[mandatoryPool[i].r][mandatoryPool[i].c].fragileCharges = 3
            }
        }

        // Charge Gate — endgame (id ≥ 158, was 164)
        // Gate relay only conducts energy after 2 charge cycles.
        // Second gate at id ≥ 171 (new).
        // Guaranteed placement via mandatoryPool reservation above (tiles after fragile slots).
        if levelId >= 158 {
            let gateStart = min(fragileNeeded, mandatoryPool.count)
            let gateCount = min(gateNeeded, mandatoryPool.count - gateStart)
            for i in gateStart..<(gateStart + gateCount) {
                grid[mandatoryPool[i].r][mandatoryPool[i].c].gateChargesRequired = 2
                minMoves += 1
            }
        }

        // Interference Zone — endgame (id ≥ 168, was 164)
        // Visual static overlay applied to relay tiles; no BFS or move-count effect.
        // Delayed past L165–167 so those levels serve as a warm-up for 3 fragile tiles
        // without the added visual noise of interference — the full combination arrives at L168.
        if levelId >= 168 {
            let gs = grid.count
            let pathSet = Set(relayPath.map { $0.r * gs + $0.c })
            var noiseTiles: [(Int, Int)] = []
            var pathTiles:  [(Int, Int)] = []
            for r in 0..<gs {
                for c in 0..<gs {
                    guard grid[r][c].role == .relay else { continue }
                    if pathSet.contains(r * gs + c) {
                        pathTiles.append((r, c))
                    } else {
                        noiseTiles.append((r, c))
                    }
                }
            }
            for i in stride(from: noiseTiles.count - 1, through: 1, by: -1) {
                noiseTiles.swapAt(i, rng.nextInt(i + 1))
            }
            for i in stride(from: pathTiles.count - 1, through: 1, by: -1) {
                pathTiles.swapAt(i, rng.nextInt(i + 1))
            }
            // 3 noise tiles + (id ≥ 171: 1 path tile) for genuine visual confusion
            let noiseCount = min(3, noiseTiles.count)
            for i in 0..<noiseCount {
                grid[noiseTiles[i].0][noiseTiles[i].1].hasInterference = true
            }
            if levelId >= 171 && !pathTiles.isEmpty {
                grid[pathTiles[0].0][pathTiles[0].1].hasInterference = true
            }
        }
    }

    // MARK: - Private: Minimum taps for one tile to reach a valid solved state
    ///
    /// • `cross`    — all rotations are equivalent → 0 taps always
    /// • `straight` — 180° symmetry (rot 0 == rot 2, rot 1 == rot 3) → at most 1 tap
    /// • `curve` / `tShape` — four distinct states → up to 3 clockwise taps
    private static func minTapsToSolve(type: TileType, from curRot: Int, solvedRot: Int) -> Int {
        switch type {
        case .cross:
            return 0
        case .straight:
            // Two equivalent solved rotations: solvedRot and (solvedRot + 2) % 4
            let alt = (solvedRot + 2) % 4
            return min((solvedRot - curRot + 4) % 4,
                       (alt      - curRot + 4) % 4)
        case .curve, .tShape:
            return (solvedRot - curRot + 4) % 4
        }
    }

    // MARK: - Private: Path carving

    /// DFS with seeded random neighbour ordering. Guaranteed to find a path on an open grid.
    private static func dfsFindPath(
        from start: Cell,
        to end: Cell,
        gs: Int,
        rng: inout SeededRNG
    ) -> [Cell] {
        var r = rng
        var visited = Array(repeating: Array(repeating: false, count: gs), count: gs)
        var path: [Cell] = []

        func dfs(_ cell: Cell) -> Bool {
            guard !visited[cell.r][cell.c] else { return false }
            visited[cell.r][cell.c] = true
            path.append(cell)
            if cell == end { return true }

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
        rng = r
        return path
    }

    /// Writes directional connections for consecutive cells in `path` into `connMap`.
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
        return (.cross, 0)
    }

    private static func noiseTile(rng: inout SeededRNG) -> Tile {
        let types: [TileType] = [.straight, .curve, .tShape, .cross]
        return Tile(type: types[rng.nextInt(types.count)], rotation: rng.nextInt(4))
    }

    // MARK: - Private: Position selection

    private static func sourceAndTargets(
        for level: Level,
        rng: inout SeededRNG
    ) -> (Cell, [Cell]) {
        let gs = level.gridSize
        let corners: [Cell] = [
            Cell(0, 0),
            Cell(0, gs - 1),
            Cell(gs - 1, 0),
            Cell(gs - 1, gs - 1)
        ]

        let si = rng.nextInt(4)
        let source = corners[si]

        if level.numTargets == 2 {
            let opposite = (si + 2) % 4
            let tgts = corners.enumerated()
                .filter { i, _ in i != si && i != opposite }
                .map { $0.element }
            return (source, tgts)
        } else {
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

    // MARK: - Catalogue (180 levels, curated progression)
    //
    // Each spec row: (difficulty, count, gridSize, levelType, numTargets)
    //
    // Tier breakdown:
    //   Easy     (IDs   1– 30, 4×4): introduces all five level types, no mechanics
    //   Medium   (IDs  31– 70, 4×4+5×5): rotation cap unlocks at ID 31 (2 caps at 61)
    //   Hard     (IDs  71–110, 5×5): time pressure (ID 71) + overloaded from ID 81
    //   Expert   (IDs 111–150, 5×5): 3 caps + 2 overloaded; autoDrift at 121; oneWay at 136; 42 s timer
    //   Endgame  (IDs 151–180, 5×5): near-zero buffer; fragile+chargeGate+interference
    //   Endgame  (IDs 151–180, 5×5): fragile tile (151), charge gate (164), interference (171)

    private static func buildCatalogue() -> [Level] {
        let specs: [(DifficultyTier, Int, Int, LevelType, Int)] = [

            // ── EASY (30 levels, 4×4) ────────────────────────────────────────
            // IDs  1– 8: linear routing; minimal noise; learn basic rotation
            (.easy,  8, 4, .singlePath,  1),
            // IDs  9–13: branching paths; introduce maxCoverage objective
            (.easy,  5, 4, .branching,   1),
            // IDs 14–17: two targets; normal objective; learn multi-target routing
            (.easy,  4, 4, .multiTarget, 2),
            // IDs 18–22: dense grid; introduce energySaving objective gently
            (.easy,  5, 4, .dense,       1),
            // IDs 23–30: second round of linear routing; slightly varied seeds
            (.easy,  8, 4, .singlePath,  1),

            // ── MEDIUM (40 levels, 4×4 + 5×5) ───────────────────────────────
            // Rotation cap unlocks at ID 31 — first tap budgets matter now
            // IDs 31–37: 4×4 normal; 1 rotation-capped tile
            (.medium,  7, 4, .singlePath,  1),
            // IDs 38–43: 4×4 branching; maxCoverage + rotation cap
            (.medium,  6, 4, .branching,   1),
            // IDs 44–51: step up to 5×5; normal; rotation cap on larger grid
            (.medium,  8, 5, .singlePath,  1),
            // IDs 52–59: 5×5 multi-target; two targets demand planning
            (.medium,  8, 5, .multiTarget, 2),
            // IDs 60–64: 4×4 multi-target; energySaving variant
            (.medium,  5, 4, .multiTarget, 2),
            // IDs 65–70: 5×5 dense; energySaving on a large noisy grid
            (.medium,  6, 5, .dense,       1),

            // ── HARD (40 levels, 5×5) ────────────────────────────────────────
            // Time pressure starts at ID 71 (120 s). Overloaded relay at ID 91.
            // IDs  71–78: normal, time (120 s), 2 rotation-capped tiles
            (.hard,  8, 5, .singlePath,  1),
            // IDs  79–85: maxCoverage, time (120 s)
            (.hard,  7, 5, .branching,   1),
            // IDs  86–92: normal + energySaving mix, time (120 s), overloaded from ID 91
            (.hard,  7, 5, .multiTarget, 2),
            // IDs  93–100: dense energySaving, time (120 s), overloaded
            (.hard,  8, 5, .dense,       1),
            // IDs 101–105: sparse; time tightens to 100 s; overloaded
            (.hard,  5, 5, .sparse,      1),
            // IDs 106–110: multi-target; time (100 s); overloaded; hardest hard
            (.hard,  5, 5, .multiTarget, 2),

            // ── EXPERT (40 levels, 5×5) ──────────────────────────────────────
            // Overloaded (2 tiles) active throughout. AutoDrift from ID 121. Timers brutal.
            // IDs 111–115: singlePath intro — 3-cap rotations + 2 overloaded; time 72 s
            (.expert,  5, 5, .singlePath,  1),
            // IDs 116–123: multi-target right away — planning required; time 72→62 s
            (.expert,  8, 5, .multiTarget, 2),
            // IDs 124–129: maxCoverage branching; time 62 s
            (.expert,  6, 5, .branching,   1),
            // IDs 130–135: sparse + autoDrift (id 121 threshold fires); time 52 s
            (.expert,  6, 5, .sparse,      1),
            // IDs 136–141: dense energySaving + oneWayRelay (id 136); time 52 s
            (.expert,  6, 5, .dense,       1),
            // IDs 142–150: multi-target + all mechanics; time 42 s — hardest expert
            (.expert,  9, 5, .multiTarget, 2),

            // ── ENDGAME (30 levels, 5×5) ─────────────────────────────────────
            // Near-zero move buffer (max 1, ×0.08). Timer 42 s. All mechanics active.
            // IDs 151–157: multi-target + fragile (1) + 4 rotation caps + 3 overloaded
            (.expert,  7, 5, .multiTarget, 2),
            // IDs 158–163: multi-target + fragile (2) + charge gate (id 158)
            (.expert,  6, 5, .multiTarget, 2),
            // IDs 164–170: multi-target + interference (id 164) + charge gate
            (.expert,  7, 5, .multiTarget, 2),
            // IDs 171–180: dense + double charge gate (id 171) + path interference
            (.expert, 10, 5, .dense,       1),
        ]

        var catalogue: [Level] = []
        var id = 1

        for (diff, count, gs, type, nTargets) in specs {
            for _ in 0..<count {
                let seed   = UInt64(id) &* 6364136223846793005 &+ 1442695040888963407
                let tl     = timeLimitSeconds(for: id, difficulty: diff)
                let objType = objectiveType(for: type, id: id)

                // Build a temporary level (maxMoves doesn't affect board generation)
                // to measure the actual minimum moves and solution path length for this seed.
                let temp = Level(
                    id: id, seed: seed, maxMoves: 99, minimumRequiredMoves: 0,
                    difficulty: diff, gridSize: gs, levelType: type,
                    numTargets: nTargets, timeLimit: tl,
                    objectiveType: objType, solutionPathLength: 0
                )
                let (_, minMoves, pathLen) = buildBoardInternal(for: temp)
                let maxMov = minMoves + movesBuffer(for: diff, minMoves: minMoves, levelId: id)

                catalogue.append(Level(
                    id: id, seed: seed,
                    maxMoves: maxMov, minimumRequiredMoves: minMoves,
                    difficulty: diff, gridSize: gs,
                    levelType: type, numTargets: nTargets, timeLimit: tl,
                    objectiveType: objType, solutionPathLength: pathLen
                ))
                id += 1
            }
        }
        return catalogue
    }

    /// Time limit in seconds for a level, or nil if there is no time limit.
    ///
    /// Easy / Medium (IDs   1– 70): no timer — learn mechanics first
    /// Hard early    (IDs  71–100): 110 s — first exposure to time pressure
    /// Hard late     (IDs 101–110):  95 s — moderate squeeze
    /// Expert tier 1 (IDs 111–120):  72 s — clear skill requirement
    /// Expert tier 2 (IDs 121–130):  62 s — autoDrift era
    /// Expert tier 3 (IDs 131–140):  52 s — oneWayRelay / fragile era
    /// Expert tier 4 (IDs 141–180):  42 s — endgame mechanics: brutal
    private static func timeLimitSeconds(for id: Int, difficulty: DifficultyTier) -> Int? {
        switch difficulty {
        case .easy, .medium:
            return nil
        case .hard:
            return id >= 101 ? 95 : 110
        case .expert:
            if id >= 141 { return 42 }
            if id >= 131 { return 52 }
            if id >= 121 { return 62 }
            return 72
        }
    }

    /// Objective type derived from structural level type and progression phase.
    ///
    /// Phase 1 (IDs  1– 50): fixed objectives — one mechanic, one goal, learn the basics.
    /// Phase 2 (IDs 51–110): cross-objectives introduced occasionally — expect the unexpected.
    /// Phase 3 (IDs 111–180): aggressive mixing — any archetype can carry any objective,
    ///                         creating trade-off puzzles (efficiency vs coverage vs speed).
    private static func objectiveType(for levelType: LevelType, id: Int) -> LevelObjectiveType {

        // ── Phase 1: fixed — clarity over variety ─────────────────────────────
        if id <= 50 {
            switch levelType {
            case .singlePath:  return .normal
            case .branching:   return .maxCoverage
            case .dense:       return .energySaving
            case .sparse:      return id % 3 == 0 ? .normal : .maxCoverage
            case .multiTarget: return id % 3 == 0 ? .energySaving : .normal
            }
        }

        // ── Phase 2: occasional cross-objectives ──────────────────────────────
        if id <= 110 {
            switch levelType {
            case .singlePath:
                // Mostly pure routing; every 7th level demands lean routing instead
                return id % 7 == 0 ? .energySaving : .normal
            case .branching:
                // Mostly coverage; every 5th level demands lean routing instead
                return id % 5 == 0 ? .energySaving : .maxCoverage
            case .dense:
                // Mostly lean routing; occasional normal break
                return id % 4 == 0 ? .normal : .energySaving
            case .sparse:
                return id % 3 == 0 ? .normal : .maxCoverage
            case .multiTarget:
                // Cycles all three — planning + efficiency + coverage
                switch id % 3 {
                case 0:  return .energySaving
                case 1:  return .normal
                default: return .maxCoverage
                }
            }
        }

        // ── Phase 3: aggressive mixing — every type can carry any objective ───
        switch levelType {
        case .singlePath:
            // Alternates: unique-route efficiency puzzle vs pure routing
            return id % 2 == 0 ? .energySaving : .normal
        case .branching:
            // Alternates: coverage exploration vs lean branching (true trade-off)
            return id % 3 == 0 ? .energySaving : .maxCoverage
        case .dense:
            // Three-way cycle: lean routing / coverage / normal
            switch id % 3 {
            case 0:  return .normal
            case 1:  return .energySaving
            default: return .maxCoverage
            }
        case .sparse:
            // Three-way cycle: coverage / efficiency / normal
            switch id % 3 {
            case 0:  return .normal
            case 1:  return .maxCoverage
            default: return .energySaving
            }
        case .multiTarget:
            // Full cycle — multi-target + any objective = complex trade-off
            switch id % 3 {
            case 0:  return .maxCoverage
            case 1:  return .energySaving
            default: return .normal
            }
        }
    }

    /// Proportional move buffer (maxMoves − minimumRequiredMoves).
    ///
    /// Scales with path length so difficulty feels consistent regardless of board size.
    /// The `levelId` parameter applies an extra squeeze for the deepest endgame levels.
    ///
    /// Formula:  buffer = max(floor, floor(minMoves × ratio))
    ///   Easy            — max(8,  min × 0.65)  very forgiving
    ///   Medium          — max(4,  min × 0.45)  moderate pressure
    ///   Hard            — max(2,  min × 0.26)  limited margin for error
    ///   Expert          — max(1,  min × 0.15)  near-optimal required
    ///   Endgame (≥151)  — max(1,  min × 0.08)  essentially perfect play
    private static func movesBuffer(for difficulty: DifficultyTier, minMoves: Int, levelId: Int = 0) -> Int {
        if levelId >= 151 { return max(1, Int(Double(minMoves) * 0.08)) }
        switch difficulty {
        case .easy:   return max(8, Int(Double(minMoves) * 0.65))
        case .medium: return max(4, Int(Double(minMoves) * 0.45))
        case .hard:   return max(2, Int(Double(minMoves) * 0.26))
        case .expert: return max(1, Int(Double(minMoves) * 0.15))
        }
    }

    // MARK: - Intro board (handcrafted)

    /// 3×3 tutorial board. Path is a single horizontal line across the middle row.
    private static func buildIntroBoard() -> [[Tile]] {
        var board: [[Tile]] = (0..<3).map { _ in
            (0..<3).map { _ in Tile(type: .curve, rotation: 0) }
        }

        board[0][0] = Tile(type: .curve, rotation: 0)
        board[0][1] = Tile(type: .curve, rotation: 0)
        board[0][2] = Tile(type: .curve, rotation: 0)

        var source = Tile(type: .straight, rotation: 1)
        source.role = .source
        board[1][0] = source

        board[1][1] = Tile(type: .straight, rotation: 0)

        var target = Tile(type: .straight, rotation: 1)
        target.role = .target
        board[1][2] = target

        board[2][0] = Tile(type: .curve, rotation: 2)
        board[2][1] = Tile(type: .curve, rotation: 2)
        board[2][2] = Tile(type: .curve, rotation: 2)

        return board
    }
}

// MARK: - Cell helper (row/col value type)
private struct Cell: Equatable {
    let r: Int
    let c: Int
    init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}
