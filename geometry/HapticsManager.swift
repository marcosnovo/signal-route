import UIKit

// MARK: - HapticsManager
/// Thin wrapper around UIKit feedback generators.
/// All methods are safe to call from the main thread (GameViewModel is @MainActor).
enum HapticsManager {

    static func light() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    static func medium() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }

    static func heavy() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare()
        g.impactOccurred()
    }

    static func selection() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }

    static func success() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }

    static func error() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.error)
    }
}
