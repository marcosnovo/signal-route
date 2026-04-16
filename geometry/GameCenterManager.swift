import Combine
import GameKit
import UIKit

// MARK: - GameCenterManager
/// Manages Game Center authentication, avatar, leaderboard submission, and dashboard presentation.
/// Authentication is non-blocking — the app works fully without it.
@MainActor
final class GameCenterManager: ObservableObject {

    static let shared = GameCenterManager()

    // ── Product constants ──────────────────────────────────────────────────
    static let leaderboardID = "signal_route_efficiency"

    // MARK: Published state
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var isGameCenterEnabled: Bool = false
    /// Real Game Center avatar. Loaded once after authentication and cached in memory.
    @Published private(set) var playerAvatar: UIImage? = nil
    /// Post-win rank feedback. Set after a score is submitted and the player's rank is loaded.
    /// Cleared when a new game starts.
    @Published private(set) var rankFeedback: RankFeedback? = nil

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
    /// Uses GKAccessPoint to present the dashboard — the modern API for iOS 14+.
    func openDashboard() {
        GKAccessPoint.shared.trigger { }
    }

    // MARK: - Leaderboard — submit

    /// Convert efficiency (0–1) to a 0–1000 integer leaderboard score and submit it.
    /// Also loads the player's rank and updates `rankFeedback` for the victory screen.
    /// No-op if Game Center is not authenticated.
    func submitScore(efficiency: Float) async {
        guard isAuthenticated else { return }
        rankFeedback = nil
        let score = Int((efficiency * 1000).rounded())

        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID]
            )
            #if DEBUG
            print("[GameCenter] ✓ Submitted score=\(score) to \(Self.leaderboardID)")
            #endif
            await loadRankFeedback()
        } catch {
            #if DEBUG
            print("[GameCenter] ✗ Score submit failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Clear stale rank feedback (call when a new game session starts).
    func clearRankFeedback() { rankFeedback = nil }

    // MARK: - Leaderboard — present

    /// Present the leaderboard sheet via UIKit. No-op if not authenticated.
    func openLeaderboards() {
        guard isAuthenticated else { return }
        guard let root = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        let vc = GKGameCenterViewController(
            leaderboardID:   Self.leaderboardID,
            playerScope:     .global,
            timeScope:       .allTime
        )
        vc.gameCenterDelegate = leaderboardDismissDelegate
        root.present(vc, animated: true)
    }

    // MARK: - Private — rank loading

    private func loadRankFeedback() async {
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID])
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
