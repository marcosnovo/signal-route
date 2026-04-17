//
//  geometryTests.swift
//  geometryTests
//
//  Created by Marcos on 10/04/2026.
//

import Foundation
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

// MARK: - EntitlementStore Access Tests
// Validates the monetisation gate logic: free intro quota, daily cap, and premium bypass.
// Runs serially to prevent state pollution across the shared singleton.
#if DEBUG
@Suite("EntitlementStore — Access Rules", .serialized)
@MainActor
struct EntitlementAccessTests {

    init() {
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetIntroCount()
        EntitlementStore.shared.resetDailyCount()
    }

    private var anyLevel: Level { LevelGenerator.levels[0] }

    // ── Business-logic constants ───────────────────────────────────────────

    @Test("freeIntroLimit == 3 and dailyLimit == 1")
    func entitlementLimitsAreCorrect() {
        #expect(EntitlementStore.freeIntroLimit == 3)
        #expect(EntitlementStore.dailyLimit      == 1)
    }

    // ── Free-user intro phase ──────────────────────────────────────────────

    @Test("Free user — 0 intro missions used — can play")
    func freeUserIntro0CanPlay() {
        EntitlementStore.shared.setFreeIntroCompleted(0)
        #expect(EntitlementStore.shared.canPlay(anyLevel))
    }

    @Test("Free user — 2 of 3 intro missions used — can play")
    func freeUserIntro2CanPlay() {
        EntitlementStore.shared.setFreeIntroCompleted(2)
        #expect(EntitlementStore.shared.canPlay(anyLevel))
    }

    // ── Free-user Phase 2 (24h cooldown) ──────────────────────────────────

    @Test("Free user — intro exhausted + no cooldown — can play")
    func freeUserIntroExhaustedNoCooldownCanPlay() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(0)   // clear cooldown
        #expect(EntitlementStore.shared.canPlay(anyLevel))
    }

    @Test("Free user — intro exhausted + cooldown active — blocked and paywall eligible")
    func freeUserCooldownActiveIsBlocked() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)   // arm cooldown
        #expect(!EntitlementStore.shared.canPlay(anyLevel),
                "canPlay must return false when 24h cooldown is active")
        #expect(EntitlementStore.shared.dailyLimitReached,
                "dailyLimitReached must be true during cooldown")
        #expect(EntitlementStore.shared.reasonBlocked != nil,
                "reasonBlocked must describe the block reason")
    }

    // ── Premium bypass ─────────────────────────────────────────────────────

    @Test("Premium user — always allowed regardless of counters")
    func premiumUserAlwaysAllowed() {
        EntitlementStore.shared.setPremium(true)
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)   // arm cooldown
        defer { EntitlementStore.shared.setPremium(false) }
        #expect(EntitlementStore.shared.canPlay(anyLevel),
                "Premium user must always be allowed to play")
        #expect(!EntitlementStore.shared.dailyLimitReached,
                "dailyLimitReached must be false for premium")
        #expect(EntitlementStore.shared.reasonBlocked == nil,
                "reasonBlocked must be nil for premium")
    }

    // ── Phase boundary ─────────────────────────────────────────────────────

    @Test("isInIntroPhase transitions to false exactly at freeIntroLimit")
    func isInIntroPhaseTransitionsAtLimit() {
        EntitlementStore.shared.setFreeIntroCompleted(EntitlementStore.freeIntroLimit - 1)
        #expect(EntitlementStore.shared.isInIntroPhase,
                "One below limit must still be in intro phase")

        EntitlementStore.shared.setFreeIntroCompleted(EntitlementStore.freeIntroLimit)
        #expect(!EntitlementStore.shared.isInIntroPhase,
                "At freeIntroLimit must no longer be in intro phase")
    }
}

// MARK: - EntitlementStore Consumption Tests
// Validates when each counter is incremented and when it must stay unchanged.
@Suite("EntitlementStore — Counter Consumption", .serialized)
@MainActor
struct EntitlementConsumptionTests {

    init() {
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetIntroCount()
        EntitlementStore.shared.resetDailyCount()
    }

    private var anyLevel: Level { LevelGenerator.levels[0] }

    // ── canPlay does not consume ───────────────────────────────────────────

    @Test("canPlay does not increment any counter")
    func canPlayDoesNotConsumeCounter() {
        EntitlementStore.shared.setFreeIntroCompleted(2)  // mid-intro, no cooldown
        let introBefore = EntitlementStore.shared.freeIntroCompleted
        let dailyBefore = EntitlementStore.shared.dailyAttemptsUsed
        _ = EntitlementStore.shared.canPlay(anyLevel)
        #expect(EntitlementStore.shared.freeIntroCompleted == introBefore,
                "Intro counter must not change on canPlay")
        #expect(EntitlementStore.shared.dailyAttemptsUsed == dailyBefore,
                "Daily indicator must not change on canPlay")
    }

    // ── Intro phase — WON increments, FAILED is free ──────────────────────

    @Test("recordAttempt(didWin: true) mid-intro increments only freeIntroCompleted")
    func winMidIntroIncrementsIntroCounter() {
        EntitlementStore.shared.setFreeIntroCompleted(1)  // 1/3 — NOT the last win
        let dailyBefore = EntitlementStore.shared.dailyAttemptsUsed  // 0
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: true)
        #expect(EntitlementStore.shared.freeIntroCompleted == 2,
                "Intro counter must increment from 1 to 2 on win")
        #expect(EntitlementStore.shared.dailyAttemptsUsed == dailyBefore,
                "Daily indicator must not change during mid-intro win")
    }

    @Test("recordAttempt(didWin: true) on last intro win exhausts phase and arms cooldown")
    func lastIntroWinArmsCooldown() {
        EntitlementStore.shared.setFreeIntroCompleted(2)  // 2/3 — about to exhaust
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: true)
        #expect(EntitlementStore.shared.freeIntroCompleted == 3,
                "Intro counter must reach freeIntroLimit")
        #expect(!EntitlementStore.shared.isInIntroPhase,
                "Must have exited intro phase")
        #expect(EntitlementStore.shared.dailyLimitReached,
                "24h cooldown must be armed immediately after intro exhaustion")
    }

    @Test("recordAttempt(didWin: false) during intro does NOT increment any counter")
    func failDuringIntroIsFreePasses() {
        EntitlementStore.shared.setFreeIntroCompleted(1)
        let introBefore = EntitlementStore.shared.freeIntroCompleted
        let dailyBefore = EntitlementStore.shared.dailyAttemptsUsed
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: false)
        #expect(EntitlementStore.shared.freeIntroCompleted == introBefore,
                "Intro counter must NOT increment on failure during intro phase")
        #expect(EntitlementStore.shared.dailyAttemptsUsed == dailyBefore,
                "Daily indicator must NOT change on failure during intro phase")
    }

    // ── Phase 2 — play arms 24h cooldown ─────────────────────────────────

    @Test("recordAttempt(didWin: true) in Phase 2 arms cooldown")
    func winInPhase2ArmsCooldown() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        let introBefore = EntitlementStore.shared.freeIntroCompleted
        EntitlementStore.shared.setDailyAttemptsUsed(0)   // clear cooldown
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: true)
        #expect(EntitlementStore.shared.dailyAttemptsUsed == 1,
                "Daily indicator must show 1 (cooldown active) after Phase 2 play")
        #expect(EntitlementStore.shared.freeIntroCompleted == introBefore,
                "Intro counter must not change in Phase 2")
    }

    @Test("recordAttempt(didWin: false) in Phase 2 also arms cooldown")
    func failInPhase2ArmsCooldown() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        let introBefore = EntitlementStore.shared.freeIntroCompleted
        EntitlementStore.shared.setDailyAttemptsUsed(0)
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: false)
        #expect(EntitlementStore.shared.dailyAttemptsUsed == 1,
                "Daily indicator must show 1 (cooldown active) after Phase 2 fail")
        #expect(EntitlementStore.shared.freeIntroCompleted == introBefore,
                "Intro counter must not change on Phase 2 failure")
    }

    // ── Premium no-op ──────────────────────────────────────────────────────

    @Test("recordAttempt for a premium user is a complete no-op on all counters")
    func premiumAttemptDoesNotConsumeAnyCounter() {
        EntitlementStore.shared.setPremium(true)
        EntitlementStore.shared.setFreeIntroCompleted(2)
        let introBefore = EntitlementStore.shared.freeIntroCompleted
        let dailyBefore = EntitlementStore.shared.dailyAttemptsUsed
        defer { EntitlementStore.shared.setPremium(false) }
        EntitlementStore.shared.recordAttempt(anyLevel, didWin: true)
        #expect(EntitlementStore.shared.freeIntroCompleted == introBefore,
                "Intro counter must not change for premium user")
        #expect(EntitlementStore.shared.dailyAttemptsUsed == dailyBefore,
                "Daily indicator must not change for premium user")
    }
}
#endif

// MARK: - Story Beat Localization Tests
// Validates that all story-beat UI strings honour the active language setting.
// Protects against the "Spanish body / English CTA or footer" regression class.
@Suite("Story Beat Localization")
struct StoryBeatLocalizationTests {

    private let en = AppStrings(lang: .en)
    private let es = AppStrings(lang: .es)
    private let fr = AppStrings(lang: .fr)

    // ── CTA strings ────────────────────────────────────────────────────────

    @Test("'Acknowledge' CTA is localized for ES and FR")
    func acknowledgeIsLocalized() {
        #expect(es.acknowledge != en.acknowledge,
                "ES 'acknowledge' must not equal EN 'ACKNOWLEDGE'")
        #expect(fr.acknowledge != en.acknowledge,
                "FR 'acknowledge' must not equal EN 'ACKNOWLEDGE'")
        #expect(!es.acknowledge.isEmpty)
        #expect(!fr.acknowledge.isEmpty)
    }

    @Test("'Incoming transmission' header is localized for ES and FR")
    func incomingTransmissionIsLocalized() {
        #expect(es.incomingTransmission != en.incomingTransmission)
        #expect(fr.incomingTransmission != en.incomingTransmission)
    }

    // ── Trigger labels ─────────────────────────────────────────────────────

    @Test("All StoryTrigger badge labels are localized for ES and FR")
    func storyTriggerLabelsAreLocalized() {
        for trigger in StoryTrigger.allCases {
            let enLabel = en.storyTriggerLabel(trigger)
            #expect(es.storyTriggerLabel(trigger) != enLabel,
                    "ES trigger label for .\(trigger) matches EN — translation missing")
            #expect(fr.storyTriggerLabel(trigger) != enLabel,
                    "FR trigger label for .\(trigger) matches EN — translation missing")
        }
    }

    // ── Footer hints ───────────────────────────────────────────────────────

    private static let representativeHints = [
        "ROTATION LIMIT ACTIVE",
        "TWO-TAP PROTOCOL ACTIVE",
        "AUTO-DRIFT ACTIVE",
        "TIME LIMIT ACTIVE",
        "MISSION 1 LOADED",
        "LUNAR APPROACH UNLOCKED",
        "MARS SECTOR UNLOCKED",
        "FULL NETWORK OPERATIONAL",
        "RANK: PILOT",
        "RANK: NAVIGATOR",
        "RANK: COMMANDER",
        "SECTOR 2 — LUNAR APPROACH",
        "SECTOR 8 — NEPTUNE DEEP",
    ]

    @Test("Known footer hints are translated for ES — not left in English")
    func footerHintsLocalizedES() {
        for hint in Self.representativeHints {
            #expect(es.storyFooterHint(hint) != hint,
                    "ES footer hint '\(hint)' is still English — add translation to storyFooterHint(_:)")
        }
    }

    @Test("Known footer hints are translated for FR — not left in English")
    func footerHintsLocalizedFR() {
        for hint in Self.representativeHints {
            #expect(fr.storyFooterHint(hint) != hint,
                    "FR footer hint '\(hint)' is still English — add translation to storyFooterHint(_:)")
        }
    }

    @Test("Unknown footer hint falls back to the original string without crashing")
    func unknownFooterHintFallsBack() {
        let unknown = "SOME_UNKNOWN_STATUS_XYZ"
        #expect(es.storyFooterHint(unknown) == unknown)
        #expect(fr.storyFooterHint(unknown) == unknown)
    }

    // ── Beat catalog ───────────────────────────────────────────────────────

    @Test("All beats with localizedTitle display a distinct ES title")
    func beatsWithLocalizedTitleShowESTitle() {
        for beat in StoryBeatCatalog.beats where beat.localizedTitle != nil {
            #expect(beat.displayTitle(for: .es) != beat.displayTitle(for: .en),
                    "Beat '\(beat.id)': ES title matches EN — localizedTitle.es may be missing")
        }
    }

    @Test("All beats with localizedBody display a distinct ES body")
    func beatsWithLocalizedBodyShowESBody() {
        for beat in StoryBeatCatalog.beats where beat.localizedBody != nil {
            #expect(beat.displayBody(for: .es) != beat.displayBody(for: .en),
                    "Beat '\(beat.id)': ES body matches EN — localizedBody.es may be missing")
        }
    }

    @Test("All beats with localizedBody display a distinct FR body")
    func beatsWithLocalizedBodyShowFRBody() {
        for beat in StoryBeatCatalog.beats where beat.localizedBody != nil {
            #expect(beat.displayBody(for: .fr) != beat.displayBody(for: .en),
                    "Beat '\(beat.id)': FR body matches EN — localizedBody.fr may be missing")
        }
    }

    // ── Mechanic strings ───────────────────────────────────────────────────

    @Test("Mechanic titles are localized for ES and FR")
    func mechanicTitlesAreLocalized() {
        let mechanics: [MechanicType] = [
            .rotationCap, .overloaded, .timeLimit, .autoDrift,
            .oneWayRelay, .fragileTile, .chargeGate, .interferenceZone,
        ]
        for mechanic in mechanics {
            let enTitle = en.mechanicTitle(mechanic)
            #expect(es.mechanicTitle(mechanic) != enTitle,
                    "ES mechanic title for .\(mechanic) matches EN — not localized")
            #expect(fr.mechanicTitle(mechanic) != enTitle,
                    "FR mechanic title for .\(mechanic) matches EN — not localized")
        }
    }

    @Test("Mechanic body messages are localized for ES and FR")
    func mechanicMessagesAreLocalized() {
        let mechanics: [MechanicType] = [
            .rotationCap, .overloaded, .timeLimit, .autoDrift,
            .oneWayRelay, .fragileTile, .chargeGate, .interferenceZone,
        ]
        for mechanic in mechanics {
            let enMsg = en.mechanicMessage(mechanic)
            #expect(es.mechanicMessage(mechanic) != enMsg,
                    "ES mechanic message for .\(mechanic) matches EN — not localized")
            #expect(fr.mechanicMessage(mechanic) != enMsg,
                    "FR mechanic message for .\(mechanic) matches EN — not localized")
        }
    }
}

// MARK: - DiscountCode Model Tests
// Pure struct tests — no I/O, no singletons, no MainActor.
@Suite("DiscountCode — Model")
struct DiscountCodeModelTests {

    private func make(
        code: String = "TEST10",
        percentageOff: Int = 10,
        isActive: Bool = true,
        expiresAt: Date? = nil,
        usageLimit: Int? = nil,
        usageCount: Int = 0
    ) -> DiscountCode {
        DiscountCode(code: code, percentageOff: percentageOff, isActive: isActive,
                     expiresAt: expiresAt, usageLimit: usageLimit, usageCount: usageCount)
    }

    @Test("id computed property equals the code string")
    func idEqualsCode() {
        let c = make(code: "WELCOME25")
        #expect(c.id == "WELCOME25")
    }

    @Test("isExpired is false when no expiresAt")
    func isExpiredFalseWithoutExpiry() {
        #expect(!make(expiresAt: nil).isExpired)
    }

    @Test("isExpired is false when expiresAt is in the future")
    func isExpiredFalseForFutureDate() {
        #expect(!make(expiresAt: Date().addingTimeInterval(3600)).isExpired)
    }

    @Test("isExpired is true when expiresAt is in the past")
    func isExpiredTrueForPastDate() {
        #expect(make(expiresAt: Date().addingTimeInterval(-1)).isExpired)
    }

    @Test("isExhausted is false when usageLimit is nil (unlimited)")
    func isExhaustedFalseWhenNoLimit() {
        #expect(!make(usageLimit: nil, usageCount: 9999).isExhausted)
    }

    @Test("isExhausted is false when usageCount is below limit")
    func isExhaustedFalseWhenBelowLimit() {
        #expect(!make(usageLimit: 5, usageCount: 4).isExhausted)
    }

    @Test("isExhausted is true when usageCount equals limit")
    func isExhaustedTrueAtLimit() {
        #expect(make(usageLimit: 5, usageCount: 5).isExhausted)
    }

    @Test("isExhausted is true when usageCount exceeds limit")
    func isExhaustedTrueAboveLimit() {
        #expect(make(usageLimit: 5, usageCount: 10).isExhausted)
    }

    @Test("percentageOff of 100 is representable")
    func fullDiscountRepresentable() {
        let c = make(percentageOff: 100)
        #expect(c.percentageOff == 100)
    }
}

// MARK: - DiscountStore Tests
// Validates validation logic, redemption, CRUD, case-insensitivity, and persistence invariants.
// Runs serially and resets the store before each test to avoid inter-test state pollution.
#if DEBUG
@Suite("DiscountStore — Validation & CRUD", .serialized)
@MainActor
struct DiscountStoreTests {

    init() {
        // Start each test with a clean slate
        DiscountStore.shared.deleteAll()
    }

    // Helper — add a fully valid code with no restrictions
    private func addValid(code: String = "ALPHA20", pct: Int = 20) -> DiscountCode {
        let dc = DiscountCode(code: code, percentageOff: pct, isActive: true,
                              expiresAt: nil, usageLimit: nil, usageCount: 0)
        DiscountStore.shared.add(dc)
        return dc
    }

    // MARK: validate — happy path

    @Test("validate returns .invalid for unknown code in empty catalog")
    func validateInvalidWhenCatalogEmpty() {
        let result = DiscountStore.shared.validate("NOPE")
        #expect(result == .invalid)
    }

    @Test("validate returns .valid for a known, active, unexpired, non-exhausted code")
    func validateValidForGoodCode() {
        let dc = addValid()
        let result = DiscountStore.shared.validate(dc.code)
        #expect(result == .valid(dc))
    }

    @Test("validate is case-insensitive — lowercase input matches uppercase stored code")
    func validateCaseInsensitive() {
        let dc = addValid(code: "UPPER50")
        let result = DiscountStore.shared.validate("upper50")
        #expect(result == .valid(dc))
    }

    @Test("validate trims leading/trailing whitespace before matching")
    func validateTrimsWhitespace() {
        let dc = addValid(code: "SPACE10")
        let result = DiscountStore.shared.validate("  SPACE10  ")
        #expect(result == .valid(dc))
    }

    // MARK: validate — failure paths

    @Test("validate returns .inactive for a deactivated code")
    func validateInactiveForDeactivatedCode() {
        let dc = DiscountCode(code: "OFF30", percentageOff: 30, isActive: false,
                              expiresAt: nil, usageLimit: nil, usageCount: 0)
        DiscountStore.shared.add(dc)
        #expect(DiscountStore.shared.validate("OFF30") == .inactive)
    }

    @Test("validate returns .expired for a code past its expiry date")
    func validateExpiredForPastExpiry() {
        let dc = DiscountCode(code: "EXP10", percentageOff: 10, isActive: true,
                              expiresAt: Date().addingTimeInterval(-1),
                              usageLimit: nil, usageCount: 0)
        DiscountStore.shared.add(dc)
        #expect(DiscountStore.shared.validate("EXP10") == .expired)
    }

    @Test("validate returns .exhausted for a code that has reached its usage limit")
    func validateExhaustedAtLimit() {
        let dc = DiscountCode(code: "USED5", percentageOff: 5, isActive: true,
                              expiresAt: nil, usageLimit: 3, usageCount: 3)
        DiscountStore.shared.add(dc)
        #expect(DiscountStore.shared.validate("USED5") == .exhausted)
    }

    // MARK: redeem

    @Test("redeem increments usageCount by 1 for a valid code")
    func redeemIncrementsUsageCount() {
        _ = addValid(code: "REDEEM10")
        let countBefore = DiscountStore.shared.codes.first(where: { $0.code == "REDEEM10" })?.usageCount ?? -1
        _ = DiscountStore.shared.redeem("REDEEM10")
        let countAfter = DiscountStore.shared.codes.first(where: { $0.code == "REDEEM10" })?.usageCount ?? -1
        #expect(countAfter == countBefore + 1)
    }

    @Test("redeem returns the DiscountCode on success")
    func redeemReturnsCodeOnSuccess() {
        _ = addValid(code: "RET20")
        let result = DiscountStore.shared.redeem("RET20")
        #expect(result != nil)
        #expect(result?.code == "RET20")
    }

    @Test("redeem returns nil for an unknown code")
    func redeemNilForUnknownCode() {
        #expect(DiscountStore.shared.redeem("GHOST") == nil)
    }

    @Test("redeem returns nil for an inactive code")
    func redeemNilForInactiveCode() {
        let dc = DiscountCode(code: "NOPE", percentageOff: 10, isActive: false,
                              expiresAt: nil, usageLimit: nil, usageCount: 0)
        DiscountStore.shared.add(dc)
        #expect(DiscountStore.shared.redeem("NOPE") == nil)
    }

    @Test("redeem returns nil and does not increment count for an exhausted code")
    func redeemNilWhenExhausted() {
        let dc = DiscountCode(code: "FULL", percentageOff: 10, isActive: true,
                              expiresAt: nil, usageLimit: 1, usageCount: 1)
        DiscountStore.shared.add(dc)
        let result = DiscountStore.shared.redeem("FULL")
        let countAfter = DiscountStore.shared.codes.first(where: { $0.code == "FULL" })?.usageCount ?? -1
        #expect(result == nil)
        #expect(countAfter == 1, "usageCount must not increment for an exhausted redemption")
    }

    // MARK: CRUD

    @Test("add rejects duplicate codes (case-insensitive)")
    func addRejectsDuplicates() {
        _ = addValid(code: "DUP10")
        let before = DiscountStore.shared.codes.count
        let duplicate = DiscountCode(code: "dup10", percentageOff: 99, isActive: true,
                                     expiresAt: nil, usageLimit: nil, usageCount: 0)
        DiscountStore.shared.add(duplicate)
        #expect(DiscountStore.shared.codes.count == before,
                "Duplicate code must not be added — catalog count must stay the same")
    }

    @Test("toggleActive flips the isActive flag")
    func toggleActiveFlipsFlag() {
        let dc = addValid(code: "TOGGLE")
        let before = DiscountStore.shared.codes.first(where: { $0.code == "TOGGLE" })!.isActive
        DiscountStore.shared.toggleActive(dc)
        let after = DiscountStore.shared.codes.first(where: { $0.code == "TOGGLE" })!.isActive
        #expect(after == !before)
    }

    @Test("delete removes the code from the catalog")
    func deleteRemovesCode() {
        let dc = addValid(code: "DEL10")
        DiscountStore.shared.delete(dc)
        #expect(DiscountStore.shared.codes.first(where: { $0.code == "DEL10" }) == nil)
    }

    @Test("resetUsage sets usageCount back to 0")
    func resetUsageZerosCount() {
        let dc = DiscountCode(code: "RESET", percentageOff: 10, isActive: true,
                              expiresAt: nil, usageLimit: 10, usageCount: 7)
        DiscountStore.shared.add(dc)
        DiscountStore.shared.resetUsage(dc)
        let count = DiscountStore.shared.codes.first(where: { $0.code == "RESET" })?.usageCount
        #expect(count == 0)
    }

    @Test("deleteAll empties the entire catalog")
    func deleteAllEmptiesCatalog() {
        _ = addValid(code: "A10")
        _ = addValid(code: "B20")
        DiscountStore.shared.deleteAll()
        #expect(DiscountStore.shared.codes.isEmpty)
    }

    @Test("validate returns .invalid after the code's only use is exhausted by redeem")
    func validateBlocksAfterFinalRedemption() {
        let dc = DiscountCode(code: "ONCE", percentageOff: 50, isActive: true,
                              expiresAt: nil, usageLimit: 1, usageCount: 0)
        DiscountStore.shared.add(dc)
        _ = DiscountStore.shared.redeem("ONCE")   // consumes the 1 allowed use
        #expect(DiscountStore.shared.validate("ONCE") == .exhausted,
                "After the only redemption, code must appear exhausted")
    }
}
#endif

// MARK: - EntitlementStore Cooldown State Tests
// Supplements the existing Access/Consumption suites with cooldown-specific derived state.
#if DEBUG
@Suite("EntitlementStore — Cooldown State", .serialized)
@MainActor
struct EntitlementCooldownStateTests {

    init() {
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetIntroCount()
        EntitlementStore.shared.resetDailyCount()
    }

    private var anyLevel: Level { LevelGenerator.levels[0] }

    // MARK: remainingCooldown

    @Test("remainingCooldown is 0 when no cooldown is active")
    func remainingCooldownZeroWhenFree() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(0)
        #expect(EntitlementStore.shared.remainingCooldown == 0)
    }

    @Test("remainingCooldown is > 0 immediately after cooldown is armed")
    func remainingCooldownPositiveWhenArmed() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)   // arms cooldown
        #expect(EntitlementStore.shared.remainingCooldown > 0,
                "remainingCooldown must be positive while the 24h gate is active")
    }

    @Test("remainingCooldown approaches 24h (86400s) right after arming")
    func remainingCooldownNear24h() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)
        // Allow ±5 s tolerance for clock jitter in CI
        let remaining = EntitlementStore.shared.remainingCooldown
        #expect(remaining > 86_390 && remaining <= 86_400,
                "Immediately after arming, remaining cooldown must be ~86400s, got \(remaining)s")
    }

    // MARK: canPlayNextMission

    @Test("canPlayNextMission returns false during cooldown")
    func canPlayNextMissionFalseWhenBlocked() {
        let levels = LevelGenerator.levels
        guard levels.count >= 2 else { return }
        let first = levels[0]
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)
        #expect(!EntitlementStore.shared.canPlayNextMission(after: first),
                "canPlayNextMission must return false when the 24h gate is active")
    }

    @Test("canPlayNextMission returns false for the last level (no next exists)")
    func canPlayNextMissionFalseForLastLevel() {
        let last = LevelGenerator.levels.last!
        // Even premium should get false here because there is no next level
        EntitlementStore.shared.setPremium(true)
        defer { EntitlementStore.shared.setPremium(false) }
        #expect(!EntitlementStore.shared.canPlayNextMission(after: last),
                "canPlayNextMission must return false when no subsequent level exists")
    }

    // MARK: forceCooldown / clearCooldown

    @Test("forceCooldown arms cooldown and blocks canPlay")
    func forceCooldownBlocksPlay() {
        EntitlementStore.shared.forceCooldown()
        #expect(!EntitlementStore.shared.canPlay(anyLevel),
                "canPlay must return false immediately after forceCooldown()")
        #expect(EntitlementStore.shared.dailyLimitReached,
                "dailyLimitReached must be true after forceCooldown()")
    }

    @Test("clearCooldown unblocks play for a free user")
    func clearCooldownUnblocksPlay() {
        EntitlementStore.shared.setFreeIntroCompleted(3)
        EntitlementStore.shared.setDailyAttemptsUsed(1)   // arm
        EntitlementStore.shared.clearCooldown()            // clear
        #expect(EntitlementStore.shared.canPlay(anyLevel),
                "canPlay must return true immediately after clearCooldown()")
        #expect(!EntitlementStore.shared.dailyLimitReached,
                "dailyLimitReached must be false after clearCooldown()")
        #expect(EntitlementStore.shared.remainingCooldown == 0,
                "remainingCooldown must be 0 after clearCooldown()")
    }

    @Test("setFreeIntroCompleted below freeIntroLimit clears any active cooldown")
    func setIntroCompletedBelowLimitClearsCooldown() {
        EntitlementStore.shared.forceCooldown()            // Phase 2 + cooldown armed
        EntitlementStore.shared.setFreeIntroCompleted(1)   // return to Phase 1
        #expect(EntitlementStore.shared.isInIntroPhase,
                "Must be back in intro phase after setFreeIntroCompleted(1)")
        #expect(EntitlementStore.shared.canPlay(anyLevel),
                "canPlay must return true after returning to intro phase")
    }
}
#endif

// MARK: - Notification Copy Tests
// Validates that all three languages produce non-empty, distinct notification strings.
// Does NOT schedule actual notifications — purely tests AppStrings string values.
@Suite("NotificationManager — Copy Strings")
struct NotificationCopyTests {

    private let en = AppStrings(lang: .en)
    private let es = AppStrings(lang: .es)
    private let fr = AppStrings(lang: .fr)

    @Test("notifCooldownTitle is non-empty in all three languages")
    func cooldownTitleNonEmpty() {
        #expect(!en.notifCooldownTitle.isEmpty)
        #expect(!es.notifCooldownTitle.isEmpty)
        #expect(!fr.notifCooldownTitle.isEmpty)
    }

    @Test("notifCooldownBody is non-empty in all three languages")
    func cooldownBodyNonEmpty() {
        #expect(!en.notifCooldownBody.isEmpty)
        #expect(!es.notifCooldownBody.isEmpty)
        #expect(!fr.notifCooldownBody.isEmpty)
    }

    @Test("notifCooldownTitle is localized — ES and FR differ from EN")
    func cooldownTitleLocalized() {
        #expect(es.notifCooldownTitle != en.notifCooldownTitle,
                "ES cooldown title must not be identical to EN")
        #expect(fr.notifCooldownTitle != en.notifCooldownTitle,
                "FR cooldown title must not be identical to EN")
    }

    @Test("notifCooldownBody is localized — ES and FR differ from EN")
    func cooldownBodyLocalized() {
        #expect(es.notifCooldownBody != en.notifCooldownBody,
                "ES cooldown body must not be identical to EN")
        #expect(fr.notifCooldownBody != en.notifCooldownBody,
                "FR cooldown body must not be identical to EN")
    }
}

// MARK: - FASE 2-4 AppStrings Localization Tests
// Validates that all strings added in FASE 2 (gating CTA), FASE 3 (notifications),
// and FASE 4 (discount codes) are correctly localized for EN, ES, and FR.
@Suite("AppStrings — FASE 2-4 Localization")
struct Fase24AppStringsTests {

    private let en = AppStrings(lang: .en)
    private let es = AppStrings(lang: .es)
    private let fr = AppStrings(lang: .fr)

    // ── FASE 2: gating CTA strings ─────────────────────────────────────────

    @Test("keepPlayingWithoutWaiting is non-empty in all languages")
    func keepPlayingNonEmpty() {
        #expect(!en.keepPlayingWithoutWaiting.isEmpty)
        #expect(!es.keepPlayingWithoutWaiting.isEmpty)
        #expect(!fr.keepPlayingWithoutWaiting.isEmpty)
    }

    @Test("keepPlayingWithoutWaiting is localized — ES and FR differ from EN")
    func keepPlayingLocalized() {
        #expect(es.keepPlayingWithoutWaiting != en.keepPlayingWithoutWaiting)
        #expect(fr.keepPlayingWithoutWaiting != en.keepPlayingWithoutWaiting)
    }

    @Test("backIn(_:) embeds the time argument in all three languages")
    func backInContainsTimeArgument() {
        let time = "12:34:56"
        #expect(en.backIn(time).contains(time), "EN backIn must include the time string")
        #expect(es.backIn(time).contains(time), "ES backIn must include the time string")
        #expect(fr.backIn(time).contains(time), "FR backIn must include the time string")
    }

    @Test("backIn(_:) is localized — ES and FR differ from EN")
    func backInLocalized() {
        let time = "00:01:00"
        #expect(es.backIn(time) != en.backIn(time))
        #expect(fr.backIn(time) != en.backIn(time))
    }

    // ── FASE 4: discount code strings ──────────────────────────────────────

    @Test("discountCodePlaceholder is non-empty and localized")
    func discountPlaceholderLocalized() {
        #expect(!en.discountCodePlaceholder.isEmpty)
        #expect(es.discountCodePlaceholder != en.discountCodePlaceholder)
        #expect(fr.discountCodePlaceholder != en.discountCodePlaceholder)
    }

    @Test("applyCode is non-empty and localized")
    func applyCodeLocalized() {
        #expect(!en.applyCode.isEmpty)
        #expect(es.applyCode != en.applyCode)
        #expect(fr.applyCode != en.applyCode)
    }

    @Test("discountValid is non-empty and localized")
    func discountValidLocalized() {
        #expect(!en.discountValid.isEmpty)
        #expect(es.discountValid != en.discountValid)
        #expect(fr.discountValid != en.discountValid)
    }

    @Test("discountInvalid is non-empty and localized")
    func discountInvalidLocalized() {
        #expect(!en.discountInvalid.isEmpty)
        #expect(es.discountInvalid != en.discountInvalid)
        #expect(fr.discountInvalid != en.discountInvalid)
    }

    @Test("discountExpired is non-empty and localized")
    func discountExpiredLocalized() {
        #expect(!en.discountExpired.isEmpty)
        #expect(es.discountExpired != en.discountExpired)
        #expect(fr.discountExpired != en.discountExpired)
    }

    @Test("discountInactive is non-empty and localized")
    func discountInactiveLocalized() {
        #expect(!en.discountInactive.isEmpty)
        #expect(es.discountInactive != en.discountInactive)
        #expect(fr.discountInactive != en.discountInactive)
    }

    @Test("discountExhausted is non-empty and localized")
    func discountExhaustedLocalized() {
        #expect(!en.discountExhausted.isEmpty)
        #expect(es.discountExhausted != en.discountExhausted)
        #expect(fr.discountExhausted != en.discountExhausted)
    }

    @Test("discountOff(_:) embeds the percentage in all languages")
    func discountOffContainsPercentage() {
        #expect(en.discountOff(20).contains("20"))
        #expect(es.discountOff(20).contains("20"))
        #expect(fr.discountOff(20).contains("20"))
    }

    @Test("discountOff(_:) is localized — ES and FR differ from EN")
    func discountOffLocalized() {
        #expect(es.discountOff(15) != en.discountOff(15))
        #expect(fr.discountOff(15) != en.discountOff(15))
    }

    @Test("discountedPrice(original:discounted:) contains both price strings")
    func discountedPriceContainsBothValues() {
        let original = "$9.99"
        let discounted = "$7.99"
        let result = en.discountedPrice(original: original, discounted: discounted)
        #expect(result.contains(original),   "EN discountedPrice must contain the original price")
        #expect(result.contains(discounted), "EN discountedPrice must contain the discounted price")
    }
}

// MARK: - GameCenterManager Smoke Tests
// Validates the observable state contract of the shared singleton.
// Does not attempt GK authentication — purely checks initial state and safe no-ops.
@Suite("GameCenterManager — State Contract")
@MainActor
struct GameCenterManagerStateTests {

    @Test("rankFeedback starts nil before any score is submitted")
    func rankFeedbackInitiallyNil() {
        // rankFeedback is only set after a successful submitScore+leaderboard load.
        // In the test environment (no GK auth) it must remain nil.
        #expect(GameCenterManager.shared.rankFeedback == nil)
    }

    @Test("lastSubmittedScore starts nil before any submission")
    func lastSubmittedScoreInitiallyNil() {
        // lastSubmittedScore is only set inside submitScore(efficiency:).
        // Without a real GK session this must remain nil.
        #expect(GameCenterManager.shared.lastSubmittedScore == nil)
    }

    @Test("clearRankFeedback is safe to call when rankFeedback is already nil")
    func clearRankFeedbackNoOpWhenNil() {
        GameCenterManager.shared.clearRankFeedback()
        #expect(GameCenterManager.shared.rankFeedback == nil)
    }

    @Test("isGameCenterEnabled matches isAuthenticated")
    func gameCenterEnabledMirrorsAuthenticated() {
        // Both flags are set/cleared together in the authenticateHandler.
        let gcm = GameCenterManager.shared
        #expect(gcm.isGameCenterEnabled == gcm.isAuthenticated,
                "isGameCenterEnabled and isAuthenticated must always agree")
    }

    @Test("displayName is empty when not authenticated")
    func displayNameEmptyWhenUnauthenticated() {
        // In the simulator / unit test context GK is not signed in.
        if !GameCenterManager.shared.isAuthenticated {
            #expect(GameCenterManager.shared.displayName.isEmpty,
                    "displayName must be empty when isAuthenticated is false")
        }
    }
}

// MARK: - Narrative Regression Tests
// Automated safety net for the story system. Covers:
//   1. Catalog integrity — unique IDs, non-empty required fields, valid triggers, locale strings
//   2. Once-only behavior — beats disappear after markSeen(), reappear after markUnseen()
//   3. Queue ordering — results are priority-ascending and deduplicated
//   4. Persistence — seenIDs round-trip correctly through UserDefaults
//   5. Localization coverage — every beat returns non-empty strings in EN, ES, FR
//
// Note: UIImage asset-resolution tests are intentionally omitted — the unit-test
// bundle does not include story image assets, so UIImage(named:) would always fail.
// Asset presence is validated at runtime via StoryAssetValidator (DevMenuView / DEBUG launch).
@Suite("NarrativeRegression — Story System Safety Net", .serialized)
struct NarrativeRegressionTests {

    /// Reset seen-IDs before every test to prevent inter-test state pollution.
    init() {
        StoryStore.reset()
    }

    // MARK: 1. Catalog Integrity

    @Test("All beat IDs are unique")
    func beatIDsAreUnique() {
        let ids = StoryBeatCatalog.beats.map(\.id)
        let duplicates = ids.filter { id in ids.filter { $0 == id }.count > 1 }
        #expect(duplicates.isEmpty,
                "Duplicate beat IDs found: \(Set(duplicates).sorted().joined(separator: ", "))")
    }

    @Test("No beat has an empty ID, title, body, or source")
    func beatsMandatoryFieldsNonEmpty() {
        for beat in StoryBeatCatalog.beats {
            #expect(!beat.id.isEmpty,     "Beat has empty id")
            #expect(!beat.title.isEmpty,  "Beat '\(beat.id)' has empty title")
            #expect(!beat.body.isEmpty,   "Beat '\(beat.id)' has empty body")
            #expect(!beat.source.isEmpty, "Beat '\(beat.id)' has empty source")
        }
    }

    @Test("All beats have a valid StoryTrigger")
    func beatsHaveValidTrigger() {
        let valid = Set(StoryTrigger.allCases)
        for beat in StoryBeatCatalog.beats {
            #expect(valid.contains(beat.trigger),
                    "Beat '\(beat.id)' has unknown trigger '\(beat.trigger.rawValue)'")
        }
    }

    @Test("Beats with localizedTitle have non-empty ES and FR strings")
    func localizedTitleStringsNonEmpty() {
        for beat in StoryBeatCatalog.beats {
            guard let lt = beat.localizedTitle else { continue }
            #expect(!lt.es.isEmpty, "Beat '\(beat.id)' localizedTitle.es is empty")
            #expect(!lt.fr.isEmpty, "Beat '\(beat.id)' localizedTitle.fr is empty")
        }
    }

    @Test("Beats with localizedBody have non-empty ES and FR strings")
    func localizedBodyStringsNonEmpty() {
        for beat in StoryBeatCatalog.beats {
            guard let lb = beat.localizedBody else { continue }
            #expect(!lb.es.isEmpty, "Beat '\(beat.id)' localizedBody.es is empty")
            #expect(!lb.fr.isEmpty, "Beat '\(beat.id)' localizedBody.fr is empty")
        }
    }

    // MARK: 2. Once-Only Behavior

    @Test("A once-only beat appears in pendingAll() when unseen")
    func onceOnlyBeatAppearsWhenUnseen() {
        guard let beat = StoryBeatCatalog.beats.first(where: { $0.onceOnly }) else { return }
        // Already reset in init — beat must be unseen
        let results = StoryStore.pendingAll(for: beat.trigger)
        #expect(results.contains(where: { $0.id == beat.id }),
                "Once-only beat '\(beat.id)' must appear in pendingAll() when unseen")
    }

    @Test("A once-only beat does not appear in pendingAll() after markSeen()")
    func onceOnlyBeatDisappearsAfterSeen() {
        guard let beat = StoryBeatCatalog.beats.first(where: { $0.onceOnly }) else { return }
        StoryStore.markSeen(beat)
        let results = StoryStore.pendingAll(for: beat.trigger)
        #expect(!results.contains(where: { $0.id == beat.id }),
                "Once-only beat '\(beat.id)' must not reappear after markSeen()")
    }

    @Test("A once-only beat reappears in pendingAll() after markUnseen()")
    func onceOnlyBeatReappearsAfterUnseen() {
        guard let beat = StoryBeatCatalog.beats.first(where: { $0.onceOnly }) else { return }
        StoryStore.markSeen(beat)
        StoryStore.markUnseen(beat)
        let results = StoryStore.pendingAll(for: beat.trigger)
        #expect(results.contains(where: { $0.id == beat.id }),
                "Beat '\(beat.id)' must reappear in pendingAll() after markUnseen()")
    }

    @Test("markSeen is idempotent — calling it twice does not corrupt seenIDs")
    func markSeenIsIdempotent() {
        guard let beat = StoryBeatCatalog.beats.first else { return }
        StoryStore.markSeen(beat)
        StoryStore.markSeen(beat)   // second call must be a no-op
        #expect(StoryStore.isSeen(beat.id), "Beat must still be seen after double markSeen()")
        let count = StoryStore.seenIDs.filter { $0 == beat.id }.count
        #expect(count == 1, "seenIDs must not contain duplicate entries; found \(count)")
    }

    // MARK: 3. Queue Ordering

    @Test("pendingAll() returns beats in priority-ascending order")
    func pendingAllSortedByPriority() {
        for trigger in StoryTrigger.allCases {
            let beats = StoryStore.pendingAll(for: trigger)
            guard beats.count > 1 else { continue }
            let priorities = beats.map(\.priority)
            #expect(priorities == priorities.sorted(),
                    ".\(trigger.rawValue) beats are not sorted by priority: \(priorities)")
        }
    }

    @Test("pendingQueue() does not return the same once-only beat twice when trigger is repeated")
    func pendingQueueDeduplicatesOnceOnlyBeats() {
        // Feed the same trigger twice — a once-only beat may only fire once per queue evaluation
        guard let trigger = StoryTrigger.allCases.first(where: {
            StoryStore.pendingAll(for: $0).contains(where: { $0.onceOnly })
        }) else { return }

        let pairs: [(trigger: StoryTrigger, context: StoryContext)] = [
            (trigger, StoryContext()),
            (trigger, StoryContext()),
        ]
        let queue = StoryStore.pendingQueue(triggers: pairs)
        let onceOnlyIDs = queue.filter(\.onceOnly).map(\.id)
        let uniqueIDs   = Set(onceOnlyIDs)
        #expect(onceOnlyIDs.count == uniqueIDs.count,
                "pendingQueue() produced duplicate once-only beats: \(onceOnlyIDs)")
    }

    // MARK: 4. Persistence

    @Test("reset() clears all seen beats — isSeen returns false for every catalog beat")
    func resetClearsAllSeenBeats() {
        StoryStore.markAllSeen()
        StoryStore.reset()
        for beat in StoryBeatCatalog.beats {
            #expect(!StoryStore.isSeen(beat.id),
                    "Beat '\(beat.id)' must not be seen after reset()")
        }
    }

    @Test("markSeen persists — isSeen returns true immediately after marking")
    func markSeenPersistsToUserDefaults() {
        guard let beat = StoryBeatCatalog.beats.first else { return }
        StoryStore.markSeen(beat)
        #expect(StoryStore.isSeen(beat.id),
                "isSeen must return true immediately after markSeen('\(beat.id)')")
    }

    @Test("markAllSeen marks every catalog beat as seen")
    func markAllSeenCoversFullCatalog() {
        StoryStore.markAllSeen()
        for beat in StoryBeatCatalog.beats {
            #expect(StoryStore.isSeen(beat.id),
                    "Beat '\(beat.id)' must be seen after markAllSeen()")
        }
    }

    @Test("pendingAll() returns no once-only beats when markAllSeen() has been called")
    func noPendingOnceOnlyBeatsWhenAllSeen() {
        StoryStore.markAllSeen()
        for trigger in StoryTrigger.allCases {
            let onceOnly = StoryStore.pendingAll(for: trigger).filter(\.onceOnly)
            #expect(onceOnly.isEmpty,
                    ".\(trigger.rawValue): \(onceOnly.count) once-only beat(s) still pending after markAllSeen()")
        }
    }

    // MARK: 5. Localization Coverage

    @Test("displayTitle(for:) returns non-empty strings in EN, ES, and FR")
    func displayTitleNonEmptyAllLanguages() {
        for beat in StoryBeatCatalog.beats {
            #expect(!beat.displayTitle(for: .en).isEmpty, "Beat '\(beat.id)' EN title is empty")
            #expect(!beat.displayTitle(for: .es).isEmpty, "Beat '\(beat.id)' ES title is empty")
            #expect(!beat.displayTitle(for: .fr).isEmpty, "Beat '\(beat.id)' FR title is empty")
        }
    }

    @Test("displayBody(for:) returns non-empty strings in EN, ES, and FR")
    func displayBodyNonEmptyAllLanguages() {
        for beat in StoryBeatCatalog.beats {
            #expect(!beat.displayBody(for: .en).isEmpty, "Beat '\(beat.id)' EN body is empty")
            #expect(!beat.displayBody(for: .es).isEmpty, "Beat '\(beat.id)' ES body is empty")
            #expect(!beat.displayBody(for: .fr).isEmpty, "Beat '\(beat.id)' FR body is empty")
        }
    }

    @Test("Beats with localizedTitle display distinct strings in ES and FR vs EN")
    func localizedTitleDistinctPerLanguage() {
        for beat in StoryBeatCatalog.beats where beat.localizedTitle != nil {
            let en = beat.displayTitle(for: .en)
            #expect(beat.displayTitle(for: .es) != en,
                    "Beat '\(beat.id)' ES title matches EN — localizedTitle.es may be wrong")
            #expect(beat.displayTitle(for: .fr) != en,
                    "Beat '\(beat.id)' FR title matches EN — localizedTitle.fr may be wrong")
        }
    }

    @Test("Beats with localizedBody display distinct strings in ES and FR vs EN")
    func localizedBodyDistinctPerLanguage() {
        for beat in StoryBeatCatalog.beats where beat.localizedBody != nil {
            let en = beat.displayBody(for: .en)
            #expect(beat.displayBody(for: .es) != en,
                    "Beat '\(beat.id)' ES body matches EN — localizedBody.es may be wrong")
            #expect(beat.displayBody(for: .fr) != en,
                    "Beat '\(beat.id)' FR body matches EN — localizedBody.fr may be wrong")
        }
    }
}
