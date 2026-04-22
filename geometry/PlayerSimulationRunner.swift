import Foundation
import SwiftUI
import Combine

// MARK: - SimPhase

enum SimPhase: String, CaseIterable {
    case freshInstall   = "FRESH INSTALL"
    case intro          = "INTRO & ONBOARDING"
    case firstMissions  = "FIRST MISSIONS"
    case sectorComplete = "SECTOR 1 COMPLETE"
    case dailyLimit     = "DAILY LIMIT"
    case premiumFlow    = "PREMIUM FLOW"

    var icon: String {
        switch self {
        case .freshInstall:   return "arrow.counterclockwise"
        case .intro:          return "text.bubble.fill"
        case .firstMissions:  return "bolt.fill"
        case .sectorComplete: return "checkmark.seal.fill"
        case .dailyLimit:     return "lock.fill"
        case .premiumFlow:    return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .freshInstall:   return Color(hex: "8A8A8A")
        case .intro:          return Color(hex: "7EC8E3")
        case .firstMissions:  return Color(hex: "4DB87A")
        case .sectorComplete: return Color(hex: "4DB87A")
        case .dailyLimit:     return Color(hex: "FFB800")
        case .premiumFlow:    return Color(hex: "E4C87A")
        }
    }
}

// MARK: - SimStepStatus

enum SimStepStatus {
    case ok, warn, fail, info

    var color: Color {
        switch self {
        case .ok:   return Color(hex: "4DB87A")
        case .warn: return Color(hex: "FFB800")
        case .fail: return Color(hex: "E84040")
        case .info: return Color(hex: "8A8A8A")
        }
    }

    var icon: String {
        switch self {
        case .ok:   return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        case .info: return "minus.circle.fill"
        }
    }
}

// MARK: - SimStep

struct SimStep: Identifiable {
    let id     = UUID()
    let phase:  SimPhase
    let name:   String
    let detail: String
    let status: SimStepStatus
}

// MARK: - SimSummary

struct SimSummary {
    let steps:    [SimStep]
    let duration: TimeInterval

    var passes:   Int { steps.filter { $0.status == .ok   }.count }
    var warns:    Int { steps.filter { $0.status == .warn }.count }
    var failures: Int { steps.filter { $0.status == .fail }.count }
    var infos:    Int { steps.filter { $0.status == .info }.count }

    var overallStatus: SimStepStatus {
        if failures > 0 { return .fail }
        if warns    > 0 { return .warn }
        return .ok
    }
}

// MARK: - PlayerSimulationRunner

/// Simulates a complete player journey from fresh install to premium unlock.
/// Drives store state directly — no UI automation required.
/// Run from DevMenuView > SIM tab.
final class PlayerSimulationRunner: ObservableObject {

    @Published var steps:        [SimStep]    = []
    @Published var isRunning:    Bool         = false
    @Published var summary:      SimSummary?
    @Published var currentPhase: SimPhase?

    // MARK: - Entry point

    @MainActor
    func run() async {
        guard !isRunning else { return }
        isRunning    = true
        steps        = []
        summary      = nil
        currentPhase = nil

        let start = Date()

        await phase1_freshInstall()
        await phase2_introOnboarding()
        await phase3_firstMissions()
        await phase4_sectorComplete()
        await phase5_dailyLimit()
        await phase6_premiumFlow()

        // Restore clean dev state after simulation
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetDailyCount()

        summary      = SimSummary(steps: steps, duration: -start.timeIntervalSinceNow)
        currentPhase = nil
        isRunning    = false
    }

    // MARK: - Phase 1: Fresh Install

    @MainActor
    private func phase1_freshInstall() async {
        currentPhase = .freshInstall

        ProgressionStore.devResetAll()
        StoryStore.reset()
        OnboardingStore.resetAll()
        EntitlementStore.shared.setPremium(false)
        EntitlementStore.shared.resetDailyCount()

        log(.freshInstall, "State wiped", "All stores reset to factory defaults")

        let p = ProgressionStore.profile
        check(.freshInstall, "Player level = 1",
              "level=\(p.level)",
              p.level == 1)

        check(.freshInstall, "No completed missions",
              "completions=\(p.uniqueCompletions)",
              p.uniqueCompletions == 0)

        check(.freshInstall, "Story store empty",
              "seenIDs=\(StoryStore.seenIDs.count)",
              StoryStore.seenIDs.isEmpty)

        check(.freshInstall, "User is free (not premium)",
              "isPremium=\(EntitlementStore.shared.isPremium)",
              !EntitlementStore.shared.isPremium)

        check(.freshInstall, "Onboarding flags cleared",
              "intro=\(OnboardingStore.hasCompletedIntro) narrative=\(OnboardingStore.hasSeenNarrativeIntro)",
              !OnboardingStore.hasCompletedIntro && !OnboardingStore.hasSeenNarrativeIntro)

        let launchBeats = StoryStore.pendingAll(for: .firstLaunch)
        check(.freshInstall, "4 firstLaunch story beats pending",
              "\(launchBeats.count) beats available",
              launchBeats.count == 4)
    }

    // MARK: - Phase 2: Intro + Onboarding

    @MainActor
    private func phase2_introOnboarding() async {
        currentPhase = .intro

        // Player sees narrative intro
        OnboardingStore.markNarrativeSeen()
        check(.intro, "Narrative intro marked seen",
              "hasSeenNarrativeIntro=\(OnboardingStore.hasSeenNarrativeIntro)",
              OnboardingStore.hasSeenNarrativeIntro)

        // Player reads all 4 firstLaunch story beats
        let launchBeats = StoryStore.pendingAll(for: .firstLaunch)
        for beat in launchBeats { StoryStore.markSeen(beat) }
        check(.intro, "firstLaunch beats consumed (no overlay leak)",
              "remaining=\(StoryStore.pendingAll(for: .firstLaunch).count)",
              StoryStore.pending(for: .firstLaunch) == nil)

        // Player wins onboarding mission
        OnboardingStore.markIntroCompleted()
        check(.intro, "Onboarding mission completed",
              "hasCompletedIntro=\(OnboardingStore.hasCompletedIntro)",
              OnboardingStore.hasCompletedIntro)

        // firstMissionReady fires after onboarding
        let readyBeat = StoryStore.pending(for: .firstMissionReady)
        check(.intro, "firstMissionReady beat fires",
              readyBeat.map { $0.id } ?? "nil — beat missing",
              readyBeat != nil)
        if let b = readyBeat { StoryStore.markSeen(b) }

        check(.intro, "Intro overlay dismissed (no UI block)",
              "seen=\(StoryStore.seenIDs.count) total",
              StoryStore.pending(for: .firstMissionReady) == nil)
    }

    // MARK: - Phase 3: First Missions

    @MainActor
    private func phase3_firstMissions() async {
        currentPhase = .firstMissions
        let levels = LevelGenerator.levels

        guard let level1 = levels.first(where: { $0.id == 1 }) else {
            log(.firstMissions, "Level 1 missing", "LevelGenerator returned no id=1", .fail)
            return
        }

        // First missions are always free (intro phase)
        check(.firstMissions, "Level 1: canPlay = true (intro phase)",
              "freeIntroCompleted=\(EntitlementStore.shared.freeIntroCompleted) isInIntroPhase=\(EntitlementStore.shared.isInIntroPhase)",
              EntitlementStore.shared.canPlay(level1))

        // Record mission 1
        ProgressionStore.record(simResult(levelId: 1, efficiency: 0.90))
        let afterM1 = ProgressionStore.profile
        check(.firstMissions, "Mission 1 recorded in profile",
              "completions=\(afterM1.uniqueCompletions)",
              afterM1.uniqueCompletions == 1)

        // firstMissionComplete story beat fires
        let completeBeat = StoryStore.pending(for: .firstMissionComplete)
        check(.firstMissions, "firstMissionComplete beat fires",
              completeBeat.map { $0.id } ?? "nil — beat missing",
              completeBeat != nil)
        if let b = completeBeat { StoryStore.markSeen(b) }

        // Complete missions 2–6
        for id in 2...6 {
            guard let lvl = levels.first(where: { $0.id == id }) else { continue }
            ProgressionStore.record(simResult(levelId: lvl.id, efficiency: 0.85))
        }
        let afterM6 = ProgressionStore.profile
        check(.firstMissions, "Missions 2–6 all recorded",
              "completions=\(afterM6.uniqueCompletions)",
              afterM6.uniqueCompletions == 6)

        check(.firstMissions, "Player level ≥ 1 after 6 missions",
              "level=\(afterM6.level)",
              afterM6.level >= 1)

        // Intro missions drain intro quota, not daily quota
        check(.firstMissions, "First 6 missions consumed from intro quota (not daily)",
              "freeIntroCompleted=\(EntitlementStore.shared.freeIntroCompleted) dailyAttemptsUsed=\(EntitlementStore.shared.dailyAttemptsUsed)",
              EntitlementStore.shared.dailyAttemptsUsed == 0)

        // Verify no stuck overlays (no pending beats that would block navigation)
        let stuckBeats = StoryStore.pendingAll(for: .firstMissionComplete)
        check(.firstMissions, "No stuck firstMissionComplete overlay",
              "remaining=\(stuckBeats.count)",
              stuckBeats.isEmpty)
    }

    // MARK: - Phase 4: Sector 1 Complete

    @MainActor
    private func phase4_sectorComplete() async {
        currentPhase = .sectorComplete

        // Simulate completing all 30 Earth Orbit missions via dev helper
        ProgressionStore.devSimulateSectorComplete(1)
        let profile = ProgressionStore.profile

        check(.sectorComplete, "Sector 1: all 30 levels marked completed",
              "completions=\(profile.uniqueCompletions)",
              profile.uniqueCompletions >= 30)

        check(.sectorComplete, "Earth Orbit PlanetPass issued (planetIdx 0)",
              "hasPass(0)=\(PassStore.hasPass(for: 0))",
              PassStore.hasPass(for: 0))

        // sectorComplete story beat fires for sector 1
        let sectorCtx  = StoryContext.forSector(1, level: profile.level)
        let sectorBeat = StoryStore.pending(for: .sectorComplete, context: sectorCtx)
        check(.sectorComplete, "sectorComplete beat fires (ORBIT RESTORED)",
              sectorBeat.map { $0.id } ?? "nil — beat missing",
              sectorBeat != nil)
        if let b = sectorBeat { StoryStore.markSeen(b) }

        // passUnlocked beat fires (Lunar clearance)
        let passCtx  = StoryContext(playerLevel: profile.level, completedSectorID: 1)
        let passBeat = StoryStore.pending(for: .passUnlocked, context: passCtx)
        check(.sectorComplete, "passUnlocked beat fires (LUNAR CLEARANCE)",
              passBeat.map { $0.id } ?? "nil — beat missing",
              passBeat != nil)
        if let b = passBeat { StoryStore.markSeen(b) }

        // Sector 2 now unlocked on the map
        let sector2    = SpatialRegion.catalog.first(where: { $0.id == 2 })
        let s2unlocked = sector2?.isUnlocked(for: profile) ?? false
        check(.sectorComplete, "Sector 2 (Lunar Approach) unlocked on map",
              "isUnlocked=\(s2unlocked)",
              s2unlocked)

        // enteringNewSector beat queued for Lunar
        let enterCtx  = StoryContext(playerLevel: profile.level, completedSectorID: 2)
        let enterBeat = StoryStore.pending(for: .enteringNewSector, context: enterCtx)
        check(.sectorComplete, "enteringNewSector beat queued (LUNAR APPROACH)",
              enterBeat.map { $0.id } ?? "nil — beat missing",
              enterBeat != nil)

        check(.sectorComplete, "No stuck sector overlay (navigation clear)",
              "pending sectorComplete=\(StoryStore.pendingAll(for: .sectorComplete, context: sectorCtx).count)",
              StoryStore.pending(for: .sectorComplete, context: sectorCtx) == nil)
    }

    // MARK: - Phase 5: Daily Limit

    @MainActor
    private func phase5_dailyLimit() async {
        currentPhase = .dailyLimit

        guard !EntitlementStore.shared.isPremium else {
            log(.dailyLimit, "Skipped", "Already premium — daily limit not enforced", .info)
            return
        }

        let store = EntitlementStore.shared
        guard let anyLevel = LevelGenerator.levels.first else {
            log(.dailyLimit, "No levels", "LevelGenerator returned empty array", .fail)
            return
        }

        // ── Phase 1: intro quota ────────────────────────────────────────
        store.resetIntroCount()
        store.resetDailyCount()

        check(.dailyLimit, "Intro counter reset to 0",
              "freeIntroCompleted=\(store.freeIntroCompleted)",
              store.freeIntroCompleted == 0)

        // All 5 intro missions must be playable (only WON sessions increment intro counter)
        for i in 0..<EntitlementStore.freeIntroLimit {
            let allowed = store.canPlay(anyLevel)
            check(.dailyLimit, "Intro mission \(i+1)/\(EntitlementStore.freeIntroLimit): canPlay = true",
                  "freeIntroCompleted=\(store.freeIntroCompleted)",
                  allowed)
            store.recordAttempt(anyLevel, didWin: true)
        }

        check(.dailyLimit, "Intro quota exhausted after \(EntitlementStore.freeIntroLimit) missions",
              "freeIntroCompleted=\(store.freeIntroCompleted) isInIntroPhase=\(store.isInIntroPhase)",
              !store.isInIntroPhase)

        // ── Phase 2: daily gate ─────────────────────────────────────────
        store.resetDailyCount()

        // 3 daily attempts allowed (both WON and FAILED count)
        for i in 0..<EntitlementStore.dailyLimit {
            let allowed = store.canPlay(anyLevel)
            check(.dailyLimit, "Daily attempt \(i+1)/\(EntitlementStore.dailyLimit): canPlay = true",
                  "dailyAttemptsUsed=\(store.dailyAttemptsUsed)",
                  allowed)
            store.recordAttempt(anyLevel, didWin: i % 2 == 0) // alternate WON/FAILED
        }

        check(.dailyLimit, "Daily limit reached after \(EntitlementStore.dailyLimit) attempts",
              "dailyAttemptsUsed=\(store.dailyAttemptsUsed)/\(EntitlementStore.dailyLimit)",
              store.dailyLimitReached)

        // Next attempt must be blocked
        let blockedVal = store.canPlay(anyLevel)
        check(.dailyLimit, "Attempt \(EntitlementStore.dailyLimit + 1) blocked — paywall fires",
              "canPlay=\(blockedVal) dailyAttemptsUsed=\(store.dailyAttemptsUsed)",
              !blockedVal)

        check(.dailyLimit, "remainingToday = 0 at limit",
              "remaining=\(store.remainingToday)",
              store.remainingToday == 0)
    }

    // MARK: - Phase 6: Premium Flow

    @MainActor
    private func phase6_premiumFlow() async {
        currentPhase = .premiumFlow

        EntitlementStore.shared.setPremium(true)
        check(.premiumFlow, "Premium activated",
              "isPremium=\(EntitlementStore.shared.isPremium)",
              EntitlementStore.shared.isPremium)

        let lunarLevels = SpatialRegion.catalog
            .first(where: { $0.id == 2 })?.levels ?? []

        guard lunarLevels.count >= 4 else {
            log(.premiumFlow, "Not enough Lunar levels", "\(lunarLevels.count) found", .fail)
            return
        }

        // Previously blocked mission now playable
        let previously = lunarLevels[3]
        check(.premiumFlow, "Previously blocked mission now playable",
              "canPlay=\(EntitlementStore.shared.canPlay(previously)) level=\(previously.id)",
              EntitlementStore.shared.canPlay(previously))

        check(.premiumFlow, "remainingToday = Int.max (no cap)",
              "remaining=\(EntitlementStore.shared.remainingToday)",
              EntitlementStore.shared.remainingToday == Int.max)

        // Record that attempt — daily counter must NOT increment for premium users
        let beforeCount = EntitlementStore.shared.dailyAttemptsUsed
        EntitlementStore.shared.recordAttempt(previously, didWin: true)
        check(.premiumFlow, "Daily counter not incremented for premium user",
              "before=\(beforeCount) after=\(EntitlementStore.shared.dailyAttemptsUsed)",
              EntitlementStore.shared.dailyAttemptsUsed == beforeCount)

        // Continue playing several more missions without restriction
        let extraRange = min(4, lunarLevels.count - 4)
        for i in 4..<(4 + extraRange) {
            let lvl = lunarLevels[i]
            check(.premiumFlow, "Lunar L\(lvl.id): no paywall (premium)",
                  "canPlay=\(EntitlementStore.shared.canPlay(lvl))",
                  EntitlementStore.shared.canPlay(lvl))
            ProgressionStore.record(simResult(levelId: lvl.id, efficiency: 0.88))
        }

        let finalProfile = ProgressionStore.profile
        log(.premiumFlow, "Premium session complete",
            "level=\(finalProfile.level) totalCompletions=\(finalProfile.uniqueCompletions)")
    }

    // MARK: - Step builders

    @MainActor
    private func check(_ phase: SimPhase, _ name: String, _ detail: String, _ pass: Bool) {
        steps.append(SimStep(phase: phase, name: name, detail: detail,
                             status: pass ? .ok : .fail))
    }

    @MainActor
    private func log(_ phase: SimPhase, _ name: String, _ detail: String,
                     _ status: SimStepStatus = .info) {
        steps.append(SimStep(phase: phase, name: name, detail: detail, status: status))
    }

    // MARK: - GameResult factory

    private func simResult(levelId: Int, efficiency: Float = 0.88) -> GameResult {
        GameResult(
            levelId:        levelId,
            success:        true,
            movesUsed:      3,
            efficiency:     efficiency,
            nodesActivated: 3,
            totalNodes:     3,
            score:          700,
            moveRating:     efficiency,
            energyRating:   efficiency,
            timeRating:     1.0,
            attemptCount:   1
        )
    }
}
