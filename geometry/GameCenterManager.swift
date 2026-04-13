import Combine
import GameKit

// MARK: - GameCenterManager
/// Manages Game Center authentication and exposes player state to SwiftUI.
/// Authentication is non-blocking — the app works fully without it.
@MainActor
final class GameCenterManager: ObservableObject {

    static let shared = GameCenterManager()

    // MARK: Published state
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var isGameCenterEnabled: Bool = false

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
            } else {
                self.isAuthenticated = false
                self.isGameCenterEnabled = false
                self.displayName = ""
                if let error { print("[GameCenter] Auth failed: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Open Game Center dashboard
    /// Uses GKAccessPoint to present the dashboard — the modern API for iOS 14+.
    func openDashboard() {
        GKAccessPoint.shared.trigger { }
    }
}
