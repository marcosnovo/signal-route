import Foundation

// MARK: - DailyLevelFactory
/// Generates the daily challenge level procedurally from a deterministic seed.
/// Follows the VersusLevelFactory pattern — creates special levels outside the campaign.
enum DailyLevelFactory {

    /// Today's daily challenge level. Deterministic: same board for all players worldwide.
    static var todayLevel: Level {
        makeLevel(seed: DailyChallengeConfig.todaySeed)
    }

    /// Generates a daily challenge level from a given seed.
    ///
    /// - Difficulty: 40% hard / 60% expert
    /// - Grid: always 5×5
    /// - Time limit: always present (90 s hard, 55 s expert)
    /// - Objective: uniform random from all 3 types
    /// - Level type: uniform random from all 5 types
    /// - Mechanics: applied via synthetic mechanic ID (100 for hard, 150 for expert)
    static func makeLevel(seed: UInt64) -> Level {
        var rng = SeededRNG(seed: seed)

        // Difficulty: 40 % hard, 60 % expert
        let difficulty: DifficultyTier = rng.nextInt(10) < 4 ? .hard : .expert

        // Level type: uniform random from all 5
        let types: [LevelType] = [.singlePath, .branching, .multiTarget, .dense, .sparse]
        let levelType = types[rng.nextInt(types.count)]

        // Num targets: multiTarget always gets 2; others 33 % chance of 2
        let numTargets = levelType == .multiTarget ? 2 : (rng.nextInt(3) == 0 ? 2 : 1)

        // Objective type: uniform random from all 3
        let objectives: [LevelObjectiveType] = [.normal, .maxCoverage, .energySaving]
        let objectiveType = objectives[rng.nextInt(objectives.count)]

        // Time limit: hard = 90 s, expert = 55 s
        let timeLimit = difficulty == .hard ? 90 : 55

        // Synthetic level ID for mechanic assignment during board generation.
        // Hard  → id 100 (triggers: rotationCap ×2, overloaded ×1, timeLimit)
        // Expert → id 150 (triggers: rotationCap ×4, overloaded ×2, autoDrift, oneWay)
        let syntheticId = difficulty == .hard ? 100 : 150

        // Minimum path length for maxCoverage (≥ 50 % of 25 tiles = 13)
        let gs = DailyChallengeConfig.gridSize
        let minPathForCoverage = objectiveType == .maxCoverage ? (gs * gs + 1) / 2 : 0

        // Trial-seed loop: retry with perturbed seeds until path is long enough for coverage
        var currentSeed = seed
        var minMoves = 0
        var pathLen  = 0

        for _ in 0..<20 {
            let temp = Level(
                id: syntheticId, seed: currentSeed,
                maxMoves: 99, minimumRequiredMoves: 0,
                difficulty: difficulty, gridSize: gs,
                levelType: levelType, numTargets: numTargets,
                timeLimit: timeLimit, objectiveType: objectiveType,
                solutionPathLength: 0
            )
            let result = LevelGenerator.buildBoardInternal(for: temp)
            minMoves = result.minMoves
            pathLen  = result.solutionPathLength
            if pathLen >= minPathForCoverage { break }
            currentSeed = currentSeed &+ 0x9E3779B97F4A7C15
        }

        // Move buffer: same formula as the campaign
        let buffer: Int
        if difficulty == .expert {
            buffer = max(1, Int(Double(minMoves) * 0.15))
        } else {
            buffer = max(2, Int(Double(minMoves) * 0.26))
        }

        return Level(
            id: DailyChallengeConfig.levelID,
            seed: currentSeed,
            maxMoves: minMoves + buffer,
            minimumRequiredMoves: minMoves,
            difficulty: difficulty,
            gridSize: gs,
            levelType: levelType,
            numTargets: numTargets,
            timeLimit: timeLimit,
            objectiveType: objectiveType,
            solutionPathLength: pathLen,
            mechanicLevelId: syntheticId
        )
    }
}
