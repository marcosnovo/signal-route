import Foundation

// MARK: - ProgressionStore
/// Persists and manages the player's AstronautProfile.
///
/// Responsibilities:
///   • Load / save the profile via UserDefaults (JSON, Codable)
///   • Record a completed mission and update cumulative stats
///   • Execute level-up logic, including advancing the planet index
///   • Expose a LevelUpEvent when a level boundary is crossed
enum ProgressionStore {

    private static let key = "astronaut-profile-v1"

    // MARK: - Profile access

    /// Current profile — returns a default Level-1 profile if no data exists yet.
    static var profile: AstronautProfile {
        guard
            let data    = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(AstronautProfile.self, from: data)
        else { return AstronautProfile() }
        return decoded
    }

    /// Persist the given profile to UserDefaults.
    static func save(_ profile: AstronautProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Recording a mission

    /// Call this after every successful mission win.
    ///
    /// Only the **best** efficiency per unique level ID contributes to progression.
    /// Replaying the same level a hundred times does not inflate the quality count —
    /// the stored entry is updated only when the new score strictly improves on the best.
    ///
    /// - Returns: A `LevelUpEvent` if the player advanced one or more levels,
    ///            or `nil` if no level boundary was crossed.
    @discardableResult
    static func record(_ result: GameResult) -> LevelUpEvent? {
        guard result.success else { return nil }

        var p = profile

        // Always accumulate lifetime score (not used for level-up gating)
        p.totalScore += result.score

        // Best-per-level dedup: only store if this result beats the previous best
        let key = String(result.levelId)
        let previousBest = p.bestEfficiencyByLevel[key] ?? 0
        if result.efficiency > previousBest {
            p.bestEfficiencyByLevel[key] = result.efficiency
        }

        // Level-up loop — handles the rare case where one result crosses multiple thresholds
        var levelsGained = 0
        let prevPlanetIndex = p.currentPlanetIndex
        while p.canLevelUp {
            p.level += 1
            p.currentPlanetIndex = min(p.level - 1, Planet.catalog.count - 1)
            levelsGained += 1
        }

        save(p)

        guard levelsGained > 0 else { return nil }

        // Issue a planet pass if the player reached a new destination
        var newPass: PlanetPass? = nil
        if p.currentPlanetIndex > prevPlanetIndex {
            newPass = PassStore.issue(planet: p.currentPlanet, profile: p)
        }

        return LevelUpEvent(
            newLevel:     p.level,
            newPlanet:    p.currentPlanet,
            levelsGained: levelsGained,
            newPass:      newPass
        )
    }

    // MARK: - Debug / testing

    /// Resets the profile to a fresh Level-1 state.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - LevelUpEvent
/// Returned by `ProgressionStore.record(_:)` when a level boundary is crossed.
struct LevelUpEvent {
    let newLevel:     Int
    let newPlanet:    Planet
    let levelsGained: Int
    /// A newly issued PlanetPass when the player reaches a new destination; nil if planet unchanged.
    let newPass:      PlanetPass?
}
