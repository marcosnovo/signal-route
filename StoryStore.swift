import Foundation

// MARK: - StoryStore
/// Persists which story beats have been seen and surfaces the next pending beat.
///
/// Responsibilities:
///   • Load / save the set of seen beat IDs via UserDefaults
///   • Answer "which unseen beat matches this trigger + context?"
///   • Mark beats as seen after display
///   • Expose a pending queue for multi-beat moments (e.g., sectorComplete + rankUp)
enum StoryStore {

    private static let key = "story-seen-ids-v1"

    // MARK: - Seen-ID persistence

    /// All beat IDs the player has already seen.
    static var seenIDs: Set<String> {
        let raw = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(raw)
    }

    /// Returns true when a beat with the given ID has already been shown.
    static func isSeen(_ id: String) -> Bool {
        seenIDs.contains(id)
    }

    /// Mark a beat as seen. Idempotent — safe to call multiple times.
    static func markSeen(_ id: String) {
        var current = seenIDs
        guard !current.contains(id) else { return }
        current.insert(id)
        UserDefaults.standard.set(Array(current), forKey: key)
    }

    /// Mark a beat as seen using its full `StoryBeat` value.
    static func markSeen(_ beat: StoryBeat) {
        markSeen(beat.id)
    }

    // MARK: - Pending beat queries

    /// Returns the first matching beat for `trigger` and `context`, or nil if none.
    ///
    /// Matching rules (all must hold for the beat to qualify):
    ///   • `beat.trigger == trigger`
    ///   • `beat.id` not in `seenIDs` (unless `beat.onceOnly == false`)
    ///   • `beat.requiredPlayerLevel` ≤ `context.playerLevel` (or nil — any level)
    ///   • `beat.requiredSectorID` == `context.completedSectorID` (or nil — any sector)
    ///   • `beat.requiredMechanic` == `context.unlockedMechanic` (or nil — any mechanic)
    /// Results are ordered by `priority` ascending (lower = higher priority).
    static func pending(for trigger: StoryTrigger,
                        context: StoryContext = StoryContext()) -> StoryBeat? {
        StoryBeatCatalog.beats
            .filter  { matches($0, trigger: trigger, context: context) }
            .sorted  { $0.priority < $1.priority }
            .first
    }

    /// Returns ALL matching beats for `trigger` and `context`, sorted by priority.
    ///
    /// Useful when multiple beats could fire at once — the caller shows them in order.
    static func pendingAll(for trigger: StoryTrigger,
                           context: StoryContext = StoryContext()) -> [StoryBeat] {
        StoryBeatCatalog.beats
            .filter { matches($0, trigger: trigger, context: context) }
            .sorted { $0.priority < $1.priority }
    }

    // MARK: - Multi-trigger queue

    /// Convenience: collect all pending beats for a set of triggers in one call.
    ///
    /// Evaluates each trigger in order and appends matching unseen beats.
    /// Useful at win-screen time when sectorComplete, rankUp, and passUnlocked
    /// may all fire simultaneously.
    static func pendingQueue(triggers: [(trigger: StoryTrigger, context: StoryContext)]) -> [StoryBeat] {
        var seen    = seenIDs
        var results = [StoryBeat]()

        for (trigger, context) in triggers {
            let beats = StoryBeatCatalog.beats
                .filter { beat in
                    beat.trigger == trigger
                    && (!beat.onceOnly || !seen.contains(beat.id))
                    && satisfiesLevel(beat, level: context.playerLevel)
                    && satisfiesSector(beat, sectorID: context.completedSectorID)
                    && satisfiesMechanic(beat, mechanic: context.unlockedMechanic)
                }
                .sorted { $0.priority < $1.priority }
            for beat in beats {
                if beat.onceOnly { seen.insert(beat.id) }   // de-duplicate once-only beats
                results.append(beat)
            }
        }

        return results
    }

    // MARK: - Debug / testing

    /// Removes all seen-beat records. Use from DevMenuView / tests only.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Force-mark every beat in the catalog as seen (skips all story on next run).
    static func markAllSeen() {
        let ids = StoryBeatCatalog.beats.map { $0.id }
        UserDefaults.standard.set(ids, forKey: key)
    }

    /// Remove a single beat from the seen set so it can fire again.
    static func markUnseen(_ id: String) {
        var current = seenIDs
        guard current.contains(id) else { return }
        current.remove(id)
        UserDefaults.standard.set(Array(current), forKey: key)
    }

    static func markUnseen(_ beat: StoryBeat) {
        markUnseen(beat.id)
    }

    // MARK: - Private helpers

    private static func matches(_ beat: StoryBeat,
                                 trigger: StoryTrigger,
                                 context: StoryContext) -> Bool {
        beat.trigger == trigger
        && (!beat.onceOnly || !isSeen(beat.id))   // onceOnly:false beats always match
        && satisfiesLevel(beat, level: context.playerLevel)
        && satisfiesSector(beat, sectorID: context.completedSectorID)
        && satisfiesMechanic(beat, mechanic: context.unlockedMechanic)
    }

    private static func satisfiesLevel(_ beat: StoryBeat, level: Int) -> Bool {
        guard let required = beat.requiredPlayerLevel else { return true }
        return level >= required
    }

    private static func satisfiesSector(_ beat: StoryBeat, sectorID: Int?) -> Bool {
        guard let required = beat.requiredSectorID else { return true }
        return sectorID == required
    }

    private static func satisfiesMechanic(_ beat: StoryBeat, mechanic: MechanicType?) -> Bool {
        guard let required = beat.requiredMechanic else { return true }
        return mechanic == required
    }
}
