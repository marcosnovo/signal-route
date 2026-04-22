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

    /// True once the player has seen the 2-panel story intro.
    static var hasSeenNarrativeIntro: Bool {
        UserDefaults.standard.bool(forKey: narrativeKey)
    }

    /// Call after the narrative panels are dismissed (skip or complete).
    static func markNarrativeSeen() {
        UserDefaults.standard.set(true, forKey: narrativeKey)
    }

    // ── First hook milestone (mission 8) ──────────────────────────────────

    private static let firstHookKey    = "hasShownFirstHook"
    private static let tutorialDialogKey = "hasSeenTutorialDialog"

    /// True once the mission-8 "SIGNAL ESTABLISHED" milestone has been displayed.
    static var hasShownFirstHook: Bool {
        UserDefaults.standard.bool(forKey: firstHookKey)
    }

    /// Call when the milestone overlay is shown — prevents it from appearing again.
    static func markFirstHookShown() {
        UserDefaults.standard.set(true, forKey: firstHookKey)
    }

    // ── Tutorial dialog (intro mission) ──────────────────────────────────

    /// True once the pre-game tutorial dialog has been shown.
    static var hasSeenTutorialDialog: Bool {
        UserDefaults.standard.bool(forKey: tutorialDialogKey)
    }

    /// Call when the tutorial dialog is dismissed.
    static func markTutorialDialogSeen() {
        UserDefaults.standard.set(true, forKey: tutorialDialogKey)
    }

    // ── Cloud sync ──────────────────────────────────────────────────────

    /// Current onboarding state as a Codable snapshot for cloud save.
    static var currentSnapshot: OnboardingSnapshot {
        OnboardingSnapshot(
            hasCompletedIntro:      hasCompletedIntro,
            hasSeenNarrativeIntro:  hasSeenNarrativeIntro,
            hasShownFirstHook:      hasShownFirstHook,
            hasSeenTutorialDialog:  hasSeenTutorialDialog
        )
    }

    /// Apply a merged onboarding snapshot from the cloud.
    /// Only sets flags to true — never reverts a true flag to false.
    static func applyCloudState(_ snapshot: OnboardingSnapshot) {
        if snapshot.hasCompletedIntro      && !hasCompletedIntro      { markIntroCompleted() }
        if snapshot.hasSeenNarrativeIntro   && !hasSeenNarrativeIntro { markNarrativeSeen() }
        if snapshot.hasShownFirstHook      && !hasShownFirstHook      { markFirstHookShown() }
        if snapshot.hasSeenTutorialDialog  && !hasSeenTutorialDialog  { markTutorialDialogSeen() }
    }

    // ── Dev / testing ─────────────────────────────────────────────────────

    /// Resets all flags — next launch shows narrative intro + gameplay onboarding.
    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: introKey)
        UserDefaults.standard.removeObject(forKey: narrativeKey)
        UserDefaults.standard.removeObject(forKey: firstHookKey)
        UserDefaults.standard.removeObject(forKey: tutorialDialogKey)
    }
}
