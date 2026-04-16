import Foundation

// MARK: - PassStore
/// Persists and manages the player's collected PlanetPass tickets.
///
/// Responsibilities:
///   • Load / save the pass collection via UserDefaults (JSON, Codable)
///   • Issue a new pass when a planet is unlocked for the first time
///   • Guard against duplicates — one pass per planet, ever
enum PassStore {

    private static let key = "planet-passes-v1"

    // MARK: - Access

    /// All collected passes, sorted by issue timestamp ascending.
    static var all: [PlanetPass] {
        guard
            let data    = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([PlanetPass].self, from: data)
        else { return [] }
        return decoded.sorted { $0.timestamp < $1.timestamp }
    }

    /// True if the player already holds a pass for the given planet index.
    static func hasPass(for planetIndex: Int) -> Bool {
        all.contains { $0.planetIndex == planetIndex }
    }

    // MARK: - Issuing

    /// Issues a new pass for the given planet using the current profile stats.
    /// If a pass for this planet already exists the existing one is returned without modification.
    ///
    /// - Returns: The newly issued pass, or the existing one if already collected.
    @discardableResult
    static func issue(planet: Planet, profile: AstronautProfile) -> PlanetPass {
        var passes = all

        // Dedup: return the existing pass if already issued for this planet
        if let existing = passes.first(where: { $0.planetIndex == planet.id }) {
            return existing
        }

        let pass = PlanetPass(
            id:              UUID(),
            planetName:      planet.name,
            planetIndex:     planet.id,
            levelReached:    profile.level,
            efficiencyScore: profile.averageEfficiency,
            missionCount:    profile.completedMissions,
            timestamp:       Date()
        )
        passes.append(pass)
        save(passes)
        return pass
    }

    // MARK: - Persistence

    private static func save(_ passes: [PlanetPass]) {
        guard let data = try? JSONEncoder().encode(passes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Debug / testing

    /// Removes all stored passes. Use only for testing/debug flows.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Replace the stored passes with the given array.
    /// Called by CloudSaveManager when applying a cloud save.
    static func restore(_ passes: [PlanetPass]) {
        save(passes)
    }
}
