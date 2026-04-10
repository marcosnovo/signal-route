import SwiftUI
import GameKit

// MARK: - HomeView  (mission-control panel)
struct HomeView: View {
    let onPlay: (Level) -> Void
    let onSecretMenu: () -> Void

    @EnvironmentObject private var gcManager: GameCenterManager
    @State private var secretTaps  = 0
    @State private var lastTapTime = Date.distantPast

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundSystem()

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
                statusStrip.padding(.bottom, 32)
            }
        }
    }

    // MARK: Subviews

    private var systemBar: some View {
        HStack {
            PlayerBlock(gcManager: gcManager)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(AppTheme.success).frame(width: 5, height: 5)
                    .pulsingGlow(color: AppTheme.success, duration: 2.0)
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
                GeoTitle()
                Text("CONNECT THE GRID")
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(3)
            }
        }
    }

    private var todayResult: GameResult? { DailyStore.todayResult }
    private var introCompleted: Bool { OnboardingStore.hasCompletedIntro }

    // MARK: Mission section — adapts to player state
    private var missionSection: some View {
        VStack(spacing: 10) {
            if introCompleted {
                // Returning player: daily mission flow
                MissionCard(level: LevelGenerator.dailyLevel, result: todayResult)

                if let result = todayResult {
                    // Already played today — show compact replay + efficiency reminder
                    Button(action: { onPlay(LevelGenerator.dailyLevel) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("REPLAY MISSION")
                                .font(AppTheme.mono(12, weight: .bold))
                                .kerning(2)
                            Spacer()
                            Text("\(result.efficiencyPercent)% EFF")
                                .font(AppTheme.mono(9))
                                .foregroundStyle(result.success ? AppTheme.success : AppTheme.danger)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(AppTheme.backgroundSecondary)
                        .foregroundStyle(AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
                        )
                    }
                } else {
                    // Daily mission not yet played
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
                    .breathingCTA()
                }
            } else {
                // New / returning pre-training player — prompt the intro
                TrainingCard()

                Button(action: { onPlay(LevelGenerator.introLevel) }) {
                    HStack(spacing: 10) {
                        Text("INITIALIZE FIRST MISSION")
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
                .breathingCTA()
            }
        }
    }

    // MARK: Status strip — live system readout replacing dead nav tabs
    private var statusStrip: some View {
        VStack(spacing: 0) {
            TechDivider()
            HStack(spacing: 0) {
                // Signal: always hot
                HStack(spacing: 5) {
                    Circle().fill(AppTheme.success).frame(width: 4, height: 4)
                        .pulsingGlow(color: AppTheme.success, duration: 1.8)
                    TechLabel(text: "SIGNAL  ·  ACTIVE")
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 18)

                // Daily status
                TechLabel(
                    text: "DAILY  ·  \(todayResult != nil ? "DONE" : "PENDING")",
                    color: todayResult != nil ? AppTheme.success : AppTheme.textSecondary
                )
                .frame(maxWidth: .infinity)

                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 18)

                // System version
                TechLabel(text: "SYS  ·  v1.0")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
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
    var result: GameResult? = nil

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
                if let result {
                    // Completion badge replaces difficulty label
                    HStack(spacing: 4) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.danger)
                        Text(result.success ? "COMPLETE" : "FAILED")
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.danger)
                            .kerning(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                (result.success ? AppTheme.success : AppTheme.danger).opacity(0.45),
                                lineWidth: 0.5
                            )
                    )
                    .pulsingGlow(color: result.success ? AppTheme.success : AppTheme.danger)
                } else {
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
                        .pulsingGlow(color: level.difficulty.color, duration: 1.5)
                }
            }
            .padding(16)

            TechDivider()

            // Stats row
            HStack(spacing: 0) {
                MiniStatCell(label: "GRID", value: "\(level.gridSize) × \(level.gridSize)")
                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                if let result {
                    MiniStatCell(label: "EFFICIENCY", value: "\(result.efficiencyPercent)%",
                                 accent: result.success)
                    Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                    MiniStatCell(label: "MOVES USED", value: "\(result.movesUsed)")
                } else {
                    MiniStatCell(label: "MOVES", value: "\(level.maxMoves)")
                    Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                    MiniStatCell(label: "SIGNAL", value: "ACTIVE", accent: true)
                }
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

// MARK: - TrainingCard
/// Mission card variant shown to players who haven't completed the intro yet.
struct TrainingCard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TechLabel(text: "SYSTEM CALIBRATION", color: AppTheme.accentPrimary)
                    Text("TRAINING MISSION")
                        .font(AppTheme.mono(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Text("REQUIRED")
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
                    .kerning(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.45), lineWidth: 0.5)
                    )
                    .pulsingGlow(color: AppTheme.accentPrimary)
            }
            .padding(16)

            TechDivider()

            HStack(spacing: 0) {
                MiniStatCell(label: "GRID", value: "3 × 3")
                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                MiniStatCell(label: "MOVES", value: "5")
                Rectangle().fill(AppTheme.stroke).frame(width: 0.5, height: 24)
                MiniStatCell(label: "SIGNAL", value: "READY", accent: true)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(AppTheme.accentPrimary.opacity(0.22), lineWidth: 0.5)
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

// MARK: - PlayerBlock
/// Top-left identity module.
/// Authenticated  → square avatar tile + name + live GC status dot.
/// Not authenticated → silent fallback to system label (no visual noise).
private struct PlayerBlock: View {
    @ObservedObject var gcManager: GameCenterManager

    var body: some View {
        Group {
            if gcManager.isAuthenticated {
                Button(action: { gcManager.openDashboard() }) {
                    identityRow
                }
                .buttonStyle(.plain)
            } else {
                TechLabel(text: "ORBITAL SYS  v1.0")
            }
        }
        // Present GK sign-in sheet when GameKit needs it
        .sheet(item: Binding(
            get: { gcManager.presentationViewController.map(UIVCWrapper.init) },
            set: { _ in }
        )) { wrapper in
            UIViewControllerRepresentableWrapper(viewController: wrapper.vc)
                .ignoresSafeArea()
        }
    }

    // MARK: Authenticated layout
    private var identityRow: some View {
        HStack(spacing: 8) {
            // Square avatar tile — mission-control aesthetic
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.surface)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.28), lineWidth: 0.5)
                    )
                Text(initials)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary)
            }

            // Name + live status
            VStack(alignment: .leading, spacing: 2) {
                Text(String(gcManager.displayName.prefix(14)).uppercased())
                    .font(AppTheme.mono(9, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 4, height: 4)
                        .pulsingGlow(color: AppTheme.success, duration: 2.2)
                    Text("GC ONLINE")
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary)
                        .kerning(0.5)
                }
            }
        }
    }

    private var initials: String {
        let words = gcManager.displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1))
        }
        return String(gcManager.displayName.prefix(2)).uppercased()
    }
}

/// Thin Identifiable wrapper so `.sheet(item:)` works with UIViewController.
private struct UIVCWrapper: Identifiable {
    let id = UUID()
    let vc: UIViewController
}

/// Bridges a UIViewController into SwiftUI for the GK sign-in sheet.
private struct UIViewControllerRepresentableWrapper: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - GeoTitle
/// "GEOMETRY" with two independent ambient effects:
///   • Periodic tilt on the "R" (easter egg, ~6s cycle)
///   • Rare glitch: horizontal offset + RGB-split ghost copies (~8–15s interval, ~150ms duration)
private struct GeoTitle: View {
    @State private var rTilt:       Double  = 0
    @State private var isGlitching: Bool    = false
    @State private var glitchX:     CGFloat = 0

    var body: some View {
        ZStack {
            // Ghost layers — only during glitch (RGB-split simulation)
            if isGlitching {
                letters
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.30))
                    .offset(x: glitchX + 3)
                letters
                    .foregroundStyle(AppTheme.accentSecondary.opacity(0.22))
                    .offset(x: glitchX - 2)
            }
            // Primary text
            letters
                .foregroundStyle(AppTheme.textPrimary)
                .offset(x: isGlitching ? glitchX : 0)
                .opacity(isGlitching ? 0.86 : 1.0)
        }
        .task { await tiltLoop() }
        .task { await glitchLoop() }
    }

    /// Letter layout shared by all layers.
    @ViewBuilder
    private var letters: some View {
        HStack(spacing: 0) {
            Text("GEOMET").kerning(5)
            Text("R").kerning(5)
                .rotationEffect(.degrees(rTilt))
            Text("Y")
        }
        .font(AppTheme.mono(26, weight: .heavy))
    }

    // MARK: Tilt loop (~6 s cycle)
    private func tiltLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { rTilt = 10 }
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) { rTilt = 0 }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: Glitch loop (8–15 s idle, ~150 ms burst)
    private func glitchLoop() async {
        // Stagger so glitch never fires immediately on launch
        try? await Task.sleep(nanoseconds: UInt64.random(in: 9_000_000_000...14_000_000_000))
        while !Task.isCancelled {
            // --- flash 1 ---
            glitchX = CGFloat.random(in: -5...5)
            isGlitching = true
            try? await Task.sleep(nanoseconds: 65_000_000)   // 65 ms
            // --- flash 2 (reposition mid-glitch) ---
            glitchX = CGFloat.random(in: -4...4)
            try? await Task.sleep(nanoseconds: 85_000_000)   // 85 ms
            // --- reset ---
            isGlitching = false
            glitchX = 0
            // --- next idle ---
            let idle = UInt64.random(in: 8_000_000_000...15_000_000_000)
            try? await Task.sleep(nanoseconds: idle)
        }
    }
}
