import Foundation

// MARK: - MechanicUnlockStore
/// Tracks which gameplay mechanics have been announced to the player.
/// Each mechanic's unlock message is shown exactly once — the first time
/// the player loads a level that contains that mechanic.
enum MechanicUnlockStore {

    private static let key = "mechanic-unlocks-v1"

    // MARK: - Access

    static func hasAnnounced(_ mechanic: MechanicType) -> Bool {
        announced.contains(mechanic.rawValue)
    }

    static func markAnnounced(_ mechanic: MechanicType) {
        var set = announced
        set.insert(mechanic.rawValue)
        announced = set
    }

    // MARK: - Debug

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private static var announced: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: key)
        }
    }
}
