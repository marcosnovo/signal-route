import Foundation

// MARK: - FrustrationGuard
/// Determines whether the player is currently in a frustrated state.
///
/// Used to gate the automatic paywall auto-show and to shift copy tone.
/// Does NOT influence puzzle difficulty or game mechanics — purely an
/// emotional-state signal for the monetization layer.
///
/// ## Ethics contract
/// Frustration is NEVER engineered to drive upgrades.
/// This guard exists to PREVENT paywall from firing at a bad moment,
/// not to create artificial urgency or exploit negative emotions.
///
/// ## Thresholds
///   ≥ 3 losses in the current session → `isFrustrated`
///   playerSkillScore < 0.35           → `isFrustrated`
///   Both conditions together          → `isHighlyFrustrated` (stricter tone shift)
enum FrustrationGuard {

    // MARK: - State

    /// True if the player is showing signs of frustration this session.
    static func isFrustrated() -> Bool {
        SessionTracker.shared.failuresInSession >= 3
            || PlayerSkillTracker.shared.skillScore < 0.35
    }

    /// True when frustration signals are strong — both failure count AND low skill.
    /// Used for a stronger tone shift in paywall copy.
    static func isHighlyFrustrated() -> Bool {
        SessionTracker.shared.failuresInSession >= 3
            && PlayerSkillTracker.shared.skillScore < 0.35
    }

    // MARK: - Gate

    /// Returns true if the automatic post-win paywall should be deferred.
    ///
    /// When true, `firePendingPaywallIfReady()` skips the auto-show.
    /// The paywall is NOT cancelled — it fires later when the player
    /// explicitly taps "Next Mission" or navigates from the map.
    /// That tap is an intent signal, which overrides the frustration state.
    static func shouldDeferAutoPaywall() -> Bool {
        isFrustrated()
    }
}
