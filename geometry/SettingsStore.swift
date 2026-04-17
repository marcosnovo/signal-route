import Foundation
import Combine

// MARK: - AppLanguage
enum AppLanguage: String, CaseIterable, Codable {
    case en, es, fr

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        }
    }
}

// MARK: - SettingsStore
/// Persistent user preferences. Observable singleton — access via `SettingsStore.shared`.
/// Wraps SoundManager's existing UserDefaults keys so all persistence stays consistent.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @Published var soundEnabled: Bool {
        didSet { AudioManager.shared.sfxEnabled = soundEnabled }
    }
    @Published var musicEnabled: Bool {
        didSet { AudioManager.shared.musicEnabled = musicEnabled }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var reducedMotion: Bool {
        didSet { UserDefaults.standard.set(reducedMotion, forKey: "reducedMotion") }
    }
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    private init() {
        // Mirror SoundManager's existing UserDefaults keys for sfx + music
        soundEnabled   = UserDefaults.standard.object(forKey: "sfxEnabled")     as? Bool ?? true
        musicEnabled   = UserDefaults.standard.object(forKey: "musicEnabled")   as? Bool ?? true
        hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        reducedMotion  = UserDefaults.standard.object(forKey: "reducedMotion")  as? Bool ?? false

        // Language — prefer saved preference, fall back to device preferred language, then English.
        // Locale.preferredLanguages reflects the language the user has set in iOS Settings,
        // which is more reliable than Locale.current (tied to region, not display language).
        let savedCode  = UserDefaults.standard.string(forKey: "language")
        let systemCode = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        language = AppLanguage(rawValue: savedCode ?? systemCode) ?? .en
    }
}
