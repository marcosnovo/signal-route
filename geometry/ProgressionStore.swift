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

    private static let key       = "astronaut-profile-v1"
    private static let backupKey = "astronaut-profile-backup"

    /// In-memory cache — eliminates repeated UserDefaults JSON decodes.
    /// Invalidated on every save() / reset() so it never goes stale.
    private static var _cache: AstronautProfile?

    // MARK: - Profile access

    /// Current profile — returns a default Level-1 profile if no data exists yet.
    ///
    /// Safety layers:
    ///   1. Decode from primary key. If that fails…
    ///   2. Attempt decode from backup key (written on every save).
    ///   3. Only returns a fresh profile if both are absent (genuine first launch).
    ///
    /// Performs one-time migrations for schema evolution (see inline comments).
    static var profile: AstronautProfile {
        if let cached = _cache { return cached }

        // ── Layer 1: Decode from primary key ─────────────────────────────
        if let data = UserDefaults.standard.data(forKey: key) {
            do {
                var decoded = try JSONDecoder().decode(AstronautProfile.self, from: data)
                return applyMigrations(&decoded)
            } catch {
                // CRITICAL: Log the failure so it's diagnosable — never silently lose data.
                print("[ProgressionStore] ✗ PRIMARY decode failed (\(data.count) bytes): \(error)")
            }
        }

        // ── Layer 2: Recover from backup ─────────────────────────────────
        if let backupData = UserDefaults.standard.data(forKey: backupKey) {
            do {
                var decoded = try JSONDecoder().decode(AstronautProfile.self, from: backupData)
                print("[ProgressionStore] ⚠ Recovered from backup — completions=\(decoded.uniqueCompletions)")
                let restored = applyMigrations(&decoded)
                // Re-persist to primary so next launch doesn't hit this path again
                if let reEncoded = try? JSONEncoder().encode(restored) {
                    UserDefaults.standard.set(reEncoded, forKey: key)
                }
                return restored
            } catch {
                print("[ProgressionStore] ✗ BACKUP decode also failed (\(backupData.count) bytes): \(error)")
            }
        }

        // ── Layer 3: Genuine first launch — no stored data anywhere ──────
        let fresh = AstronautProfile()
        _cache = fresh
        return fresh
    }

    /// Apply schema migrations and cache the result. Returns the migrated profile.
    private static func applyMigrations(_ decoded: inout AstronautProfile) -> AstronautProfile {
        var needsSave = false

        // Migration 1: seed last-score store from best-score store
        if decoded.lastEfficiencyByLevel.isEmpty && !decoded.bestEfficiencyByLevel.isEmpty {
            decoded.lastEfficiencyByLevel = decoded.bestEfficiencyByLevel
            needsSave = true
        }

        // Migration 2: backfill weighted leaderboard scores from efficiency data
        let hadScores = decoded.bestScoreByLevel.isEmpty
        decoded.migrateScoresIfNeeded()
        if hadScores && !decoded.bestScoreByLevel.isEmpty { needsSave = true }

        if needsSave {
            save(decoded)   // save() also sets _cache
        } else {
            _cache = decoded
        }

        return decoded
    }

    /// Persist the given profile to UserDefaults and update the in-memory cache.
    ///
    /// Safety: also writes to a backup key so data can be recovered if the
    /// primary key becomes corrupted or a future schema change breaks decoding.
    static func save(_ profile: AstronautProfile) {
        // ── Regression guard: warn if saving a profile with fewer completions ──
        if let existing = _cache, existing.uniqueCompletions > 0,
           profile.uniqueCompletions == 0 && !_isDevReset {
            print("[ProgressionStore] ⚠ REGRESSION BLOCKED — attempted to overwrite \(existing.uniqueCompletions) completions with 0. Ignoring save.")
            return
        }

        _cache = profile
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
        // Write backup on every save — independent key survives primary corruption
        UserDefaults.standard.set(data, forKey: backupKey)
    }

    /// Flag to allow dev resets to bypass the regression guard.
    private static var _isDevReset = false

    // MARK: - Recording a mission

    /// Call this after every successful mission win.
    ///
    /// Only the **best** efficiency per unique level ID contributes to progression.
    /// Replaying the same level a hundred times does not inflate the quality count —
    /// the stored entry is updated only when the new score strictly improves on the best.
    ///
    /// A `PlanetPass` is issued the first time the player completes every mission
    /// in a sector — this is what unlocks the next sector, not the astronaut level.
    ///
    /// - Returns: A `LevelUpEvent` if the player levelled up or earned a new pass,
    ///            or `nil` if neither happened.
    @discardableResult
    static func record(_ result: GameResult) -> LevelUpEvent? {
        guard result.success else { return nil }

        var p = profile

        // Always accumulate lifetime score (not used for level-up gating)
        p.totalScore += result.score

        let key = String(result.levelId)

        // Best efficiency: update only when the new result strictly beats the previous best (for display).
        let previousBest = p.bestEfficiencyByLevel[key] ?? 0
        if result.efficiency > previousBest {
            p.bestEfficiencyByLevel[key] = result.efficiency
        }

        // Best weighted score: update only when the new score exceeds previous (for leaderboard).
        let previousBestScore = p.bestScoreByLevel[key] ?? 0
        if result.score > previousBestScore {
            p.bestScoreByLevel[key] = result.score
        }

        // Last score: always overwrite regardless of quality (for level-up gating).
        // This prevents farming: replaying an easy mission at 100% stays in the record
        // but replaying it later at 50% will reduce its contribution to level progress.
        p.lastEfficiencyByLevel[key] = result.efficiency

        // Level-up loop — handles the rare case where one result crosses multiple thresholds
        var levelsGained = 0
        while p.canLevelUp {
            p.level += 1
            levelsGained += 1
        }

        // Sector completion check — issue a pass when ALL missions in the completed level's
        // sector are done for the first time. This pass gates the next sector on the map.
        var newPass: PlanetPass? = nil
        if let sector = SpatialRegion.catalog.first(where: { $0.levelRange.contains(result.levelId) }) {
            let planetIdx = sector.id - 1
            if planetIdx < Planet.catalog.count,
               !PassStore.hasPass(for: planetIdx),
               sector.levels.allSatisfy({ p.hasCompleted(levelId: $0.id) }) {
                newPass = PassStore.issue(planet: Planet.catalog[planetIdx], profile: p)
            }
        }

        save(p)

        guard levelsGained > 0 || newPass != nil else { return nil }

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
        _isDevReset = true
        defer { _isDevReset = false }
        _cache = nil
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: backupKey)
    }

    /// Jump to a specific player level and re-issue passes for all earned planets.
    static func devSetLevel(_ targetLevel: Int) {
        var p = profile
        p.level = max(1, targetLevel)
        save(p)
        PassStore.reset()
        for planet in Planet.catalog where planet.requiredLevel <= p.level {
            PassStore.issue(planet: planet, profile: p)
        }
    }

    /// Clear mission history (both best and last efficiency maps) while keeping level/planet.
    static func devResetMissions() {
        var p = profile
        p.bestEfficiencyByLevel  = [:]
        p.lastEfficiencyByLevel  = [:]
        save(p)
    }

    /// Full factory reset — profile, passes, and mechanic announcements.
    static func devResetAll() {
        reset()
        PassStore.reset()
        MechanicUnlockStore.reset()
    }

    /// Mark every level in a sector as completed at 100% efficiency and issue its pass.
    /// Used by the dev QA scenario panel to simulate sector progression without manual play.
    static func devSimulateSectorComplete(_ sectorID: Int) {
        guard let sector = SpatialRegion.catalog.first(where: { $0.id == sectorID }) else { return }
        var p = profile

        // Stamp each level at 100% in both efficiency maps
        for level in sector.levels {
            let k = String(level.id)
            p.bestEfficiencyByLevel[k] = 1.0
            p.lastEfficiencyByLevel[k] = 1.0
        }

        // Run level-up loop (same as record())
        while p.canLevelUp { p.level += 1 }
        save(p)

        // Issue pass for the sector's planet if not already held
        let planetIdx = sectorID - 1
        guard planetIdx < Planet.catalog.count else { return }
        PassStore.issue(planet: Planet.catalog[planetIdx], profile: p)
    }

    /// Issue passes for every sector whose levels are all completed but has no pass yet.
    /// Repairs state that can occur after devResetMissions + re-play without re-issuing passes.
    static func devSyncPasses() {
        let p = profile
        for sector in SpatialRegion.catalog {
            let planetIdx = sector.id - 1
            guard planetIdx < Planet.catalog.count,
                  !PassStore.hasPass(for: planetIdx),
                  sector.levels.allSatisfy({ p.hasCompleted(levelId: $0.id) }) else { continue }
            PassStore.issue(planet: Planet.catalog[planetIdx], profile: p)
        }
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
