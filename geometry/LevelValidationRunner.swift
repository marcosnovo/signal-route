#if DEBUG
import Foundation

// MARK: - LevelValidationReport
/// Per-level audit result produced by LevelValidationRunner.
struct LevelValidationReport {
    let levelID:              Int
    let difficulty:           DifficultyTier
    let gridSize:             Int
    let levelType:            LevelType
    let objectiveType:        LevelObjectiveType
    let numTargets:           Int
    let timeLimit:            Int?

    let minimumRequiredMoves: Int
    let moveLimit:            Int
    let buffer:               Int        // moveLimit - minimumRequiredMoves
    let solutionPathLength:   Int

    let hasRotationCap:       Bool
    let hasOverloaded:        Bool
    let hasAutoDrift:         Bool
    let hasOneWayRelay:       Bool
    let hasFragileTile:       Bool
    let hasChargeGate:        Bool
    let hasInterferenceZone:  Bool

    /// Heuristic pass: source count == 1, target count matches spec, path ≥ 3.
    let isSolvable:           Bool
    let warnings:             [String]

    /// Solver result — nil when validation ran without solver (useSolver: false).
    let solverResult:         SolverResult?

    /// Composite difficulty estimate, independent of assigned tier.
    /// score = minimumRequiredMoves + solutionPathLength×0.25 + mechanicBonus + gridSizeBonus
    /// Mechanic bonuses: rotationCap +2, overloaded +3, autoDrift +4
    /// Grid size bonus:  5×5 +3, 4×4 +0
    let complexityScore:      Float

    var hasMechanics: Bool {
        hasRotationCap || hasOverloaded || hasAutoDrift || hasOneWayRelay
            || hasFragileTile || hasChargeGate || hasInterferenceZone
    }
    /// True when the puzzle requires ≤ 1 tap to solve — almost certainly handed to the player.
    var isTrivial: Bool { minimumRequiredMoves <= 1 }
    /// Best confirmed minimum: solver result if available and exact, else generator estimate.
    var confirmedMinMoves: Int {
        if let s = solverResult, s.isExact { return s.minimumMoves }
        return minimumRequiredMoves
    }
    /// True when solver found a shorter path than the generator predicted.
    var solverFoundShorterPath: Bool { (solverResult?.improvement ?? 0) > 0 }
}

// MARK: - LevelValidationRunner
/// Validates all entries in LevelGenerator.levels and produces a structured report.
/// Entirely debug-only — wrap call sites with #if DEBUG.
enum LevelValidationRunner {

    // MARK: - Public API

    /// Validate every level in the catalogue. Returns one report per level.
    /// - Parameter useSolver: When true, runs the exact Dijkstra solver per level
    ///   (budget: 20 K nodes per level — adds ~300 ms total for 150 levels).
    static func validateAll(useSolver: Bool = false) -> [LevelValidationReport] {
        LevelGenerator.levels.map { validate(level: $0, useSolver: useSolver) }
    }

    /// Validate a single level, building its board and inspecting every tile.
    /// - Parameter useSolver: When true, runs Dijkstra to confirm/improve minimumRequiredMoves.
    static func validate(level: Level, useSolver: Bool = false) -> LevelValidationReport {
        let board  = LevelGenerator.buildBoard(for: level)
        let tiles  = board.flatMap { $0 }

        let hasRotationCap      = tiles.contains { $0.maxRotations  != nil }
        let hasOverloaded       = tiles.contains { $0.isOverloaded  }
        let hasAutoDrift        = tiles.contains { $0.autoDriftDelay != nil }
        let hasOneWayRelay      = tiles.contains { !$0.baseBlockedInboundDirections.isEmpty }
        let hasFragileTile      = tiles.contains { $0.fragileCharges != nil }
        let hasChargeGate       = tiles.contains { $0.gateChargesRequired != nil }
        let hasInterferenceZone = tiles.contains { $0.hasInterference }
        let sourceCount         = tiles.filter   { $0.role == .source }.count
        let targetCount         = tiles.filter   { $0.role == .target }.count

        var warnings: [String] = []

        // ── Solvability heuristic ─────────────────────────────────────────
        // The generator guarantees a valid path, so failures here indicate
        // a catalogue or generator bug rather than a real unsolvable puzzle.
        let isSolvable = sourceCount == 1
            && targetCount == level.numTargets
            && level.solutionPathLength >= 3
        if !isSolvable {
            warnings.append("SOLVABILITY: board appears invalid — "
                + "source=\(sourceCount) target=\(targetCount) "
                + "pathLen=\(level.solutionPathLength)")
        }

        // ── Trivial detection ─────────────────────────────────────────────
        if level.minimumRequiredMoves == 0 {
            warnings.append("TRIVIAL: minimumRequiredMoves = 0 "
                + "(board already solved after scramble)")
        } else if level.minimumRequiredMoves <= 1 && level.difficulty != .easy {
            warnings.append("TRIVIAL: minimumRequiredMoves = \(level.minimumRequiredMoves) "
                + "on \(level.difficulty.fullLabel) level")
        } else if level.minimumRequiredMoves <= 3 && level.difficulty == .expert {
            warnings.append("TRIVIAL: minimumRequiredMoves = \(level.minimumRequiredMoves) "
                + "seems very low for EXPERT")
        }

        // ── Move buffer calibration ───────────────────────────────────────
        let range = bufferRange(for: level.difficulty)
        if level.moveBuffer > range.max {
            warnings.append("GENEROUS: buffer \(level.moveBuffer) > max \(range.max) "
                + "for \(level.difficulty.fullLabel)")
        }
        if level.moveBuffer < range.min {
            warnings.append("TIGHT: buffer \(level.moveBuffer) < min \(range.min) "
                + "for \(level.difficulty.fullLabel)")
        }

        // ── Path topology ─────────────────────────────────────────────────
        let minPath: Int
        switch level.difficulty {
        case .easy:   minPath = 3
        case .medium: minPath = 4
        case .hard:   minPath = 5
        case .expert: minPath = 6
        }
        if level.solutionPathLength < minPath {
            warnings.append("SIMPLE: solutionPathLength \(level.solutionPathLength) "
                + "< expected ≥ \(minPath) for \(level.difficulty.fullLabel)")
        }

        // ── Expected mechanics ────────────────────────────────────────────
        // Mechanics require relay tiles with minTaps ≥ 1 as candidates.
        // If all relay path tiles happened to need 0 taps (rare but possible),
        // the generator correctly skips the mechanic — flag it as a soft warning.
        if level.id >= 31 && !hasRotationCap {
            warnings.append("NO_CAP: expected rotationCap at id ≥ 31 but none applied "
                + "(all relay relays may already be in solved position)")
        }
        if level.id >= 91 && !hasOverloaded {
            warnings.append("NO_OVERLOAD: expected overloaded relay at id ≥ 91 but none applied")
        }
        if level.id >= 131 && !hasAutoDrift {
            warnings.append("NO_DRIFT: expected autoDrift at id ≥ 131 but none applied")
        }
        if level.id >= 146 && !hasOneWayRelay {
            warnings.append("NO_ONEWAY: expected oneWayRelay at id ≥ 146 but none applied "
                + "(no eligible 2-connection relay with known approach direction)")
        }
        if level.id < 146 && hasOneWayRelay {
            warnings.append("UNEXPECTED_ONEWAY: oneWayRelay present at id < 146")
        }
        if level.id >= 151 && !hasFragileTile {
            warnings.append("NO_FRAGILE: expected fragileTile at id ≥ 151 but none applied "
                + "(no candidate relay tiles remaining after earlier mechanics)")
        }
        if level.id < 151 && hasFragileTile {
            warnings.append("UNEXPECTED_FRAGILE: fragileTile present at id < 151")
        }
        if level.id >= 164 && !hasChargeGate {
            warnings.append("NO_GATE: expected chargeGate at id ≥ 164 but none applied "
                + "(no candidate relay tiles remaining)")
        }
        if level.id < 164 && hasChargeGate {
            warnings.append("UNEXPECTED_GATE: chargeGate present at id < 164")
        }
        if level.id >= 171 && !hasInterferenceZone {
            warnings.append("NO_INTERFERENCE: expected interferenceZone at id ≥ 171 but none applied")
        }
        if level.id < 171 && hasInterferenceZone {
            warnings.append("UNEXPECTED_INTERFERENCE: interferenceZone present at id < 171")
        }

        // ── Objective quality ─────────────────────────────────────────────
        let totalTiles = level.gridSize * level.gridSize
        let pathRatio  = Float(level.solutionPathLength) / Float(totalTiles)

        if level.objectiveType == .energySaving {
            if level.energySavingLimit >= totalTiles {
                warnings.append("OBJECTIVE_EMPTY: energySaving limit "
                    + "\(level.energySavingLimit) ≥ total tiles \(totalTiles) — constraint never binds")
            }
            if pathRatio > 0.75 {
                warnings.append("OBJECTIVE_WEAK: energySaving path covers "
                    + "\(Int(pathRatio * 100))% of grid — very little room to save energy")
            }
        }

        if level.objectiveType == .maxCoverage && pathRatio < 0.30 {
            warnings.append("OBJECTIVE_WEAK: maxCoverage but solution path is only "
                + "\(Int(pathRatio * 100))% of grid — coverage bonus may feel negligible")
        }

        // ── Complexity score + misclassification ──────────────────────────
        let score = complexityScore(
            minMoves:        level.minimumRequiredMoves,
            pathLength:      level.solutionPathLength,
            hasRotCap:       hasRotationCap,
            hasOverloaded:   hasOverloaded,
            hasAutoDrift:    hasAutoDrift,
            hasFragileTile:  hasFragileTile,
            hasChargeGate:   hasChargeGate,
            hasInterference: hasInterferenceZone,
            gridSize:        level.gridSize
        )
        let scoreRange = complexityRange(for: level.difficulty)
        if score < scoreRange.min - 5 {
            warnings.append(String(format:
                "MISCLASSIFIED: complexity %.1f is LOW for %@ (expected ≥ %.0f) — may be too easy",
                score, level.difficulty.fullLabel, scoreRange.min))
        } else if score > scoreRange.max + 5 {
            warnings.append(String(format:
                "MISCLASSIFIED: complexity %.1f is HIGH for %@ (expected ≤ %.0f) — may be too hard",
                score, level.difficulty.fullLabel, scoreRange.max))
        }

        // ── Solver (optional) ─────────────────────────────────────────────
        var solverResult: SolverResult? = nil
        if useSolver {
            // Budget capped at 20 K nodes so 150-level audit stays under ~500 ms total
            let result = LevelSolver.solve(board: board, level: level, nodeBudget: 20_000)
            solverResult = result

            if !result.isSolvable {
                warnings.append("SOLVER_FAIL: Dijkstra found no solution within budget "
                    + "(genuinely unsolvable or generatorEstimate is unachievable)")
            } else if result.isExact && result.improvement > 0 {
                warnings.append("SHORTER_PATH: solver found minimum \(result.minimumMoves) "
                    + "vs generator estimate \(result.generatorEstimate) "
                    + "(\(result.improvement) fewer moves via alternative path)")
            } else if !result.isExact {
                warnings.append("SOLVER_INCONCLUSIVE: budget hit — "
                    + "fell back to generator estimate \(result.generatorEstimate)")
            }
        }

        return LevelValidationReport(
            levelID:              level.id,
            difficulty:           level.difficulty,
            gridSize:             level.gridSize,
            levelType:            level.levelType,
            objectiveType:        level.objectiveType,
            numTargets:           level.numTargets,
            timeLimit:            level.timeLimit,
            minimumRequiredMoves: level.minimumRequiredMoves,
            moveLimit:            level.maxMoves,
            buffer:               level.moveBuffer,
            solutionPathLength:   level.solutionPathLength,
            hasRotationCap:       hasRotationCap,
            hasOverloaded:        hasOverloaded,
            hasAutoDrift:         hasAutoDrift,
            hasOneWayRelay:       hasOneWayRelay,
            hasFragileTile:       hasFragileTile,
            hasChargeGate:        hasChargeGate,
            hasInterferenceZone:  hasInterferenceZone,
            isSolvable:           isSolvable,
            warnings:             warnings,
            solverResult:         solverResult,
            complexityScore:      score
        )
    }

    // MARK: - Console report

    /// Prints a full formatted audit to the Xcode console.
    static func printReport(_ reports: [LevelValidationReport]) {
        let total       = reports.count
        let warned      = reports.filter { !$0.warnings.isEmpty }.count
        let trivial     = reports.filter { $0.isTrivial }.count
        let unsolvable  = reports.filter { !$0.isSolvable }.count
        let noMech      = reports.filter { !$0.hasMechanics && $0.levelID >= 31 }.count

        print("")
        print("╔══════════════════════════════════════════════════════════╗")
        print("║       SIGNAL ROUTE — CATALOGUE AUDIT                    ║")
        print("╠══════════════════════════════════════════════════════════╣")
        print(String(format: "║  Total levels     : %-36d║", total))
        print(String(format: "║  Levels warned    : %-36d║", warned))
        print(String(format: "║  Trivial (min ≤ 1): %-36d║", trivial))
        print(String(format: "║  Heuristic fails  : %-36d║", unsolvable))
        print(String(format: "║  Missing mechanics: %-36d║", noMech))
        print("╚══════════════════════════════════════════════════════════╝")

        var lastDiff: DifficultyTier? = nil
        for r in reports {
            if r.difficulty != lastDiff {
                lastDiff = r.difficulty
                let header = diffSectionHeader(r.difficulty)
                print("")
                print(header)
            }

            let mech = [
                r.hasRotationCap     ? "CAP" : nil,
                r.hasOverloaded      ? "OVL" : nil,
                r.hasAutoDrift       ? "DRF" : nil,
                r.hasOneWayRelay     ? "OWR" : nil,
                r.hasFragileTile     ? "FRG" : nil,
                r.hasChargeGate      ? "CGT" : nil,
                r.hasInterferenceZone ? "INF" : nil,
            ].compactMap { $0 }.joined(separator: "+")
            let mechStr  = mech.isEmpty
                ? "         "
                : ("[" + mech + "]").padding(toLength: 9, withPad: " ", startingAt: 0)

            let timerStr = r.timeLimit.map { String(format: "%3ds", $0) } ?? "    "
            let warnMark = r.warnings.isEmpty ? " " : "⚠"
            let trivMark = r.isTrivial        ? "T" : " "
            let obj: String
            switch r.objectiveType {
            case .normal:       obj = "NRM"
            case .maxCoverage:  obj = "COV"
            case .energySaving: obj = "SAV"
            }

            // Solver column: show confirmed min, or "~gen" if inconclusive, or blank
            let solverStr: String
            if let s = r.solverResult {
                if !s.isSolvable {
                    solverStr = " FAIL"
                } else if s.isExact && s.improvement > 0 {
                    solverStr = String(format: " S%-2d!", s.minimumMoves)  // shorter path found
                } else if s.isExact {
                    solverStr = String(format: " S%-2d ", s.minimumMoves)  // confirmed
                } else {
                    solverStr = "  ~  "   // budget hit, inconclusive
                }
            } else {
                solverStr = "     "       // solver not run
            }

            print(String(format: " %@ %@  L%03d  %dx%d  min=%-3d max=%-3d buf=%-3d path=%-3d tgt=%d  cx=%-5.1f  %@⏱%@  %@%@",
                warnMark, trivMark,
                r.levelID, r.gridSize, r.gridSize,
                r.minimumRequiredMoves, r.moveLimit, r.buffer,
                r.solutionPathLength, r.numTargets,
                r.complexityScore,
                mechStr, timerStr, obj, solverStr
            ))

            for w in r.warnings {
                print("         └─ \(w)")
            }
        }

        print("")
        print("  Legend:")
        print("  T = trivial (min ≤ 1)  ⚠ = has warnings  cx = complexity score")
        print("  CAP = rotationCap  OVL = overloaded  DRF = autoDrift  OWR = oneWayRelay")
        print("  FRG = fragileTile  CGT = chargeGate  INF = interferenceZone")
        print("  NRM = normal  COV = maxCoverage  SAV = energySaving")
        print("  Solver column: S<n> = confirmed min  S<n>! = shorter path found  ~ = inconclusive")
        print("")

        printCatalogSummary(reports)
    }

    // MARK: - Catalog summary

    /// Prints aggregate statistics across all tiers, objectives, and mechanics.
    static func printCatalogSummary(_ reports: [LevelValidationReport]) {
        print("╔══════════════════════════════════════════════════════════╗")
        print("║       CATALOGUE SUMMARY                                 ║")
        print("╚══════════════════════════════════════════════════════════╝")

        // ── Per-tier stats ────────────────────────────────────────────────
        print("")
        print("  BY TIER:")
        print(String(format: "  %-8s  cnt  avgMin  avgBuf  avgPath  avgCx  warned  misclassified",
                     "TIER"))
        for tier in DifficultyTier.allCases {
            let r = reports.filter { $0.difficulty == tier }
            guard !r.isEmpty else { continue }
            let cnt      = r.count
            let avgMin   = r.map { $0.minimumRequiredMoves }.reduce(0, +) / cnt
            let avgBuf   = r.map { $0.buffer               }.reduce(0, +) / cnt
            let avgPath  = r.map { $0.solutionPathLength   }.reduce(0, +) / cnt
            let avgCx    = r.map { $0.complexityScore      }.reduce(0, +) / Float(cnt)
            let warned   = r.filter { !$0.warnings.isEmpty }.count
            let misclass = r.filter { $0.warnings.contains { $0.hasPrefix("MISCLASSIFIED") } }.count
            print(String(format: "  %-8@  %3d  %6d  %6d  %7d  %5.1f  %6d  %13d",
                         tier.fullLabel as NSString, cnt,
                         avgMin, avgBuf, avgPath, avgCx, warned, misclass))
        }

        // ── Objective distribution ─────────────────────────────────────────
        print("")
        print("  BY OBJECTIVE:")
        for obj in LevelObjectiveType.allCases {
            let r = reports.filter { $0.objectiveType == obj }
            guard !r.isEmpty else { continue }
            let cnt    = r.count
            let avgMin = r.map { $0.minimumRequiredMoves }.reduce(0, +) / cnt
            let avgCx  = r.map { $0.complexityScore      }.reduce(0, +) / Float(cnt)
            print(String(format: "  %-15@  %3d levels  avgMin=%2d  avgCx=%.1f",
                         obj.hudLabel as NSString, cnt, avgMin, avgCx))
        }

        // ── Mechanics distribution ─────────────────────────────────────────
        print("")
        print("  MECHANICS:")
        let withCap  = reports.filter { $0.hasRotationCap     }.count
        let withOvl  = reports.filter { $0.hasOverloaded      }.count
        let withDrf  = reports.filter { $0.hasAutoDrift       }.count
        let withOwr  = reports.filter { $0.hasOneWayRelay     }.count
        let withFrg  = reports.filter { $0.hasFragileTile     }.count
        let withCgt  = reports.filter { $0.hasChargeGate      }.count
        let withInf  = reports.filter { $0.hasInterferenceZone }.count
        let total    = reports.count
        print(String(format: "  rotationCap    : %3d  (%2d%%)", withCap, withCap * 100 / max(1, total)))
        print(String(format: "  overloaded     : %3d  (%2d%%)", withOvl, withOvl * 100 / max(1, total)))
        print(String(format: "  autoDrift      : %3d  (%2d%%)", withDrf, withDrf * 100 / max(1, total)))
        print(String(format: "  oneWayRelay    : %3d  (%2d%%)", withOwr, withOwr * 100 / max(1, total)))
        print(String(format: "  fragileTile    : %3d  (%2d%%)", withFrg, withFrg * 100 / max(1, total)))
        print(String(format: "  chargeGate     : %3d  (%2d%%)", withCgt, withCgt * 100 / max(1, total)))
        print(String(format: "  interferenceZone:%3d  (%2d%%)", withInf, withInf * 100 / max(1, total)))

        // ── Buffer distribution ────────────────────────────────────────────
        print("")
        print("  BUFFER DISTRIBUTION:")
        for tier in DifficultyTier.allCases {
            let bufs = reports.filter { $0.difficulty == tier }.map { $0.buffer }
            guard !bufs.isEmpty else { continue }
            let mn = bufs.min()!, mx = bufs.max()!
            let avg = bufs.reduce(0, +) / bufs.count
            print(String(format: "  %-8@  min=%2d  max=%2d  avg=%2d",
                         tier.fullLabel as NSString, mn, mx, avg))
        }

        // ── Complexity score distribution ──────────────────────────────────
        print("")
        print("  COMPLEXITY SCORE BY TIER (expected ranges):")
        let ranges: [(DifficultyTier, ClosedRange<Float>)] = [
            (.easy,   2...15),
            (.medium, 8...25),
            (.hard,   15...35),
            (.expert, 22...999),
        ]
        for (tier, expected) in ranges {
            let scores = reports.filter { $0.difficulty == tier }.map { $0.complexityScore }
            guard !scores.isEmpty else { continue }
            let mn = scores.min()!, mx = scores.max()!
            let out = scores.filter { !expected.contains($0) }.count
            print(String(format: "  %-8@  observed %.1f–%.1f  expected %.0f–%@  out-of-range: %d",
                         tier.fullLabel as NSString, mn, mx,
                         expected.lowerBound,
                         expected.upperBound > 500 ? "∞" : String(format: "%.0f", expected.upperBound),
                         out))
        }

        // ── Suspected misclassified ────────────────────────────────────────
        let misclass = reports.filter { r in r.warnings.contains { $0.hasPrefix("MISCLASSIFIED") } }
        if !misclass.isEmpty {
            print("")
            print("  SUSPECTED MISCLASSIFIED (\(misclass.count) levels):")
            for r in misclass {
                let msg = r.warnings.first { $0.hasPrefix("MISCLASSIFIED") } ?? ""
                print(String(format: "  L%03d  %@  cx=%.1f  → %@",
                             r.levelID, r.difficulty.fullLabel as NSString, r.complexityScore, msg))
            }
        }

        print("")
    }

    // MARK: - Private helpers

    /// Acceptable move-buffer range per difficulty tier (matches proportional formula).
    /// Buffers outside this range get a GENEROUS or TIGHT warning.
    private static func bufferRange(for difficulty: DifficultyTier) -> (min: Int, max: Int) {
        switch difficulty {
        case .easy:   return (min: 6,  max: 14)
        case .medium: return (min: 4,  max: 10)
        case .hard:   return (min: 2,  max: 8)
        case .expert: return (min: 1,  max: 6)
        }
    }

    /// Composite difficulty estimate independent of assigned tier.
    /// score = minimumRequiredMoves + pathLength×0.25 + mechanicBonus + gridSizeBonus
    /// Mechanic bonuses: rotationCap +2, overloaded +3, autoDrift +4, fragileTile +3, chargeGate +4, interference +1
    /// Grid size bonus:  5×5 +3, 4×4 +0
    private static func complexityScore(
        minMoves: Int,
        pathLength: Int,
        hasRotCap: Bool,
        hasOverloaded: Bool,
        hasAutoDrift: Bool,
        hasFragileTile: Bool = false,
        hasChargeGate: Bool = false,
        hasInterference: Bool = false,
        gridSize: Int
    ) -> Float {
        var score = Float(minMoves) + Float(pathLength) * 0.25
        if hasRotCap      { score += 2 }
        if hasOverloaded  { score += 3 }
        if hasAutoDrift   { score += 4 }
        if hasFragileTile { score += 3 }
        if hasChargeGate  { score += 4 }
        if hasInterference { score += 1 }
        if gridSize == 5  { score += 3 }
        return score
    }

    /// Expected complexity score range for a given difficulty tier.
    private static func complexityRange(for difficulty: DifficultyTier) -> (min: Float, max: Float) {
        switch difficulty {
        case .easy:   return (min: 2,  max: 15)
        case .medium: return (min: 8,  max: 25)
        case .hard:   return (min: 15, max: 35)
        case .expert: return (min: 22, max: 999)
        }
    }

    private static func diffSectionHeader(_ diff: DifficultyTier) -> String {
        let range: String
        switch diff {
        case .easy:   range = "IDs   1– 30"
        case .medium: range = "IDs  31– 70"
        case .hard:   range = "IDs  71–110"
        case .expert: range = "IDs 111–180"
        }
        return "── \(diff.fullLabel.uppercased()) (\(range)) "
            + String(repeating: "─", count: max(0, 44 - diff.fullLabel.count))
    }
}

// MARK: - LevelDifficultyMetrics
/// Flat difficulty snapshot for a single level.
/// Derived from LevelValidationReport — debug-only.
struct LevelDifficultyMetrics {
    let levelID:           Int
    let solvable:          Bool
    let minMoves:          Int          // generator estimate (or solver-confirmed if exact)
    let moveLimit:         Int
    let buffer:            Int          // moveLimit - minMoves
    let gridSize:          Int
    let numberOfTargets:   Int
    let objectiveType:     LevelObjectiveType
    let timeLimit:         Int?
    let solutionPathLength: Int
    let complexityScore:   Float
    let difficultyTier:    DifficultyTier   // declared by generator
    let mechanics:         [MechanicType]
    let warnings:          [String]

    // ── Computed difficulty (data-driven) ─────────────────────────────────
    /// Score 0–100 derived from buffer, grid size, targets, and active mechanics.
    ///
    /// Component weights:
    ///   • Buffer (0–70): `max(0, 70 - buffer × 7)` — primary driver
    ///   • Grid size (0–10): 3×3 = 0,  4×4 = 5,  5×5 = 10
    ///   • Targets (0–10): 1 → 0,  2 → 3,  3 → 7,  4+ → 10
    ///   • Mechanics (0–10, capped): each mechanic contributes 2–4 pts
    let computedDifficultyScore: Int
    /// Tier derived from `computedDifficultyScore`:
    ///   0–24 → easy,  25–49 → medium,  50–74 → hard,  75–100 → expert
    let computedTier: DifficultyTier

    /// True when the puzzle requires ≤ 1 tap — essentially handed to the player.
    var isTrivial: Bool { minMoves <= 1 }
    /// True when any mechanic beyond normal routing is present.
    var hasMechanics: Bool { !mechanics.isEmpty }
    /// True when computed tier differs from the generator's declared tier.
    var tierMismatch: Bool { computedTier != difficultyTier }
}

// MARK: - DifficultyDataset
/// Builds and exports the full difficulty dataset for all 180 levels.
/// Always wrapped in #if DEBUG — do not call from release code.
@MainActor
enum DifficultyDataset {

    // MARK: - Build

    /// Generate metrics for every level in LevelGenerator.levels.
    /// - Parameter useSolver: When true, runs Dijkstra per level to confirm minMoves
    ///   (budget: 20 K nodes — adds ~300 ms total).  Defaults to false for speed.
    static func build(useSolver: Bool = false) -> [LevelDifficultyMetrics] {
        LevelValidationRunner.validateAll(useSolver: useSolver).map(metrics(from:))
    }

    // MARK: - Print helpers

    /// Prints a compact table of all metrics to the Xcode console.
    static func printTable(_ dataset: [LevelDifficultyMetrics]) {
        print("")
        print("╔═══════════════════════════════════════════════════════════════════════════════════════════╗")
        print("║  SIGNAL ROUTE — DIFFICULTY DATASET                                                       ║")
        print("╠═══════════════════════════════════════════════════════════════════════════════════════════╣")
        print("║  ! LVL  DECLARED  COMPUTED(sc)  GRD  TGT  OBJ  TIME  minM  maxM  buf   cx  MECHANICS     ║")
        print("╠═══════════════════════════════════════════════════════════════════════════════════════════╣")
        for m in dataset {
            let decl = m.difficultyTier.fullLabel.padding(toLength: 6, withPad: " ", startingAt: 0)
            let comp = m.computedTier.fullLabel.padding(toLength: 6, withPad: " ", startingAt: 0)
            let mismatch = m.tierMismatch ? "≠" : " "
            let obj: String
            switch m.objectiveType {
            case .normal:       obj = "NRM"
            case .maxCoverage:  obj = "COV"
            case .energySaving: obj = "SAV"
            }
            let timeStr = m.timeLimit.map { String(format: "%3ds", $0) } ?? "    "
            let mechStr = mechanicAbbrevs(m.mechanics)
                .padding(toLength: 22, withPad: " ", startingAt: 0)
            let warn = m.warnings.isEmpty ? " " : "⚠"
            print(String(format: "║ %@ %3d  %@  %@ %@(%3d)  %dx%d  %2d   %@  %@  %3d   %3d   %3d  %5.1f  %@║",
                warn,
                m.levelID, decl,
                mismatch, comp, m.computedDifficultyScore,
                m.gridSize, m.gridSize,
                m.numberOfTargets, obj,
                timeStr,
                m.minMoves, m.moveLimit, m.buffer,
                m.complexityScore,
                mechStr
            ))
        }
        print("╚═══════════════════════════════════════════════════════════════════════════════════════════╝")
        printSummary(dataset)
    }

    /// Prints a CSV suitable for pasting into a spreadsheet or Jupyter notebook.
    static func printCSV(_ dataset: [LevelDifficultyMetrics]) {
        let header = [
            "levelID", "declaredTier", "computedTier", "computedScore", "tierMismatch",
            "gridSize", "numberOfTargets", "objectiveType", "timeLimit",
            "minMoves", "moveLimit", "buffer", "solutionPathLength",
            "complexityScore", "solvable",
            "rotationCap", "overloaded", "autoDrift", "oneWayRelay",
            "fragileTile", "chargeGate", "interferenceZone",
            "isTrivial", "hasMechanics", "warningCount"
        ].joined(separator: ",")
        print(header)

        for m in dataset {
            func b(_ v: Bool) -> String { v ? "1" : "0" }
            let cols: [String] = [
                "\(m.levelID)",
                m.difficultyTier.fullLabel,
                m.computedTier.fullLabel,
                "\(m.computedDifficultyScore)",
                b(m.tierMismatch),
                "\(m.gridSize)",
                "\(m.numberOfTargets)",
                m.objectiveType.rawValue,
                m.timeLimit.map { "\($0)" } ?? "",
                "\(m.minMoves)",
                "\(m.moveLimit)",
                "\(m.buffer)",
                "\(m.solutionPathLength)",
                String(format: "%.2f", m.complexityScore),
                b(m.solvable),
                b(m.mechanics.contains(.rotationCap)),
                b(m.mechanics.contains(.overloaded)),
                b(m.mechanics.contains(.autoDrift)),
                b(m.mechanics.contains(.oneWayRelay)),
                b(m.mechanics.contains(.fragileTile)),
                b(m.mechanics.contains(.chargeGate)),
                b(m.mechanics.contains(.interferenceZone)),
                b(m.isTrivial),
                b(m.hasMechanics),
                "\(m.warnings.count)",
            ]
            print(cols.joined(separator: ","))
        }
    }

    // MARK: - Private

    private static func metrics(from r: LevelValidationReport) -> LevelDifficultyMetrics {
        var mechs: [MechanicType] = []
        if r.hasRotationCap      { mechs.append(.rotationCap) }
        if r.hasOverloaded       { mechs.append(.overloaded) }
        if r.timeLimit != nil    { mechs.append(.timeLimit) }
        if r.hasAutoDrift        { mechs.append(.autoDrift) }
        if r.hasOneWayRelay      { mechs.append(.oneWayRelay) }
        if r.hasFragileTile      { mechs.append(.fragileTile) }
        if r.hasChargeGate       { mechs.append(.chargeGate) }
        if r.hasInterferenceZone { mechs.append(.interferenceZone) }

        let score = computedScore(buffer: r.buffer, gridSize: r.gridSize,
                                  targets: r.numTargets, mechanics: mechs,
                                  hasTimeLimit: r.timeLimit != nil)

        return LevelDifficultyMetrics(
            levelID:                r.levelID,
            solvable:               r.isSolvable,
            minMoves:               r.confirmedMinMoves,
            moveLimit:              r.moveLimit,
            buffer:                 r.buffer,
            gridSize:               r.gridSize,
            numberOfTargets:        r.numTargets,
            objectiveType:          r.objectiveType,
            timeLimit:              r.timeLimit,
            solutionPathLength:     r.solutionPathLength,
            complexityScore:        r.complexityScore,
            difficultyTier:         r.difficulty,
            mechanics:              mechs,
            warnings:               r.warnings,
            computedDifficultyScore: score,
            computedTier:           tierFromScore(score)
        )
    }

    /// Data-driven difficulty score 0–100.
    ///
    /// Buffer is the dominant axis (0–70 pts).  Grid size, targets, and mechanics
    /// provide the remaining 30 pts — enough to push borderline levels one tier up,
    /// but never enough to override a generous buffer.
    private static func computedScore(
        buffer: Int,
        gridSize: Int,
        targets: Int,
        mechanics: [MechanicType],
        hasTimeLimit: Bool
    ) -> Int {
        // ── Buffer (0–70): primary driver ─────────────────────────────────
        // buffer > 9 → 0 pts (trivially easy)
        // buffer 0  → 70 pts (player has zero slack)
        let bufPts = max(0, 70 - buffer * 7)

        // ── Grid size (0–10) ───────────────────────────────────────────────
        let gridPts: Int
        switch gridSize {
        case 5:    gridPts = 10
        case 4:    gridPts = 5
        default:   gridPts = 0
        }

        // ── Targets (0–10) ─────────────────────────────────────────────────
        let tgtPts: Int
        switch targets {
        case 1:    tgtPts = 0
        case 2:    tgtPts = 3
        case 3:    tgtPts = 7
        default:   tgtPts = 10
        }

        // ── Mechanics (0–10, capped) ───────────────────────────────────────
        var mechRaw = 0
        for m in mechanics {
            switch m {
            case .rotationCap:      mechRaw += 2
            case .overloaded:       mechRaw += 3
            case .timeLimit:        mechRaw += 2    // also covered by hasTimeLimit flag
            case .autoDrift:        mechRaw += 4
            case .oneWayRelay:      mechRaw += 3
            case .fragileTile:      mechRaw += 3
            case .chargeGate:       mechRaw += 4
            case .interferenceZone: mechRaw += 2
            }
        }
        let mechPts = min(10, mechRaw)

        return min(100, bufPts + gridPts + tgtPts + mechPts)
    }

    /// Map score 0–100 to difficulty tier.
    ///   0–24  → easy
    ///   25–49 → medium
    ///   50–74 → hard
    ///   75–100 → expert
    private static func tierFromScore(_ score: Int) -> DifficultyTier {
        switch score {
        case 0..<25:  return .easy
        case 25..<50: return .medium
        case 50..<75: return .hard
        default:      return .expert
        }
    }

    private static func mechanicAbbrevs(_ mechs: [MechanicType]) -> String {
        mechs.map { m -> String in
            switch m {
            case .rotationCap:      return "CAP"
            case .overloaded:       return "OVL"
            case .timeLimit:        return "TMR"
            case .autoDrift:        return "DRF"
            case .oneWayRelay:      return "OWR"
            case .fragileTile:      return "FRG"
            case .chargeGate:       return "CGT"
            case .interferenceZone: return "INF"
            }
        }.joined(separator: "+")
    }

    private static func printSummary(_ dataset: [LevelDifficultyMetrics]) {
        let mismatches = dataset.filter { $0.tierMismatch }
        print("")
        print("  SUMMARY  total=\(dataset.count)"
            + "  trivial=\(dataset.filter { $0.isTrivial }.count)"
            + "  withMechanics=\(dataset.filter { $0.hasMechanics }.count)"
            + "  warnings=\(dataset.filter { !$0.warnings.isEmpty }.count)"
            + "  tierMismatches=\(mismatches.count)")
        print("")
        print("  ── BY DECLARED TIER ─────────────────────────────────────────────────")
        print("  TIER    n    avgMin  avgBuf  avgScore  avgCx")
        for tier in DifficultyTier.allCases {
            let sub = dataset.filter { $0.difficultyTier == tier }
            guard !sub.isEmpty else { continue }
            let avgMin   = sub.map { $0.minMoves              }.reduce(0, +) / sub.count
            let avgBuf   = sub.map { $0.buffer                }.reduce(0, +) / sub.count
            let avgScore = sub.map { $0.computedDifficultyScore }.reduce(0, +) / sub.count
            let avgCx    = sub.map { $0.complexityScore       }.reduce(0, +) / Float(sub.count)
            print(String(format: "  %-6@  %3d  %6d  %6d  %8d  %5.1f",
                tier.fullLabel as NSString, sub.count, avgMin, avgBuf, avgScore, avgCx))
        }
        print("")
        print("  ── BY COMPUTED TIER ─────────────────────────────────────────────────")
        for tier in DifficultyTier.allCases {
            let sub = dataset.filter { $0.computedTier == tier }
            guard !sub.isEmpty else { continue }
            print(String(format: "  %-6@  %3d levels  (score %2d–%2d)",
                tier.fullLabel as NSString, sub.count,
                sub.map { $0.computedDifficultyScore }.min() ?? 0,
                sub.map { $0.computedDifficultyScore }.max() ?? 0))
        }
        if !mismatches.isEmpty {
            print("")
            print("  ── TIER MISMATCHES (\(mismatches.count)) ──────────────────────────────────────")
            for m in mismatches {
                print(String(format: "  L%03d  declared=%-6@  computed=%-6@ (score=%2d  buf=%d)",
                    m.levelID,
                    m.difficultyTier.fullLabel as NSString,
                    m.computedTier.fullLabel as NSString,
                    m.computedDifficultyScore,
                    m.buffer))
            }
        }
        print("")
    }
}

// MARK: - LevelIssue

enum IssueSeverity: String {
    case critical = "CRITICAL"   // must fix before shipping
    case warning  = "WARNING"    // should investigate
}

enum IssueType: String {
    case impossible              // solvable == false
    case trivial                 // puzzle offers no meaningful resistance
    case overPermissive          // moveLimit is excessively generous
    case fakeHard                // declared hard/expert but data says otherwise
    case misalignedProgression   // level N harder than level N+1 by a significant margin

    var displayLabel: String {
        switch self {
        case .impossible:            return "IMPOSSIBLE"
        case .trivial:               return "TRIVIAL"
        case .overPermissive:        return "PERMISSIVE"
        case .fakeHard:              return "FAKE HARD"
        case .misalignedProgression: return "MISALIGNED"
        }
    }
}

struct LevelIssue {
    let levelID:     Int
    let issueType:   IssueType
    let severity:    IssueSeverity
    let description: String
}

// MARK: - LevelIssueDetector

/// Scans a `[LevelDifficultyMetrics]` dataset and returns a list of balance problems.
/// Always wrapped in #if DEBUG — do not call from release code.
@MainActor
enum LevelIssueDetector {

    // MARK: - Thresholds (tune here)

    /// Buffer above this value is flagged OVER_PERMISSIVE regardless of declared tier.
    private static let bufferAbsoluteMax      = 11

    /// Buffer above this value is flagged OVER_PERMISSIVE for declared HARD.
    private static let bufferHardMax          = 7

    /// Buffer above this value is flagged OVER_PERMISSIVE for declared EXPERT.
    private static let bufferExpertMax        = 5

    /// Buffer above this value is flagged TRIVIAL for declared MEDIUM/HARD/EXPERT.
    private static let bufferTrivialThreshold = 8

    /// Score drop between consecutive levels that triggers MISALIGNED_PROGRESSION.
    private static let progressionDropThreshold = 15

    // MARK: - Detection

    /// Run all issue detectors over the dataset and return every found issue.
    static func detect(from dataset: [LevelDifficultyMetrics]) -> [LevelIssue] {
        var issues: [LevelIssue] = []

        for m in dataset {
            issues += detectImpossible(m)
            issues += detectTrivial(m)
            issues += detectOverPermissive(m)
            issues += detectFakeHard(m)
        }

        // Progression detector needs the full ordered dataset
        issues += detectMisalignedProgression(dataset)

        return issues.sorted { $0.levelID < $1.levelID }
    }

    // MARK: - Print

    /// Prints a grouped issue report to the Xcode console.
    static func printIssues(_ issues: [LevelIssue]) {
        guard !issues.isEmpty else {
            print("\n  ✓ No balance issues detected in the catalogue.\n")
            return
        }

        let criticals = issues.filter { $0.severity == .critical }
        let warnings  = issues.filter { $0.severity == .warning  }

        print("")
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  SIGNAL ROUTE — BALANCE ISSUE REPORT                        ║")
        print(String(format: "║  Total: %-3d   Critical: %-3d   Warnings: %-3d               ║",
            issues.count, criticals.count, warnings.count))
        print("╚══════════════════════════════════════════════════════════════╝")

        for type in [IssueType.impossible, .trivial, .overPermissive, .fakeHard, .misalignedProgression] {
            let group = issues.filter { $0.issueType == type }
            guard !group.isEmpty else { continue }
            print("")
            print("  ── \(sectionLabel(type)) (\(group.count)) " + String(repeating: "─", count: max(0, 42 - sectionLabel(type).count)))
            for issue in group {
                let sev = issue.severity == .critical ? "●" : "◦"
                print(String(format: "  %@ L%03d  %@", sev, issue.levelID, issue.description))
            }
        }

        print("")
        print("  Legend:  ● CRITICAL (must fix)   ◦ WARNING (investigate)")
        print("")
    }

    /// Prints a compact CSV: levelID, issueType, severity, description.
    static func printIssuesCSV(_ issues: [LevelIssue]) {
        print("levelID,issueType,severity,description")
        for i in issues {
            let desc = i.description.replacingOccurrences(of: ",", with: ";")
            print("\(i.levelID),\(i.issueType.rawValue),\(i.severity.rawValue),\(desc)")
        }
    }

    // MARK: - Individual detectors

    private static func detectImpossible(_ m: LevelDifficultyMetrics) -> [LevelIssue] {
        guard !m.solvable else { return [] }
        return [LevelIssue(
            levelID:     m.levelID,
            issueType:   .impossible,
            severity:    .critical,
            description: "Board appears unsolvable (source/target/path heuristic failed)"
        )]
    }

    private static func detectTrivial(_ m: LevelDifficultyMetrics) -> [LevelIssue] {
        var issues: [LevelIssue] = []

        if m.minMoves == 0 {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .trivial,
                severity:    .critical,
                description: "minMoves=0 — board is pre-solved after scramble"
            ))
        } else if m.minMoves == 1 {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .trivial,
                severity:    m.difficultyTier == .easy ? .warning : .critical,
                description: "minMoves=1 — single tap solves the puzzle"
                    + (m.difficultyTier != .easy ? " (declared \(m.difficultyTier.fullLabel))" : "")
            ))
        }

        if m.buffer > bufferTrivialThreshold && m.difficultyTier != .easy {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .trivial,
                severity:    .warning,
                description: "buffer=\(m.buffer) on declared \(m.difficultyTier.fullLabel) "
                    + "— player has \(m.buffer - bufferTrivialThreshold) extra moves above trivial threshold"
            ))
        }

        return issues
    }

    private static func detectOverPermissive(_ m: LevelDifficultyMetrics) -> [LevelIssue] {
        var issues: [LevelIssue] = []

        if m.buffer > bufferAbsoluteMax {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .overPermissive,
                severity:    .warning,
                description: "buffer=\(m.buffer) exceeds absolute max \(bufferAbsoluteMax) "
                    + "(moveLimit=\(m.moveLimit) vs minMoves=\(m.minMoves))"
            ))
        } else if m.difficultyTier == .expert && m.buffer > bufferExpertMax {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .overPermissive,
                severity:    .warning,
                description: "EXPERT level has buffer=\(m.buffer) > max \(bufferExpertMax) for tier"
            ))
        } else if m.difficultyTier == .hard && m.buffer > bufferHardMax {
            issues.append(LevelIssue(
                levelID:     m.levelID,
                issueType:   .overPermissive,
                severity:    .warning,
                description: "HARD level has buffer=\(m.buffer) > max \(bufferHardMax) for tier"
            ))
        }

        return issues
    }

    private static func detectFakeHard(_ m: LevelDifficultyMetrics) -> [LevelIssue] {
        // Only flag when there's a gap of 2+ tiers (declared >> computed)
        let declaredRank  = m.difficultyTier.rawValue   // Int 1–4
        let computedRank  = m.computedTier.rawValue

        guard declaredRank >= 3,                        // only care about HARD/EXPERT
              computedRank <= declaredRank - 2          // 2+ tiers below declared
        else { return [] }

        let severity: IssueSeverity = computedRank == 1 ? .critical : .warning
        return [LevelIssue(
            levelID:     m.levelID,
            issueType:   .fakeHard,
            severity:    severity,
            description: "Declared \(m.difficultyTier.fullLabel) but computed \(m.computedTier.fullLabel) "
                + "(score=\(m.computedDifficultyScore)  buf=\(m.buffer))"
        )]
    }

    private static func detectMisalignedProgression(_ dataset: [LevelDifficultyMetrics]) -> [LevelIssue] {
        guard dataset.count > 1 else { return [] }
        var issues: [LevelIssue] = []

        // Sort by levelID to ensure correct sequence
        let sorted = dataset.sorted { $0.levelID < $1.levelID }

        for i in 0..<(sorted.count - 1) {
            let cur  = sorted[i]
            let next = sorted[i + 1]
            // Only flag when adjacent IDs (no gaps) and the drop is meaningful
            guard next.levelID == cur.levelID + 1 else { continue }
            let drop = cur.computedDifficultyScore - next.computedDifficultyScore
            guard drop >= progressionDropThreshold else { continue }
            issues.append(LevelIssue(
                levelID:     cur.levelID,
                issueType:   .misalignedProgression,
                severity:    .warning,
                description: "L\(cur.levelID)(score=\(cur.computedDifficultyScore)) "
                    + "→ L\(next.levelID)(score=\(next.computedDifficultyScore)) "
                    + "drops \(drop) pts — difficulty regresses"
            ))
        }

        return issues
    }

    // MARK: - Helpers

    private static func sectionLabel(_ type: IssueType) -> String {
        switch type {
        case .impossible:             return "IMPOSSIBLE"
        case .trivial:                return "TRIVIAL"
        case .overPermissive:         return "OVER-PERMISSIVE"
        case .fakeHard:               return "FAKE HARD"
        case .misalignedProgression:  return "MISALIGNED PROGRESSION"
        }
    }
}

// MARK: - RebalanceSuggestion

/// The outcome of running `RebalancingEngine.suggest(for:)` on a single level.
struct RebalanceSuggestion {
    enum Action: String {
        case tighten = "TIGHTEN"    // reduce moveLimit (buffer was too generous)
        case loosen  = "LOOSEN"     // increase moveLimit (buffer was too tight)
        case ok      = "OK"         // already within target range
    }

    let levelID:              Int
    let difficultyTier:       DifficultyTier
    let minMoves:             Int
    let currentMoveLimit:     Int
    let currentBuffer:        Int
    let targetRange:          ClosedRange<Int>   // target buffer range (with mechanic bonus)
    let recommendedMoveLimit: Int                // always >= minMoves
    let recommendedBuffer:    Int
    let delta:                Int                // recommended − current (negative = tighten)
    let action:               Action
    let justification:        String

    var needsChange: Bool { action != .ok }
}

// MARK: - RebalancingEngine

/// Computes recommended `maxMoves` values for every level in the dataset.
///
/// Strategy:
///   1. Derive the target buffer range for the level's declared tier.
///   2. Add a small mechanic bonus (+1 per "execution-hard" mechanic, capped at +2)
///      to account for genuine added difficulty from autoDrift / chargeGate etc.
///   3. If current buffer is already within range → no change.
///   4. Otherwise snap to the nearest bound (tighten or loosen).
///   5. Safety guard: `recommendedMoveLimit` is always ≥ `minMoves`.
///
/// Target buffer ranges (before mechanic bonus):
///   easy   → 6–8   medium → 4–6   hard → 2–4   expert → 0–2
@MainActor
enum RebalancingEngine {

    // MARK: - Mechanics that justify a higher buffer (harder to execute precisely)
    private static let hardMechanics: Set<MechanicType> = [
        .autoDrift, .chargeGate, .fragileTile, .oneWayRelay, .overloaded
    ]

    // MARK: - Public API

    /// Generate one `RebalanceSuggestion` per level in `dataset`.
    static func suggest(from dataset: [LevelDifficultyMetrics]) -> [RebalanceSuggestion] {
        dataset.map { suggestion(for: $0) }
    }

    // MARK: - Print helpers

    /// Prints a full rebalance report to the Xcode console.
    static func printReport(_ suggestions: [RebalanceSuggestion]) {
        let changes = suggestions.filter { $0.needsChange }
        let tighten = changes.filter { $0.action == .tighten }
        let loosen  = changes.filter { $0.action == .loosen  }
        let totalDelta = changes.map { abs($0.delta) }.reduce(0, +)

        print("")
        print("╔══════════════════════════════════════════════════════════════════════╗")
        print("║  SIGNAL ROUTE — AUTO REBALANCE REPORT                               ║")
        print(String(format: "║  Total: %-3d  OK: %-3d  Tighten: %-3d  Loosen: %-3d  |Δ|sum: %-4d   ║",
            suggestions.count,
            suggestions.count - changes.count,
            tighten.count, loosen.count, totalDelta))
        print("╠══════════════════════════════════════════════════════════════════════╣")
        print("║  LVL  TIER    minM  curMax  curBuf  tgtRange  recMax  recBuf  Δ  ACTION ║")
        print("╠══════════════════════════════════════════════════════════════════════╣")

        for s in suggestions {
            let tier     = s.difficultyTier.fullLabel.padding(toLength: 6, withPad: " ", startingAt: 0)
            let tgtStr   = "\(s.targetRange.lowerBound)–\(s.targetRange.upperBound)"
                .padding(toLength: 5, withPad: " ", startingAt: 0)
            let actionStr = s.action == .ok ? "  ·  "
                          : s.action == .tighten ? "▼ TGT" : "▲ LSN"
            let deltaStr = s.delta == 0 ? " 0" : String(format: "%+d", s.delta)
            print(String(format: "║ %3d  %@   %3d     %3d     %3d   %@     %3d     %3d  %@  %@  ║",
                s.levelID, tier,
                s.minMoves, s.currentMoveLimit, s.currentBuffer,
                tgtStr,
                s.recommendedMoveLimit, s.recommendedBuffer,
                deltaStr, actionStr
            ))
        }
        print("╚══════════════════════════════════════════════════════════════════════╝")
        printSummary(suggestions)
    }

    /// Prints a CSV of all suggestions.
    static func printCSV(_ suggestions: [RebalanceSuggestion]) {
        print("levelID,tier,minMoves,currentMoveLimit,currentBuffer,targetMin,targetMax,"
            + "recommendedMoveLimit,recommendedBuffer,delta,action")
        for s in suggestions {
            print([
                "\(s.levelID)",
                s.difficultyTier.fullLabel,
                "\(s.minMoves)",
                "\(s.currentMoveLimit)",
                "\(s.currentBuffer)",
                "\(s.targetRange.lowerBound)",
                "\(s.targetRange.upperBound)",
                "\(s.recommendedMoveLimit)",
                "\(s.recommendedBuffer)",
                "\(s.delta)",
                s.action.rawValue,
            ].joined(separator: ","))
        }
    }

    /// Prints only the levels that need changes — the actionable patch list.
    static func printPatch(_ suggestions: [RebalanceSuggestion]) {
        let changes = suggestions.filter { $0.needsChange }
            .sorted { $0.levelID < $1.levelID }
        guard !changes.isEmpty else {
            print("\n  ✓ All levels already balanced — no patch required.\n")
            return
        }

        print("")
        print("  ── REBALANCE PATCH (\(changes.count) levels) ──────────────────────────────────")
        print(String(format: "  %-5s  %-6s  %-6s  %-8s  %-8s  %-8s  %s",
            "LVL", "TIER", "ACTION", "curMax", "recMax", "Δ", "REASON"))
        for s in changes {
            let sign = s.delta > 0 ? "+" : ""
            print(String(format: "  L%03d  %-6@  %-6@  %-8d  %-8d  %@%-6d  %@",
                s.levelID,
                s.difficultyTier.fullLabel as NSString,
                s.action.rawValue as NSString,
                s.currentMoveLimit,
                s.recommendedMoveLimit,
                sign, s.delta,
                s.justification))
        }
        print("")
        printTierBreakdown(changes)
    }

    // MARK: - Private

    private static func suggestion(for m: LevelDifficultyMetrics) -> RebalanceSuggestion {
        let target = targetBufferRange(tier: m.difficultyTier, mechanics: m.mechanics)

        let recommended: Int
        let action: RebalanceSuggestion.Action
        let justification: String

        if m.buffer < target.lowerBound {
            // Too tight — loosen to target minimum
            recommended   = m.minMoves + target.lowerBound
            action        = .loosen
            justification = "buf=\(m.buffer) < tgt_min=\(target.lowerBound) → loosen"
        } else if m.buffer > target.upperBound {
            // Too generous — tighten to target maximum
            recommended   = m.minMoves + target.upperBound
            action        = .tighten
            justification = "buf=\(m.buffer) > tgt_max=\(target.upperBound) → tighten"
        } else {
            recommended   = m.moveLimit
            action        = .ok
            justification = "buf=\(m.buffer) already in [\(target.lowerBound)–\(target.upperBound)]"
        }

        // Safety: never go below minMoves (would make the level unsolvable)
        let safe = max(m.minMoves, recommended)

        return RebalanceSuggestion(
            levelID:              m.levelID,
            difficultyTier:       m.difficultyTier,
            minMoves:             m.minMoves,
            currentMoveLimit:     m.moveLimit,
            currentBuffer:        m.buffer,
            targetRange:          target,
            recommendedMoveLimit: safe,
            recommendedBuffer:    safe - m.minMoves,
            delta:                safe - m.moveLimit,
            action:               action,
            justification:        justification
        )
    }

    /// Target buffer range for a tier, extended by a mechanic bonus.
    ///
    /// "Execution-hard" mechanics (autoDrift, chargeGate, fragileTile, oneWayRelay, overloaded)
    /// add +1 to both bounds per mechanic, capped at +2.  A hard mechanic makes even the
    /// minimum solution harder to execute, so allowing a wider buffer is fair.
    private static func targetBufferRange(tier: DifficultyTier,
                                          mechanics: [MechanicType]) -> ClosedRange<Int> {
        let bonus = min(2, mechanics.filter { hardMechanics.contains($0) }.count)

        let base: ClosedRange<Int>
        switch tier {
        case .easy:   base = 6...8
        case .medium: base = 4...6
        case .hard:   base = 2...4
        case .expert: base = 0...2
        }
        return (base.lowerBound + bonus)...(base.upperBound + bonus)
    }

    private static func printSummary(_ suggestions: [RebalanceSuggestion]) {
        print("")
        print("  ── BY TIER ────────────────────────────────────────────────────────")
        for tier in DifficultyTier.allCases {
            let sub  = suggestions.filter { $0.difficultyTier == tier }
            guard !sub.isEmpty else { continue }
            let chg  = sub.filter { $0.needsChange }
            let avgD = chg.isEmpty ? 0 : chg.map { $0.delta }.reduce(0, +) / chg.count
            print(String(format: "  %-6@  total=%3d  changes=%3d  avgDelta=%+d",
                tier.fullLabel as NSString, sub.count, chg.count, avgD))
        }
        print("")
    }

    private static func printTierBreakdown(_ changes: [RebalanceSuggestion]) {
        print("  ── CHANGE BREAKDOWN BY TIER ───────────────────────────────────────")
        for tier in DifficultyTier.allCases {
            let sub = changes.filter { $0.difficultyTier == tier }
            guard !sub.isEmpty else { continue }
            let t = sub.filter { $0.action == .tighten }.count
            let l = sub.filter { $0.action == .loosen  }.count
            let sumD = sub.map { $0.delta }.reduce(0, +)
            print(String(format: "  %-6@  tighten=%d  loosen=%d  netDelta=%+d",
                tier.fullLabel as NSString, t, l, sumD))
        }
        print("")
    }
}

// MARK: - DifficultyCurveAnalyzer

/// Analyses the global difficulty progression across all 180 levels.
///
/// Responsibilities:
///   • Classify levels into 4 game phases and validate each phase's average score
///   • Compute a 7-level trailing rolling average and detect sustained drops / spikes
///   • Flag levels that are too easy for late-game or too hard for early-game
///   • Render a compact ASCII 2-D chart showing the full difficulty curve
@MainActor
enum DifficultyCurveAnalyzer {

    // MARK: - Types

    enum GamePhase: String, CaseIterable {
        case early = "EARLY"    // IDs  1– 30
        case mid   = "MID"      // IDs 31– 90
        case late  = "LATE"     // IDs 91–150
        case end   = "END"      // IDs 151–180

        var levelRange: ClosedRange<Int> {
            switch self {
            case .early: return   1...30
            case .mid:   return  31...90
            case .late:  return  91...150
            case .end:   return 151...180
            }
        }

        /// Acceptable average computed score for levels in this phase.
        var expectedAvgRange: ClosedRange<Double> {
            switch self {
            case .early: return  0...40
            case .mid:   return 20...65
            case .late:  return 40...85
            case .end:   return 55...100
            }
        }

        /// Minimum score a single level should have by this phase.
        var minimumExpectedScore: Int {
            switch self {
            case .early: return  0
            case .mid:   return  5
            case .late:  return 20
            case .end:   return 35
            }
        }

        /// Maximum score a single level should have in this phase.
        var maximumExpectedScore: Int {
            switch self {
            case .early: return 60
            case .mid:   return 80
            case .late:  return 100
            case .end:   return 100
            }
        }
    }

    struct PhaseReport {
        let phase:         GamePhase
        let count:         Int
        let avgScore:      Double
        let minScore:      Int
        let maxScore:      Int
        let trend:         Double    // avg(second half) − avg(first half) — positive = rising
        let anomalyCount:  Int
        let avgOnTarget:   Bool      // avgScore within expectedAvgRange
        let isRising:      Bool      // trend > −5 (flat is OK; declining is not)
    }

    struct CurveAnomaly {
        enum Kind: String {
            case sustainedDrop  = "SUSTAINED DROP"
            case spike          = "SPIKE"
            case earlyTooHard   = "TOO HARD EARLY"
            case lateTooEasy    = "TOO EASY LATE"
        }
        let levelID:     Int
        let kind:        Kind
        let severity:    IssueSeverity
        let description: String
    }

    // MARK: - Public API

    /// Full analysis: returns phase reports and curve anomalies.
    static func analyze(_ dataset: [LevelDifficultyMetrics]) -> (phases: [PhaseReport], anomalies: [CurveAnomaly]) {
        let sorted = dataset.filter { $0.levelID >= 1 }.sorted { $0.levelID < $1.levelID }
        let rolling = rollingAverage(sorted, window: 7)

        let phases    = GamePhase.allCases.map { phaseReport($0, dataset: sorted) }
        var anomalies = detectDrops(sorted, rolling: rolling)
               + detectSpikes(sorted, rolling: rolling)
               + detectPhaseViolations(sorted)
        anomalies.sort { $0.levelID < $1.levelID }

        return (phases, anomalies)
    }

    /// Prints the full curve report: phase table + anomaly list.
    static func printReport(phases: [PhaseReport], anomalies: [CurveAnomaly]) {
        print("")
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║  SIGNAL ROUTE — GLOBAL DIFFICULTY CURVE                         ║")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print("")
        print("  ── PHASE HEALTH ──────────────────────────────────────────────────")
        print("  PHASE  n    avg   min  max  trend  avgOK  rising  issues")
        for r in phases {
            let avgOK  = r.avgOnTarget ? "✓" : "✗"
            let rising = r.isRising    ? "✓" : "✗"
            let trendStr = String(format: "%+.1f", r.trend)
            print(String(format: "  %-5@  %3d  %5.1f  %3d  %3d  %@   %@      %@     %d",
                r.phase.rawValue as NSString, r.count,
                r.avgScore, r.minScore, r.maxScore,
                trendStr.padding(toLength: 6, withPad: " ", startingAt: 0),
                avgOK, rising, r.anomalyCount))
        }

        let criticals = anomalies.filter { $0.severity == .critical }
        let warnings  = anomalies.filter { $0.severity == .warning  }
        print("")
        print(String(format: "  ── CURVE ANOMALIES  total=%d  critical=%d  warnings=%d",
            anomalies.count, criticals.count, warnings.count))

        if anomalies.isEmpty {
            print("  ✓ Curve is smooth — no anomalies detected.")
        } else {
            for kind in [CurveAnomaly.Kind.sustainedDrop, .spike, .earlyTooHard, .lateTooEasy] {
                let group = anomalies.filter { $0.kind == kind }
                guard !group.isEmpty else { continue }
                print("")
                print("  ── \(kind.rawValue) (\(group.count)) " + String(repeating: "─", count: max(0, 38 - kind.rawValue.count)))
                for a in group {
                    let sev = a.severity == .critical ? "●" : "◦"
                    print(String(format: "  %@ L%03d  %@", sev, a.levelID, a.description))
                }
            }
        }
        print("")
    }

    /// Renders a 2-D ASCII chart of the difficulty curve (one column per 5-level bucket).
    ///
    /// Each column = average `computedDifficultyScore` of its 5-level bucket.
    /// The chart is 20 rows tall (each row = 5 pts) and marks the rolling average with '●'.
    static func printChart(_ dataset: [LevelDifficultyMetrics]) {
        let sorted = dataset.filter { $0.levelID >= 1 }.sorted { $0.levelID < $1.levelID }
        let bucketSize = 5
        let numBuckets = Int(ceil(Double(sorted.count) / Double(bucketSize)))

        // Bucket averages
        var avgs: [Double] = []
        for b in 0..<numBuckets {
            let s = b * bucketSize
            let e = min(s + bucketSize, sorted.count)
            let avg = Double(sorted[s..<e].map { $0.computedDifficultyScore }.reduce(0, +))
                    / Double(e - s)
            avgs.append(avg)
        }

        let chartH = 20    // rows, each = 5 pts (0–100)
        var grid = Array(repeating: Array(repeating: " ", count: numBuckets), count: chartH)

        for col in 0..<numBuckets {
            // Row 0 = top (score 100), row 19 = bottom (score 0–4)
            let row = max(0, min(chartH - 1, chartH - 1 - Int(avgs[col] / 5.0)))
            grid[row][col] = "●"
        }

        // Phase separator columns (0-based bucket index)
        // bucket = (levelID - 1) / 5   →   phase boundary after level 30,90,150
        let sep30  = 30  / bucketSize     // = 6
        let sep90  = 90  / bucketSize     // = 18
        let sep150 = 150 / bucketSize     // = 30

        print("")
        print("  DIFFICULTY CURVE  ● = avg computedScore per 5-level bucket")
        print("")
        for row in 0..<chartH {
            let score = (chartH - row) * 5
            let label = String(format: "%3d│", score)
            var line = "  " + label
            for col in 0..<numBuckets {
                // Overlay phase separators
                if col == sep30 || col == sep90 || col == sep150 {
                    line += grid[row][col] == "●" ? "●" : "│"
                } else {
                    line += grid[row][col]
                }
            }
            print(line)
        }

        // X axis
        print("    └" + String(repeating: "─", count: numBuckets))
        // Phase labels
        let early = "EARLY".padding(toLength: sep30,        withPad: " ", startingAt: 0)
        let mid   = "MID".padding(  toLength: sep90 - sep30,  withPad: " ", startingAt: 0)
        let late  = "LATE".padding( toLength: sep150 - sep90, withPad: " ", startingAt: 0)
        let end   = "END"
        print("     " + early + mid + late + end)
        print("     1" + String(repeating: " ", count: sep30 - 1) + "31"
            + String(repeating: " ", count: sep90 - sep30 - 2) + "91"
            + String(repeating: " ", count: sep150 - sep90 - 2) + "151"
            + String(repeating: " ", count: numBuckets - sep150 - 3) + "180")

        // Sparkline (single-line summary)
        let sparks = avgs.map { sparkChar(Double($0)) }
        print("")
        print("  Sparkline: " + sparks.joined())
        print("  (▁<13 ▂13–25 ▃26–37 ▄38–50 ▅51–62 ▆63–75 ▇76–87 █≥88)")
        print("")
    }

    // MARK: - Private

    private static func phaseReport(_ phase: GamePhase,
                                    dataset: [LevelDifficultyMetrics]) -> PhaseReport {
        let levels = dataset.filter { phase.levelRange.contains($0.levelID) }
        guard !levels.isEmpty else {
            return PhaseReport(phase: phase, count: 0, avgScore: 0, minScore: 0,
                               maxScore: 0, trend: 0, anomalyCount: 0,
                               avgOnTarget: false, isRising: false)
        }
        let scores  = levels.map { Double($0.computedDifficultyScore) }
        let avg     = scores.reduce(0, +) / Double(scores.count)
        let minScore = levels.map { $0.computedDifficultyScore }.min() ?? 0
        let maxScore = levels.map { $0.computedDifficultyScore }.max() ?? 0

        let half   = levels.count / 2
        let first  = Array(levels[0..<half])
        let second = Array(levels[half...])
        let avgFirst  = first.isEmpty  ? avg : first.map  { Double($0.computedDifficultyScore) }.reduce(0,+) / Double(first.count)
        let avgSecond = second.isEmpty ? avg : second.map { Double($0.computedDifficultyScore) }.reduce(0,+) / Double(second.count)
        let trend = avgSecond - avgFirst

        let anomalyCount = detectDrops(levels, rolling: rollingAverage(levels, window: 7)).count
                         + detectSpikes(levels, rolling: rollingAverage(levels, window: 7)).count
                         + detectPhaseViolations(levels).count

        return PhaseReport(
            phase:         phase,
            count:         levels.count,
            avgScore:      avg,
            minScore:      minScore,
            maxScore:      maxScore,
            trend:         trend,
            anomalyCount:  anomalyCount,
            avgOnTarget:   phase.expectedAvgRange.contains(avg),
            isRising:      trend > -5
        )
    }

    /// Trailing window rolling average indexed by position in `sorted`.
    private static func rollingAverage(_ sorted: [LevelDifficultyMetrics],
                                       window: Int) -> [Double] {
        sorted.indices.map { i in
            let start = max(0, i - window + 1)
            let slice = sorted[start...i]
            return Double(slice.map { $0.computedDifficultyScore }.reduce(0, +)) / Double(slice.count)
        }
    }

    /// Sustained drop: 3 or more consecutive levels all below rolling avg − 12.
    private static func detectDrops(_ sorted: [LevelDifficultyMetrics],
                                    rolling: [Double]) -> [CurveAnomaly] {
        guard sorted.count == rolling.count else { return [] }
        var anomalies: [CurveAnomaly] = []
        var runStart: Int? = nil

        for i in sorted.indices {
            let below = Double(sorted[i].computedDifficultyScore) < rolling[i] - 12
            if below {
                if runStart == nil { runStart = i }
            } else {
                if let start = runStart, i - start >= 3 {
                    let startLevel = sorted[start].levelID
                    let endLevel   = sorted[i - 1].levelID
                    let drop       = Int(rolling[start] - Double(sorted[start].computedDifficultyScore))
                    anomalies.append(CurveAnomaly(
                        levelID:     startLevel,
                        kind:        .sustainedDrop,
                        severity:    drop > 20 ? .critical : .warning,
                        description: "L\(startLevel)–L\(endLevel): \(i - start) levels "
                            + "drop \(drop)+ pts below rolling avg"
                    ))
                }
                runStart = nil
            }
        }
        return anomalies
    }

    /// Spike: single level score > rolling avg + 20.
    private static func detectSpikes(_ sorted: [LevelDifficultyMetrics],
                                     rolling: [Double]) -> [CurveAnomaly] {
        guard sorted.count == rolling.count else { return [] }
        var anomalies: [CurveAnomaly] = []
        for i in sorted.indices {
            let score  = Double(sorted[i].computedDifficultyScore)
            let excess = score - rolling[i]
            guard excess > 20 else { continue }
            anomalies.append(CurveAnomaly(
                levelID:     sorted[i].levelID,
                kind:        .spike,
                severity:    excess > 35 ? .critical : .warning,
                description: "score=\(sorted[i].computedDifficultyScore) "
                    + "is \(Int(excess)) pts above rolling avg \(Int(rolling[i]))"
            ))
        }
        return anomalies
    }

    /// Phase boundary violations: too hard for early game, or too easy for late game.
    private static func detectPhaseViolations(_ sorted: [LevelDifficultyMetrics]) -> [CurveAnomaly] {
        var anomalies: [CurveAnomaly] = []
        for phase in GamePhase.allCases {
            let levels = sorted.filter { phase.levelRange.contains($0.levelID) }
            for m in levels {
                if m.computedDifficultyScore > phase.maximumExpectedScore {
                    anomalies.append(CurveAnomaly(
                        levelID:     m.levelID,
                        kind:        .earlyTooHard,
                        severity:    .warning,
                        description: "\(phase.rawValue) phase: score=\(m.computedDifficultyScore) "
                            + "> max expected \(phase.maximumExpectedScore)"
                    ))
                } else if m.computedDifficultyScore < phase.minimumExpectedScore {
                    anomalies.append(CurveAnomaly(
                        levelID:     m.levelID,
                        kind:        .lateTooEasy,
                        severity:    .warning,
                        description: "\(phase.rawValue) phase: score=\(m.computedDifficultyScore) "
                            + "< min expected \(phase.minimumExpectedScore)"
                    ))
                }
            }
        }
        return anomalies
    }

    static func sparkChar(_ score: Double) -> String {
        switch score {
        case ..<13:  return "▁"
        case ..<26:  return "▂"
        case ..<38:  return "▃"
        case ..<51:  return "▄"
        case ..<63:  return "▅"
        case ..<76:  return "▆"
        case ..<88:  return "▇"
        default:     return "█"
        }
    }
}
#endif
