import GameKit

// MARK: - AchievementManager
/// Evaluates and reports Game Center achievements after each win.
/// All 14 achievement IDs are configured in App Store Connect.
/// GKAchievement.report is idempotent — percentComplete only increases, never decreases.
@MainActor
final class AchievementManager {

    static let shared = AchievementManager()
    private init() {}

    // ── Achievement IDs (App Store Connect) ────────────────────────────────
    private static let prefix = "com.marcosnovo.signalvoidgame.achievement"

    private enum ID {
        static let firstLevel      = "\(prefix).first_level"
        static let complete10      = "\(prefix).complete_10"
        static let complete25      = "\(prefix).complete_25"
        static let completeAll     = "\(prefix).complete_all"
        static let tierEasyClear   = "\(prefix).tier_easy_clear"
        static let tierMediumClear = "\(prefix).tier_medium_clear"
        static let tierHardClear   = "\(prefix).tier_hard_clear"
        static let tierExpertClear = "\(prefix).tier_expert_clear"
        static let perfectRun      = "\(prefix).perfect_run"
        static let perfectX10      = "\(prefix).perfect_x10"
        static let branchMaster    = "\(prefix).branch_master"
        static let denseMaster     = "\(prefix).dense_master"
        static let multiNode       = "\(prefix).multi_node"
        static let noRetry         = "\(prefix).no_retry"
    }

    // ── Level catalog counts (cached at first use) ─────────────────────────

    private static let easyCount:   Int = LevelGenerator.levels.filter { $0.difficulty == .easy }.count
    private static let mediumCount: Int = LevelGenerator.levels.filter { $0.difficulty == .medium }.count
    private static let hardCount:   Int = LevelGenerator.levels.filter { $0.difficulty == .hard }.count
    private static let expertCount: Int = LevelGenerator.levels.filter { $0.difficulty == .expert }.count
    private static let totalLevels: Int = LevelGenerator.levels.count

    // ── Public API ─────────────────────────────────────────────────────────

    /// Evaluate all 14 achievements after a successful win and report progress.
    /// Safe to call every win — GC ignores reports where percentComplete <= previous.
    func checkAfterWin(
        result: GameResult,
        level: Level,
        profile: AstronautProfile
    ) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        var achievements: [GKAchievement] = []

        let completions = profile.uniqueCompletions

        // 1. First Level — binary
        if completions >= 1 {
            achievements.append(achievement(ID.firstLevel, percent: 100))
        }

        // 2. Complete 10 — progress
        achievements.append(achievement(ID.complete10, percent: progress(completions, of: 10)))

        // 3. Complete 25 — progress
        achievements.append(achievement(ID.complete25, percent: progress(completions, of: 25)))

        // 4. Complete All (180) — progress
        achievements.append(achievement(ID.completeAll, percent: progress(completions, of: Self.totalLevels)))

        // 5–8. Tier clears — progress
        let easyDone   = profile.completedCount(for: .easy)
        let mediumDone = profile.completedCount(for: .medium)
        let hardDone   = profile.completedCount(for: .hard)
        let expertDone = profile.completedCount(for: .expert)

        achievements.append(achievement(ID.tierEasyClear,   percent: progress(easyDone,   of: Self.easyCount)))
        achievements.append(achievement(ID.tierMediumClear, percent: progress(mediumDone, of: Self.mediumCount)))
        achievements.append(achievement(ID.tierHardClear,   percent: progress(hardDone,   of: Self.hardCount)))
        achievements.append(achievement(ID.tierExpertClear, percent: progress(expertDone, of: Self.expertCount)))

        // 9. Perfect Run — binary (any level with efficiency >= 0.95)
        if result.isOptimalRoute {
            achievements.append(achievement(ID.perfectRun, percent: 100))
        }

        // 10. Perfect x10 — progress (10 levels with optimal efficiency)
        let optimalTotal = profile.totalOptimalCount
        achievements.append(achievement(ID.perfectX10, percent: progress(optimalTotal, of: 10)))

        // 11. Branch Master — 5 branching levels with optimal efficiency
        let branchOptimal = profile.optimalCount(for: .branching)
        achievements.append(achievement(ID.branchMaster, percent: progress(branchOptimal, of: 5)))

        // 12. Dense Master — 5 dense levels with optimal efficiency
        let denseOptimal = profile.optimalCount(for: .dense)
        achievements.append(achievement(ID.denseMaster, percent: progress(denseOptimal, of: 5)))

        // 13. Multi-Node — binary (first multiTarget level completed)
        if level.levelType == .multiTarget {
            achievements.append(achievement(ID.multiNode, percent: 100))
        }

        // 14. No Retry — binary (expert level won on first try)
        if level.difficulty == .expert && result.attemptCount == 1 {
            achievements.append(achievement(ID.noRetry, percent: 100))
        }

        // Filter out 0% progress and report
        let toReport = achievements.filter { $0.percentComplete > 0 }
        guard !toReport.isEmpty else { return }

        Task {
            do {
                try await GKAchievement.report(toReport)
                #if DEBUG
                let names = toReport.map { "\($0.identifier)=\(Int($0.percentComplete))%" }
                print("[Achievements] ✓ Reported: \(names.joined(separator: ", "))")
                #endif
            } catch {
                #if DEBUG
                print("[Achievements] ✗ Report failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private func achievement(_ identifier: String, percent: Double) -> GKAchievement {
        let a = GKAchievement(identifier: identifier)
        a.percentComplete = percent
        a.showsCompletionBanner = true
        return a
    }

    /// Clamp progress to 0–100 range.
    private func progress(_ current: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(100.0, Double(current) / Double(total) * 100.0)
    }
}
