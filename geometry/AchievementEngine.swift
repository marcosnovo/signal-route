import Foundation
import SwiftUI

// MARK: - AchievementEngine

@Observable
final class AchievementEngine {

    static let shared = AchievementEngine()

    private(set) var progress: AchievementProgress
    private(set) var lastUnlocked: Achievement?
    private(set) var gcImages: [String: UIImage] = [:]

    private static let storageKey = "signalroute.achievements.v1"
    private static let levelTypeById: [Int: LevelType] = {
        Dictionary(uniqueKeysWithValues: LevelGenerator.levels.map { ($0.id, $0.levelType) })
    }()

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data) {
            self.progress = decoded
        } else {
            self.progress = AchievementProgress()
        }
    }

    // MARK: - Public API

    func state(for achievement: Achievement) -> AchievementState {
        progress.states[achievement.id] ?? .locked
    }

    var unlockedCount: Int {
        progress.states.values.filter(\.isUnlocked).count
    }

    var totalCount: Int {
        AchievementCatalog.all.count
    }

    func record(event: GameEvent) {
        var changed = false

        if case .levelCleared(_, _, _, _, let attemptCount) = event, attemptCount == 1 {
            progress.firstAttemptClears += 1
            changed = true
        }

        for achievement in AchievementCatalog.all {
            let current = state(for: achievement)
            guard !current.isUnlocked else { continue }

            let newValue = evaluate(achievement: achievement, event: event, currentState: current)
            guard newValue != current else { continue }

            progress.states[achievement.id] = newValue
            changed = true

            if newValue.isUnlocked {
                lastUnlocked = achievement
                HapticsManager.success()
            }
        }

        if changed { save() }
    }

    func syncFromProfile() {
        let profile = ProgressionStore.profile
        var changed = false

        for achievement in AchievementCatalog.all {
            let current = state(for: achievement)
            guard !current.isUnlocked else { continue }

            let value = profileValue(for: achievement, profile: profile)
            if value >= achievement.target {
                progress.states[achievement.id] = .unlocked(date: Date())
                changed = true
            } else if value > 0 {
                progress.states[achievement.id] = .inProgress(current: value)
                changed = true
            }
        }

        if changed { save() }
    }

    func clearLastUnlocked() {
        lastUnlocked = nil
    }

    // MARK: - GC Image Loading

    func loadGCImages() async {
        guard gcImages.isEmpty else { return }
        let data = await GameCenterManager.shared.fetchAchievements()
        for ach in data {
            if let img = ach.image {
                gcImages[ach.identifier] = img
            }
        }
    }

    func image(for achievement: Achievement) -> UIImage? {
        gcImages[achievement.gcIdentifier]
    }

    // MARK: - Evaluation

    private func evaluate(achievement: Achievement, event: GameEvent, currentState: AchievementState) -> AchievementState {
        guard case .levelCleared = event else {
            return currentState
        }

        let profile = ProgressionStore.profile
        let value: Int

        switch achievement.metric {
        case .levelsCompleted:
            value = profile.uniqueCompletions
        case .perfectScores:
            value = profile.totalOptimalCount
        case .totalScore:
            value = profile.leaderboardScore
        case .easyLevelsCleared:
            value = profile.completedCount(for: .easy)
        case .mediumLevelsCleared:
            value = profile.completedCount(for: .medium)
        case .hardLevelsCleared:
            value = profile.completedCount(for: .hard)
        case .expertLevelsCleared:
            value = profile.completedCount(for: .expert)
        case .branchingLevelsCleared:
            value = completedLevelTypeCount(.branching, profile: profile)
        case .denseLevelsCleared:
            value = completedLevelTypeCount(.dense, profile: profile)
        case .multiNodeLevelsCleared:
            value = completedLevelTypeCount(.multiTarget, profile: profile)
        case .firstAttemptClears:
            value = progress.firstAttemptClears
        case .streakWins:
            value = SessionTracker.shared.streakCount
        case .astronautLevel:
            value = profile.level
        }

        if value >= achievement.target {
            return .unlocked(date: Date())
        } else if value > 0 {
            return .inProgress(current: value)
        }
        return currentState
    }

    private func profileValue(for achievement: Achievement, profile: AstronautProfile) -> Int {
        switch achievement.metric {
        case .levelsCompleted:         profile.uniqueCompletions
        case .perfectScores:           profile.totalOptimalCount
        case .totalScore:              profile.leaderboardScore
        case .easyLevelsCleared:       profile.completedCount(for: .easy)
        case .mediumLevelsCleared:     profile.completedCount(for: .medium)
        case .hardLevelsCleared:       profile.completedCount(for: .hard)
        case .expertLevelsCleared:     profile.completedCount(for: .expert)
        case .branchingLevelsCleared:  completedLevelTypeCount(.branching, profile: profile)
        case .denseLevelsCleared:      completedLevelTypeCount(.dense, profile: profile)
        case .multiNodeLevelsCleared:  completedLevelTypeCount(.multiTarget, profile: profile)
        case .firstAttemptClears:      progress.firstAttemptClears
        case .streakWins:              SessionTracker.shared.streakCount
        case .astronautLevel:          profile.level
        }
    }

    private func completedLevelTypeCount(_ type: LevelType, profile: AstronautProfile) -> Int {
        profile.bestEfficiencyByLevel.keys.compactMap { Int($0) }.filter { id in
            Self.levelTypeById[id] == type
        }.count
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - Sorted catalog

    func sortedAchievements() -> [Achievement] {
        AchievementCatalog.all.sorted { a, b in
            let sa = state(for: a)
            let sb = state(for: b)
            return sortKey(sa) < sortKey(sb)
        }
    }

    private func sortKey(_ state: AchievementState) -> Int {
        switch state {
        case .unlocked(let date):
            return Int(-date.timeIntervalSince1970)
        case .inProgress(let current):
            return 1_000_000_000 - current
        case .locked:
            return 2_000_000_000
        }
    }

    // MARK: - Dev / testing

    func devReset() {
        progress = AchievementProgress()
        save()
    }

    func devUnlockAll() {
        for a in AchievementCatalog.all {
            progress.states[a.id] = .unlocked(date: Date())
        }
        save()
    }

    func devUnlock(_ id: String) {
        progress.states[id] = .unlocked(date: Date())
        save()
    }
}
