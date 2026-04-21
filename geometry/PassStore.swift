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

    /// In-memory cache; nil means "not yet loaded from disk."
    private static var _cache: [PlanetPass]?

    // MARK: - Access

    /// All collected passes, sorted by issue timestamp ascending.
    /// Decoded lazily from UserDefaults once, then served from cache.
    static var all: [PlanetPass] {
        if let cached = _cache { return cached }
        guard
            let data    = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([PlanetPass].self, from: data)
        else { return [] }
        let sorted = decoded.sorted { $0.timestamp < $1.timestamp }
        _cache = sorted
        return sorted
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
        let sorted = passes.sorted { $0.timestamp < $1.timestamp }
        _cache = sorted
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Debug / testing

    /// Removes all stored passes. Use only for testing/debug flows.
    static func reset() {
        _cache = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Monotonically merge incoming passes with the local collection, then persist.
    /// Called by CloudSaveManager when applying a cloud save.
    ///
    /// **Invariant:** a restore never loses a legitimately earned pass.
    ///
    /// Merge rules (keyed by `planetIndex`):
    ///   - Pass exists only in local → kept.
    ///   - Pass exists only in incoming → added.
    ///   - Pass exists in both → the earlier `timestamp` wins (original unlock moment).
    static func restore(_ passes: [PlanetPass]) {
        let merged = Self.mergePasses(local: all, incoming: passes)
        save(merged)
    }

    // MARK: - Monotonic pass merge (pure, testable)

    /// Union-merge two pass arrays by `planetIndex`.
    ///
    /// When the same planet appears in both arrays, the pass with the earlier
    /// `timestamp` is kept (preserves the original unlock moment).
    /// Result is sorted by timestamp ascending.
    ///
    /// This is a pure function with no side effects — safe for unit testing.
    static func mergePasses(local: [PlanetPass], incoming: [PlanetPass]) -> [PlanetPass] {
        // Index local passes by planetIndex
        var byPlanet: [Int: PlanetPass] = [:]
        for pass in local {
            byPlanet[pass.planetIndex] = pass
        }
        // Merge incoming: add if absent, keep earlier timestamp if both exist
        for pass in incoming {
            if let existing = byPlanet[pass.planetIndex] {
                if pass.timestamp < existing.timestamp {
                    byPlanet[pass.planetIndex] = pass
                }
            } else {
                byPlanet[pass.planetIndex] = pass
            }
        }
        return byPlanet.values.sorted { $0.timestamp < $1.timestamp }
    }
}
