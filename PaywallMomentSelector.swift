import Foundation

// MARK: - PaywallMomentSelector
/// Determines the right PaywallContext for each trigger site.
///
/// ## Priority rule
/// postVictory > sectorExcitement > nextMissionBlocked > homeSoftCTA
///
/// ## Anti-frustration contract
/// This selector is NEVER called from failure paths (triggerLoss, retry, abandon).
/// Paywall only appears during high-intent moments: wins, new sector access, and
/// the passive Home upgrade row.
enum PaywallMomentSelector {

    // MARK: - Post-win

    /// Context to use when the player just won and the daily limit is now reached.
    /// Returns nil if no paywall should fire (premium user or limit not yet reached).
    ///
    /// Call AFTER `EntitlementStore.recordMissionCompleted` so `dailyLimitReached` is current.
    static func contextAfterWin(
        event:       LevelUpEvent?,
        entitlement: EntitlementStore
    ) -> PaywallContext? {
        guard !entitlement.isPremium, entitlement.dailyLimitReached else { return nil }
        // New planet pass / sector unlock → frame it as an expansion moment
        if event?.newPass != nil { return .sectorExcitement }
        return .postVictory
    }

    // MARK: - Blocked navigation

    /// Context when a player tries to play a level they can't access due to the daily limit.
    /// Used for map and home navigation (not for immediate post-win taps).
    static func contextWhenBlocked(_ level: Level) -> PaywallContext {
        // Entry level of a non-Earth sector → frame as an expansion/unlock moment
        if let sector = SpatialRegion.catalog.first(where: { $0.levelRange.contains(level.id) }),
           sector.id > 1,
           sector.levelRange.lowerBound == level.id {
            return .sectorExcitement
        }
        return .nextMissionBlocked
    }
}
