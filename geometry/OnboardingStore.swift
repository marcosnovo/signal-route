import Foundation

// MARK: - OnboardingStore
/// Persists first-launch state. Once the intro mission is won the flag is set
/// permanently, so the player goes straight to Home on every subsequent launch.
enum OnboardingStore {
    private static let key = "hasCompletedIntro"

    static var hasCompletedIntro: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markIntroCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
