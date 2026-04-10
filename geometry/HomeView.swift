import SwiftUI

// MARK: - HomeView  (mission-control panel)
struct HomeView: View {
    let onPlay: (Level) -> Void
    let onSecretMenu: () -> Void

    @State private var secretTaps  = 0
    @State private var lastTapTime = Date.distantPast

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            // Large decorative text in background
            Text("GEO")
                .font(.system(size: 200, weight: .black, design: .default))
                .foregroundStyle(Color.white.opacity(0.022))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 20, y: 50)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                systemBar
                Spacer()
                titleSection.padding(.bottom, 48)
                missionSection.padding(.horizontal, 24)
                Spacer()
                bottomNav.padding(.bottom, 32)
            }
        }
    }

    // MARK: Subviews

    private var systemBar: some View {
        HStack {
            TechLabel(text: "ORBITAL SYS  v1.0")
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(AppTheme.success).frame(width: 5, height: 5)
                TechLabel(text: "NODE ACTIVE")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var titleSection: some View {
        VStack(spacing: 18) {
            // Logo (secret menu trigger: tap 5× within 2 s)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.35), lineWidth: 1)
                    .frame(width: 68, height: 68)
                Image(systemName: "circle.grid.3x3")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(AppTheme.accentPrimary)
            }
            .onTapGesture { handleSecretTap() }

            VStack(spacing: 7) {
                Text("GEOMETRY")
                    .font(AppTheme.mono(26, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(5)
                Text("CONNECT THE GRID")
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(3)
            }
        }
    }

    private var missionSection: some View {
        VStack(spacing: 10) {
            MissionCard(level: LevelGenerator.dailyLevel)

            Button(action: { onPlay(LevelGenerator.dailyLevel) }) {
                HStack(spacing: 10) {
                    Text("INITIALIZE MISSION")
                        .font(AppTheme.mono(12, weight: .bold))
                        .kerning(2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accentPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }

            Button(action: {}) {
                TechLabel(text: "PRACTICE MODE  ·  COMING SOON")
            }
            .disabled(true)
            .opacity(0.4)
        }
    }

    private var bottomNav: some View {
        VStack(spacing: 0) {
            TechDivider()
            HStack(spacing: 0) {
                ForEach(["SIGNAL", "NODE", "CONTROL", "ORBITAL"], id: \.self) { label in
                    Button(action: {}) {
                        TechLabel(text: label)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(true)
                }
            }
        }
    }

    // MARK: Secret trigger
    private func handleSecretTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 2.0 { secretTaps = 0 }
        lastTapTime = now
        secretTaps += 1
        if secretTaps >= 5 {
            secretTaps = 0
            onSecretMenu()
        }
    }
}

// MARK: - MissionCard
struct MissionCard: View {
    let level: Level

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: "DAILY MISSION · \(dateString)", color: AppTheme.accentPrimary)
                    Text(level.displayName)
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Text(level.difficulty.fullLabel)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(level.difficulty.color)
                    .kerning(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(level.difficulty.color.opacity(0.45), lineWidth: 0.5)
                    )
            }
            .padding(16)

            TechDivider()

            // Stats row
            HStack(spacing: 0) {
                MiniStatCell(label: "GRID",  value: "4 × 4")
                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                MiniStatCell(label: "MOVES", value: "\(level.maxMoves)")
                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                MiniStatCell(label: "SIGNAL", value: "ACTIVE", accent: true)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.strokeBright, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

// MARK: - MiniStatCell
struct MiniStatCell: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            TechLabel(text: label)
            Text(value)
                .font(AppTheme.mono(12, weight: .semibold))
                .foregroundStyle(accent ? AppTheme.success : AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
