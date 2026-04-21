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

    // MARK: - Cloud sync

    /// Current announced mechanics as sorted raw-value strings for cloud save.
    static var announcedRawValues: [String] {
        Array(announced).sorted()
    }

    /// Apply a merged set of mechanic unlocks from the cloud.
    /// Only adds — never removes an already-announced mechanic.
    static func applyCloudState(_ rawValues: [String]) {
        var set = announced
        for rv in rawValues { set.insert(rv) }
        announced = set
    }

    // MARK: - Debug

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Mark a single mechanic as unseen so its unlock message can fire again.
    static func markUnannounced(_ mechanic: MechanicType) {
        var set = announced
        set.remove(mechanic.rawValue)
        announced = set
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
