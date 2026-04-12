#if DEBUG
import Foundation

// MARK: - SolverResult

struct SolverResult {
    /// True when the search found a winning configuration.
    let isSolvable: Bool
    /// Minimum taps found. Equals generatorEstimate when budget was hit (isExact == false).
    let minimumMoves: Int
    /// True when Dijkstra completed without hitting the node budget.
    /// False means the result falls back to generatorEstimate and may not be exact.
    let isExact: Bool
    /// The generator's own pre-computed estimate for comparison.
    let generatorEstimate: Int

    /// Positive means solver found a shorter path than the generator expected.
    var improvement: Int { generatorEstimate - minimumMoves }
    /// True when solver confirmed the generator's estimate exactly.
    var matchesGenerator: Bool { isExact && isSolvable && minimumMoves == generatorEstimate }
}

// MARK: - LevelSolver

/// Exact minimum-move solver using Dijkstra over tile-rotation states.
///
/// State encoding: 2 bits per tile (rotation 0–3), row-major. Fits in UInt64
/// for both 4×4 (32 bits) and 5×5 (50 bits) boards.
///
/// Pruning rules:
///   • Never rotate source, target, or cross tiles (no-op or sub-optimal)
///   • Never explore paths whose total cost exceeds generatorEstimate
///     (we only care about confirming or improving on the generator)
///
/// Budget control: set nodeBudget low for batch audit runs (≈20 K per level)
/// and higher for interactive/single-level calls (≈100 K).
enum LevelSolver {

    // MARK: - Public

    /// Solve a single level. Returns exact result if within `nodeBudget`, else falls back.
    static func solve(board: [[Tile]], level: Level, nodeBudget: Int = 100_000) -> SolverResult {
        let gs          = level.gridSize
        let genEstimate = level.minimumRequiredMoves
        let initial     = encodeState(board: board, gs: gs)

        // Trivial case: board already in a winning configuration
        if checkWin(state: initial, board: board, gs: gs, level: level) {
            return SolverResult(isSolvable: true, minimumMoves: 0,
                                isExact: true, generatorEstimate: genEstimate)
        }

        var heap     = MinHeap()
        var bestCost = [UInt64: Int]()

        heap.insert(0, initial)
        bestCost[initial] = 0
        var explored = 0

        while let (cost, state) = heap.extractMin() {
            explored += 1

            // Budget exhausted — fall back to generator estimate
            if explored > nodeBudget {
                return SolverResult(isSolvable: true, minimumMoves: genEstimate,
                                    isExact: false, generatorEstimate: genEstimate)
            }

            // Skip stale entries
            guard bestCost[state] == cost else { continue }

            // Win check using the decoded rotation state
            if checkWin(state: state, board: board, gs: gs, level: level) {
                return SolverResult(isSolvable: true, minimumMoves: cost,
                                    isExact: true, generatorEstimate: genEstimate)
            }

            // Generate successors: rotate each eligible tile one step clockwise
            for r in 0..<gs {
                for c in 0..<gs {
                    let tile = board[r][c]
                    // Source and target tiles are always in their correct orientation
                    guard tile.role != .source && tile.role != .target else { continue }
                    // Cross tiles are rotationally symmetric — skip
                    guard tile.type != .cross else { continue }

                    let tapCost  = tile.isOverloaded ? 2 : 1
                    let newCost  = cost + tapCost
                    // Prune: no path longer than the known achievable solution is useful
                    guard newCost <= genEstimate else { continue }

                    let newState = rotateState(state, tileIndex: r * gs + c)
                    guard (bestCost[newState] ?? Int.max) > newCost else { continue }
                    bestCost[newState] = newCost
                    heap.insert(newCost, newState)
                }
            }
        }

        // Exhaustive search within budget found no solution — genuinely unsolvable (rare)
        return SolverResult(isSolvable: false, minimumMoves: -1,
                            isExact: true, generatorEstimate: genEstimate)
    }

    // MARK: - State encoding

    /// Encodes all tile rotations into a UInt64 (2 bits per tile, row-major order).
    private static func encodeState(board: [[Tile]], gs: Int) -> UInt64 {
        var state = UInt64(0)
        for r in 0..<gs {
            for c in 0..<gs {
                let idx = r * gs + c
                state |= UInt64(board[r][c].rotation & 3) << (idx * 2)
            }
        }
        return state
    }

    /// Returns a new state with the tile at `tileIndex` rotated +1 clockwise.
    private static func rotateState(_ state: UInt64, tileIndex: Int) -> UInt64 {
        let shift  = tileIndex * 2
        let curRot = Int((state >> shift) & 3)
        let newRot = (curRot + 1) % 4
        let mask   = UInt64(3) << shift
        return (state & ~mask) | (UInt64(newRot) << shift)
    }

    // MARK: - Win check (mirrors GameViewModel.propagateEnergy / checkWin)

    /// BFS energy propagation using tile types/roles from `board` and rotations from `state`.
    private static func checkWin(state: UInt64, board: [[Tile]], gs: Int, level: Level) -> Bool {
        var energized = [[Bool]](repeating: [Bool](repeating: false, count: gs), count: gs)
        var queue     = ContiguousArray<(Int, Int)>()

        // Seed sources
        for r in 0..<gs {
            for c in 0..<gs where board[r][c].role == .source {
                energized[r][c] = true
                queue.append((r, c))
            }
        }

        // BFS — use index into queue to avoid removeFirst overhead
        var qi = 0
        var visited = Set<Int>()
        while qi < queue.count {
            let (r, c) = queue[qi]; qi += 1
            guard visited.insert(r * gs + c).inserted else { continue }

            let tileConns = tileConnections(board[r][c], state: state, tileIndex: r * gs + c)
            for dir in tileConns {
                let (nr, nc) = neighbor(r: r, c: c, dir: dir)
                guard nr >= 0, nr < gs, nc >= 0, nc < gs else { continue }
                let nConns = tileConnections(board[nr][nc], state: state, tileIndex: nr * gs + nc)
                guard nConns.contains(dir.opposite) else { continue }
                // Mirror the engine's one-way relay check using the static board property
                guard !board[nr][nc].blockedInboundDirections.contains(dir.opposite) else { continue }
                guard !energized[nr][nc]             else { continue }
                energized[nr][nc] = true
                queue.append((nr, nc))
            }
        }

        // Tally targets and active nodes
        var onlineTargets = 0, totalTargets = 0, activeNodes = 0
        for r in 0..<gs {
            for c in 0..<gs {
                if board[r][c].role == .target { totalTargets += 1 }
                if energized[r][c] {
                    activeNodes += 1
                    if board[r][c].role == .target { onlineTargets += 1 }
                }
            }
        }
        guard totalTargets > 0 && onlineTargets == totalTargets else { return false }

        // energySaving levels also require total active nodes within the cap
        if level.objectiveType == .energySaving {
            return activeNodes <= level.energySavingLimit
        }
        return true
    }

    /// Computes connections for `tile` using its type from the board and rotation from `state`.
    private static func tileConnections(_ tile: Tile, state: UInt64, tileIndex: Int) -> Set<Direction> {
        let rotation = Int((state >> (tileIndex * 2)) & 3)
        return Set(tile.type.baseConnections.map { $0.rotated(by: rotation) })
    }

    private static func neighbor(r: Int, c: Int, dir: Direction) -> (Int, Int) {
        switch dir {
        case .north: return (r - 1, c)
        case .south: return (r + 1, c)
        case .east:  return (r, c + 1)
        case .west:  return (r, c - 1)
        }
    }
}

// MARK: - MinHeap (binary min-heap keyed by cost)

private struct MinHeap {
    private var items = ContiguousArray<(cost: Int, state: UInt64)>()

    var isEmpty: Bool { items.isEmpty }

    mutating func insert(_ cost: Int, _ state: UInt64) {
        items.append((cost, state))
        siftUp(items.count - 1)
    }

    mutating func extractMin() -> (Int, UInt64)? {
        guard !items.isEmpty else { return nil }
        let result = items[0]
        let last   = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            siftDown(0)
        }
        return (result.cost, result.state)
    }

    private mutating func siftUp(_ i: Int) {
        var i = i
        while i > 0 {
            let p = (i - 1) / 2
            guard items[i].cost < items[p].cost else { break }
            items.swapAt(i, p)
            i = p
        }
    }

    private mutating func siftDown(_ i: Int) {
        var i = i
        let n = items.count
        while true {
            let l = 2 * i + 1, r = 2 * i + 2
            var m = i
            if l < n && items[l].cost < items[m].cost { m = l }
            if r < n && items[r].cost < items[m].cost { m = r }
            guard m != i else { break }
            items.swapAt(i, m)
            i = m
        }
    }
}
#endif
