import UserNotifications

// MARK: - NotificationManager
/// Central manager for all local notifications in Signal Void.
///
/// ## Notification categories (extensible)
///   - `cooldown_expired`  — fired when the 24h free-user gate lifts
///
/// ## Extension points
///   Add new `schedule*(…)` / `cancel*(…)` pairs for:
///   - Daily play reminders
///   - New sector unlocked events
///   - Special limited-time events
///
/// All public methods are safe to call from any concurrency context.
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Notification identifiers

    private enum ID {
        /// Fired when the 24h cooldown expires and the player can play again.
        static let cooldown = "signal_route.cooldown_expired"
        /// Short-lived test notification (dev only).
        static let test     = "signal_route.test"
    }

    // MARK: - Authorization

    /// Returns the current UNAuthorizationStatus without triggering a system prompt.
    func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Presents the system permission prompt if status is `.notDetermined`.
    /// Returns the granted state after the prompt resolves (or the current state if already decided).
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional: return true
        case .denied:                   return false
        case .notDetermined, .ephemeral:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:               return false
        }
    }

    // MARK: - Cooldown expiry notification

    /// Schedule a "you can play again" notification at `date`.
    /// Cancels any previous cooldown notification first to avoid duplicates.
    /// Requests permission automatically if not yet determined.
    func scheduleCooldown(at date: Date, language: AppLanguage) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        let s = AppStrings(lang: language)
        content.title = s.notifCooldownTitle
        content.body  = s.notifCooldownBody
        content.sound = .default

        schedule(id: ID.cooldown, content: content, after: interval)
    }

    /// Cancel any pending cooldown expiry notification (call on cooldown clear or premium purchase).
    func cancelCooldown() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.cooldown])
    }

    // MARK: - Dev helpers

    /// Schedule a test notification firing after `delay` seconds (default 10s).
    func scheduleTest(after delay: TimeInterval = 10, language: AppLanguage) {
        let content = UNMutableNotificationContent()
        let s = AppStrings(lang: language)
        content.title = "[TEST] \(s.notifCooldownTitle)"
        content.body  = s.notifCooldownBody
        content.sound = .default
        schedule(id: ID.test, content: content, after: delay)
    }

    /// Cancel all pending notifications scheduled by this app.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Returns identifiers of all currently pending notifications.
    func pendingIDs() async -> [String] {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .map(\.identifier)
    }

    // MARK: - Private

    private func schedule(id: String, content: UNMutableNotificationContent, after interval: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        Task {
            let center = UNUserNotificationCenter.current()
            // Request permission if not yet decided; proceed if already authorized
            let status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            let resolved = await center.notificationSettings().authorizationStatus
            guard resolved == .authorized || resolved == .provisional else { return }

            // Remove stale request with same ID before adding new one
            center.removePendingNotificationRequests(withIdentifiers: [id])
            try? await center.add(request)
        }
    }
}
