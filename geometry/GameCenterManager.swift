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

    /// When GK requires a login UI, this holds the view controller to present.
    @Published var presentationViewController: UIViewController? = nil

    private init() {}

    // MARK: - Authenticate
    /// Call once at app launch or Home entry. Safe to call multiple times — GK is idempotent.
    func authenticate() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }

            if let vc = viewController {
                // GK wants to show a sign-in sheet
                self.presentationViewController = vc
                return
            }

            // Clear any pending presentation
            self.presentationViewController = nil

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
