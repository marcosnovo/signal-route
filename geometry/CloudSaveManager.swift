import Combine
import Foundation
import GameKit

// MARK: - CloudSavePayload
/// Everything needed to reconstruct the player's state on a fresh device.
/// Wraps AstronautProfile + PlanetPasses with a conflict-resolution timestamp.
struct CloudSavePayload: Codable {
    var profile:       AstronautProfile
    var passes:        [PlanetPass]
    var lastUpdated:   Date
    var schemaVersion: Int = 1
}

// MARK: - CloudSaveManager
///
/// Syncs player progress to/from Game Center's cloud save slot.
///
/// ## Rules
///   - `save()` encodes local state and uploads it.  No-op if GC is not authenticated.
///   - `load()` fetches the cloud slot and applies it when the cloud timestamp is newer
///     than the last sync.  Completions are always union-merged so no level is ever lost.
///   - Conflicts (multiple slots) are resolved by picking highest `lastUpdated`, then
///     union-merging completions from every conflicting slot.
///   - Falls back silently: local UserDefaults is always the canonical offline store.
///
/// ## Threading
///   All public methods are `async` and run on the `@MainActor` so published properties
///   update SwiftUI without explicit DispatchQueue.main hops.
@MainActor
final class CloudSaveManager: ObservableObject {

    static let shared = CloudSaveManager()

    private static let slotName    = "signal_route_progress"
    private static let syncDateKey = "cloudSave.lastSyncedAt"

    // MARK: Published state
    @Published private(set) var isSyncing:    Bool  = false
    @Published private(set) var lastSyncedAt: Date? = {
        UserDefaults.standard.object(forKey: CloudSaveManager.syncDateKey) as? Date
    }()

    private init() {}

    // MARK: - Public API

    /// Encode current local progress and upload to the cloud save slot.
    /// Skips silently when Game Center is not authenticated or a sync is already in flight.
    func save() async {
        guard GKLocalPlayer.local.isAuthenticated, !isSyncing else { return }

        let now = Date()
        let payload = CloudSavePayload(
            profile:     ProgressionStore.profile,
            passes:      PassStore.all,
            lastUpdated: now
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await gkSave(data: data)
            persistSyncDate(now)
            #if DEBUG
            print("[CloudSave] ✓ Saved — completions=\(payload.profile.uniqueCompletions)  at=\(now)")
            #endif
        } catch {
            #if DEBUG
            print("[CloudSave] ✗ Save failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Fetch the cloud save, merge with local data, and apply if the cloud is newer.
    /// Skips silently when Game Center is not authenticated or a sync is already in flight.
    func load() async {
        guard GKLocalPlayer.local.isAuthenticated, !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let all      = try await gkFetchSavedGames()
            let matching = all.filter { $0.name == Self.slotName }
            guard !matching.isEmpty else {
                #if DEBUG
                print("[CloudSave] No cloud save found")
                #endif
                return
            }
            if matching.count > 1 {
                await resolveConflict(matching)
            } else {
                await apply(matching[0])
            }
        } catch {
            #if DEBUG
            print("[CloudSave] ✗ Load failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Dev helpers

    #if DEBUG
    func devForceSave() { Task { await save() } }
    func devForceLoad() { Task { await load() } }
    #endif

    // MARK: - Private — apply

    private func apply(_ game: GKSavedGame) async {
        do {
            let data    = try await gkLoadData(game)
            var payload = try JSONDecoder().decode(CloudSavePayload.self, from: data)

            // Only apply when cloud is strictly newer than our last sync
            let knownDate = lastSyncedAt ?? .distantPast
            guard payload.lastUpdated > knownDate else {
                #if DEBUG
                print("[CloudSave] Local up-to-date (local=\(knownDate)  cloud=\(payload.lastUpdated)) — skipped")
                #endif
                return
            }

            mergeLocalInto(&payload)
            applyLocally(payload)

            #if DEBUG
            print("[CloudSave] ✓ Applied cloud save  completions=\(payload.profile.uniqueCompletions)  at=\(payload.lastUpdated)")
            #endif
        } catch {
            #if DEBUG
            print("[CloudSave] ✗ Apply failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func resolveConflict(_ games: [GKSavedGame]) async {
        // Load all saves; select the one with the highest lastUpdated as the winner
        var candidates: [(GKSavedGame, CloudSavePayload)] = []
        for game in games {
            guard let data    = try? await gkLoadData(game),
                  let payload = try? JSONDecoder().decode(CloudSavePayload.self, from: data)
            else { continue }
            candidates.append((game, payload))
        }
        guard !candidates.isEmpty else { return }

        candidates.sort { $0.1.lastUpdated > $1.1.lastUpdated }
        var (_, winner) = candidates[0]

        // Union-merge completions from every conflicting save into the winner
        for (_, other) in candidates.dropFirst() {
            for (k, v) in other.profile.bestEfficiencyByLevel {
                let best = winner.profile.bestEfficiencyByLevel[k] ?? 0
                winner.profile.bestEfficiencyByLevel[k] = max(v, best)
            }
        }
        while winner.profile.canLevelUp { winner.profile.level += 1 }

        guard let mergedData = try? JSONEncoder().encode(winner) else { return }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                GKLocalPlayer.local.resolveConflictingSavedGames(games, with: mergedData) { _, error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
            mergeLocalInto(&winner)
            applyLocally(winner)
            #if DEBUG
            print("[CloudSave] ✓ Conflict resolved — applied merged save  completions=\(winner.profile.uniqueCompletions)")
            #endif
        } catch {
            #if DEBUG
            print("[CloudSave] ✗ Conflict resolution failed — applying winner directly")
            #endif
            applyLocally(winner)
        }
    }

    // MARK: - Private — helpers

    /// Union-merge the local profile's completions into `payload` so no level is ever lost.
    private func mergeLocalInto(_ payload: inout CloudSavePayload) {
        let local = ProgressionStore.profile
        for (k, v) in local.bestEfficiencyByLevel {
            let existing = payload.profile.bestEfficiencyByLevel[k] ?? 0
            payload.profile.bestEfficiencyByLevel[k] = max(v, existing)
        }
        for (k, v) in local.lastEfficiencyByLevel where payload.profile.lastEfficiencyByLevel[k] == nil {
            payload.profile.lastEfficiencyByLevel[k] = v
        }
        // Re-run level-up in case merged completions push level higher
        while payload.profile.canLevelUp { payload.profile.level += 1 }
    }

    private func applyLocally(_ payload: CloudSavePayload) {
        ProgressionStore.save(payload.profile)
        PassStore.restore(payload.passes)
        persistSyncDate(payload.lastUpdated)
    }

    private func persistSyncDate(_ date: Date) {
        lastSyncedAt = date
        UserDefaults.standard.set(date, forKey: Self.syncDateKey)
    }

    // MARK: - GK async wrappers

    private func gkSave(data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            GKLocalPlayer.local.saveGameData(data, withName: Self.slotName) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    private func gkFetchSavedGames() async throws -> [GKSavedGame] {
        try await withCheckedThrowingContinuation { cont in
            GKLocalPlayer.local.fetchSavedGames { games, error in
                if let error { cont.resume(throwing: error) }
                else         { cont.resume(returning: games ?? []) }
            }
        }
    }

    private func gkLoadData(_ game: GKSavedGame) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            game.loadData { data, error in
                if let error     { cont.resume(throwing: error) }
                else if let data { cont.resume(returning: data) }
                else             { cont.resume(throwing: CloudSaveError.noData) }
            }
        }
    }

    enum CloudSaveError: Error { case noData }
}
