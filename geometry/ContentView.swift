import SwiftUI

struct ContentView: View {
    @State private var activeLevel: Level?        = nil
    @State private var showingLevelSelect: Bool   = false
    @State private var isIntroActive: Bool        = !OnboardingStore.hasCompletedIntro

    var body: some View {
        ZStack {
            if isIntroActive {
                // First launch → intro mission (no home screen)
                GameView(
                    level: LevelGenerator.introLevel,
                    isIntro: true,
                    onDismiss: {
                        // Back/skip — don't mark complete; show intro again next launch
                        isIntroActive = false
                    },
                    onIntroComplete: {
                        // Win — mark complete and proceed to Home
                        OnboardingStore.markIntroCompleted()
                        isIntroActive = false
                    }
                )
                .transition(.opacity)
            } else if let level = activeLevel {
                GameView(
                    level: level,
                    onDismiss: { activeLevel = nil },
                    onNextMission: { activeLevel = ProgressionStore.profile.nextMission },
                    onMissions: { activeLevel = nil; showingLevelSelect = true }
                )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
            } else if showingLevelSelect {
                MissionMapView(
                    onSelect: { level in
                        showingLevelSelect = false
                        activeLevel = level
                    },
                    onDismiss: { showingLevelSelect = false }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal:   .move(edge: .bottom)
                ))
            } else {
                HomeView(
                    onPlay:     { level in activeLevel = level },
                    onMissions: { showingLevelSelect = true }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal:   .move(edge: .leading)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: activeLevel != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: showingLevelSelect)
        .animation(.spring(response: 0.44, dampingFraction: 0.88), value: isIntroActive)
    }
}

#Preview {
    ContentView()
}
