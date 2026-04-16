import Foundation
import SwiftUI
import Combine

// MARK: - QAStatus

enum QAStatus: Int, Comparable {
    case pass    = 0
    case warning = 1
    case fail    = 2

    static func < (lhs: QAStatus, rhs: QAStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .pass:    return "PASS"
        case .warning: return "WARN"
        case .fail:    return "FAIL"
        }
    }

    var color: Color {
        switch self {
        case .pass:    return Color(hex: "4DB87A")
        case .warning: return Color(hex: "FFB800")
        case .fail:    return Color(hex: "E84040")
        }
    }

    var systemIcon: String {
        switch self {
        case .pass:    return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }
}

// MARK: - QACategory

enum QACategory: String, CaseIterable {
    case gameplay     = "GAMEPLAY"
    case progression  = "PROGRESSION"
    case story        = "STORY"
    case monetization = "MONETIZATION"
    case tickets      = "TICKETS"
    case missionMap   = "MISSION MAP"
    case devPanel     = "DEV PANEL"

    var icon: String {
        switch self {
        case .gameplay:     return "bolt.fill"
        case .progression:  return "chart.bar.fill"
        case .story:        return "text.bubble.fill"
        case .monetization: return "creditcard.fill"
        case .tickets:      return "ticket.fill"
        case .missionMap:   return "map.fill"
        case .devPanel:     return "wrench.fill"
        }
    }
}

// MARK: - QAResult

struct QAResult: Identifiable {
    let id            = UUID()
    let name:         String
    let category:     QACategory
    let status:       QAStatus
    /// Short context or measured value shown below the name.
    let detail:       String
    /// What to do to fix the issue — nil when status is .pass.
    let suggestion:   String?
    /// When set, the UI shows a "Jump to" button that opens this level.
    let linkedLevelID: Int?
}

// MARK: - QASummary

struct QASummary {
    let results:  [QAResult]
    let duration: TimeInterval
    let mode:     String        // "QUICK" or "FULL"

    var passes:   Int { results.filter { $0.status == .pass    }.count }
    var warnings: Int { results.filter { $0.status == .warning }.count }
    var failures: Int { results.filter { $0.status == .fail    }.count }
    var total:    Int { results.count }

    var overallStatus: QAStatus {
        if failures > 0 { return .fail }
        if warnings > 0 { return .warning }
        return .pass
    }

    /// Failures first, then warnings — nothing else.
    var nonPassing: [QAResult] {
        results.filter { $0.status != .pass }.sorted { $0.status > $1.status }
    }

    func results(for category: QACategory) -> [QAResult] {
        results.filter { $0.category == category }
    }
}

// MARK: - SelfQARunner

/// Runs a structured self-QA pass across all game systems and produces a QASummary.
/// Launch from DevMenuView via "Run Quick QA" or "Run Full QA".
///
/// Quick vs Full difference:
///   - Gameplay board generation: 7 sample levels vs all 180
///   - Ticket render: first pass only vs all passes
final class SelfQARunner: ObservableObject {

    @Published var isRunning = false
    @Published var summary:  QASummary?

    // MARK: - Public entry points

    @MainActor func runQuick() async { await run(quick: true)  }
    @MainActor func runFull()  async { await run(quick: false) }

    // MARK: - Core runner

    @MainActor
    private func run(quick: Bool) async {
        guard !isRunning else { return }
        isRunning = true
        let start = Date()

        var results: [QAResult] = []
        results += checkGameplay(quick: quick)
        results += checkProgression()
        results += checkStory()
        results += checkMonetization()
        results += checkTickets(quick: quick)
        results += checkMissionMap()
        results += checkDevPanel()

        summary   = QASummary(results: results,
                              duration: -start.timeIntervalSinceNow,
                              mode:     quick ? "QUICK" : "FULL")
        isRunning = false
    }

    // MARK: - 1. Core Gameplay

    private func checkGameplay(quick: Bool) -> [QAResult] {
        var r: [QAResult] = []
        let levels = LevelGenerator.levels

        // Catalog count
        r += pass("Level catalog count = 180", .gameplay,
                  condition: levels.count == 180,
                  detail:    "\(levels.count) levels",
                  fix:       "Expected 180 levels in LevelGenerator.levels.")

        // Sequential IDs 1–180
        let ids = levels.map { $0.id }.sorted()
        r += pass("Level IDs sequential 1–180", .gameplay,
                  condition: ids == Array(1...180),
                  detail:    "first=\(ids.first ?? 0) last=\(ids.last ?? 0) count=\(ids.count)",
                  fix:       "Level IDs must cover 1–180 with no gaps or duplicates.")

        // Non-negative move buffer
        let negBuf = levels.filter { $0.moveBuffer < 0 }
        r += pass("All levels: move buffer ≥ 0", .gameplay,
                  condition: negBuf.isEmpty,
                  detail:    negBuf.isEmpty ? "OK" : "\(negBuf.count) levels: \(negBuf.prefix(5).map { $0.id })",
                  fix:       "maxMoves must be > minimumRequiredMoves.",
                  level:     negBuf.first?.id)

        // numTargets ≥ 1
        let noTarget = levels.filter { $0.numTargets < 1 }
        r += pass("All levels: numTargets ≥ 1", .gameplay,
                  condition: noTarget.isEmpty,
                  detail:    noTarget.isEmpty ? "OK" : "\(noTarget.count) levels",
                  fix:       "numTargets must be ≥ 1.",
                  level:     noTarget.first?.id)

        // Solution path ≥ 3
        let shortPath = levels.filter { $0.solutionPathLength < 3 }
        r += pass("All levels: solutionPathLength ≥ 3", .gameplay,
                  condition: shortPath.isEmpty,
                  detail:    shortPath.isEmpty ? "OK" : "\(shortPath.count) levels",
                  fix:       "solutionPathLength < 3 produces trivially simple puzzles.",
                  level:     shortPath.first?.id)

        // Timed levels ≥ 20s
        let badTimer = levels.compactMap { l -> Level? in
            guard let t = l.timeLimit else { return nil }
            return t < 20 ? l : nil
        }
        r += pass("Timed levels: limit ≥ 20s", .gameplay,
                  condition: badTimer.isEmpty,
                  detail:    badTimer.isEmpty ? "OK" : "\(badTimer.count) levels with timeLimit < 20s",
                  fix:       "Time limits < 20s are unplayable on real hardware.",
                  level:     badTimer.first?.id)

        // Board generation
        let sampleIDs: [Int] = quick ? [1, 30, 60, 90, 120, 150, 180] : Array(1...180)
        let badBoards = sampleIDs.compactMap { id -> Level? in
            guard let level = levels.first(where: { $0.id == id }) else { return nil }
            let tiles = LevelGenerator.buildBoard(for: level).flatMap { $0 }
            let src = tiles.filter { $0.role == .source }.count
            let tgt = tiles.filter { $0.role == .target }.count
            return (src != 1 || tgt != level.numTargets) ? level : nil
        }
        let boardLabel = quick ? "Board generation (7 samples)" : "Board generation (all 180)"
        r += pass(boardLabel, .gameplay,
                  condition: badBoards.isEmpty,
                  detail:    badBoards.isEmpty
                      ? "\(sampleIDs.count) boards OK"
                      : "\(badBoards.count) failures: \(badBoards.prefix(5).map { $0.id })",
                  fix:       "Board must have exactly 1 source and numTargets targets.",
                  level:     badBoards.first?.id)

        // Starts-solved: no board should satisfy the win condition before the first tap.
        // Checks the same sample set as board generation. Uses LevelGenerator.startsSolved
        // which mirrors GameViewModel.propagateEnergy() + checkWin() on the initial board.
        // Status: .fail (CRITICAL) — a pre-solved board is a broken gameplay experience.
        let preSolved = sampleIDs.compactMap { id -> Level? in
            guard let level = levels.first(where: { $0.id == id }) else { return nil }
            return LevelGenerator.startsSolved(level: level) ? level : nil
        }
        let solvedLabel = quick ? "No pre-solved boards (7 samples)" : "No pre-solved boards (all 180)"
        r += pass(solvedLabel, .gameplay,
                  condition: preSolved.isEmpty,
                  detail:    preSolved.isEmpty
                      ? "\(sampleIDs.count) levels OK"
                      : "\(preSolved.count) pre-solved: \(preSolved.prefix(5).map { $0.id })",
                  fix:       "buildBoardInternal must apply the starts-solved rescue. Check LevelGenerator.boardStartsSolved invariant.",
                  level:     preSolved.first?.id)

        return r
    }

    // MARK: - 2. Progression

    private func checkProgression() -> [QAResult] {
        var r: [QAResult] = []
        let profile = ProgressionStore.profile
        let prog    = profile.progression

        r += pass("Player level ≥ 1", .progression,
                  condition: profile.level >= 1,
                  detail:    "level=\(profile.level)",
                  fix:       "Level should never be < 1.")

        r += pass("currentPlanet in catalog", .progression,
                  condition: Planet.catalog.indices.contains(prog.currentPlanet.id),
                  detail:    "\(prog.currentPlanet.name) (id=\(prog.currentPlanet.id))",
                  fix:       "currentPlanet.id must be a valid Planet.catalog index.")

        if let next = prog.nextPlanet {
            r += pass("nextPlanet.requiredLevel > current", .progression,
                      condition: next.requiredLevel > prog.currentPlanet.requiredLevel,
                      detail:    "current=\(prog.currentPlanet.requiredLevel) next=\(next.requiredLevel)",
                      fix:       "nextPlanet must require a higher level than currentPlanet.")
        }

        r += pass("currentSector in catalog", .progression,
                  condition: SpatialRegion.catalog.contains { $0.id == prog.currentSector.id },
                  detail:    "\(prog.currentSector.name) (id=\(prog.currentSector.id))",
                  fix:       "currentSector.id must be in SpatialRegion.catalog.")

        r += pass("Sector 1 always unlocked", .progression,
                  condition: prog.isSectorUnlocked(1),
                  detail:    "unlocked=\(prog.isSectorUnlocked(1))",
                  fix:       "SpatialRegion id=1 must always return isUnlocked = true.")

        if let mission = prog.activeMission {
            r += pass("activeMission in catalog", .progression,
                      condition: LevelGenerator.levels.contains { $0.id == mission.id },
                      detail:    "Mission \(mission.id)",
                      fix:       "activeMission.id must be a valid level ID.",
                      level:     mission.id)
        }

        r += pass("levelProgress in [0,1]", .progression,
                  condition: profile.levelProgress >= 0 && profile.levelProgress <= 1,
                  detail:    String(format: "%.3f", profile.levelProgress),
                  fix:       "levelProgress must be clamped to [0,1].")

        let passes = PassStore.all
        let badPasses = passes.filter { $0.planetIndex >= Planet.catalog.count || $0.planetIndex < 0 }
        r += pass("Pass planetIndex within catalog", .progression,
                  condition: badPasses.isEmpty,
                  detail:    "\(passes.count) passes, \(badPasses.count) invalid",
                  fix:       "PlanetPass.planetIndex must be a valid Planet.catalog index.")

        let dupPasses = passes.count != Set(passes.map { $0.planetIndex }).count
        r += pass("No duplicate passes per planet", .progression,
                  condition: !dupPasses,
                  detail:    "\(passes.count) passes, \(Set(passes.map { $0.planetIndex }).count) unique",
                  fix:       "PassStore must never hold two passes for the same planet.")

        return r
    }

    // MARK: - 3. Story / Onboarding

    private func checkStory() -> [QAResult] {
        var r: [QAResult] = []
        let beats = StoryBeatCatalog.beats

        r += pass("Story catalog not empty", .story,
                  condition: !beats.isEmpty,
                  detail:    "\(beats.count) beats",
                  fix:       "StoryBeatCatalog.beats should not be empty.")

        // Unique IDs
        let ids = beats.map { $0.id }
        r += pass("Beat IDs all unique", .story,
                  condition: ids.count == Set(ids).count,
                  detail:    "\(ids.count) beats, \(Set(ids).count) unique IDs",
                  fix:       "Duplicate beat IDs cause story deduplication bugs.")

        // Every trigger type has ≥1 beat
        let missingTriggers = StoryTrigger.allCases.filter { t in !beats.contains { $0.trigger == t } }
        r += pass("All trigger types covered", .story,
                  condition: missingTriggers.isEmpty,
                  detail:    missingTriggers.isEmpty
                      ? "\(StoryTrigger.allCases.count)/\(StoryTrigger.allCases.count)"
                      : "Missing: \(missingTriggers.map { $0.rawValue })",
                  fix:       "Every StoryTrigger case must have at least one beat.")

        // requiredSectorID in 1–8
        let badSector = beats.filter { b in b.requiredSectorID.map { $0 < 1 || $0 > 8 } ?? false }
        r += pass("requiredSectorID in [1,8]", .story,
                  condition: badSector.isEmpty,
                  detail:    badSector.isEmpty ? "OK" : "Bad IDs: \(badSector.map { $0.id })",
                  fix:       "requiredSectorID must be 1–8 to match SpatialRegion.catalog.")

        // Non-empty title / body
        let emptyContent = beats.filter { $0.title.isEmpty || $0.body.isEmpty }
        r += pass("All beats have title & body", .story,
                  condition: emptyContent.isEmpty,
                  detail:    emptyContent.isEmpty ? "OK" : "\(emptyContent.count) empty",
                  fix:       "Story beats must have non-empty title and body.")

        // localizedTitle present on all beats (WARNING, not FAIL)
        let noI18n = beats.filter { $0.localizedTitle == nil }
        r += warn("All beats have localizedTitle", .story,
                  condition: noI18n.isEmpty,
                  detail:    noI18n.isEmpty
                      ? "\(beats.count)/\(beats.count) localised"
                      : "\(noI18n.count) without: \(noI18n.prefix(3).map { $0.id })",
                  fix:       "All beats should have localizedTitle for EN/ES/FR support.")

        // Images exist in asset catalog (WARNING)
        let beatsWithImg = beats.filter { $0.imageName != nil }
        let missingImg   = beatsWithImg.filter { UIImage(named: $0.imageName!) == nil }
        r += warn("Story beat images exist", .story,
                  condition: missingImg.isEmpty,
                  detail:    missingImg.isEmpty
                      ? "\(beatsWithImg.count) images OK"
                      : "\(missingImg.count) missing: " + missingImg.map { "\($0.id)→\($0.imageName!)" }.joined(separator: " | "),
                  fix:       "Add missing image assets or remove the imageName reference from the beat.")

        // Beats with no imageName at all (WARNING — informational)
        let noImg = beats.filter { $0.imageName == nil }
        r += warn("All beats have an image", .story,
                  condition: noImg.isEmpty,
                  detail:    noImg.isEmpty
                      ? "OK"
                      : "\(noImg.count) without image: " + noImg.map { $0.id }.joined(separator: ", "),
                  fix:       "Consider adding illustrative images to these beats for richer narrative.")

        // Orphaned seen IDs in StoryStore
        let seenIDs  = StoryStore.seenIDs
        let validIDs = Set(beats.map { $0.id })
        let orphaned = seenIDs.filter { !validIDs.contains($0) }
        r += warn("No orphaned seen-beat IDs", .story,
                  condition: orphaned.isEmpty,
                  detail:    orphaned.isEmpty ? "\(seenIDs.count) seen" : "\(orphaned.count) orphaned: \(orphaned.prefix(3))",
                  fix:       "StoryStore contains IDs for beats that no longer exist in the catalog.")

        // OnboardingStore readable
        r += pass("OnboardingStore flags readable", .story,
                  condition: true,
                  detail:    "intro=\(OnboardingStore.hasCompletedIntro) narrative=\(OnboardingStore.hasSeenNarrativeIntro)",
                  fix:       nil)

        return r
    }

    // MARK: - 4. Monetization

    private func checkMonetization() -> [QAResult] {
        var r: [QAResult] = []
        let store = EntitlementStore.shared

        r += pass("dailyLimit > 0", .monetization,
                  condition: EntitlementStore.shared.dailyLimit > 0,
                  detail:    "limit=\(EntitlementStore.shared.dailyLimit)",
                  fix:       "dailyLimit must be a positive integer.")

        r += pass("remainingToday ≥ 0", .monetization,
                  condition: store.remainingToday >= 0,
                  detail:    "remaining=\(store.remainingToday)",
                  fix:       "remainingToday must not be negative.")

        r += pass("dailyCompleted ≥ 0", .monetization,
                  condition: store.dailyCompleted >= 0,
                  detail:    "dailyCompleted=\(store.dailyCompleted)",
                  fix:       "dailyCompleted must not be negative.")

        // Earth Orbit always free
        let earthLevels  = SpatialRegion.catalog.first(where: { $0.id == 1 })?.levels ?? []
        let earthBlocked = earthLevels.filter { !store.canPlay($0) }
        r += pass("Earth Orbit levels always free", .monetization,
                  condition: earthBlocked.isEmpty,
                  detail:    earthBlocked.isEmpty ? "\(earthLevels.count) levels free" : "\(earthBlocked.count) blocked",
                  fix:       "canPlay must return true for all sector 1 levels regardless of premium state.",
                  level:     earthBlocked.first?.id)

        // dailyLimitReached coherence
        let limitCoherent = store.dailyLimitReached == (store.remainingToday == 0)
        r += pass("dailyLimitReached coherent", .monetization,
                  condition: limitCoherent,
                  detail:    "limitReached=\(store.dailyLimitReached) remaining=\(store.remainingToday)",
                  fix:       "dailyLimitReached should be true iff remainingToday == 0.")

        // Premium bypass check
        if store.isPremium {
            if let s2Level = SpatialRegion.catalog.first(where: { $0.id == 2 })?.levels.first {
                r += pass("Premium bypasses daily limit", .monetization,
                          condition: store.canPlay(s2Level),
                          detail:    "isPremium=true canPlay=\(store.canPlay(s2Level))",
                          fix:       "Premium users must always be able to play non-Earth Orbit levels.",
                          level:     s2Level.id)
            }
        }

        return r
    }

    // MARK: - 5. Tickets / Share

    private func checkTickets(quick: Bool) -> [QAResult] {
        var r: [QAResult] = []
        let passes  = PassStore.all
        let profile = ProgressionStore.profile

        r += pass("PassStore loads cleanly", .tickets,
                  condition: true,
                  detail:    "\(passes.count) passes",
                  fix:       nil)

        // Serial codes well-formed
        let badSerials = passes.filter { $0.serialCode.isEmpty || !$0.serialCode.hasPrefix("SR-") }
        r += pass("Pass serialCodes well-formed", .tickets,
                  condition: badSerials.isEmpty,
                  detail:    badSerials.isEmpty ? "OK" : "\(badSerials.count) bad serials",
                  fix:       "serialCode must start with 'SR-' and be non-empty.")

        // Timestamps not in future
        let futurePasses = passes.filter { $0.timestamp > Date().addingTimeInterval(60) }
        r += warn("Pass timestamps not in future", .tickets,
                  condition: futurePasses.isEmpty,
                  detail:    futurePasses.isEmpty ? "OK" : "\(futurePasses.count) future-dated passes",
                  fix:       "PlanetPass.timestamp should not be in the future.")

        // Cache round-trip
        if let firstPass = passes.first {
            let testImg = UIImage(systemName: "checkmark") ?? UIImage()
            TicketCache.shared.cache(testImg, for: firstPass)
            let hit = TicketCache.shared.image(for: firstPass)
            r += pass("TicketCache round-trip", .tickets,
                      condition: hit != nil,
                      detail:    "cache hit=\(hit != nil)",
                      fix:       "TicketCache should return an image after caching it.")
        }

        // Render check
        if !passes.isEmpty {
            let toRender = quick ? [passes[0]] : passes
            var failures: [PlanetPass] = []
            for p in toRender {
                let img = TicketRenderer.render(pass: p, profile: profile)
                if img.size.width < 100 { failures.append(p) }
            }
            let label = quick ? "Ticket render (first pass)" : "Ticket render (all \(passes.count))"
            r += pass(label, .tickets,
                      condition: failures.isEmpty,
                      detail:    failures.isEmpty ? "OK" : "\(failures.count) render failures",
                      fix:       "TicketRenderer.render must produce a ≥ 100×100 image.")
        }

        return r
    }

    // MARK: - 6. Mission Map

    private func checkMissionMap() -> [QAResult] {
        var r: [QAResult] = []
        let catalog = SpatialRegion.catalog
        let profile = ProgressionStore.profile

        r += pass("SpatialRegion catalog has 8 sectors", .missionMap,
                  condition: catalog.count == 8,
                  detail:    "\(catalog.count) sectors",
                  fix:       "Expected exactly 8 sectors.")

        let sectorIDs = catalog.map { $0.id }.sorted()
        r += pass("Sector IDs sequential 1–8", .missionMap,
                  condition: sectorIDs == [1, 2, 3, 4, 5, 6, 7, 8],
                  detail:    "\(sectorIDs)",
                  fix:       "Sector IDs must be sequential 1–8.")

        // Overlapping ranges
        let ranges  = catalog.map { $0.levelRange }
        let overlap = (0..<ranges.count).contains { i in
            (i+1..<ranges.count).contains { j in ranges[i].overlaps(ranges[j]) }
        }
        r += pass("Sector level ranges: no overlap", .missionMap,
                  condition: !overlap,
                  detail:    overlap ? "OVERLAP DETECTED" : "OK",
                  fix:       "Two or more sectors share level IDs.")

        // Full coverage 1–180
        let covered = Set(catalog.flatMap { Array($0.levelRange) })
        let missing = Set(1...180).subtracting(covered)
        let extra   = covered.subtracting(Set(1...180))
        r += pass("Sector ranges cover 1–180", .missionMap,
                  condition: missing.isEmpty && extra.isEmpty,
                  detail:    missing.isEmpty && extra.isEmpty ? "OK" : "missing=\(missing.count) extra=\(extra.count)",
                  fix:       "Every level ID 1–180 must belong to exactly one sector.")

        // Sector 1 always unlocked
        r += pass("Sector 1 always unlocked", .missionMap,
                  condition: catalog.first?.isUnlocked(for: profile) == true,
                  detail:    "unlocked=\(catalog.first?.isUnlocked(for: profile) ?? false)",
                  fix:       "Sector 1 must always return isUnlocked = true.")

        // No gap in unlock sequence
        let unlocked   = Set(catalog.filter { $0.isUnlocked(for: profile) }.map { $0.id })
        let gapExists  = unlocked.contains { id in id > 1 && !unlocked.contains(id - 1) }
        r += pass("Sector unlock sequence: no gap", .missionMap,
                  condition: !gapExists,
                  detail:    "unlocked=\(unlocked.sorted())",
                  fix:       "Sector N cannot be unlocked when sector N-1 is still locked.")

        // All sectors have levels
        let emptySectors = catalog.filter { $0.levels.isEmpty }
        r += pass("All sectors have ≥1 level", .missionMap,
                  condition: emptySectors.isEmpty,
                  detail:    emptySectors.isEmpty ? "OK" : "Empty: \(emptySectors.map { $0.id })",
                  fix:       "Every sector must have at least one level in LevelGenerator.")

        return r
    }

    // MARK: - 7. Dev Panel

    private func checkDevPanel() -> [QAResult] {
        var r: [QAResult] = []
        let profile = ProgressionStore.profile

        r += pass("ProgressionStore readable", .devPanel,
                  condition: true,
                  detail:    "level=\(profile.level) completions=\(profile.uniqueCompletions)",
                  fix:       nil)

        r += pass("PassStore readable", .devPanel,
                  condition: true,
                  detail:    "\(PassStore.all.count) passes",
                  fix:       nil)

        r += pass("StoryStore readable", .devPanel,
                  condition: true,
                  detail:    "\(StoryStore.seenIDs.count) seen beats",
                  fix:       nil)

        let announcedCount = MechanicType.allCases.filter { MechanicUnlockStore.hasAnnounced($0) }.count
        r += pass("MechanicUnlockStore readable", .devPanel,
                  condition: true,
                  detail:    "\(announcedCount)/\(MechanicType.allCases.count) announced",
                  fix:       nil)

        r += pass("MechanicType catalog = 8", .devPanel,
                  condition: MechanicType.allCases.count == 8,
                  detail:    "\(MechanicType.allCases.count) mechanics",
                  fix:       "Expected 8 MechanicType cases.")

        r += pass("First catalog level is ID 1", .devPanel,
                  condition: LevelGenerator.levels.first?.id == 1,
                  detail:    "firstID=\(LevelGenerator.levels.first?.id ?? -1)",
                  fix:       "LevelGenerator.levels[0].id must be 1.")

        r += pass("canLevelUp computable", .devPanel,
                  condition: true,
                  detail:    "canLevelUp=\(profile.canLevelUp) level=\(profile.level)",
                  fix:       nil)

        return r
    }

    // MARK: - Builder helpers

    /// Failure condition produces .fail.
    private func pass(
        _ name:  String,
        _ cat:   QACategory,
        condition: Bool,
        detail:  String,
        fix:     String?,
        level:   Int? = nil
    ) -> [QAResult] {
        [QAResult(name: name, category: cat,
                  status:        condition ? .pass : .fail,
                  detail:        detail,
                  suggestion:    condition ? nil : fix,
                  linkedLevelID: condition ? nil : level)]
    }

    /// Failure condition produces .warning (not .fail).
    private func warn(
        _ name:  String,
        _ cat:   QACategory,
        condition: Bool,
        detail:  String,
        fix:     String?,
        level:   Int? = nil
    ) -> [QAResult] {
        [QAResult(name: name, category: cat,
                  status:        condition ? .pass : .warning,
                  detail:        detail,
                  suggestion:    condition ? nil : fix,
                  linkedLevelID: condition ? nil : level)]
    }
}
