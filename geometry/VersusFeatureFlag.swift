import Foundation

// MARK: - VersusFeatureFlag
/// Master gate for all Versus mode UI and functionality.
///
/// - **DEBUG builds:** togglable via DevMenu (persisted in UserDefaults).
/// - **RELEASE builds:** hardcoded OFF — the compiler strips the entire code path.
///
/// Every versus entry point checks `VersusFeatureFlag.isEnabled` before rendering.
enum VersusFeatureFlag {

    private static let key = "versus.enabled"

    /// True when Versus mode is active and should be exposed in the UI.
    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }

    /// Toggle the flag (DEBUG only — no-op in RELEASE).
    static func setEnabled(_ on: Bool) {
        #if DEBUG
        UserDefaults.standard.set(on, forKey: key)
        #endif
    }
}
