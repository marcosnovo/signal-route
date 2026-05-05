import Combine
import GameKit
import UIKit

// MARK: - GameCenterManager
/// Manages Game Center authentication, avatar, leaderboard submission, and dashboard presentation.
/// Authentication is non-blocking — the app works fully without it.
@MainActor
final class GameCenterManager: ObservableObject {

    static let shared = GameCenterManager()

    // ── Leaderboard IDs (configured in App Store Connect) ─────────────────
    private static let prefix = "com.marcosnovo.signalvoidgame.leaderboard"
    static let leaderboardTotalScore = "\(prefix).total_score.v2"
    static let leaderboardTierEasy   = "\(prefix).tier_easy"
    static let leaderboardTierMedium = "\(prefix).tier_medium"
    static let leaderboardTierHard   = "\(prefix).tier_hard"
    static let leaderboardTierExpert = "\(prefix).tier_expert"
    static let leaderboardDailyChallenge  = "\(prefix).daily_challenge"
    static let leaderboardDailyCumulative = "\(prefix).daily_cumulative"
    static let leaderboardVersus          = "\(prefix).versus"

    // MARK: Published state
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var isGameCenterEnabled: Bool = false
    /// Real Game Center avatar. Loaded once after authentication and cached in memory.
    @Published private(set) var playerAvatar: UIImage? = nil
    /// Post-win rank feedback. Set after a score is submitted and the player's rank is loaded.
    /// Cleared when a new game starts.
    @Published private(set) var rankFeedback: RankFeedback? = nil
    /// Last score submitted to the leaderboard (0–1000 scale). Nil before any submission.
    @Published private(set) var lastSubmittedScore: Int? = nil
    /// Number of challenge definitions that have at least one active challenge.
    @Published private(set) var activeChallengeCount: Int = 0

    // MARK: - Rank feedback
    enum RankFeedback: Equatable {
        case newRecord              // rank #1
        case topPercent(Int)        // top N% — N is 10, 25, or 50
        case ranked(Int)            // raw rank number
    }

    // Retains the GKGameCenterControllerDelegate so it is not released mid-presentation.
    private let leaderboardDismissDelegate = LeaderboardDismissDelegate()

    private init() {}

    // MARK: - Authenticate
    /// Call once at app launch or Home entry. Safe to call multiple times — GK is idempotent.
    func authenticate() {
        // Prevent GameKit's access-point overlay from auto-showing at launch.
        // On some real-device configs the GKGameOverlayUI remote proxy fails to
        // start and leaves a black UIWindow in the hierarchy — disabling the
        // access point before authentication silences that race condition.
        GKAccessPoint.shared.isActive = false

        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] _, error in
            guard let self else { return }
            // On iOS 14+ GameKit presents its own auth UI without the app
            // needing to present the view controller. Just check auth state.
            if player.isAuthenticated {
                self.isAuthenticated = true
                self.isGameCenterEnabled = true
                self.displayName = player.displayName
                self.loadAvatar()
                // Pull cloud save, then catch up any leaderboard scores that
                // may have been missed (offline wins, failed submissions, migrations).
                Task {
                    await CloudSaveManager.shared.load()
                    // Recalibrate scores after cloud merge (v1.0 scoring bug fix).
                    // Cloud merge takes max(local, cloud) which can restore inflated scores.
                    var profile = ProgressionStore.profile
                    if profile.recalibrateScoresIfNeeded() {
                        ProgressionStore.save(profile)
                    }
                    guard profile.leaderboardScore > 0 else { return }
                    await self.submitAllScores(profile: profile)
                    // Catch up daily cumulative leaderboard — use the max of both
                    // sources since UserDefaults and profile can be out of sync
                    // (e.g. reinstall, cloud restore, migration).
                    let cumulative = max(DailyStore.cumulativeScore, profile.dailyCumulativeScore)
                    if cumulative > 0 {
                        // Sync DailyStore if profile has a higher value
                        if profile.dailyCumulativeScore > DailyStore.cumulativeScore {
                            UserDefaults.standard.set(profile.dailyCumulativeScore, forKey: "daily-cumulative-score")
                        }
                        await self.submitDailyScores(dailyScore: 0, cumulativeDaily: cumulative, profile: profile)
                    }
                }
            } else {
                self.isAuthenticated = false
                self.isGameCenterEnabled = false
                self.displayName = ""
                self.playerAvatar = nil
                if let error { print("[GameCenter] Auth failed: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Avatar
    /// Fetches the small Game Center avatar and caches it. No-op if already loaded.
    func loadAvatar() {
        guard playerAvatar == nil else { return }
        GKLocalPlayer.local.loadPhoto(for: .small) { [weak self] image, error in
            DispatchQueue.main.async {
                if let image {
                    self?.playerAvatar = image
                }
                if let error {
                    print("[GameCenter] Avatar load failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Open Game Center dashboard
    /// Presents the Game Center dashboard from the topmost view controller.
    /// Uses GKGameCenterViewController for reliable presentation regardless of GKAccessPoint state.
    func openDashboard() {
        guard isAuthenticated else { return }
        guard let topVC = topPresentedViewController() else { return }
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = leaderboardDismissDelegate
        topVC.present(vc, animated: true)
    }

    // MARK: - Leaderboard — submit

    /// Submit the player's scores to all 5 leaderboards (total + 4 tier-specific).
    /// Also loads the player's rank and updates `rankFeedback` for the victory screen.
    /// No-op if Game Center is not authenticated.
    func submitAllScores(profile: AstronautProfile) async {
        guard isAuthenticated else { return }
        rankFeedback = nil

        let total  = profile.leaderboardScore
        lastSubmittedScore = total

        let submissions: [(Int, [String])] = [
            (total,                               [Self.leaderboardTotalScore]),
            (profile.tierScore(for: .easy),       [Self.leaderboardTierEasy]),
            (profile.tierScore(for: .medium),     [Self.leaderboardTierMedium]),
            (profile.tierScore(for: .hard),       [Self.leaderboardTierHard]),
            (profile.tierScore(for: .expert),     [Self.leaderboardTierExpert]),
        ]

        for (score, ids) in submissions where score > 0 {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: ids
                )
                #if DEBUG
                print("[GameCenter] ✓ Submitted \(score) → \(ids.first ?? "?")")
                #endif
            } catch {
                #if DEBUG
                print("[GameCenter] ✗ Score submit failed for \(ids): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("[GameCenter] ✓ All submissions done — total=\(total)")
        #endif

        await loadRankFeedback()
    }

    /// Submit daily challenge scores: today's score, cumulative daily total, and updated total score.
    /// Called after a daily challenge win.
    func submitDailyScores(dailyScore: Int, cumulativeDaily: Int, profile: AstronautProfile) async {
        guard isAuthenticated else { return }

        let submissions: [(Int, [String])] = [
            (dailyScore,               [Self.leaderboardDailyChallenge]),
            (cumulativeDaily,          [Self.leaderboardDailyCumulative]),
        ]

        for (score, ids) in submissions where score > 0 {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: ids
                )
                #if DEBUG
                print("[GameCenter] ✓ Daily submitted \(score) → \(ids.first ?? "?")")
                #endif
            } catch {
                #if DEBUG
                print("[GameCenter] ✗ Daily score submit failed for \(ids): \(error.localizedDescription)")
                #endif
            }
        }

        await loadRankFeedback(leaderboardID: Self.leaderboardDailyChallenge)
    }

    /// Submit cumulative versus score.
    func submitVersusScore(_ score: Int) async {
        guard isAuthenticated, score > 0 else { return }
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardVersus]
            )
            #if DEBUG
            print("[GameCenter] ✓ Versus score submitted: \(score)")
            #endif
        } catch {
            #if DEBUG
            print("[GameCenter] ✗ Versus score submit failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Clear stale rank feedback (call when a new game session starts).
    func clearRankFeedback() { rankFeedback = nil }

    // MARK: - Leaderboard — present

    /// Present the leaderboard for `leaderboardID` from the topmost view controller.
    ///
    /// If the user is not authenticated, triggers the GK authentication flow instead —
    /// the leaderboard will be openable once they sign in.
    func openLeaderboards(leaderboardID: String = leaderboardTotalScore) {
        guard isAuthenticated else {
            authenticate()
            return
        }
        guard let topVC = topPresentedViewController() else { return }
        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope:   .global,
            timeScope:     .allTime
        )
        vc.gameCenterDelegate = leaderboardDismissDelegate
        topVC.present(vc, animated: true)
    }

    // MARK: - Challenges

    func openChallenges() {
        guard isAuthenticated else { return }
        guard let topVC = topPresentedViewController() else { return }
        let vc = GKGameCenterViewController(state: .challenges)
        vc.gameCenterDelegate = leaderboardDismissDelegate
        topVC.present(vc, animated: true)
    }

    // MARK: - Private — VC presentation

    /// Returns the topmost presented UIViewController in the key window hierarchy.
    ///
    /// SwiftUI sheets and fullScreenCovers sit *above* the root UIHostingController.
    /// Presenting GKGameCenterViewController from the root when a sheet is already on screen
    /// causes layout artifacts and garbled text. Traversing to the top avoids this.
    private func topPresentedViewController() -> UIViewController? {
        guard let root = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return nil }
        return traverse(from: root)
    }

    private func traverse(from vc: UIViewController) -> UIViewController {
        // Stop at a VC that is currently being dismissed — presenting over it would crash.
        guard let next = vc.presentedViewController, !next.isBeingDismissed else {
            return vc
        }
        return traverse(from: next)
    }

    // MARK: - Leaderboard — fetch entries for in-app display

    struct LeaderboardData {
        let entries: [LeaderboardEntrySnapshot]
        let playerRank: Int?
        let totalPlayers: Int
    }

    func fetchLeaderboard(id: String, count: Int = 25) async -> LeaderboardData? {
        guard isAuthenticated else {
            print("[GameCenter] ⚠ fetchLeaderboard(\(id)) — not authenticated")
            return nil
        }
        do {
            let lbs = try await GKLeaderboard.loadLeaderboards(IDs: [id])
            guard let lb = lbs.first else {
                print("[GameCenter] ⚠ fetchLeaderboard(\(id)) — board not found in GC")
                return nil
            }
            let range = NSRange(1...count)
            let (localEntry, topEntries, total) = try await lb.loadEntries(
                for: .global, timeScope: .allTime, range: range
            )
            let localID = GKLocalPlayer.local.gamePlayerID
            var entries = topEntries.map { e in
                LeaderboardEntrySnapshot(
                    rank: e.rank,
                    displayName: e.player.displayName,
                    score: e.score,
                    isLocalPlayer: e.player.gamePlayerID == localID
                )
            }
            if let local = localEntry, !entries.contains(where: { $0.isLocalPlayer }) {
                entries.append(LeaderboardEntrySnapshot(
                    rank: local.rank,
                    displayName: local.player.displayName,
                    score: local.score,
                    isLocalPlayer: true
                ))
            }
            #if DEBUG
            print("[GameCenter] fetchLeaderboard(\(id)) — \(entries.count) entries, localRank=\(localEntry?.rank as Any), total=\(total)")
            #endif
            return LeaderboardData(
                entries: entries.sorted { $0.rank < $1.rank },
                playerRank: localEntry?.rank,
                totalPlayers: total
            )
        } catch {
            print("[GameCenter] ✗ fetchLeaderboard(\(id)) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Achievements — fetch for in-app display

    struct AchievementData: Identifiable {
        var id: String { identifier }
        let identifier: String
        let title: String
        let descriptionText: String
        let isCompleted: Bool
        let percentComplete: Double
        let image: UIImage?
        let isHidden: Bool
        let maximumPoints: Int
        let rarityPercent: Double?
        let isReplayable: Bool
    }

    func fetchAchievements() async -> [AchievementData] {
        guard isAuthenticated else { return [] }
        do {
            let descriptions = try await GKAchievementDescription.loadAchievementDescriptions()
            let progress = try await GKAchievement.loadAchievements()
            let progressMap = Dictionary(uniqueKeysWithValues: progress.map { ($0.identifier, $0) })

            struct AchievementInput: Sendable {
                let identifier: String
                let title: String
                let achievedDesc: String
                let unachievedDesc: String
                let completed: Bool
                let percent: Double
                let isHidden: Bool
                let maximumPoints: Int
                let rarityPercent: Double?
                let isReplayable: Bool
            }

            let inputs: [(AchievementInput, GKAchievementDescription)] = descriptions.map { desc in
                let ach = progressMap[desc.identifier]
                let completed = ach?.isCompleted ?? false
                return (AchievementInput(
                    identifier: desc.identifier,
                    title: desc.title,
                    achievedDesc: desc.achievedDescription,
                    unachievedDesc: desc.unachievedDescription,
                    completed: completed,
                    percent: ach?.percentComplete ?? 0,
                    isHidden: desc.isHidden && !completed,
                    maximumPoints: desc.maximumPoints,
                    rarityPercent: desc.rarityPercent,
                    isReplayable: desc.isReplayable
                ), desc)
            }

            var results: [AchievementData] = []
            for (input, desc) in inputs {
                if input.isHidden { continue }
                let img = try? await desc.loadImage()
                results.append(AchievementData(
                    identifier: input.identifier,
                    title: input.title,
                    descriptionText: input.completed ? input.achievedDesc : input.unachievedDesc,
                    isCompleted: input.completed,
                    percentComplete: input.percent,
                    image: img,
                    isHidden: false,
                    maximumPoints: input.maximumPoints,
                    rarityPercent: input.rarityPercent,
                    isReplayable: input.isReplayable
                ))
            }
            return results
        } catch {
            #if DEBUG
            print("[GameCenter] Achievements fetch failed: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Challenges — fetch definitions from App Store Connect

    struct ChallengeDefinitionData: Identifiable {
        var id: String { identifier }
        let identifier: String
        let title: String
        let details: String?
        let leaderboardTitle: String?
        let image: UIImage?
        let durationOptions: [DateComponents]
        let isRepeatable: Bool
        let hasActive: Bool
    }

    func fetchChallengeDefinitions() async -> [ChallengeDefinitionData] {
        guard isAuthenticated else { return [] }
        do {
            let defs = try await GKChallengeDefinition.all
            var results: [ChallengeDefinitionData] = []
            var activeCount = 0
            for def in defs {
                let active = (try? await def.hasActiveChallenges) ?? false
                if active { activeCount += 1 }
                let img = try? await def.image
                results.append(ChallengeDefinitionData(
                    identifier: def.identifier,
                    title: def.title,
                    details: def.details,
                    leaderboardTitle: def.leaderboard?.title,
                    image: img,
                    durationOptions: def.durationOptions,
                    isRepeatable: def.isRepeatable,
                    hasActive: active
                ))
            }
            activeChallengeCount = activeCount
            return results
        } catch {
            #if DEBUG
            print("[GameCenter] Challenge definitions fetch failed: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    func refreshActiveChallengeCount() async {
        guard isAuthenticated else { return }
        do {
            let defs = try await GKChallengeDefinition.all
            var count = 0
            for def in defs {
                if (try? await def.hasActiveChallenges) ?? false { count += 1 }
            }
            activeChallengeCount = count
        } catch {
            #if DEBUG
            print("[GameCenter] Active challenge count refresh failed: \(error.localizedDescription)")
            #endif
        }
    }

    func triggerChallenge(identifier: String) {
        guard isAuthenticated else { return }
        Task {
            await GKAccessPoint.shared.trigger(challengeDefinitionID: identifier)
        }
    }

    // MARK: - Private — rank loading

    private func loadRankFeedback(leaderboardID: String? = nil) async {
        let boardID = leaderboardID ?? Self.leaderboardTotalScore
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [boardID])
            guard let lb = boards.first else { return }

            let (localEntry, topEntries, total) = try await lb.loadEntries(
                for: .global, timeScope: .allTime, range: NSRange(1...5)
            )

            guard let entry = localEntry, total > 0 else { return }
            #if DEBUG
            print("[GameCenter] GC rank for \(boardID): score=\(entry.score) rank=\(entry.rank)/\(total)")
            #endif
            let rank = entry.rank

            rankFeedback = .ranked(rank)

            // Cache top-5 entries + rank for widget leaderboard (campaign only)
            if boardID == Self.leaderboardTotalScore {
                let localID = GKLocalPlayer.local.gamePlayerID
                let cached = topEntries.map { e in
                    LeaderboardEntrySnapshot(
                        rank: e.rank,
                        displayName: e.player.displayName,
                        score: e.score,
                        isLocalPlayer: e.player.gamePlayerID == localID
                    )
                }
                LeaderboardCache.update(entries: cached, playerRank: rank, totalPlayers: total)
                await MainActor.run {
                    ProgressionStore.pushWidgetSnapshot(ProgressionStore.profile)
                }
            }
        } catch {
            #if DEBUG
            print("[GameCenter] Rank load failed: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - LeaderboardDismissDelegate

/// Retains the GKGameCenterControllerDelegate lifetime separately so it is never nil
/// while the view controller is on screen.
private final class LeaderboardDismissDelegate: NSObject, GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
