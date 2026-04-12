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
#endif
