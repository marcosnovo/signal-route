import Foundation

// MARK: - OnboardingStore
/// Persists first-launch and narrative state.
///
/// Step order:
///   1. Narrative intro panels (hasSeenNarrativeIntro)
///   2. Gameplay onboarding mission (hasCompletedIntro)
///
/// Both flags must be set before the player reaches Home on launch.
enum OnboardingStore {
    private static let introKey     = "hasCompletedIntro"
    private static let narrativeKey = "hasSeenNarrativeIntro"

    // ── Gameplay onboarding (intro mission) ───────────────────────────────

    /// True once the intro mission has been won.
    static var hasCompletedIntro: Bool {
        UserDefaults.standard.bool(forKey: introKey)
    }

    /// Call after the intro mission is won.
    static func markIntroCompleted() {
        UserDefaults.standard.set(true, forKey: introKey)
    }

    // ── Narrative intro panels ────────────────────────────────────────────

    /// True once the player has seen the 4-panel story intro.
    static var hasSeenNarrativeIntro: Bool {
        UserDefaults.standard.bool(forKey: narrativeKey)
    }

    /// Call after the narrative panels are dismissed (skip or complete).
    static func markNarrativeSeen() {
        UserDefaults.standard.set(true, forKey: narrativeKey)
    }

    // ── Dev / testing ─────────────────────────────────────────────────────

    /// Resets both flags — next launch shows narrative intro + gameplay onboarding.
    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: introKey)
        UserDefaults.standard.removeObject(forKey: narrativeKey)
    }
}
