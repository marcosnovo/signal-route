import SwiftUI

// MARK: - RankingsView

struct RankingsView: View {
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private let engine = AchievementEngine.shared

    private let dark  = Color(hex: "0D0D0D")
    private let light = Color(hex: "F0EDE8")
    private let muted = Color(hex: "9A9A9A")

    var body: some View {
        ZStack {
            dark.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Rectangle().fill(light.opacity(0.06)).frame(height: 0.5)
                achievementsSection
            }
        }
        .task {
            engine.syncFromProfile()
            await engine.loadGCImages()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: { SoundManager.play(.tapSecondary); onDismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(light.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(light.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(light.opacity(0.12), lineWidth: 0.5))
                }
                Spacer()
                Text(S.achievements)
                    .font(AppTheme.mono(12, weight: .bold))
                    .adaptiveKerning(1.5)
                    .foregroundStyle(light)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 4)

            Text(S.achievementCount(engine.unlockedCount, engine.totalCount))
                .font(AppTheme.mono(9, weight: .medium))
                .foregroundStyle(muted)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let sorted = engine.sortedAchievements()
        return VStack(spacing: 0) {
            AchievementsCardStackView(achievements: sorted, engine: engine)
                .padding(.top, 16)

            Text("\(min(currentPageIndex(sorted.count) + 1, sorted.count)) / \(sorted.count)")
                .font(AppTheme.mono(10, weight: .semibold))
                .foregroundStyle(muted)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }

    private func currentPageIndex(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return 0
    }
}
