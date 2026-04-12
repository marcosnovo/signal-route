import UIKit

// MARK: - HapticsManager
/// Thin wrapper around UIKit feedback generators.
/// Generators are created once and reused — avoids the allocation + prepare() overhead
/// that occurs when creating a new generator on every single haptic call.
/// All methods are safe to call from the main thread (GameViewModel is @MainActor).
enum HapticsManager {

    private static let lightImpact    = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact   = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact    = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGen   = UISelectionFeedbackGenerator()
    private static let notificationGen = UINotificationFeedbackGenerator()

    static func light() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        lightImpact.impactOccurred()
    }

    static func medium() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }

    static func heavy() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }

    static func selection() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        selectionGen.selectionChanged()
    }

    static func success() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        notificationGen.notificationOccurred(.success)
    }

    static func error() {
        guard SettingsStore.shared.hapticsEnabled else { return }
        notificationGen.notificationOccurred(.error)
    }
}
