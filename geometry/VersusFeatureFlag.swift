import Foundation

// MARK: - VersusFeatureFlag
/// Granular feature flags for Versus mode. Every flag is OFF by default.
///
/// ## DEBUG builds
///   All flags are individually togglable via DevMenu (persisted in UserDefaults).
///   Turning a flag ON logs the state change.
///
/// ## RELEASE builds (TestFlight)
///   All flags are toggleable via DevMenu, same as DEBUG.
///   Logging is suppressed (print statements compiled out).
///
/// ## Flag Hierarchy
///   `isEnabled` is the master gate. Other flags require it:
///   - `isVisibleInHome` requires `isEnabled`
///   - `isMatchmakingAllowed` requires `isEnabled`
///
/// ## Entry Points Gated
///   - **HomeView "VERSUS 1v1" button** → `isVisibleInHome`
///   - **VersusMatchmakingManager.findMatch()** → `isMatchmakingAllowed`
///   - **DevMenu versus panel** → `isEnabled` (always accessible for dev testing)
///   - **Deep links** → no `signalvoid://versus` route exists
enum VersusFeatureFlag {

    // MARK: - Storage keys

    private static let keyEnabled      = "versus.enabled"
    private static let keyVisible      = "versus.visibleInHome"
    private static let keyMatchmaking  = "versus.allowMatchmaking"

    // MARK: - Flags

    /// Master gate — all versus functionality depends on this.
    /// When OFF: no UI, no matchmaking, no network, no state.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: keyEnabled)
    }

    /// Whether the "VERSUS 1v1" button appears in HomeView.
    /// Requires `isEnabled`. When OFF, versus is only accessible via DevMenu.
    static var isVisibleInHome: Bool {
        isEnabled && UserDefaults.standard.bool(forKey: keyVisible)
    }

    /// Whether GKMatchmaker.findMatch() is allowed.
    /// Requires `isEnabled`. When OFF, the lobby UI renders but matchmaking is blocked.
    static var isMatchmakingAllowed: Bool {
        isEnabled && UserDefaults.standard.bool(forKey: keyMatchmaking)
    }

    /// True when versus is enabled but NOT shown in Home — dev-only access via DevMenu.
    static var isDevOnly: Bool {
        isEnabled && !isVisibleInHome
    }

    // MARK: - Setters

    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: keyEnabled)
        // When master flag turns OFF, cascade all sub-flags OFF
        if !on {
            UserDefaults.standard.set(false, forKey: keyVisible)
            UserDefaults.standard.set(false, forKey: keyMatchmaking)
        }
        log("isEnabled → \(on)")
    }

    static func setVisibleInHome(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: keyVisible)
        log("isVisibleInHome → \(on) (requires isEnabled=\(isEnabled))")
    }

    static func setMatchmakingAllowed(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: keyMatchmaking)
        log("isMatchmakingAllowed → \(on) (requires isEnabled=\(isEnabled))")
    }

    // MARK: - Logging

    static func log(_ message: String) {
        #if DEBUG
        print("[VersusFlag] \(message)")
        #endif
    }

    /// Logs the full flag state — call from DevMenu or on app launch.
    static func logCurrentState() {
        #if DEBUG
        print("[VersusFlag] ──────────────────────────")
        print("[VersusFlag] isEnabled           = \(isEnabled)")
        print("[VersusFlag] isVisibleInHome     = \(isVisibleInHome)")
        print("[VersusFlag] isMatchmakingAllowed = \(isMatchmakingAllowed)")
        print("[VersusFlag] isDevOnly           = \(isDevOnly)")
        print("[VersusFlag] ──────────────────────────")
        #endif
    }
}
