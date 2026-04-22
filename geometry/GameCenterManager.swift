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
    static let leaderboardTotalScore = "\(prefix).total_score"
    static let leaderboardTierEasy   = "\(prefix).tier_easy"
    static let leaderboardTierMedium = "\(prefix).tier_medium"
    static let leaderboardTierHard   = "\(prefix).tier_hard"
    static let leaderboardTierExpert = "\(prefix).tier_expert"

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
                // Pull cloud save as soon as we're authenticated
                Task { await CloudSaveManager.shared.load() }
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
            } catch {
                #if DEBUG
                print("[GameCenter] ✗ Score submit failed for \(ids): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("[GameCenter] ✓ Submitted scores: total=\(total)")
        #endif

        await loadRankFeedback()
    }

    /// Clear stale rank feedback (call when a new game session starts).
    func clearRankFeedback() { rankFeedback = nil }

    // MARK: - Leaderboard — present

    /// Present the leaderboard for `leaderboardID` from the topmost view controller.
    ///
    /// If the user is not authenticated, triggers the GK authentication flow instead —
    /// the leaderboard will be openable once they sign in.
    func openLeaderboards() {
        guard isAuthenticated else {
            // Kick off sign-in; leaderboard can be opened once authenticated.
            authenticate()
            return
        }
        guard let topVC = topPresentedViewController() else { return }
        let vc = GKGameCenterViewController(
            leaderboardID: Self.leaderboardTotalScore,
            playerScope:   .global,
            timeScope:     .allTime
        )
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

    // MARK: - Private — rank loading

    private func loadRankFeedback() async {
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardTotalScore])
            guard let lb = boards.first else { return }

            // loadEntries(for:timeScope:range:) returns (localPlayerEntry, rangeEntries, totalCount)
            let (localEntry, _, total) = try await lb.loadEntries(
                for: .global, timeScope: .allTime, range: NSRange(1...1)
            )

            guard let entry = localEntry, total > 0 else { return }
            let rank       = entry.rank
            let percentile = Int(Double(rank) / Double(total) * 100)

            if rank == 1 {
                rankFeedback = .newRecord
            } else if percentile <= 10 {
                rankFeedback = .topPercent(10)
            } else if percentile <= 25 {
                rankFeedback = .topPercent(25)
            } else if percentile <= 50 {
                rankFeedback = .topPercent(50)
            } else {
                rankFeedback = .ranked(rank)
            }
        } catch {
            // Rank loading is best-effort — failure is silent
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
