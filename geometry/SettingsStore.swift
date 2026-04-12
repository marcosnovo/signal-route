import Foundation
import Combine

// MARK: - SettingsStore
/// Persistent user preferences. Observable singleton — access via `SettingsStore.shared`.
/// Wraps SoundManager's existing UserDefaults keys so all persistence stays consistent.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @Published var soundEnabled: Bool {
        didSet { SoundManager.sfxEnabled = soundEnabled }
    }
    @Published var musicEnabled: Bool {
        didSet { SoundManager.musicEnabled = musicEnabled }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var reducedMotion: Bool {
        didSet { UserDefaults.standard.set(reducedMotion, forKey: "reducedMotion") }
    }

    private init() {
        // Mirror SoundManager's existing UserDefaults keys for sfx + music
        soundEnabled   = UserDefaults.standard.object(forKey: "sfxEnabled")     as? Bool ?? true
        musicEnabled   = UserDefaults.standard.object(forKey: "musicEnabled")   as? Bool ?? true
        hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        reducedMotion  = UserDefaults.standard.object(forKey: "reducedMotion")  as? Bool ?? false
    }
}
