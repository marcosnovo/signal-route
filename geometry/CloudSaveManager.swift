import Combine
import Foundation
import GameKit

// MARK: - EntitlementSnapshot
/// A Codable snapshot of the player's entitlement state for cloud sync.
///
/// Does NOT include device-specific monotonic uptime fields (`cooldownArmedUptime`,
/// `dailyWindowStartUptime`) — those are meaningless on a different device.
/// The receiving device clears them and falls back to wall-clock-only verification.
struct EntitlementSnapshot: Codable {
    var isPremium:          Bool
    var premiumByCode:      Bool
    var activeCodeID:       String?
    var freeIntroCompleted: Int
    var dailyPlaysUsed:     Int
    var nextPlayableDate:   Date?
    var dailyWindowStart:   Date?
}

// MARK: - OnboardingSnapshot
/// A Codable snapshot of the player's onboarding flags for cloud sync.
/// All fields are monotonic — once true, they must never revert.
struct OnboardingSnapshot: Codable {
    var hasCompletedIntro:     Bool
    var hasSeenNarrativeIntro: Bool
    var hasShownFirstHook:     Bool
    var hasSeenTutorialDialog: Bool = false
}

// MARK: - CloudSavePayload
/// Everything needed to reconstruct the player's state on a fresh device.
/// Wraps AstronautProfile + PlanetPasses + EntitlementSnapshot with a conflict-resolution timestamp.
struct CloudSavePayload: Codable {
    var profile:       AstronautProfile
    var passes:        [PlanetPass]
    var lastUpdated:   Date
    var schemaVersion: Int = 4
    /// Entitlement state — nil when decoding a v1 payload (backward compatible).
    var entitlement:       EntitlementSnapshot?
    /// Onboarding flags — nil when decoding a v1/v2 payload.
    var onboarding:        OnboardingSnapshot?
    /// Announced mechanic rawValues — nil when decoding a v1/v2 payload.
    var mechanicUnlocks:   [String]?
    /// Story beat IDs the player has dismissed — nil when decoding a v1/v2/v3 payload.
    var storySeenIDs:      [String]?
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
            profile:         ProgressionStore.profile,
            passes:          PassStore.all,
            lastUpdated:     now,
            entitlement:     EntitlementStore.shared.currentSnapshot,
            onboarding:      OnboardingStore.currentSnapshot,
            mechanicUnlocks: MechanicUnlockStore.announcedRawValues,
            storySeenIDs:    Array(StoryStore.seenIDs).sorted()
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

        // Union-merge completions, entitlement, onboarding, and mechanics from every conflicting save
        for (_, other) in candidates.dropFirst() {
            Self.mergeProfiles(local: other.profile, into: &winner.profile)
            if let otherEnt = other.entitlement, let winnerEnt = winner.entitlement {
                winner.entitlement = Self.mergeEntitlements(local: winnerEnt, cloud: otherEnt)
            } else if let otherEnt = other.entitlement {
                winner.entitlement = otherEnt
            }
            if let otherOnb = other.onboarding, let winnerOnb = winner.onboarding {
                winner.onboarding = Self.mergeOnboarding(local: winnerOnb, cloud: otherOnb)
            } else if let otherOnb = other.onboarding {
                winner.onboarding = otherOnb
            }
            if let otherMech = other.mechanicUnlocks, let winnerMech = winner.mechanicUnlocks {
                winner.mechanicUnlocks = Self.mergeMechanicUnlocks(local: winnerMech, cloud: otherMech)
            } else if let otherMech = other.mechanicUnlocks {
                winner.mechanicUnlocks = otherMech
            }
            if let otherSeen = other.storySeenIDs, let winnerSeen = winner.storySeenIDs {
                winner.storySeenIDs = Self.mergeStorySeenIDs(local: winnerSeen, cloud: otherSeen)
            } else if let otherSeen = other.storySeenIDs {
                winner.storySeenIDs = otherSeen
            }
        }

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

    // MARK: - Monotonic entitlement merge (pure, testable)

    /// Monotonically merge two entitlement snapshots so that the result is always
    /// the "most restrictive" state — premium never downgrades, cooldowns never shorten,
    /// intro counter never regresses.
    ///
    /// **Cooldown merge — "most restrictive wins":**
    ///   - If either side has `nextPlayableDate != nil`, keep the one expiring LATER.
    ///   - If both nil: take `max(dailyPlaysUsed)` + the later `dailyWindowStart`.
    ///
    /// This is a pure function with no side effects — safe for unit testing.
    nonisolated static func mergeEntitlements(
        local: EntitlementSnapshot,
        cloud: EntitlementSnapshot
    ) -> EntitlementSnapshot {
        // Premium: OR — never lose premium (StoreKit listener re-verifies/revokes independently)
        let premium = local.isPremium || cloud.isPremium
        let byCode  = local.premiumByCode || cloud.premiumByCode
        let code    = local.activeCodeID ?? cloud.activeCodeID

        // Intro: max — you can't un-play intro sessions
        let intro = max(local.freeIntroCompleted, cloud.freeIntroCompleted)

        // Cooldown group: most restrictive wins
        let plays:       Int
        let playDate:    Date?
        let windowStart: Date?

        switch (local.nextPlayableDate, cloud.nextPlayableDate) {
        case let (l?, c?):
            // Both have an active cooldown — keep the one expiring later
            if l >= c {
                plays       = local.dailyPlaysUsed
                playDate    = l
                windowStart = local.dailyWindowStart
            } else {
                plays       = cloud.dailyPlaysUsed
                playDate    = c
                windowStart = cloud.dailyWindowStart
            }
        case let (l?, nil):
            // Only local has cooldown — keep it
            plays       = local.dailyPlaysUsed
            playDate    = l
            windowStart = local.dailyWindowStart
        case let (nil, c?):
            // Only cloud has cooldown — adopt it
            plays       = cloud.dailyPlaysUsed
            playDate    = c
            windowStart = cloud.dailyWindowStart
        case (nil, nil):
            // Neither has cooldown — take max plays + later window
            plays = max(local.dailyPlaysUsed, cloud.dailyPlaysUsed)
            if let lw = local.dailyWindowStart, let cw = cloud.dailyWindowStart {
                windowStart = lw >= cw ? lw : cw
            } else {
                windowStart = local.dailyWindowStart ?? cloud.dailyWindowStart
            }
            playDate = nil
        }

        return EntitlementSnapshot(
            isPremium:          premium,
            premiumByCode:      byCode,
            activeCodeID:       code,
            freeIntroCompleted: intro,
            dailyPlaysUsed:     plays,
            nextPlayableDate:   playDate,
            dailyWindowStart:   windowStart
        )
    }

    // MARK: - Monotonic onboarding merge (pure, testable)

    /// OR-merge two onboarding snapshots — once a flag is true it never reverts.
    nonisolated static func mergeOnboarding(
        local: OnboardingSnapshot,
        cloud: OnboardingSnapshot
    ) -> OnboardingSnapshot {
        OnboardingSnapshot(
            hasCompletedIntro:     local.hasCompletedIntro     || cloud.hasCompletedIntro,
            hasSeenNarrativeIntro: local.hasSeenNarrativeIntro || cloud.hasSeenNarrativeIntro,
            hasShownFirstHook:     local.hasShownFirstHook     || cloud.hasShownFirstHook,
            hasSeenTutorialDialog: local.hasSeenTutorialDialog || cloud.hasSeenTutorialDialog
        )
    }

    // MARK: - Monotonic mechanic-unlock merge (pure, testable)

    /// Union-merge two mechanic-unlock sets — once announced, never unannounced.
    nonisolated static func mergeMechanicUnlocks(
        local: [String],
        cloud: [String]
    ) -> [String] {
        Array(Set(local).union(cloud)).sorted()
    }

    // MARK: - Monotonic story-seen merge (pure, testable)

    /// Union-merge two story-seen-ID sets — once seen, never unseen.
    nonisolated static func mergeStorySeenIDs(
        local: [String],
        cloud: [String]
    ) -> [String] {
        Array(Set(local).union(cloud)).sorted()
    }

    // MARK: - Private — helpers

    /// Union-merge local profile, entitlement, onboarding, and mechanics into `payload`
    /// so no progress is ever lost and no state regresses.
    private func mergeLocalInto(_ payload: inout CloudSavePayload) {
        let local = ProgressionStore.profile
        Self.mergeProfiles(local: local, into: &payload.profile)

        // Merge entitlement state: local always has a snapshot; payload may not (v1)
        let localEnt = EntitlementStore.shared.currentSnapshot
        if let cloudEnt = payload.entitlement {
            payload.entitlement = Self.mergeEntitlements(local: localEnt, cloud: cloudEnt)
        } else {
            payload.entitlement = localEnt
        }

        // Merge onboarding: OR-merge local vs cloud
        let localOnb = OnboardingStore.currentSnapshot
        if let cloudOnb = payload.onboarding {
            payload.onboarding = Self.mergeOnboarding(local: localOnb, cloud: cloudOnb)
        } else {
            payload.onboarding = localOnb
        }

        // Merge mechanic unlocks: union-merge local vs cloud
        let localMech = MechanicUnlockStore.announcedRawValues
        if let cloudMech = payload.mechanicUnlocks {
            payload.mechanicUnlocks = Self.mergeMechanicUnlocks(local: localMech, cloud: cloudMech)
        } else {
            payload.mechanicUnlocks = localMech
        }

        // Merge story seen IDs: union-merge local vs cloud
        let localSeen = Array(StoryStore.seenIDs).sorted()
        if let cloudSeen = payload.storySeenIDs {
            payload.storySeenIDs = Self.mergeStorySeenIDs(local: localSeen, cloud: cloudSeen)
        } else {
            payload.storySeenIDs = localSeen
        }
    }

    // MARK: - Monotonic profile merge (pure, testable)

    /// Monotonically merge `local` into `cloud` so that every per-level score and
    /// every scalar counter in `cloud` is ≥ the maximum of the two inputs.
    ///
    /// **Invariant:** a merge never downgrades player progress.
    ///
    /// This is a pure function with no side effects — safe for unit testing.
    nonisolated static func mergeProfiles(local: AstronautProfile, into cloud: inout AstronautProfile) {
        // bestEfficiencyByLevel: take max from both sides
        for (k, v) in local.bestEfficiencyByLevel {
            cloud.bestEfficiencyByLevel[k] = max(v, cloud.bestEfficiencyByLevel[k] ?? 0)
        }
        // lastEfficiencyByLevel: take max from both sides (never regress gating progress)
        for (k, v) in local.lastEfficiencyByLevel {
            cloud.lastEfficiencyByLevel[k] = max(v, cloud.lastEfficiencyByLevel[k] ?? 0)
        }
        // bestScoreByLevel: take max from both sides (cumulative leaderboard)
        for (k, v) in local.bestScoreByLevel {
            cloud.bestScoreByLevel[k] = max(v, cloud.bestScoreByLevel[k] ?? 0)
        }
        // Scalar counters: always take the higher value
        cloud.totalScore = max(local.totalScore, cloud.totalScore)
        // Level: cascade from merged data, then take the higher of cascaded vs local
        while cloud.canLevelUp { cloud.level += 1 }
        cloud.level = max(local.level, cloud.level)
    }

    private func applyLocally(_ payload: CloudSavePayload) {
        // Safety: never overwrite a richer local profile with a poorer cloud one.
        let local = ProgressionStore.profile
        if local.uniqueCompletions > payload.profile.uniqueCompletions {
            print("[CloudSave] ⚠ Skipped profile apply — local has \(local.uniqueCompletions) completions, cloud has \(payload.profile.uniqueCompletions)")
        } else {
            ProgressionStore.save(payload.profile)
        }
        PassStore.restore(payload.passes)
        if let cloudEnt = payload.entitlement {
            EntitlementStore.shared.applyCloudState(cloudEnt)
        }
        if let cloudOnb = payload.onboarding {
            OnboardingStore.applyCloudState(cloudOnb)
        }
        if let cloudMech = payload.mechanicUnlocks {
            MechanicUnlockStore.applyCloudState(cloudMech)
        }
        if let cloudSeen = payload.storySeenIDs {
            StoryStore.applyCloudState(cloudSeen)
        }
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
