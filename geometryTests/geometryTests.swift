//
//  geometryTests.swift
//  geometryTests
//
//  Created by Marcos on 10/04/2026.
//

import Testing
@testable import geometry

struct geometryTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

}

// MARK: - One-Way Relay Model Tests
// Verifies that the blockedInboundDirections property is correctly modelled
// and that it is zero-cost when unused (empty set = identical to baseline).
@Suite("One-Way Relay Model Tests")
struct OneWayRelayModelTests {

    @Test("Tile defaults to no blocked inbound directions")
    func tileDefaultsToNoBlockedDirections() {
        let tile = Tile(type: .straight)
        #expect(tile.blockedInboundDirections.isEmpty)
    }

    @Test("Base blocked directions are stored and read back at rotation 0")
    func baseBlockedDirectionsRoundtrip() {
        var relay = Tile(type: .curve)
        relay.baseBlockedInboundDirections = [.west, .south]
        // At rotation 0, blockedInboundDirections == baseBlockedInboundDirections
        #expect(relay.blockedInboundDirections.contains(.west))
        #expect(relay.blockedInboundDirections.contains(.south))
        #expect(!relay.blockedInboundDirections.contains(.north))
        #expect(!relay.blockedInboundDirections.contains(.east))
    }

    @Test("Blocking all four directions is representable")
    func allDirectionsBlockable() {
        var tile = Tile(type: .cross)
        tile.baseBlockedInboundDirections = Set(Direction.allCases)
        #expect(tile.blockedInboundDirections.count == 4)
    }

    /// blockedInboundDirections is a flow rule — it must NOT change the tile's
    /// structural connections (the wires are still physically present).
    @Test("Blocked inbound directions do not alter tile connections")
    func blockedDirectionsDoNotAffectConnections() {
        var tile = Tile(type: .straight)   // connects north ↔ south
        tile.baseBlockedInboundDirections = [.north, .south]
        #expect(tile.connections.contains(.north))
        #expect(tile.connections.contains(.south))
        #expect(!tile.connections.contains(.east))
        #expect(!tile.connections.contains(.west))
    }

    @Test("Tiles with identical types but different base blocked directions are independent")
    func blockedDirectionsArePerInstance() {
        let base   = Tile(type: .straight)
        var gated  = Tile(type: .straight)
        gated.baseBlockedInboundDirections = [.north]
        #expect(base.blockedInboundDirections.isEmpty)
        #expect(!gated.blockedInboundDirections.isEmpty)
    }

    /// The one-way constraint rotates with the tile: as the player taps a tile,
    /// the blocked direction changes, and the puzzle requires the correct orientation.
    @Test("Blocked direction rotates with the tile")
    func blockedDirectionRotatesWithTile() {
        var tile = Tile(type: .straight)
        tile.baseBlockedInboundDirections = [.east]   // base: block east (at rotation 0)

        // Rotation 0: blocked = east
        tile.rotation = 0
        #expect(tile.blockedInboundDirections == [.east])

        // Rotation 1 (90° CW): east rotates to south
        tile.rotation = 1
        #expect(tile.blockedInboundDirections == [.south])

        // Rotation 2 (180°): east rotates to west
        tile.rotation = 2
        #expect(tile.blockedInboundDirections == [.west])

        // Rotation 3 (270° CW): east rotates to north
        tile.rotation = 3
        #expect(tile.blockedInboundDirections == [.north])
    }
}

// MARK: - Mechanic Smoke Tests
// Verifies that all special mechanics in the level catalogue produce
// fair, solvable, and strategically meaningful puzzles.
// Runs only in Debug builds (test targets always use Debug configuration).
#if DEBUG
@Suite("Mechanic Smoke Tests")
struct MechanicSmokeTests {

    // Validate every level once at suite setup — no solver for speed.
    private static let reports: [LevelValidationReport] =
        LevelValidationRunner.validateAll(useSolver: false)
    private static let levels: [Level] = LevelGenerator.levels

    // MARK: - Baseline sanity

    /// Every level must have at least one source, the right number of targets,
    /// and a path of ≥ 3 tiles — the generator's own invariant.
    @Test("All levels pass solvability heuristic")
    func allLevelsPassSolvabilityHeuristic() {
        for r in Self.reports {
            #expect(r.isSolvable,
                    "L\(r.levelID): \(r.warnings.joined(separator: " | "))")
        }
    }

    /// A zero buffer means the player must solve perfectly every time — no slack.
    @Test("All levels have a positive move buffer")
    func allLevelsHavePositiveBuffer() {
        for level in Self.levels {
            #expect(level.moveBuffer > 0,
                    "L\(level.id): buffer=\(level.moveBuffer) (min=\(level.minimumRequiredMoves) max=\(level.maxMoves))")
        }
    }

    /// Levels for medium tier and above should require meaningful effort.
    @Test("No trivial levels (minimumRequiredMoves ≤ 1) in medium tier or above")
    func noTrivialLevelsInMediumAndAbove() {
        for level in Self.levels where level.difficulty != .easy {
            #expect(level.minimumRequiredMoves > 1,
                    "L\(level.id) [\(level.difficulty.fullLabel)]: minimumRequiredMoves=\(level.minimumRequiredMoves)")
        }
    }

    // MARK: - Time limit mechanic

    /// A time limit under 30 s combined with any path length is punishing regardless of skill.
    @Test("Timed levels have at least 30 seconds")
    func timedLevelsHaveAtLeast30Seconds() {
        for level in Self.levels {
            guard let limit = level.timeLimit else { continue }
            #expect(limit >= 30,
                    "L\(level.id): time limit \(limit)s is too short for any realistic play")
        }
    }

    /// Fewer than 2 s per minimum move makes a level reaction-based rather than puzzle-based.
    @Test("Timed levels allow at least 2 seconds per minimum move")
    func timedLevelsAllow2SecondsPerMove() {
        for level in Self.levels {
            guard let limit = level.timeLimit, level.minimumRequiredMoves > 0 else { continue }
            let ratio = Double(limit) / Double(level.minimumRequiredMoves)
            #expect(ratio >= 2.0,
                    "L\(level.id): \(ratio)s/move (limit=\(limit)s min=\(level.minimumRequiredMoves))")
        }
    }

    /// A timed level with a very small move buffer is a double-punishment:
    /// the player must be both fast AND perfect.
    @Test("Timed levels have at least 3 buffer moves")
    func timedLevelsHaveAtLeast3BufferMoves() {
        for level in Self.levels where level.timeLimit != nil {
            #expect(level.moveBuffer >= 3,
                    "L\(level.id): timed with only \(level.moveBuffer) buffer moves — time + tight buffer is unfair")
        }
    }

    // MARK: - Rotation cap mechanic

    /// Capping rotations should add planning depth, not make the level unsolvable.
    @Test("Rotation-capped levels pass solvability heuristic")
    func rotationCapLevelsAreSolvable() {
        for r in Self.reports where r.hasRotationCap {
            #expect(r.isSolvable,
                    "L\(r.levelID): rotationCap present but solvability heuristic failed")
        }
    }

    /// With capped tiles the player can accidentally exhaust a tile's rotations;
    /// they need at least 2 buffer moves to recover or reroute.
    @Test("Rotation-capped levels have at least 2 buffer moves")
    func rotationCapLevelsHaveAtLeast2BufferMoves() {
        for r in Self.reports where r.hasRotationCap {
            guard let level = Self.levels.first(where: { $0.id == r.levelID }) else { continue }
            #expect(level.moveBuffer >= 2,
                    "L\(level.id): rotationCap with only \(level.moveBuffer) buffer moves")
        }
    }

    // MARK: - Auto-drift mechanic

    /// Drift tiles rotate automatically — the level must still be winnable
    /// before or after a drift event.
    @Test("Auto-drift levels pass solvability heuristic")
    func autoDriftLevelsAreSolvable() {
        for r in Self.reports where r.hasAutoDrift {
            #expect(r.isSolvable,
                    "L\(r.levelID): autoDrift present but solvability heuristic failed")
        }
    }

    /// When a drift fires the player may need 1–2 corrective taps per drifted tile.
    /// A buffer under 4 makes the level unwinnable after a single bad drift event.
    @Test("Auto-drift levels have at least 4 buffer moves to absorb drift corrections")
    func autoDriftLevelsHaveAtLeast4BufferMoves() {
        for r in Self.reports where r.hasAutoDrift {
            guard let level = Self.levels.first(where: { $0.id == r.levelID }) else { continue }
            #expect(level.moveBuffer >= 4,
                    "L\(level.id): autoDrift with only \(level.moveBuffer) buffer moves — a single drift event may make the level unwinnable")
        }
    }

    // MARK: - energySaving objective

    /// If the limit equals or exceeds the total tile count it never applies pressure.
    @Test("energySaving limit is strictly less than total tile count")
    func energySavingLimitIsConstraining() {
        for level in Self.levels where level.objectiveType == .energySaving {
            let total = level.gridSize * level.gridSize
            #expect(level.energySavingLimit < total,
                    "L\(level.id): energySavingLimit=\(level.energySavingLimit) >= totalTiles=\(total) — win condition never activates")
        }
    }

    /// The limit must be at least as large as the solution path or winning becomes impossible.
    @Test("energySaving limit is at least as large as the solution path")
    func energySavingLimitIsAchievable() {
        for level in Self.levels where level.objectiveType == .energySaving {
            #expect(level.energySavingLimit >= level.solutionPathLength,
                    "L\(level.id): energySavingLimit=\(level.energySavingLimit) < solutionPathLength=\(level.solutionPathLength) — level is impossible to win")
        }
    }

    /// When the limit covers more than 80 % of the grid, virtually any solution satisfies it —
    /// the objective provides no strategic constraint.
    @Test("energySaving limit covers at most 80% of the grid")
    func energySavingObjectiveRequiresStrategy() {
        for level in Self.levels where level.objectiveType == .energySaving {
            let total = level.gridSize * level.gridSize
            let threshold = Int((Double(total) * 0.80).rounded(.up))
            #expect(level.energySavingLimit <= threshold,
                    "L\(level.id): energySavingLimit=\(level.energySavingLimit) > 80% of grid (\(threshold)) — objective is trivially satisfied by any valid solution")
        }
    }

    // MARK: - One-way relay mechanic

    /// Levels without one-way relay must not inadvertently carry the property.
    @Test("One-way relay is absent from levels below ID 146")
    func oneWayRelayAbsentBeforeThreshold() {
        for r in Self.reports where r.levelID < 146 {
            #expect(!r.hasOneWayRelay,
                    "L\(r.levelID): oneWayRelay unexpectedly applied before threshold (id < 146)")
        }
    }

    @Test("One-way relay levels pass solvability heuristic")
    func oneWayRelayLevelsAreSolvable() {
        for r in Self.reports where r.hasOneWayRelay {
            #expect(r.isSolvable,
                    "L\(r.levelID): oneWayRelay present but solvability heuristic failed")
        }
    }

    /// The one-way constraint adds orientation complexity; at least 3 buffer moves
    /// ensures the player can recover from routing the signal in the wrong direction.
    @Test("One-way relay levels have at least 3 buffer moves")
    func oneWayRelayLevelsHaveAdequateBuffer() {
        for level in Self.levels {
            guard let r = Self.reports.first(where: { $0.levelID == level.id }),
                  r.hasOneWayRelay else { continue }
            #expect(level.moveBuffer >= 3,
                    "L\(level.id): oneWayRelay with only \(level.moveBuffer) buffer moves")
        }
    }

    // MARK: - maxCoverage objective

    /// If the solution path already covers ≥ 85 % of the grid, extending coverage further
    /// requires almost no extra effort — the objective distinction is meaningless.
    @Test("maxCoverage solution path leaves at least 15% of the grid for bonus coverage")
    func maxCoverageObjectiveHasMeaningfulRoom() {
        for level in Self.levels where level.objectiveType == .maxCoverage {
            let total = level.gridSize * level.gridSize
            let pathRatio = Float(level.solutionPathLength) / Float(total)
            #expect(pathRatio <= 0.85,
                    "L\(level.id): maxCoverage solution path covers \(Int(pathRatio * 100))% of grid — coverage bonus is trivially achieved alongside the base objective")
        }
    }

    // MARK: - Fragile tile mechanic

    @Test("Fragile tile is absent from levels below ID 151")
    func fragileTileAbsentBeforeThreshold() {
        for r in Self.reports where r.levelID < 151 {
            #expect(!r.hasFragileTile,
                    "L\(r.levelID): fragileTile unexpectedly present before threshold (id < 151)")
        }
    }

    @Test("Fragile tile levels pass solvability heuristic")
    func fragileTileLevelsAreSolvable() {
        for r in Self.reports where r.hasFragileTile {
            #expect(r.isSolvable,
                    "L\(r.levelID): fragileTile present but solvability heuristic failed")
        }
    }

    /// Fragile tiles burn after 3 energized turns, so the player needs slack to recover
    /// routing if they accidentally burned a tile. At least 3 buffer moves is the minimum.
    @Test("Fragile tile levels have at least 3 buffer moves")
    func fragileTileLevelsHaveAdequateBuffer() {
        for level in Self.levels {
            guard let r = Self.reports.first(where: { $0.levelID == level.id }),
                  r.hasFragileTile else { continue }
            #expect(level.moveBuffer >= 3,
                    "L\(level.id): fragileTile with only \(level.moveBuffer) buffer moves — player has no recovery slack after burn-out")
        }
    }

    // MARK: - Charge gate mechanic

    @Test("Charge gate is absent from levels below ID 164")
    func chargeGateAbsentBeforeThreshold() {
        for r in Self.reports where r.levelID < 164 {
            #expect(!r.hasChargeGate,
                    "L\(r.levelID): chargeGate unexpectedly present before threshold (id < 164)")
        }
    }

    @Test("Charge gate levels pass solvability heuristic")
    func chargeGateLevelsAreSolvable() {
        for r in Self.reports where r.hasChargeGate {
            #expect(r.isSolvable,
                    "L\(r.levelID): chargeGate present but solvability heuristic failed")
        }
    }

    /// The gate requires 2 charge cycles (+1 to minMoves). The player also needs
    /// buffer to explore routing paths before the gate opens.
    @Test("Charge gate levels have at least 3 buffer moves")
    func chargeGateLevelsHaveAdequateBuffer() {
        for level in Self.levels {
            guard let r = Self.reports.first(where: { $0.levelID == level.id }),
                  r.hasChargeGate else { continue }
            #expect(level.moveBuffer >= 3,
                    "L\(level.id): chargeGate with only \(level.moveBuffer) buffer moves — player may run out while waiting for the gate to open")
        }
    }

    // MARK: - Interference zone mechanic

    @Test("Interference zone is absent from levels below ID 171")
    func interferenceZoneAbsentBeforeThreshold() {
        for r in Self.reports where r.levelID < 171 {
            #expect(!r.hasInterferenceZone,
                    "L\(r.levelID): interferenceZone unexpectedly present before threshold (id < 171)")
        }
    }

    @Test("Interference zone levels pass solvability heuristic")
    func interferenceZoneLevelsAreSolvable() {
        for r in Self.reports where r.hasInterferenceZone {
            #expect(r.isSolvable,
                    "L\(r.levelID): interferenceZone present but solvability heuristic failed")
        }
    }
}
#endif

// MARK: - Starts-Solved Regression Tests
// Validates that the starts-solved invariant introduced in LevelGenerator.buildBoardInternal
// is upheld across the entire catalogue.
//
// Covers the two levels originally reported as broken (M18 and M25) as explicit regression
// guards, plus a full catalogue sweep to prevent future regressions.
@Suite("Starts-Solved Regression Tests")
struct StartsSolvedRegressionTests {

    private static let levels = LevelGenerator.levels

    // MARK: - Explicit regression guards for reported levels

    /// Mission 18 (dense / energySaving) was seen starting with the circuit already complete.
    /// Root cause: all relay path tiles were straight tiles that landed on their alt-solved
    /// rotation (scramble=2), giving minimumRequiredMoves=0 and active nodes within the
    /// energySaving limit — so checkWin() would pass on the very first tap.
    @Test("Mission 18: does not start pre-solved (regression guard)")
    func mission18NotPreSolved() {
        guard let level = Self.levels.first(where: { $0.id == 18 }) else {
            Issue.record("Level 18 not found in catalogue"); return
        }
        #expect(!LevelGenerator.startsSolved(level: level),
                "L18: board starts with win condition satisfied — rescue invariant failed")
    }

    /// Mission 25 (singlePath / normal) was seen starting with the full circuit connected.
    /// Same root cause as M18: all relay path straight tiles got scramble=2 from the seeded
    /// RNG, placing every one in its alt-solved rotation (minTapsToSolve=0 for each).
    @Test("Mission 25: does not start pre-solved (regression guard)")
    func mission25NotPreSolved() {
        guard let level = Self.levels.first(where: { $0.id == 25 }) else {
            Issue.record("Level 25 not found in catalogue"); return
        }
        #expect(!LevelGenerator.startsSolved(level: level),
                "L25: board starts with win condition satisfied — rescue invariant failed")
    }

    // MARK: - Post-fix property checks for reported levels

    @Test("Mission 18: minimumRequiredMoves > 0 after fix")
    func mission18RequiresAtLeastOneTap() {
        guard let level = Self.levels.first(where: { $0.id == 18 }) else { return }
        #expect(level.minimumRequiredMoves > 0,
                "L18: minimumRequiredMoves=\(level.minimumRequiredMoves) — rescue must add ≥ 1 tap")
    }

    @Test("Mission 25: minimumRequiredMoves > 0 after fix")
    func mission25RequiresAtLeastOneTap() {
        guard let level = Self.levels.first(where: { $0.id == 25 }) else { return }
        #expect(level.minimumRequiredMoves > 0,
                "L25: minimumRequiredMoves=\(level.minimumRequiredMoves) — rescue must add ≥ 1 tap")
    }

    @Test("Mission 18: move buffer is positive (still playable)")
    func mission18HasPositiveMoveBuffer() {
        guard let level = Self.levels.first(where: { $0.id == 18 }) else { return }
        #expect(level.moveBuffer > 0,
                "L18: moveBuffer=\(level.moveBuffer) — level became unplayable after rescue")
    }

    @Test("Mission 25: move buffer is positive (still playable)")
    func mission25HasPositiveMoveBuffer() {
        guard let level = Self.levels.first(where: { $0.id == 25 }) else { return }
        #expect(level.moveBuffer > 0,
                "L25: moveBuffer=\(level.moveBuffer) — level became unplayable after rescue")
    }

    // MARK: - Full catalogue sweep

    /// No level in the 180-level catalogue should produce a board where the win condition is
    /// satisfied before the player makes a single tap.
    @Test("Full catalogue: no level starts pre-solved")
    func fullCatalogueNoPresentSolvedBoards() {
        let broken = Self.levels.filter { LevelGenerator.startsSolved(level: $0) }.map { $0.id }
        #expect(broken.isEmpty,
                "Pre-solved levels found: \(broken) — boardStartsSolved rescue invariant failed for these seeds")
    }

    /// Every level must require at least one tap. minimumRequiredMoves=0 is the generator-side
    /// symptom of a starts-solved board. The rescue increments this to ≥ 1.
    @Test("Full catalogue: minimumRequiredMoves > 0 for all levels")
    func fullCatalogueAllLevelsRequireAtLeastOneTap() {
        let zero = Self.levels.filter { $0.minimumRequiredMoves == 0 }.map { $0.id }
        #expect(zero.isEmpty,
                "Levels with minimumRequiredMoves=0: \(zero)")
    }
}
