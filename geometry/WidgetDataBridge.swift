import Foundation
import WidgetKit

// MARK: - WidgetDataBridge
/// Reads and writes the shared widget data via App Groups UserDefaults.
/// Used by both the main app (write) and the widget extension (read).
enum WidgetDataBridge {

    static let appGroupID = "group.com.marcosnovo.signalvoidgame"
    private static let snapshotKey = "widget-data-snapshot-v1"

    /// Shared UserDefaults backed by the App Group container.
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Write (main app)

    /// Persist the snapshot and tell WidgetKit to refresh all timelines.
    static func write(_ snapshot: WidgetDataSnapshot) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (widget extension)

    /// Load the most recent snapshot, or nil if none has been written yet.
    static func read() -> WidgetDataSnapshot? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDataSnapshot.self, from: data)
    }
}
