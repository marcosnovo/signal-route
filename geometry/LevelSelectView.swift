import SwiftUI

// MARK: - LevelSelectView  (secret developer menu)
struct LevelSelectView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                header
                difficultyLegend
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                TechDivider()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(LevelGenerator.levels) { level in
                            LevelCell(level: level) { onSelect(level) }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: Subviews

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    TechLabel(text: "BACK")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("LEVEL SELECT")
                    .font(AppTheme.mono(13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(2)
                TechLabel(text: "DEV MODE  ·  \(LevelGenerator.levels.count) MISSIONS",
                          color: AppTheme.accentPrimary)
            }

            Spacer()

            // Balance placeholder
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                TechLabel(text: "BACK")
            }
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var difficultyLegend: some View {
        HStack(spacing: 20) {
            ForEach(DifficultyTier.allCases) { tier in
                HStack(spacing: 5) {
                    Circle().fill(tier.color).frame(width: 5, height: 5)
                    TechLabel(text: tier.fullLabel, color: tier.color)
                }
            }
            Spacer()
        }
    }
}

// MARK: - LevelCell
struct LevelCell: View {
    let level: Level
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Difficulty accent bar
                Rectangle()
                    .fill(level.difficulty.color)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 5) {
                    // Top row: level number + grid size
                    HStack(alignment: .firstTextBaseline) {
                        Text(level.displayID)
                            .font(AppTheme.mono(16, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(level.gridSize)×\(level.gridSize)")
                            .font(AppTheme.mono(9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    // Level type
                    Text(level.levelType.rawValue)
                        .font(AppTheme.mono(8, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // Bottom row: difficulty + targets
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(level.difficulty.color)
                                .frame(width: 5, height: 5)
                            Text(level.difficulty.label)
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(level.difficulty.color)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "scope")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(AppTheme.accentSecondary.opacity(0.8))
                            Text("\(level.numTargets)")
                                .font(AppTheme.mono(8, weight: .bold))
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }
}
