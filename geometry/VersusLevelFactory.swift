import Foundation

// MARK: - VersusLevelFactory
/// Converts a shared seed + config into a `Level` struct suitable for `LevelGenerator.buildBoard(for:)`.
///
/// Versus levels use `id: -1` to distinguish them from the 180 campaign missions.
/// Both players call this with the same seed/config → identical boards.
enum VersusLevelFactory {

    /// Build a Level from the versus match parameters.
    /// The board is generated deterministically by `LevelGenerator.buildBoard(for:)` using the seed.
    static func makeLevel(seed: UInt64, config: VersusLevelConfig) -> Level {
        Level(
            id:                    -1,
            seed:                  seed,
            maxMoves:              config.maxMoves,
            minimumRequiredMoves:  1,   // not used for versus scoring
            difficulty:            DifficultyTier(rawValue: config.difficultyRaw) ?? .medium,
            gridSize:              config.gridSize,
            levelType:             LevelType(rawValue: config.levelType) ?? .branching,
            numTargets:            config.numTargets,
            timeLimit:             nil,
            objectiveType:         LevelObjectiveType(rawValue: config.objectiveType) ?? .normal,
            solutionPathLength:    0    // not used for versus scoring
        )
    }
}
