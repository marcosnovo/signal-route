import Foundation
import os.log

// MARK: - PaywallAnalyticsSnapshot
/// Full context captured at the moment a paywall event fires.
/// Answers the product questions: who is this player, where are they, and why are they here?
struct PaywallAnalyticsSnapshot {
    /// Trigger context — matches PaywallContext.analyticsName.
    let context: String
    /// Smoothed player skill (0.0 struggling → 1.0 expert). From PlayerSkillTracker EMA.
    let playerSkillScore: Double
    /// Missions the player has completed today (free quota usage).
    let dailyMissionsPlayed: Int
    /// All-time unique missions completed.
    let missionsCompletedTotal: Int
    /// Numeric ID of the player's current sector (1 = Earth Orbit, 8 = Neptune Deep).
    let currentSector: Int
    /// Number of planet passes earned (progression depth proxy).
    let currentPass: Int
    /// Consecutive wins in this session without a failure or abandon between them.
    let streakCount: Int
    /// Average efficiency across all completed missions (0.0–1.0).
    let avgEfficiency: Float
    /// Total losses triggered since session start.
    let failuresInSession: Int
    /// Seconds elapsed since app launch.
    let sessionDurationSeconds: Int
    /// True when FrustrationGuard considers the player frustrated at event time.
    /// Key funnel dimension: do frustrated players convert at a different rate?
    let isFrustrated: Bool

    // MARK: - Serialisation

    var asDictionary: [String: Any] {
        [
            "context":                  context,
            "player_skill_score":       (playerSkillScore * 100).rounded() / 100,  // 2 d.p.
            "daily_missions_played":    dailyMissionsPlayed,
            "missions_completed_total": missionsCompletedTotal,
            "current_sector":           currentSector,
            "current_pass":             currentPass,
            "streak_count":             streakCount,
            "avg_efficiency":           (Double(avgEfficiency) * 100).rounded() / 100,
            "failures_in_session":      failuresInSession,
            "session_duration_seconds": sessionDurationSeconds,
            "is_frustrated":            isFrustrated,
        ]
    }
}

// MARK: - AnalyticsBackend
/// Plug-in interface for the analytics destination.
/// Swap the default ConsoleAnalyticsBackend for any SDK (PostHog, Amplitude, Mixpanel…)
/// by setting `MonetizationAnalytics.shared.backend` at app startup.
protocol AnalyticsBackend: AnyObject {
    func track(event: String, properties: [String: Any])
}

// MARK: - ConsoleAnalyticsBackend
/// Default no-dependency backend: writes structured events to os_log.
/// Visible in Console.app and Xcode debug output. Zero network traffic.
final class ConsoleAnalyticsBackend: AnalyticsBackend {

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "geometry",
                            category: "monetization")

    func track(event: String, properties: [String: Any]) {
        let props = properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " | ")
        os_log("[ANALYTICS] %{public}@ { %{public}@ }",
               log: log, type: .info, event, props)
    }
}

// MARK: - PaywallContext + analyticsName
extension PaywallContext {
    /// Snake_case event label used in analytics dashboards.
    var analyticsName: String {
        switch self {
        case .postVictory:        return "post_victory"
        case .sectorExcitement:   return "sector_unlock"
        case .nextMissionBlocked: return "next_block"
        case .homeSoftCTA:        return "home"
        }
    }
}

// MARK: - MonetizationAnalytics
/// Single entry point for all monetization-related analytics events.
///
/// ## Usage
/// ```swift
/// // On paywall appear:
/// MonetizationAnalytics.shared.trackPaywallShown(context: context)
///
/// // On CTA tap (before purchase async call):
/// MonetizationAnalytics.shared.trackPaywallCTATap()
///
/// // On user-initiated dismiss:
/// MonetizationAnalytics.shared.trackPaywallDismiss()
///
/// // After verified successful purchase:
/// MonetizationAnalytics.shared.trackPurchaseSuccess()
/// ```
///
/// ## Backend
/// Default is ConsoleAnalyticsBackend. Replace at app launch:
/// ```swift
/// MonetizationAnalytics.shared.backend = MyAmplitudeBackend()
/// ```
@MainActor
final class MonetizationAnalytics {

    static let shared = MonetizationAnalytics()
    private init() {}

    /// Pluggable backend. Replace with any conforming object before first event.
    var backend: AnalyticsBackend = ConsoleAnalyticsBackend()

    /// Stored so `paywall_cta_tap`, `paywall_dismiss`, and `purchase_success` can
    /// include the context that opened this paywall session without re-passing it.
    private(set) var lastShownContext: PaywallContext?
    /// Timestamp of the most recent paywall_shown event. Nil if no paywall shown this session.
    private(set) var lastShownAt: Date?

    // MARK: - Events

    /// Fire when the paywall becomes visible.
    func trackPaywallShown(context: PaywallContext) {
        lastShownContext = context
        lastShownAt      = Date()
        let snap = snapshot(context: context)
        backend.track(event: "paywall_shown", properties: snap.asDictionary)
    }

    /// Fire when the user taps the primary purchase CTA.
    func trackPaywallCTATap() {
        let context = lastShownContext ?? .nextMissionBlocked
        let snap = snapshot(context: context)
        backend.track(event: "paywall_cta_tap", properties: snap.asDictionary)
    }

    /// Fire when the user dismisses the paywall without purchasing.
    /// Do NOT call this on successful purchase — StoreKit triggers `trackPurchaseSuccess` instead.
    func trackPaywallDismiss() {
        let context = lastShownContext ?? .nextMissionBlocked
        let snap = snapshot(context: context)
        backend.track(event: "paywall_dismiss", properties: snap.asDictionary)
        lastShownContext = nil
    }

    /// Fire after a transaction is verified and premium is activated.
    /// Called by StoreKitManager, which correlates with the last-shown context.
    func trackPurchaseSuccess() {
        let context = lastShownContext ?? .nextMissionBlocked
        // purchase_success spec: context, playerSkillScore, currentSector, dailyMissionsPlayed
        // Full snapshot included — backend/dashboard can filter columns as needed.
        let snap = snapshot(context: context)
        backend.track(event: "purchase_success", properties: snap.asDictionary)
        lastShownContext = nil
    }

    // MARK: - Private

    private func snapshot(context: PaywallContext) -> PaywallAnalyticsSnapshot {
        let profile = ProgressionStore.profile
        let session = SessionTracker.shared
        return PaywallAnalyticsSnapshot(
            context:                context.analyticsName,
            playerSkillScore:       PlayerSkillTracker.shared.skillScore,
            dailyMissionsPlayed:    EntitlementStore.shared.dailyAttemptsUsed,
            missionsCompletedTotal: profile.uniqueCompletions,
            currentSector:          profile.progression.currentSector.id,
            currentPass:            PassStore.all.count,
            streakCount:            session.streakCount,
            avgEfficiency:          profile.averageEfficiency,
            failuresInSession:      session.failuresInSession,
            sessionDurationSeconds: session.sessionDurationSeconds,
            isFrustrated:           FrustrationGuard.isFrustrated()
        )
    }
}
