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

// MARK: - CustomTestStringConvertible conformances
// Provide human-readable test case names for parameterized tests.

extension Level: @retroactive CustomTestStringConvertible {
    public var testDescription: String { "L\(id) \(displayName)" }
}

extension LevelValidationReport: @retroactive CustomTestStringConvertible {
    public var testDescription: String { "L\(levelID)" }
}

extension StoryBeat: @retroactive CustomTestStringConvertible {
    public var testDescription: String { id }
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

    // ── Precomputed filtered collections for parameterized tests ──────────

    private static let nonEasyLevels: [Level] =
        levels.filter { $0.difficulty != .easy }
    private static let timedLevels: [Level] =
        levels.filter { $0.timeLimit != nil }
    private static let timedLevelsWithPositiveMoves: [Level] =
        levels.filter { $0.timeLimit != nil && $0.minimumRequiredMoves > 0 }
    private static let energySavingLevels: [Level] =
        levels.filter { $0.objectiveType == .energySaving }
    private static let maxCoverageLevels: [Level] =
        levels.filter { $0.objectiveType == .maxCoverage }

    private static let rotationCapReports: [LevelValidationReport] =
        reports.filter { $0.hasRotationCap }
    private static let rotationCapLevels: [Level] =
        levels.filter { level in reports.first(where: { $0.levelID == level.id })?.hasRotationCap == true }

    private static let autoDriftReports: [LevelValidationReport] =
        reports.filter { $0.hasAutoDrift }
    private static let autoDriftLevels: [Level] =
        levels.filter { level in reports.first(where: { $0.levelID == level.id })?.hasAutoDrift == true }

    private static let oneWayRelayReports: [LevelValidationReport] =
        reports.filter { $0.hasOneWayRelay }
    private static let oneWayRelayLevels: [Level] =
        levels.filter { level in reports.first(where: { $0.levelID == level.id })?.hasOneWayRelay == true }
    private static let earlyReportsForOneWay: [LevelValidationReport] =
        reports.filter { $0.levelID < 146 }

    private static let fragileTileReports: [LevelValidationReport] =
        reports.filter { $0.hasFragileTile }
    private static let fragileTileLevels: [Level] =
        levels.filter { level in reports.first(where: { $0.levelID == level.id })?.hasFragileTile == true }
    private static let earlyReportsForFragile: [LevelValidationReport] =
        reports.filter { $0.levelID < 151 }

    private static let chargeGateReports: [LevelValidationReport] =
        reports.filter { $0.hasChargeGate }
    private static let chargeGateLevels: [Level] =
        levels.filter { level in reports.first(where: { $0.levelID == level.id })?.hasChargeGate == true }
    private static let earlyReportsForChargeGate: [LevelValidationReport] =
        reports.filter { $0.levelID < 164 }

    private static let interferenceZoneReports: [LevelValidationReport] =
        reports.filter { $0.hasInterferenceZone }
    private static let earlyReportsForInterference: [LevelValidationReport] =
        reports.filter { $0.levelID < 171 }

    // MARK: - Baseline sanity

    /// Every level must have at least one source, the right number of targets,
    /// and a path of ≥ 3 tiles — the generator's own invariant.
    @Test("Level passes solvability heuristic", arguments: Self.reports)
    func levelPassesSolvabilityHeuristic(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): \(report.warnings.joined(separator: " | "))")
    }

    /// A zero buffer means the player must solve perfectly every time — no slack.
    @Test("Level has a positive move buffer", arguments: Self.levels)
    func levelHasPositiveBuffer(_ level: Level) {
        #expect(level.moveBuffer > 0,
                "L\(level.id): buffer=\(level.moveBuffer) (min=\(level.minimumRequiredMoves) max=\(level.maxMoves))")
    }

    /// Levels for medium tier and above should require meaningful effort.
    @Test("Non-easy level requires more than 1 move to solve", arguments: Self.nonEasyLevels)
    func nonEasyLevelHasMeaningfulMoves(_ level: Level) {
        #expect(level.minimumRequiredMoves > 1,
                "L\(level.id) [\(level.difficulty.fullLabel)]: minimumRequiredMoves=\(level.minimumRequiredMoves)")
    }

    // MARK: - Time limit mechanic

    /// A time limit under 30 s combined with any path length is punishing regardless of skill.
    @Test("Timed level has at least 30 seconds", arguments: Self.timedLevels)
    func timedLevelHasAtLeast30Seconds(_ level: Level) {
        guard let limit = level.timeLimit else { return }
        #expect(limit >= 30,
                "L\(level.id): time limit \(limit)s is too short for any realistic play")
    }

    /// Fewer than 2 s per minimum move makes a level reaction-based rather than puzzle-based.
    @Test("Timed level allows at least 2 seconds per minimum move", arguments: Self.timedLevelsWithPositiveMoves)
    func timedLevelAllows2SecondsPerMove(_ level: Level) {
        guard let limit = level.timeLimit, level.minimumRequiredMoves > 0 else { return }
        let ratio = Double(limit) / Double(level.minimumRequiredMoves)
        #expect(ratio >= 2.0,
                "L\(level.id): \(ratio)s/move (limit=\(limit)s min=\(level.minimumRequiredMoves))")
    }

    /// A timed level with a very small move buffer is a double-punishment:
    /// the player must be both fast AND perfect.
    @Test("Timed level has at least 3 buffer moves", arguments: Self.timedLevels)
    func timedLevelHasAtLeast3BufferMoves(_ level: Level) {
        #expect(level.moveBuffer >= 3,
                "L\(level.id): timed with only \(level.moveBuffer) buffer moves — time + tight buffer is unfair")
    }

    // MARK: - Rotation cap mechanic

    /// Capping rotations should add planning depth, not make the level unsolvable.
    @Test("Rotation-capped level passes solvability heuristic", arguments: Self.rotationCapReports)
    func rotationCapLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): rotationCap present but solvability heuristic failed")
    }

    /// With capped tiles the player can accidentally exhaust a tile's rotations;
    /// they need at least 2 buffer moves to recover or reroute.
    @Test("Rotation-capped level has at least 2 buffer moves", arguments: Self.rotationCapLevels)
    func rotationCapLevelHasAtLeast2BufferMoves(_ level: Level) {
        #expect(level.moveBuffer >= 2,
                "L\(level.id): rotationCap with only \(level.moveBuffer) buffer moves")
    }

    // MARK: - Auto-drift mechanic

    /// Drift tiles rotate automatically — the level must still be winnable
    /// before or after a drift event.
    @Test("Auto-drift level passes solvability heuristic", arguments: Self.autoDriftReports)
    func autoDriftLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): autoDrift present but solvability heuristic failed")
    }

    /// When a drift fires the player may need 1–2 corrective taps per drifted tile.
    /// A buffer under 4 makes the level unwinnable after a single bad drift event.
    @Test("Auto-drift level has at least 4 buffer moves", arguments: Self.autoDriftLevels)
    func autoDriftLevelHasAtLeast4BufferMoves(_ level: Level) {
        #expect(level.moveBuffer >= 4,
                "L\(level.id): autoDrift with only \(level.moveBuffer) buffer moves — a single drift event may make the level unwinnable")
    }

    // MARK: - energySaving objective

    /// If the limit equals or exceeds the total tile count it never applies pressure.
    @Test("energySaving limit is strictly less than total tile count", arguments: Self.energySavingLevels)
    func energySavingLimitIsConstraining(_ level: Level) {
        let total = level.gridSize * level.gridSize
        #expect(level.energySavingLimit < total,
                "L\(level.id): energySavingLimit=\(level.energySavingLimit) >= totalTiles=\(total) — win condition never activates")
    }

    /// The limit must be at least as large as the solution path or winning becomes impossible.
    @Test("energySaving limit is at least as large as the solution path", arguments: Self.energySavingLevels)
    func energySavingLimitIsAchievable(_ level: Level) {
        #expect(level.energySavingLimit >= level.solutionPathLength,
                "L\(level.id): energySavingLimit=\(level.energySavingLimit) < solutionPathLength=\(level.solutionPathLength) — level is impossible to win")
    }

    /// When the limit covers more than 80 % of the grid, virtually any solution satisfies it —
    /// the objective provides no strategic constraint.
    @Test("energySaving limit covers at most 80% of the grid", arguments: Self.energySavingLevels)
    func energySavingObjectiveRequiresStrategy(_ level: Level) {
        let total = level.gridSize * level.gridSize
        let threshold = Int((Double(total) * 0.80).rounded(.up))
        #expect(level.energySavingLimit <= threshold,
                "L\(level.id): energySavingLimit=\(level.energySavingLimit) > 80% of grid (\(threshold)) — objective is trivially satisfied by any valid solution")
    }

    // MARK: - One-way relay mechanic

    /// Levels without one-way relay must not inadvertently carry the property.
    @Test("One-way relay is absent before level ID 146", arguments: Self.earlyReportsForOneWay)
    func oneWayRelayAbsentBeforeThreshold(_ report: LevelValidationReport) {
        #expect(!report.hasOneWayRelay,
                "L\(report.levelID): oneWayRelay unexpectedly applied before threshold (id < 146)")
    }

    @Test("One-way relay level passes solvability heuristic", arguments: Self.oneWayRelayReports)
    func oneWayRelayLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): oneWayRelay present but solvability heuristic failed")
    }

    /// The one-way constraint adds orientation complexity; at least 3 buffer moves
    /// ensures the player can recover from routing the signal in the wrong direction.
    @Test("One-way relay level has at least 3 buffer moves", arguments: Self.oneWayRelayLevels)
    func oneWayRelayLevelHasAdequateBuffer(_ level: Level) {
        #expect(level.moveBuffer >= 3,
                "L\(level.id): oneWayRelay with only \(level.moveBuffer) buffer moves")
    }

    // MARK: - maxCoverage objective

    /// If the solution path already covers ≥ 85 % of the grid, extending coverage further
    /// requires almost no extra effort — the objective distinction is meaningless.
    @Test("maxCoverage solution path leaves at least 15% of the grid for bonus coverage", arguments: Self.maxCoverageLevels)
    func maxCoverageObjectiveHasMeaningfulRoom(_ level: Level) {
        let total = level.gridSize * level.gridSize
        let pathRatio = Float(level.solutionPathLength) / Float(total)
        #expect(pathRatio <= 0.85,
                "L\(level.id): maxCoverage solution path covers \(Int(pathRatio * 100))% of grid — coverage bonus is trivially achieved alongside the base objective")
    }

    // MARK: - Fragile tile mechanic

    @Test("Fragile tile is absent before level ID 151", arguments: Self.earlyReportsForFragile)
    func fragileTileAbsentBeforeThreshold(_ report: LevelValidationReport) {
        #expect(!report.hasFragileTile,
                "L\(report.levelID): fragileTile unexpectedly present before threshold (id < 151)")
    }

    @Test("Fragile tile level passes solvability heuristic", arguments: Self.fragileTileReports)
    func fragileTileLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): fragileTile present but solvability heuristic failed")
    }

    /// Fragile tiles burn after 3 energized turns, so the player needs slack to recover
    /// routing if they accidentally burned a tile. At least 3 buffer moves is the minimum.
    @Test("Fragile tile level has at least 3 buffer moves", arguments: Self.fragileTileLevels)
    func fragileTileLevelHasAdequateBuffer(_ level: Level) {
        #expect(level.moveBuffer >= 3,
                "L\(level.id): fragileTile with only \(level.moveBuffer) buffer moves — player has no recovery slack after burn-out")
    }

    // MARK: - Charge gate mechanic

    @Test("Charge gate is absent before level ID 164", arguments: Self.earlyReportsForChargeGate)
    func chargeGateAbsentBeforeThreshold(_ report: LevelValidationReport) {
        #expect(!report.hasChargeGate,
                "L\(report.levelID): chargeGate unexpectedly present before threshold (id < 164)")
    }

    @Test("Charge gate level passes solvability heuristic", arguments: Self.chargeGateReports)
    func chargeGateLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): chargeGate present but solvability heuristic failed")
    }

    /// The gate requires 2 charge cycles (+1 to minMoves). The player also needs
    /// buffer to explore routing paths before the gate opens.
    @Test("Charge gate level has at least 3 buffer moves", arguments: Self.chargeGateLevels)
    func chargeGateLevelHasAdequateBuffer(_ level: Level) {
        #expect(level.moveBuffer >= 3,
                "L\(level.id): chargeGate with only \(level.moveBuffer) buffer moves — player may run out while waiting for the gate to open")
    }

    // MARK: - Interference zone mechanic

    @Test("Interference zone is absent before level ID 171", arguments: Self.earlyReportsForInterference)
    func interferenceZoneAbsentBeforeThreshold(_ report: LevelValidationReport) {
        #expect(!report.hasInterferenceZone,
                "L\(report.levelID): interferenceZone unexpectedly present before threshold (id < 171)")
    }

    @Test("Interference zone level passes solvability heuristic", arguments: Self.interferenceZoneReports)
    func interferenceZoneLevelIsSolvable(_ report: LevelValidationReport) {
        #expect(report.isSolvable,
                "L\(report.levelID): interferenceZone present but solvability heuristic failed")
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
// All tests reference EntitlementStore.freeIntroLimit and .dailyLimit — never hardcoded values.
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
    private var introLimit: Int { EntitlementStore.freeIntroLimit }
    private var dailyLimit: Int { EntitlementStore.dailyLimit }

    // ── Product constants ─────────────────────────────────────────────────

    @Test("freeIntroLimit == 8 and dailyLimit == 3")
    func entitlementLimitsAreCorrect() {
        #expect(introLimit == 8)
        #expect(dailyLimit == 3)
    }

    @Test("Product limits are positive and intro > daily (design invariant)")
    func productLimitsAreValid() {
        #expect(introLimit > 0, "freeIntroLimit must be positive")
        #expect(dailyLimit > 0, "dailyLimit must be positive")
        #expect(introLimit > dailyLimit,
                "Intro phase must be more generous than daily window")
    }

    // ── Intro phase boundaries ────────────────────────────────────────────

    @Test("Intro: at 0 sessions — canPlay, isInIntroPhase, remainingToday == freeIntroLimit")
    func introAt0() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(0)
        #expect(s.canPlay(anyLevel))
        #expect(s.isInIntroPhase)
        #expect(s.remainingToday == introLimit)
        #expect(!s.dailyLimitReached)
        #expect(s.reasonBlocked == nil)
    }

    @Test("Intro: mid-phase — canPlay, isInIntroPhase, remainingToday decremented")
    func introMidPhase() {
        let s = EntitlementStore.shared
        let mid = introLimit / 2
        s.setFreeIntroCompleted(mid)
        #expect(s.canPlay(anyLevel))
        #expect(s.isInIntroPhase)
        #expect(s.remainingToday == introLimit - mid)
    }

    @Test("Intro: just before limit (freeIntroLimit - 1) — canPlay, isInIntroPhase, remainingToday == 1")
    func introJustBeforeLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit - 1)
        #expect(s.canPlay(anyLevel))
        #expect(s.isInIntroPhase)
        #expect(s.remainingToday == 1)
    }

    @Test("Intro → Phase 2 transition: exactly at freeIntroLimit flips isInIntroPhase to false")
    func introExactlyAtLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit - 1)
        #expect(s.isInIntroPhase, "One below must still be intro")

        s.setFreeIntroCompleted(introLimit)
        #expect(!s.isInIntroPhase, "At freeIntroLimit must not be intro")
    }

    // ── Phase 2 boundaries ────────────────────────────────────────────────

    @Test("Phase 2: fresh window (0 daily used) — canPlay, remainingToday == dailyLimit")
    func phase2FreshWindow() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        #expect(s.canPlay(anyLevel))
        #expect(s.remainingToday == dailyLimit)
        #expect(!s.dailyLimitReached)
        #expect(s.reasonBlocked == nil)
    }

    @Test("Phase 2: 1 daily play used — canPlay, remainingToday == dailyLimit - 1")
    func phase2OneDailyUsed() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(1)
        #expect(s.canPlay(anyLevel))
        #expect(s.remainingToday == dailyLimit - 1)
        #expect(!s.dailyLimitReached)
    }

    @Test("Phase 2: just before daily limit — canPlay, remainingToday == 1")
    func phase2JustBeforeDailyLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit - 1)
        #expect(s.canPlay(anyLevel))
        #expect(s.remainingToday == 1)
        #expect(!s.dailyLimitReached)
    }

    @Test("Phase 2: exactly at daily limit — blocked, cooldown armed, remainingToday == 0")
    func phase2ExactlyAtDailyLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)   // arms cooldown
        #expect(!s.canPlay(anyLevel), "Must be blocked")
        #expect(s.dailyLimitReached, "dailyLimitReached must be true")
        #expect(s.reasonBlocked != nil, "Must have a block reason")
        #expect(s.remainingToday == 0, "No plays remaining")
    }

    // ── Premium bypass ────────────────────────────────────────────────────

    @Test("Premium: always allowed even with worst-case free state")
    func premiumAlwaysAllowed() {
        let s = EntitlementStore.shared
        s.setPremium(true)
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)   // arm cooldown
        defer { s.setPremium(false) }

        #expect(s.canPlay(anyLevel), "Premium must always play")
        #expect(!s.dailyLimitReached, "dailyLimitReached must be false for premium")
        #expect(s.reasonBlocked == nil, "reasonBlocked must be nil for premium")
        #expect(s.remainingToday == Int.max, "remainingToday must be Int.max for premium")
    }

    // ── dailyAttemptsUsed derived property ────────────────────────────────

    @Test("dailyAttemptsUsed returns 0 during intro phase (regardless of raw counter)")
    func dailyAttemptsUsedZeroDuringIntro() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(0)
        #expect(s.dailyAttemptsUsed == 0,
                "During intro phase dailyAttemptsUsed must report 0")
    }

    @Test("dailyAttemptsUsed returns 0 for premium (regardless of raw counter)")
    func dailyAttemptsUsedZeroForPremium() {
        let s = EntitlementStore.shared
        s.setPremium(true)
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit - 1)
        defer { s.setPremium(false) }
        #expect(s.dailyAttemptsUsed == 0,
                "Premium dailyAttemptsUsed must report 0")
    }

    @Test("dailyAttemptsUsed returns actual count in Phase 2")
    func dailyAttemptsUsedReflectsPhase2Counter() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit - 1)
        #expect(s.dailyAttemptsUsed == dailyLimit - 1)
    }
}

// MARK: - EntitlementStore Consumption Tests
// Validates when each counter is incremented, and when it must stay unchanged.
// Covers: win, fail, retry sequence, no-interaction, premium no-op, cooldown no-op.
@Suite("EntitlementStore — Counter Consumption", .serialized)
@MainActor
struct EntitlementConsumptionTests {

    init() {
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetIntroCount()
        EntitlementStore.shared.resetDailyCount()
    }

    private var anyLevel: Level { LevelGenerator.levels[0] }
    private var introLimit: Int { EntitlementStore.freeIntroLimit }
    private var dailyLimit: Int { EntitlementStore.dailyLimit }

    // ── canPlay is read-only ──────────────────────────────────────────────

    @Test("canPlay does not increment any counter (intro phase)")
    func canPlayDoesNotConsumeIntro() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(2)
        let before = s.freeIntroCompleted
        _ = s.canPlay(anyLevel)
        #expect(s.freeIntroCompleted == before, "canPlay must never mutate intro counter")
    }

    @Test("canPlay does not increment any counter (Phase 2)")
    func canPlayDoesNotConsumePhase2() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(1)
        let before = s.dailyAttemptsUsed
        _ = s.canPlay(anyLevel)
        #expect(s.dailyAttemptsUsed == before, "canPlay must never mutate daily counter")
    }

    // ── Intro phase: both WON and FAILED consume a slot ──────────────────

    @Test("Win mid-intro increments freeIntroCompleted by 1")
    func winMidIntroIncrements() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(1)
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.freeIntroCompleted == 2)
        #expect(s.dailyAttemptsUsed == 0, "Daily must not change during intro")
    }

    @Test("Fail mid-intro also increments freeIntroCompleted by 1")
    func failMidIntroIncrements() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(1)
        s.recordAttempt(anyLevel, didWin: false)
        #expect(s.freeIntroCompleted == 2,
                "Both wins and fails consume an intro slot")
        #expect(s.dailyAttemptsUsed == 0, "Daily must not change during intro")
    }

    @Test("Last intro session via WIN exhausts phase and arms cooldown")
    func lastIntroWinArmsCooldown() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit - 1)
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.freeIntroCompleted == introLimit)
        #expect(!s.isInIntroPhase)
        #expect(s.dailyLimitReached, "Cooldown must arm after intro exhaustion")
    }

    @Test("Last intro session via FAIL also exhausts phase and arms cooldown")
    func lastIntroFailArmsCooldown() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit - 1)
        s.recordAttempt(anyLevel, didWin: false)
        #expect(s.freeIntroCompleted == introLimit)
        #expect(!s.isInIntroPhase)
        #expect(s.dailyLimitReached, "Cooldown must arm on fail too")
    }

    @Test("Intro counter is clamped at freeIntroLimit (overflow protection)")
    func introCounterClampedAtLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        // Already at limit — recordAttempt should take the Phase 2 path,
        // which means intro counter stays at freeIntroLimit.
        s.setDailyAttemptsUsed(0)   // ensure we can play in Phase 2
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.freeIntroCompleted == introLimit,
                "Intro counter must never exceed freeIntroLimit")
    }

    // ── Phase 2: daily plays ──────────────────────────────────────────────

    @Test("Phase 2: win increments daily counter")
    func phase2WinIncrements() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.dailyAttemptsUsed == 1)
        #expect(s.freeIntroCompleted == introLimit, "Intro must not change in Phase 2")
    }

    @Test("Phase 2: fail increments daily counter")
    func phase2FailIncrements() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        s.recordAttempt(anyLevel, didWin: false)
        #expect(s.dailyAttemptsUsed == 1)
        #expect(s.freeIntroCompleted == introLimit, "Intro must not change in Phase 2")
    }

    @Test("Phase 2: arms cooldown exactly at dailyLimit plays")
    func phase2ArmsCooldownAtLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        for i in 0..<dailyLimit {
            #expect(s.canPlay(anyLevel), "Play \(i+1)/\(dailyLimit) should be allowed")
            s.recordAttempt(anyLevel, didWin: i % 2 == 0)
        }
        #expect(s.dailyAttemptsUsed == dailyLimit)
        #expect(s.dailyLimitReached, "Cooldown must arm after all daily plays consumed")
        #expect(!s.canPlay(anyLevel), "Must be blocked after dailyLimit plays")
    }

    @Test("Phase 2: just before daily limit — still allowed")
    func phase2JustBeforeDailyLimit() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        for _ in 0..<(dailyLimit - 1) {
            s.recordAttempt(anyLevel, didWin: false)
        }
        #expect(s.canPlay(anyLevel),
                "Player must still be able to play with 1 daily slot remaining")
        #expect(s.remainingToday == 1)
    }

    @Test("Phase 2: recordAttempt during active cooldown is a no-op")
    func phase2RecordAttemptDuringCooldownIsNoOp() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)   // arm cooldown
        let dailyBefore = s.dailyPlaysUsed
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.dailyPlaysUsed == dailyBefore,
                "recordAttempt during active cooldown must not increment the counter")
    }

    // ── Retry sequence ────────────────────────────────────────────────────

    @Test("Phase 2 full retry sequence: fail → retry → fail → retry → win → blocked")
    func phase2RetrySequence() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)

        // Play 1: fail
        s.recordAttempt(anyLevel, didWin: false)
        #expect(s.canPlay(anyLevel), "After 1/\(dailyLimit) fails — must still be allowed")

        // Play 2: fail again
        s.recordAttempt(anyLevel, didWin: false)
        if dailyLimit > 2 {
            #expect(s.canPlay(anyLevel), "After 2/\(dailyLimit) fails — must still be allowed")
        }

        // Play 3 (dailyLimit): win
        s.recordAttempt(anyLevel, didWin: true)
        #expect(!s.canPlay(anyLevel),
                "After \(dailyLimit)/\(dailyLimit) plays — must be blocked regardless of outcome")
    }

    // ── No-interaction contract ───────────────────────────────────────────
    // GameView only calls recordAttempt if the player made ≥1 tap (hasInteracted).
    // If the player opens a mission but abandons without tapping, nothing is consumed.

    @Test("No-interaction during intro: counters unchanged if recordAttempt is never called")
    func noInteractionIntroPhase() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(3)
        let introBefore = s.freeIntroCompleted
        // Simulate: player opens mission, views board, taps BACK without interacting
        // — GameView does NOT call recordAttempt
        #expect(s.freeIntroCompleted == introBefore)
        #expect(s.canPlay(anyLevel), "Player must be able to immediately re-enter")
    }

    @Test("No-interaction during Phase 2: counters unchanged if recordAttempt is never called")
    func noInteractionPhase2() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        let dailyBefore = s.dailyAttemptsUsed
        // — GameView does NOT call recordAttempt
        #expect(s.dailyAttemptsUsed == dailyBefore)
        #expect(s.canPlay(anyLevel), "Player must be able to immediately re-enter")
    }

    // ── Premium no-op ─────────────────────────────────────────────────────

    @Test("Premium: recordAttempt is a no-op in intro phase")
    func premiumNoOpIntro() {
        let s = EntitlementStore.shared
        s.setPremium(true)
        s.setFreeIntroCompleted(2)
        let before = s.freeIntroCompleted
        defer { s.setPremium(false) }
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.freeIntroCompleted == before)
    }

    @Test("Premium: recordAttempt is a no-op in Phase 2")
    func premiumNoOpPhase2() {
        let s = EntitlementStore.shared
        s.setPremium(true)
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        let dailyBefore = s.dailyAttemptsUsed
        defer { s.setPremium(false) }
        s.recordAttempt(anyLevel, didWin: false)
        #expect(s.dailyAttemptsUsed == dailyBefore)
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

    // ── Precomputed filtered collections ──────────────────────────────────

    private static let beatsWithLocalizedTitle: [StoryBeat] =
        StoryBeatCatalog.beats.filter { $0.localizedTitle != nil }
    private static let beatsWithLocalizedBody: [StoryBeat] =
        StoryBeatCatalog.beats.filter { $0.localizedBody != nil }
    private static let allMechanics: [MechanicType] = [
        .rotationCap, .overloaded, .timeLimit, .autoDrift,
        .oneWayRelay, .fragileTile, .chargeGate, .interferenceZone,
    ]

    // ── Trigger labels ─────────────────────────────────────────────────────

    @Test("StoryTrigger badge label is localized for ES and FR", arguments: StoryTrigger.allCases)
    func storyTriggerLabelIsLocalized(_ trigger: StoryTrigger) {
        let enLabel = en.storyTriggerLabel(trigger)
        #expect(es.storyTriggerLabel(trigger) != enLabel,
                "ES trigger label for .\(trigger) matches EN — translation missing")
        #expect(fr.storyTriggerLabel(trigger) != enLabel,
                "FR trigger label for .\(trigger) matches EN — translation missing")
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

    @Test("Footer hint is translated for ES — not left in English", arguments: Self.representativeHints)
    func footerHintLocalizedES(_ hint: String) {
        #expect(es.storyFooterHint(hint) != hint,
                "ES footer hint '\(hint)' is still English — add translation to storyFooterHint(_:)")
    }

    @Test("Footer hint is translated for FR — not left in English", arguments: Self.representativeHints)
    func footerHintLocalizedFR(_ hint: String) {
        #expect(fr.storyFooterHint(hint) != hint,
                "FR footer hint '\(hint)' is still English — add translation to storyFooterHint(_:)")
    }

    @Test("Unknown footer hint falls back to the original string without crashing")
    func unknownFooterHintFallsBack() {
        let unknown = "SOME_UNKNOWN_STATUS_XYZ"
        #expect(es.storyFooterHint(unknown) == unknown)
        #expect(fr.storyFooterHint(unknown) == unknown)
    }

    // ── Beat catalog ───────────────────────────────────────────────────────

    @Test("Beat with localizedTitle displays a distinct ES title", arguments: Self.beatsWithLocalizedTitle)
    func beatLocalizedTitleShowsESTitle(_ beat: StoryBeat) {
        #expect(beat.displayTitle(for: .es) != beat.displayTitle(for: .en),
                "Beat '\(beat.id)': ES title matches EN — localizedTitle.es may be missing")
    }

    @Test("Beat with localizedBody displays a distinct ES body", arguments: Self.beatsWithLocalizedBody)
    func beatLocalizedBodyShowsESBody(_ beat: StoryBeat) {
        #expect(beat.displayBody(for: .es) != beat.displayBody(for: .en),
                "Beat '\(beat.id)': ES body matches EN — localizedBody.es may be missing")
    }

    @Test("Beat with localizedBody displays a distinct FR body", arguments: Self.beatsWithLocalizedBody)
    func beatLocalizedBodyShowsFRBody(_ beat: StoryBeat) {
        #expect(beat.displayBody(for: .fr) != beat.displayBody(for: .en),
                "Beat '\(beat.id)': FR body matches EN — localizedBody.fr may be missing")
    }

    // ── Mechanic strings ───────────────────────────────────────────────────

    @Test("Mechanic title is localized for ES and FR", arguments: Self.allMechanics)
    func mechanicTitleIsLocalized(_ mechanic: MechanicType) {
        let enTitle = en.mechanicTitle(mechanic)
        #expect(es.mechanicTitle(mechanic) != enTitle,
                "ES mechanic title for .\(mechanic) matches EN — not localized")
        #expect(fr.mechanicTitle(mechanic) != enTitle,
                "FR mechanic title for .\(mechanic) matches EN — not localized")
    }

    @Test("Mechanic body message is localized for ES and FR", arguments: Self.allMechanics)
    func mechanicMessageIsLocalized(_ mechanic: MechanicType) {
        let enMsg = en.mechanicMessage(mechanic)
        #expect(es.mechanicMessage(mechanic) != enMsg,
                "ES mechanic message for .\(mechanic) matches EN — not localized")
        #expect(fr.mechanicMessage(mechanic) != enMsg,
                "FR mechanic message for .\(mechanic) matches EN — not localized")
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
// Tests cooldown timing, reset paths, daily counter reset, and canPlayNextMission.
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
    private var introLimit: Int { EntitlementStore.freeIntroLimit }
    private var dailyLimit: Int { EntitlementStore.dailyLimit }

    // MARK: remainingCooldown

    @Test("remainingCooldown is 0 when no cooldown is active")
    func remainingCooldownZeroWhenFree() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(0)
        #expect(s.remainingCooldown == 0)
    }

    @Test("remainingCooldown is 0 during intro phase (cooldown is irrelevant)")
    func remainingCooldownZeroDuringIntro() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(0)
        #expect(s.remainingCooldown == 0)
    }

    @Test("remainingCooldown is > 0 immediately after cooldown is armed")
    func remainingCooldownPositiveWhenArmed() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)
        #expect(s.remainingCooldown > 0,
                "remainingCooldown must be positive while the 24h gate is active")
    }

    @Test("remainingCooldown approaches 24h (86400s) right after arming")
    func remainingCooldownNear24h() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)
        let remaining = s.remainingCooldown
        // Allow ±5 s tolerance for clock jitter in CI
        #expect(remaining > 86_390 && remaining <= 86_400,
                "Immediately after arming, remaining cooldown must be ~86400s, got \(remaining)s")
    }

    // MARK: canPlayNextMission

    @Test("canPlayNextMission returns true when no cooldown and next level exists")
    func canPlayNextMissionTrueWhenAllowed() {
        let levels = LevelGenerator.levels
        guard levels.count >= 2 else { return }
        let first = levels[0]
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(0)   // intro phase — always allowed
        #expect(s.canPlayNextMission(after: first),
                "canPlayNextMission must return true when player can play")
    }

    @Test("canPlayNextMission returns false during cooldown")
    func canPlayNextMissionFalseWhenBlocked() {
        let levels = LevelGenerator.levels
        guard levels.count >= 2 else { return }
        let first = levels[0]
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)
        #expect(!s.canPlayNextMission(after: first),
                "canPlayNextMission must return false when the 24h gate is active")
    }

    @Test("canPlayNextMission returns false for the last level (no next exists)")
    func canPlayNextMissionFalseForLastLevel() {
        let last = LevelGenerator.levels.last!
        let s = EntitlementStore.shared
        s.setPremium(true)
        defer { s.setPremium(false) }
        #expect(!s.canPlayNextMission(after: last),
                "canPlayNextMission must return false when no subsequent level exists")
    }

    // MARK: forceCooldown / clearCooldown

    @Test("forceCooldown promotes to Phase 2 and blocks canPlay")
    func forceCooldownBlocksPlay() {
        let s = EntitlementStore.shared
        s.forceCooldown()
        #expect(!s.isInIntroPhase, "forceCooldown must promote to Phase 2")
        #expect(!s.canPlay(anyLevel))
        #expect(s.dailyLimitReached)
    }

    @Test("clearCooldown unblocks play and resets daily counter to 0")
    func clearCooldownUnblocksAndResets() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)
        s.clearCooldown()
        #expect(s.canPlay(anyLevel), "Must be playable after clearCooldown")
        #expect(!s.dailyLimitReached)
        #expect(s.remainingCooldown == 0)
        #expect(s.dailyAttemptsUsed == 0, "Daily counter must reset to 0 after clearCooldown")
        #expect(s.remainingToday == dailyLimit, "Full daily quota must be restored")
    }

    @Test("setFreeIntroCompleted below freeIntroLimit returns to intro and clears cooldown")
    func setIntroCompletedBelowLimitClearsCooldown() {
        let s = EntitlementStore.shared
        s.forceCooldown()
        s.setFreeIntroCompleted(1)
        #expect(s.isInIntroPhase, "Must be back in intro phase")
        #expect(s.canPlay(anyLevel), "Must be playable")
        #expect(s.remainingToday == introLimit - 1, "remainingToday must reflect intro quota")
    }

    @Test("resetIntroCount returns to Phase 1 at 0 and clears cooldown")
    func resetIntroCountFullReset() {
        let s = EntitlementStore.shared
        s.forceCooldown()
        s.resetIntroCount()
        #expect(s.freeIntroCompleted == 0)
        #expect(s.isInIntroPhase)
        #expect(s.canPlay(anyLevel))
        #expect(s.remainingToday == introLimit)
    }

    @Test("clearCooldown after intro exhaustion allows a fresh daily window")
    func clearCooldownAfterIntroExhaustionAllowsFreshWindow() {
        let s = EntitlementStore.shared
        s.setFreeIntroCompleted(introLimit)
        s.setDailyAttemptsUsed(dailyLimit)   // arm
        #expect(!s.canPlay(anyLevel))

        s.clearCooldown()
        #expect(s.canPlay(anyLevel))

        // Can now consume a full daily window
        s.recordAttempt(anyLevel, didWin: true)
        #expect(s.dailyAttemptsUsed == 1)
        #expect(s.canPlay(anyLevel), "Only 1/\(dailyLimit) used — still allowed")
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
        // lastSubmittedScore is only set inside submitScore(_:).
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

    // ── Precomputed filtered collections ──────────────────────────────────

    private static let beatsWithLocalizedTitle: [StoryBeat] =
        StoryBeatCatalog.beats.filter { $0.localizedTitle != nil }
    private static let beatsWithLocalizedBody: [StoryBeat] =
        StoryBeatCatalog.beats.filter { $0.localizedBody != nil }

    // MARK: 1. Catalog Integrity

    @Test("All beat IDs are unique")
    func beatIDsAreUnique() {
        let ids = StoryBeatCatalog.beats.map(\.id)
        let duplicates = ids.filter { id in ids.filter { $0 == id }.count > 1 }
        #expect(duplicates.isEmpty,
                "Duplicate beat IDs found: \(Set(duplicates).sorted().joined(separator: ", "))")
    }

    @Test("Beat has non-empty ID, title, body, and source", arguments: StoryBeatCatalog.beats)
    func beatMandatoryFieldsNonEmpty(_ beat: StoryBeat) {
        #expect(!beat.id.isEmpty,     "Beat has empty id")
        #expect(!beat.title.isEmpty,  "Beat '\(beat.id)' has empty title")
        #expect(!beat.body.isEmpty,   "Beat '\(beat.id)' has empty body")
        #expect(!beat.source.isEmpty, "Beat '\(beat.id)' has empty source")
    }

    @Test("Beat has a valid StoryTrigger", arguments: StoryBeatCatalog.beats)
    func beatHasValidTrigger(_ beat: StoryBeat) {
        let valid = Set(StoryTrigger.allCases)
        #expect(valid.contains(beat.trigger),
                "Beat '\(beat.id)' has unknown trigger '\(beat.trigger.rawValue)'")
    }

    @Test("Beat with localizedTitle has non-empty ES and FR strings", arguments: Self.beatsWithLocalizedTitle)
    func localizedTitleStringsNonEmpty(_ beat: StoryBeat) {
        let lt = beat.localizedTitle!
        #expect(!lt.es.isEmpty, "Beat '\(beat.id)' localizedTitle.es is empty")
        #expect(!lt.fr.isEmpty, "Beat '\(beat.id)' localizedTitle.fr is empty")
    }

    @Test("Beat with localizedBody has non-empty ES and FR strings", arguments: Self.beatsWithLocalizedBody)
    func localizedBodyStringsNonEmpty(_ beat: StoryBeat) {
        let lb = beat.localizedBody!
        #expect(!lb.es.isEmpty, "Beat '\(beat.id)' localizedBody.es is empty")
        #expect(!lb.fr.isEmpty, "Beat '\(beat.id)' localizedBody.fr is empty")
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

    @Test("pendingAll() returns beats in priority-ascending order", arguments: StoryTrigger.allCases)
    func pendingAllSortedByPriority(_ trigger: StoryTrigger) {
        let beats = StoryStore.pendingAll(for: trigger)
        guard beats.count > 1 else { return }
        let priorities = beats.map(\.priority)
        #expect(priorities == priorities.sorted(),
                ".\(trigger.rawValue) beats are not sorted by priority: \(priorities)")
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

    @Test("reset() clears all seen beats — isSeen returns false for every catalog beat", arguments: StoryBeatCatalog.beats)
    func resetClearsSeenBeat(_ beat: StoryBeat) {
        StoryStore.markAllSeen()
        StoryStore.reset()
        #expect(!StoryStore.isSeen(beat.id),
                "Beat '\(beat.id)' must not be seen after reset()")
    }

    @Test("markSeen persists — isSeen returns true immediately after marking")
    func markSeenPersistsToUserDefaults() {
        guard let beat = StoryBeatCatalog.beats.first else { return }
        StoryStore.markSeen(beat)
        #expect(StoryStore.isSeen(beat.id),
                "isSeen must return true immediately after markSeen('\(beat.id)')")
    }

    @Test("markAllSeen marks every catalog beat as seen", arguments: StoryBeatCatalog.beats)
    func markAllSeenCoversBeat(_ beat: StoryBeat) {
        StoryStore.markAllSeen()
        #expect(StoryStore.isSeen(beat.id),
                "Beat '\(beat.id)' must be seen after markAllSeen()")
    }

    @Test("pendingAll() returns no once-only beats when markAllSeen() has been called", arguments: StoryTrigger.allCases)
    func noPendingOnceOnlyBeatsForTrigger(_ trigger: StoryTrigger) {
        StoryStore.markAllSeen()
        let onceOnly = StoryStore.pendingAll(for: trigger).filter(\.onceOnly)
        #expect(onceOnly.isEmpty,
                ".\(trigger.rawValue): \(onceOnly.count) once-only beat(s) still pending after markAllSeen()")
    }

    // MARK: 5. Localization Coverage

    @Test("displayTitle(for:) returns non-empty strings in EN, ES, and FR", arguments: StoryBeatCatalog.beats)
    func displayTitleNonEmptyAllLanguages(_ beat: StoryBeat) {
        #expect(!beat.displayTitle(for: .en).isEmpty, "Beat '\(beat.id)' EN title is empty")
        #expect(!beat.displayTitle(for: .es).isEmpty, "Beat '\(beat.id)' ES title is empty")
        #expect(!beat.displayTitle(for: .fr).isEmpty, "Beat '\(beat.id)' FR title is empty")
    }

    @Test("displayBody(for:) returns non-empty strings in EN, ES, and FR", arguments: StoryBeatCatalog.beats)
    func displayBodyNonEmptyAllLanguages(_ beat: StoryBeat) {
        #expect(!beat.displayBody(for: .en).isEmpty, "Beat '\(beat.id)' EN body is empty")
        #expect(!beat.displayBody(for: .es).isEmpty, "Beat '\(beat.id)' ES body is empty")
        #expect(!beat.displayBody(for: .fr).isEmpty, "Beat '\(beat.id)' FR body is empty")
    }

    @Test("Beat with localizedTitle displays distinct strings in ES and FR vs EN", arguments: Self.beatsWithLocalizedTitle)
    func localizedTitleDistinctPerLanguage(_ beat: StoryBeat) {
        let enTitle = beat.displayTitle(for: .en)
        #expect(beat.displayTitle(for: .es) != enTitle,
                "Beat '\(beat.id)' ES title matches EN — localizedTitle.es may be wrong")
        #expect(beat.displayTitle(for: .fr) != enTitle,
                "Beat '\(beat.id)' FR title matches EN — localizedTitle.fr may be wrong")
    }

    @Test("Beat with localizedBody displays distinct strings in ES and FR vs EN", arguments: Self.beatsWithLocalizedBody)
    func localizedBodyDistinctPerLanguage(_ beat: StoryBeat) {
        let enBody = beat.displayBody(for: .en)
        #expect(beat.displayBody(for: .es) != enBody,
                "Beat '\(beat.id)' ES body matches EN — localizedBody.es may be wrong")
        #expect(beat.displayBody(for: .fr) != enBody,
                "Beat '\(beat.id)' FR body matches EN — localizedBody.fr may be wrong")
    }
}

// MARK: - CloudSaveManager Merge Tests
// Verifies that mergeProfiles is monotonic — a merge never downgrades progress.

@Suite("CloudSave Merge — Per-Level Efficiency")
struct CloudSaveMergeEfficiencyTests {

    // MARK: bestEfficiencyByLevel

    @Test("Better local best-efficiency wins over worse cloud")
    func betterLocalBestEfficiency() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.5, "2": 0.8]
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["1": 0.9, "2": 0.3]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel["1"] == 0.9, "Local 0.9 should beat cloud 0.5")
        #expect(cloud.bestEfficiencyByLevel["2"] == 0.8, "Cloud 0.8 should beat local 0.3")
    }

    @Test("Better cloud best-efficiency is retained")
    func betterCloudBestEfficiency() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.95]
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["1": 0.60]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel["1"] == 0.95, "Cloud 0.95 should remain")
    }

    @Test("Missing local levels are kept from cloud")
    func missingLocalBestEfficiency() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["5": 0.7]
        let local = AstronautProfile() // no entries

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel["5"] == 0.7, "Cloud-only level preserved")
    }

    @Test("Missing cloud levels are added from local")
    func missingCloudBestEfficiency() {
        var cloud = AstronautProfile() // no entries
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["10": 0.85]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel["10"] == 0.85, "Local-only level added to cloud")
    }

    // MARK: lastEfficiencyByLevel

    @Test("Better local last-efficiency wins over worse cloud")
    func betterLocalLastEfficiency() {
        var cloud = AstronautProfile()
        cloud.lastEfficiencyByLevel = ["1": 0.4, "2": 0.9]
        var local = AstronautProfile()
        local.lastEfficiencyByLevel = ["1": 0.8, "2": 0.3]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.lastEfficiencyByLevel["1"] == 0.8, "Local 0.8 should beat cloud 0.4")
        #expect(cloud.lastEfficiencyByLevel["2"] == 0.9, "Cloud 0.9 should beat local 0.3")
    }

    @Test("Missing cloud last-efficiency levels are added from local")
    func missingCloudLastEfficiency() {
        var cloud = AstronautProfile()
        cloud.lastEfficiencyByLevel = ["1": 0.5]
        var local = AstronautProfile()
        local.lastEfficiencyByLevel = ["1": 0.3, "7": 0.75]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.lastEfficiencyByLevel["1"] == 0.5, "Cloud 0.5 should beat local 0.3")
        #expect(cloud.lastEfficiencyByLevel["7"] == 0.75, "Local-only level 7 added")
    }

    @Test("Mixed partial progress: each side has unique levels, merge is superset")
    func mixedPartialProgress() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.6, "3": 0.9]
        cloud.lastEfficiencyByLevel = ["1": 0.6, "3": 0.9]
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["2": 0.8, "3": 0.5]
        local.lastEfficiencyByLevel = ["2": 0.8, "3": 0.5]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        // best
        #expect(cloud.bestEfficiencyByLevel["1"] == 0.6, "Cloud-only level 1 kept")
        #expect(cloud.bestEfficiencyByLevel["2"] == 0.8, "Local-only level 2 added")
        #expect(cloud.bestEfficiencyByLevel["3"] == 0.9, "Cloud 0.9 beats local 0.5")
        // last
        #expect(cloud.lastEfficiencyByLevel["1"] == 0.6, "Cloud-only level 1 kept")
        #expect(cloud.lastEfficiencyByLevel["2"] == 0.8, "Local-only level 2 added")
        #expect(cloud.lastEfficiencyByLevel["3"] == 0.9, "Cloud 0.9 beats local 0.5")
    }

    @Test("Tied scores remain unchanged")
    func tiedScores() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.75]
        cloud.lastEfficiencyByLevel = ["1": 0.75]
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["1": 0.75]
        local.lastEfficiencyByLevel = ["1": 0.75]

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel["1"] == 0.75)
        #expect(cloud.lastEfficiencyByLevel["1"] == 0.75)
    }
}

@Suite("CloudSave Merge — Scalars")
struct CloudSaveMergeScalarTests {

    @Test("totalScore takes the higher value — local wins")
    func totalScoreLocalHigher() {
        var cloud = AstronautProfile()
        cloud.totalScore = 500
        var local = AstronautProfile()
        local.totalScore = 1200

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.totalScore == 1200)
    }

    @Test("totalScore takes the higher value — cloud wins")
    func totalScoreCloudHigher() {
        var cloud = AstronautProfile()
        cloud.totalScore = 3000
        var local = AstronautProfile()
        local.totalScore = 800

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.totalScore == 3000)
    }

    @Test("totalScore tie remains unchanged")
    func totalScoreTied() {
        var cloud = AstronautProfile()
        cloud.totalScore = 999
        var local = AstronautProfile()
        local.totalScore = 999

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.totalScore == 999)
    }

    @Test("level takes max of local vs cascaded cloud level — local higher")
    func levelLocalHigher() {
        var cloud = AstronautProfile()
        cloud.level = 2
        var local = AstronautProfile()
        local.level = 5

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.level >= 5, "Merged level must be at least local level")
    }

    @Test("level takes max of local vs cascaded cloud level — cloud higher")
    func levelCloudHigher() {
        var cloud = AstronautProfile()
        cloud.level = 8
        var local = AstronautProfile()
        local.level = 3

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.level >= 8, "Merged level must be at least cloud level")
    }

    @Test("level is never downgraded by merge")
    func levelNeverDowngraded() {
        var cloud = AstronautProfile()
        cloud.level = 6
        let originalCloudLevel = cloud.level
        var local = AstronautProfile()
        local.level = 2

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.level >= originalCloudLevel, "Merge must never decrease level")
    }
}

@Suite("CloudSave Merge — Idempotency & Edge Cases")
struct CloudSaveMergeEdgeCaseTests {

    @Test("Merging two empty profiles produces empty profile")
    func mergeEmptyProfiles() {
        var cloud = AstronautProfile()
        let local = AstronautProfile()

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel.isEmpty)
        #expect(cloud.lastEfficiencyByLevel.isEmpty)
        #expect(cloud.totalScore == 0)
        #expect(cloud.level == 1)
    }

    @Test("Merge is idempotent — merging same data twice gives same result")
    func mergeIdempotent() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.8, "2": 0.6]
        cloud.lastEfficiencyByLevel = ["1": 0.7, "2": 0.5]
        cloud.totalScore = 500
        cloud.level = 3

        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["1": 0.5, "3": 0.9]
        local.lastEfficiencyByLevel = ["1": 0.4, "3": 0.85]
        local.totalScore = 300
        local.level = 4

        // First merge
        CloudSaveManager.mergeProfiles(local: local, into: &cloud)
        let afterFirst = cloud

        // Second merge with same local data
        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel == afterFirst.bestEfficiencyByLevel)
        #expect(cloud.lastEfficiencyByLevel == afterFirst.lastEfficiencyByLevel)
        #expect(cloud.totalScore == afterFirst.totalScore)
        #expect(cloud.level == afterFirst.level)
    }

    @Test("Merging local-only data into empty cloud copies everything")
    func mergeIntoEmptyCloud() {
        var cloud = AstronautProfile()
        var local = AstronautProfile()
        local.bestEfficiencyByLevel = ["1": 0.9, "2": 0.7, "3": 0.5]
        local.lastEfficiencyByLevel = ["1": 0.85, "2": 0.65, "3": 0.45]
        local.totalScore = 2000
        local.level = 4

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel == local.bestEfficiencyByLevel)
        #expect(cloud.lastEfficiencyByLevel == local.lastEfficiencyByLevel)
        #expect(cloud.totalScore == 2000)
        #expect(cloud.level >= 4)
    }

    @Test("Merging empty local into populated cloud leaves cloud unchanged")
    func mergeEmptyLocalIntoPopulatedCloud() {
        var cloud = AstronautProfile()
        cloud.bestEfficiencyByLevel = ["1": 0.9, "2": 0.7]
        cloud.lastEfficiencyByLevel = ["1": 0.85, "2": 0.65]
        cloud.totalScore = 1500
        cloud.level = 5
        let original = cloud
        let local = AstronautProfile()

        CloudSaveManager.mergeProfiles(local: local, into: &cloud)

        #expect(cloud.bestEfficiencyByLevel == original.bestEfficiencyByLevel)
        #expect(cloud.lastEfficiencyByLevel == original.lastEfficiencyByLevel)
        #expect(cloud.totalScore == original.totalScore)
        #expect(cloud.level >= original.level, "Level must not decrease")
    }
}

// MARK: - PassStore Merge Tests
// Verifies that mergePasses is monotonic — a merge never loses a legitimately earned pass.

@Suite("PassStore Merge")
struct PassStoreMergeTests {

    // Helper to create a PlanetPass with minimal boilerplate
    private static func makePass(
        planetIndex: Int,
        planetName: String = "TEST",
        levelReached: Int = 1,
        efficiency: Float = 0.5,
        missions: Int = 1,
        timestamp: Date = Date()
    ) -> PlanetPass {
        PlanetPass(
            id: UUID(),
            planetName: planetName,
            planetIndex: planetIndex,
            levelReached: levelReached,
            efficiencyScore: efficiency,
            missionCount: missions,
            timestamp: timestamp
        )
    }

    @Test("Local-only pass is preserved when cloud has nothing")
    func localOnlyPassPreserved() {
        let local = [Self.makePass(planetIndex: 0, planetName: "MERCURY")]
        let incoming: [PlanetPass] = []

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].planetIndex == 0)
        #expect(result[0].planetName == "MERCURY")
    }

    @Test("Cloud-only pass is added when local has nothing")
    func cloudOnlyPassAdded() {
        let local: [PlanetPass] = []
        let incoming = [Self.makePass(planetIndex: 3, planetName: "MARS")]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].planetIndex == 3)
        #expect(result[0].planetName == "MARS")
    }

    @Test("Same planet in both — earlier timestamp wins")
    func samePlanetEarlierTimestampWins() {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later   = Date(timeIntervalSince1970: 2000)

        let local    = [Self.makePass(planetIndex: 1, planetName: "VENUS-LOCAL", timestamp: later)]
        let incoming = [Self.makePass(planetIndex: 1, planetName: "VENUS-CLOUD", timestamp: earlier)]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 1, "Duplicate planet should be deduplicated")
        #expect(result[0].planetName == "VENUS-CLOUD", "Earlier timestamp (cloud) should win")
    }

    @Test("Same planet in both — local earlier timestamp wins")
    func samePlanetLocalEarlierWins() {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later   = Date(timeIntervalSince1970: 2000)

        let local    = [Self.makePass(planetIndex: 2, planetName: "EARTH-LOCAL", timestamp: earlier)]
        let incoming = [Self.makePass(planetIndex: 2, planetName: "EARTH-CLOUD", timestamp: later)]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].planetName == "EARTH-LOCAL", "Earlier timestamp (local) should win")
    }

    @Test("Mixed set: local has planets 0,1 — cloud has planets 1,2 — result is superset {0,1,2}")
    func mixedSetUnionMerge() {
        let t0 = Date(timeIntervalSince1970: 100)
        let t1 = Date(timeIntervalSince1970: 200)
        let t2 = Date(timeIntervalSince1970: 300)

        let local = [
            Self.makePass(planetIndex: 0, planetName: "P0", timestamp: t0),
            Self.makePass(planetIndex: 1, planetName: "P1-LOCAL", timestamp: t1)
        ]
        let incoming = [
            Self.makePass(planetIndex: 1, planetName: "P1-CLOUD", timestamp: t2),
            Self.makePass(planetIndex: 2, planetName: "P2", timestamp: t2)
        ]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 3, "Union of {0,1} and {1,2} should be {0,1,2}")
        let indices = Set(result.map(\.planetIndex))
        #expect(indices == [0, 1, 2])
        // Planet 1: local t1 < cloud t2, so local wins
        let p1 = result.first { $0.planetIndex == 1 }!
        #expect(p1.planetName == "P1-LOCAL", "Earlier timestamp (local) should win for planet 1")
    }

    @Test("Result is sorted by timestamp ascending")
    func resultSortedByTimestamp() {
        let t1 = Date(timeIntervalSince1970: 300)
        let t2 = Date(timeIntervalSince1970: 100)
        let t3 = Date(timeIntervalSince1970: 200)

        let local    = [Self.makePass(planetIndex: 0, timestamp: t1)]
        let incoming = [
            Self.makePass(planetIndex: 1, timestamp: t2),
            Self.makePass(planetIndex: 2, timestamp: t3)
        ]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 3)
        #expect(result[0].planetIndex == 1, "t=100 should be first")
        #expect(result[1].planetIndex == 2, "t=200 should be second")
        #expect(result[2].planetIndex == 0, "t=300 should be third")
    }

    @Test("Both empty returns empty")
    func bothEmptyReturnsEmpty() {
        let result = PassStore.mergePasses(local: [], incoming: [])
        #expect(result.isEmpty)
    }

    @Test("Merge is idempotent — merging same data twice gives same result")
    func mergeIdempotent() {
        let passes = [
            Self.makePass(planetIndex: 0, timestamp: Date(timeIntervalSince1970: 100)),
            Self.makePass(planetIndex: 1, timestamp: Date(timeIntervalSince1970: 200))
        ]

        let first  = PassStore.mergePasses(local: passes, incoming: passes)
        let second = PassStore.mergePasses(local: first, incoming: passes)

        #expect(first.count == second.count)
        for i in 0..<first.count {
            #expect(first[i].planetIndex == second[i].planetIndex)
            #expect(first[i].timestamp == second[i].timestamp)
        }
    }

    @Test("Same planet same timestamp — local is kept (stable tie-breaking)")
    func samePlanetSameTimestamp() {
        let t = Date(timeIntervalSince1970: 500)
        let local    = [Self.makePass(planetIndex: 0, planetName: "LOCAL", timestamp: t)]
        let incoming = [Self.makePass(planetIndex: 0, planetName: "CLOUD", timestamp: t)]

        let result = PassStore.mergePasses(local: local, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].planetName == "LOCAL", "On tie, local should be kept (no overwrite)")
    }
}

// MARK: - Clock Manipulation Resistance Tests
// Verifies that isCooldownExpired and cooldownRemaining detect device clock manipulation.

@Suite("Cooldown Clock Hardening — isCooldownExpired")
struct CooldownClockExpiryTests {

    // Shared test constants
    private static let armDate = Date(timeIntervalSince1970: 1_000_000)
    private static let target  = armDate.addingTimeInterval(86_400) // armDate + 24h
    private static let armUptime: TimeInterval = 5_000 // system uptime when armed

    @Test("No cooldown armed → expired (can play)")
    func noCooldownIsExpired() {
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: nil,
            cooldownArmedUptime: nil,
            now: Date(),
            systemUptime: 1000
        )
        #expect(result == true)
    }

    @Test("Wall clock before target → NOT expired")
    func wallClockBeforeTarget() {
        let now = Self.armDate.addingTimeInterval(3600) // only 1h later
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 3600
        )
        #expect(result == false, "Only 1h passed — should still be blocked")
    }

    @Test("Normal expiry: wall clock + uptime both confirm 24h passed → expired")
    func normalExpiry() {
        let now = Self.armDate.addingTimeInterval(86_401) // 24h + 1s
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 86_401
        )
        #expect(result == true, "24h legitimately passed — should be expired")
    }

    @Test("Clock moved forward: wall says expired, uptime says only 100s → NOT expired")
    func clockMovedForward() {
        let now = Self.armDate.addingTimeInterval(86_401) // wall: 24h+ after arm
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 100 // only 100s of real time
        )
        #expect(result == false, "Clock manipulation detected — should stay blocked")
    }

    @Test("Clock moved forward by exactly 24h but only 1h uptime → NOT expired")
    func clockForwardExact24hButLowUptime() {
        let now = Self.target // wall: exactly at target
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 3600 // only 1h of real time
        )
        #expect(result == false, "Uptime only 1h — clock was manipulated")
    }

    @Test("Device rebooted, wall clock honest (24h+ passed) → expired (trust wall clock)")
    func rebootedHonestClock() {
        let now = Self.armDate.addingTimeInterval(90_000) // ~25h
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: 500 // < armUptime → reboot detected
        )
        #expect(result == true, "Rebooted — fall back to wall clock, which says expired")
    }

    @Test("Device rebooted, wall clock manipulated forward → expired (accepted limitation)")
    func rebootedManipulatedClock() {
        // This is the known weakness: reboot + clock forward bypasses.
        // Documenting it explicitly as an accepted tradeoff.
        let now = Self.armDate.addingTimeInterval(86_401)
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: 30 // tiny uptime (just rebooted) < armUptime → reboot
        )
        #expect(result == true, "After reboot, can only trust wall clock — accepted tradeoff")
    }

    @Test("Legacy data (no uptime recorded): wall says expired → expired")
    func legacyNoUptimeRecorded() {
        let now = Self.armDate.addingTimeInterval(86_401)
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: nil, // pre-update data
            now: now,
            systemUptime: 1000
        )
        #expect(result == true, "Legacy data — trust wall clock for backward compatibility")
    }

    @Test("Legacy data (no uptime recorded): wall says NOT expired → NOT expired")
    func legacyNotExpired() {
        let now = Self.armDate.addingTimeInterval(3600)
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: nil,
            now: now,
            systemUptime: 1000
        )
        #expect(result == false, "Wall clock says not expired — blocked")
    }

    @Test("Clock moved backward: wall now before arm date → NOT expired")
    func clockMovedBackward() {
        let now = Self.armDate.addingTimeInterval(-7200) // 2h before arm
        let result = EntitlementStore.isCooldownExpired(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 7200
        )
        #expect(result == false, "Wall clock before target — blocked regardless of uptime")
    }
}

@Suite("Cooldown Clock Hardening — cooldownRemaining")
struct CooldownClockRemainingTests {

    private static let armDate = Date(timeIntervalSince1970: 1_000_000)
    private static let target  = armDate.addingTimeInterval(86_400)
    private static let armUptime: TimeInterval = 5_000

    @Test("No cooldown → remaining is 0")
    func noCooldownRemainingZero() {
        let result = EntitlementStore.cooldownRemaining(
            nextPlayableDate: nil,
            cooldownArmedUptime: nil,
            now: Date(),
            systemUptime: 1000
        )
        #expect(result == 0)
    }

    @Test("Normal: 1h elapsed → remaining ≈ 23h")
    func normalRemainingAfter1h() {
        let now = Self.armDate.addingTimeInterval(3600)
        let result = EntitlementStore.cooldownRemaining(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 3600
        )
        // 86400 - 3600 = 82800
        #expect(result >= 82_799 && result <= 82_801, "Should be ~82800s remaining")
    }

    @Test("Clock forward manipulation: wall says expired, uptime says 100s → remaining ≈ 86300s")
    func clockForwardShowsUptimeRemaining() {
        let now = Self.armDate.addingTimeInterval(86_401) // wall: past target
        let result = EntitlementStore.cooldownRemaining(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 100 // only 100s real time
        )
        // 86400 - 100 = 86300
        #expect(result >= 86_299 && result <= 86_301,
                "Should show uptime-based remaining (~86300s), not wall-clock 0")
    }

    @Test("Legitimately expired → remaining is 0")
    func legitimatelyExpiredRemainingZero() {
        let now = Self.armDate.addingTimeInterval(86_401)
        let result = EntitlementStore.cooldownRemaining(
            nextPlayableDate: Self.target,
            cooldownArmedUptime: Self.armUptime,
            now: now,
            systemUptime: Self.armUptime + 86_401
        )
        #expect(result == 0)
    }
}

// MARK: - EntitlementMergeTests

@Suite("Entitlement cloud-sync merge")
struct EntitlementMergeTests {

    // ── Helpers ──────────────────────────────────────────────────────────

    /// A "clean" snapshot with no premium, no intro, no cooldown.
    static func blank() -> EntitlementSnapshot {
        EntitlementSnapshot(
            isPremium:          false,
            premiumByCode:      false,
            activeCodeID:       nil,
            freeIntroCompleted: 0,
            dailyPlaysUsed:     0,
            nextPlayableDate:   nil,
            dailyWindowStart:   nil
        )
    }

    static let now = Date()

    // ── Premium merge (OR) ──────────────────────────────────────────────

    @Test("Premium: local true + cloud false → true")
    func premiumLocalTrue() {
        var local = Self.blank()
        local.isPremium = true
        let cloud = Self.blank()
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.isPremium == true)
    }

    @Test("Premium: local false + cloud true → true")
    func premiumCloudTrue() {
        let local = Self.blank()
        var cloud = Self.blank()
        cloud.isPremium = true
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.isPremium == true)
    }

    @Test("Premium: both false → false")
    func premiumBothFalse() {
        let result = CloudSaveManager.mergeEntitlements(local: Self.blank(), cloud: Self.blank())
        #expect(result.isPremium == false)
    }

    // ── Code premium merge ──────────────────────────────────────────────

    @Test("Code premium: local has code, cloud doesn't → code preserved")
    func codePremiumLocalOnly() {
        var local = Self.blank()
        local.isPremium     = true
        local.premiumByCode = true
        local.activeCodeID  = "SIGNALRM"
        let cloud = Self.blank()
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.premiumByCode == true)
        #expect(result.activeCodeID == "SIGNALRM")
    }

    @Test("Code premium: cloud has code, local doesn't → code adopted")
    func codePremiumCloudOnly() {
        let local = Self.blank()
        var cloud = Self.blank()
        cloud.isPremium     = true
        cloud.premiumByCode = true
        cloud.activeCodeID  = "TESTCODE"
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.premiumByCode == true)
        #expect(result.activeCodeID == "TESTCODE")
    }

    // ── Intro merge (max) ───────────────────────────────────────────────

    @Test("Intro: local 5 + cloud 3 → 5")
    func introLocalHigher() {
        var local = Self.blank()
        local.freeIntroCompleted = 5
        var cloud = Self.blank()
        cloud.freeIntroCompleted = 3
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.freeIntroCompleted == 5)
    }

    @Test("Intro: local 2 + cloud 8 → 8")
    func introCloudHigher() {
        var local = Self.blank()
        local.freeIntroCompleted = 2
        var cloud = Self.blank()
        cloud.freeIntroCompleted = 8
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.freeIntroCompleted == 8)
    }

    // ── Cooldown merge (most restrictive) ───────────────────────────────

    @Test("Cooldown: only local has cooldown → kept")
    func cooldownLocalOnly() {
        var local = Self.blank()
        local.nextPlayableDate = Self.now.addingTimeInterval(86_400)
        local.dailyPlaysUsed   = 3
        let cloud = Self.blank()
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.nextPlayableDate != nil)
        #expect(result.dailyPlaysUsed == 3)
    }

    @Test("Cooldown: only cloud has cooldown → adopted")
    func cooldownCloudOnly() {
        let local = Self.blank()
        var cloud = Self.blank()
        cloud.nextPlayableDate = Self.now.addingTimeInterval(86_400)
        cloud.dailyPlaysUsed   = 3
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.nextPlayableDate != nil)
        #expect(result.dailyPlaysUsed == 3)
    }

    @Test("Cooldown: both have cooldown → later expiry wins")
    func cooldownBothLaterWins() {
        let earlyExpiry = Self.now.addingTimeInterval(3_600)
        let lateExpiry  = Self.now.addingTimeInterval(86_400)
        var local = Self.blank()
        local.nextPlayableDate = earlyExpiry
        local.dailyPlaysUsed   = 3
        var cloud = Self.blank()
        cloud.nextPlayableDate = lateExpiry
        cloud.dailyPlaysUsed   = 3
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.nextPlayableDate == lateExpiry, "Should keep the later (more restrictive) expiry")
    }

    @Test("Cooldown: neither has cooldown, max daily plays wins")
    func noCooldownMaxPlays() {
        var local = Self.blank()
        local.dailyPlaysUsed = 1
        local.dailyWindowStart = Self.now
        var cloud = Self.blank()
        cloud.dailyPlaysUsed = 2
        cloud.dailyWindowStart = Self.now.addingTimeInterval(-3600)
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.dailyPlaysUsed == 2, "Should take max daily plays")
        #expect(result.nextPlayableDate == nil, "No cooldown should be set")
    }

    @Test("Cooldown: neither has cooldown, later window start wins")
    func noCooldownLaterWindow() {
        let earlyWindow = Self.now.addingTimeInterval(-7200)
        let lateWindow  = Self.now.addingTimeInterval(-3600)
        var local = Self.blank()
        local.dailyPlaysUsed   = 1
        local.dailyWindowStart = lateWindow
        var cloud = Self.blank()
        cloud.dailyPlaysUsed   = 1
        cloud.dailyWindowStart = earlyWindow
        let result = CloudSaveManager.mergeEntitlements(local: local, cloud: cloud)
        #expect(result.dailyWindowStart == lateWindow)
    }

    // ── v1 backward compatibility ───────────────────────────────────────

    @Test("v1 payload decodes with entitlement == nil")
    func v1BackwardCompat() throws {
        // Simulate a v1 payload (no entitlement field)
        let v1JSON = """
        {
            "profile": {"level": 1, "totalScore": 0, "currentPlanetIndex": 0,
                        "bestEfficiencyByLevel": {}, "lastEfficiencyByLevel": {}},
            "passes": [],
            "lastUpdated": 0,
            "schemaVersion": 1
        }
        """
        let data = Data(v1JSON.utf8)
        let payload = try JSONDecoder().decode(CloudSavePayload.self, from: data)
        #expect(payload.entitlement == nil, "v1 payload must decode without entitlement")
        #expect(payload.schemaVersion == 1)
    }

    @Test("v2 payload decodes with entitlement present")
    func v2WithEntitlement() throws {
        let v2JSON = """
        {
            "profile": {"level": 3, "totalScore": 500, "currentPlanetIndex": 1,
                        "bestEfficiencyByLevel": {"1": 0.8}, "lastEfficiencyByLevel": {"1": 0.7}},
            "passes": [],
            "lastUpdated": 0,
            "schemaVersion": 2,
            "entitlement": {
                "isPremium": true,
                "premiumByCode": false,
                "freeIntroCompleted": 8,
                "dailyPlaysUsed": 0,
                "nextPlayableDate": null,
                "dailyWindowStart": null
            }
        }
        """
        let data = Data(v2JSON.utf8)
        let payload = try JSONDecoder().decode(CloudSavePayload.self, from: data)
        #expect(payload.entitlement != nil, "v2 payload must decode with entitlement")
        #expect(payload.entitlement?.isPremium == true)
        #expect(payload.entitlement?.freeIntroCompleted == 8)
    }

    // ── Device-hop cooldown bypass prevention ───────────────────────────

    @Test("Device hop: device A armed cooldown, device B clean → cooldown applied")
    func deviceHopCooldownPrevented() {
        // Device A used all plays and has a 24h cooldown
        var deviceA = Self.blank()
        deviceA.freeIntroCompleted = 8  // Phase 2
        deviceA.dailyPlaysUsed     = 3
        deviceA.nextPlayableDate   = Self.now.addingTimeInterval(86_400)
        deviceA.dailyWindowStart   = Self.now
        // Device B is clean (no plays, no cooldown)
        var deviceB = Self.blank()
        deviceB.freeIntroCompleted = 8  // Phase 2
        let result = CloudSaveManager.mergeEntitlements(local: deviceB, cloud: deviceA)
        #expect(result.nextPlayableDate != nil, "Cooldown from device A must be applied to device B")
        #expect(result.dailyPlaysUsed == 3)
        #expect(result.freeIntroCompleted == 8)
    }
}

// MARK: - PremiumStateTransitionTests

@Suite("Premium state transitions", .serialized)
struct PremiumStateTransitionTests {

    @Test("Purchase after code: clears code flags")
    @MainActor func purchaseAfterCode() {
        let s = EntitlementStore.shared
        // Start clean
        s.setPremium(false)
        // Activate via code
        s.activateByCode("SIGNALRM")
        #expect(s.isPremium == true)
        #expect(s.premiumByCode == true)
        #expect(s.activeCodeID == "SIGNALRM")
        // StoreKit purchase supersedes code
        s.setPremium(true)
        #expect(s.isPremium == true)
        #expect(s.premiumByCode == false, "Purchase must clear premiumByCode")
        #expect(s.activeCodeID == nil, "Purchase must clear activeCodeID")
        // Cleanup
        s.setPremium(false)
    }

    @Test("Code after purchase: no-op (purchase takes precedence)")
    @MainActor func codeAfterPurchase() {
        let s = EntitlementStore.shared
        s.setPremium(false)
        // StoreKit purchase first
        s.setPremium(true)
        #expect(s.isPremium == true)
        #expect(s.premiumByCode == false)
        // Attempt code activation — should be no-op (guard !isPremium)
        s.activateByCode("SIGNALRM")
        #expect(s.premiumByCode == false, "Code must not override purchase")
        #expect(s.activeCodeID == nil, "Code ID must not be set over purchase")
        // Cleanup
        s.setPremium(false)
    }

    @Test("Revoke code: does not affect purchase premium")
    @MainActor func revokeCodeWithPurchase() {
        let s = EntitlementStore.shared
        s.setPremium(false)
        // Activate via code, then purchase supersedes
        s.activateByCode("SIGNALRM")
        s.setPremium(true)
        // revokeCodePremium should be no-op since premiumByCode is now false
        s.revokeCodePremium()
        #expect(s.isPremium == true, "Purchase premium must survive code revocation")
        // Cleanup
        s.setPremium(false)
    }

    @Test("setPremium(true) clears cooldown state")
    @MainActor func purchaseClearsCooldown() {
        let s = EntitlementStore.shared
        s.setPremium(false)
        s.setFreeIntroCompleted(EntitlementStore.freeIntroLimit)
        s.setDailyAttemptsUsed(EntitlementStore.dailyLimit) // arms cooldown
        #expect(s.dailyLimitReached == true, "Cooldown should be active before purchase")
        // Purchase clears everything
        s.setPremium(true)
        #expect(s.dailyLimitReached == false, "Purchase must clear cooldown")
        #expect(s.remainingCooldown == 0, "No remaining cooldown after purchase")
        // Cleanup
        s.setPremium(false)
    }

    @Test("setPremium(false) clears code flags")
    @MainActor func disableClearsCodeFlags() {
        let s = EntitlementStore.shared
        s.setPremium(false)
        s.activateByCode("TESTCODE")
        #expect(s.premiumByCode == true)
        #expect(s.activeCodeID == "TESTCODE")
        // Disable premium
        s.setPremium(false)
        #expect(s.isPremium == false)
        #expect(s.premiumByCode == false, "Disable must clear premiumByCode")
        #expect(s.activeCodeID == nil, "Disable must clear activeCodeID")
    }
}
