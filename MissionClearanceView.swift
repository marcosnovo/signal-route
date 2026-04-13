import SwiftUI

// MARK: - MissionClearanceView
/// Brief "cleared for mission" confirmation shown after the onboarding gameplay tutorial.
/// Acts as a bridge between the intro and the player's first real mission.
///
/// Shown once — `onLaunch` is called when the player taps the launch button.
/// `ContentView` marks the intro complete and loads Mission 1 from `onLaunch`.
struct MissionClearanceView: View {

    let onLaunch: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.93).ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                gradient: Gradient(colors: [AppTheme.accentPrimary.opacity(0.10), .clear]),
                center: .center, startRadius: 40, endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Card
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    header
                    content
                    launchButton
                }
                .background(AppTheme.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(AppTheme.accentPrimary.opacity(0.32), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 22)
                .scaleEffect(appeared ? 1.0 : 0.94)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack(spacing: 8) {
            BlinkingSignalDot(color: AppTheme.accentPrimary)
            Text("MISSION CONTROL  ·  ENCRYPTED LINK")
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(AppTheme.accentPrimary.opacity(0.65))
                .kerning(1.2)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(AppTheme.accentPrimary.opacity(0.06))
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Clearance badge
            Text("CLEARANCE GRANTED")
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(AppTheme.accentPrimary)
                .kerning(1.2)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(AppTheme.accentPrimary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(AppTheme.accentPrimary.opacity(0.30), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Title
            Text("MISSION READY")
                .font(AppTheme.mono(24, weight: .black))
                .foregroundStyle(Color.white)
                .kerning(3)

            // Body
            Text("You are cleared for your first mission.")
                .font(AppTheme.mono(11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)

            // Footer hint
            HStack(spacing: 5) {
                Rectangle()
                    .fill(AppTheme.accentPrimary.opacity(0.50))
                    .frame(width: 14, height: 1)
                Text("MISSION 1  ·  EARTH ORBIT")
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.70))
                    .kerning(1.0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var launchButton: some View {
        Button(action: onLaunch) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("LAUNCH MISSION")
                    .font(AppTheme.mono(10, weight: .bold))
                    .kerning(2)
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BlinkingSignalDot
/// Reusable blinking dot (same as in StoryBeatView but scoped here for independence).
private struct BlinkingSignalDot: View {
    let color: Color
    @State private var on = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(on ? 1.0 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { on = false }
            }
    }
}
