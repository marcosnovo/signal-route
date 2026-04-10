import SwiftUI

struct ContentView: View {
    @State private var activeLevel: Level?        = nil
    @State private var showingLevelSelect: Bool   = false

    var body: some View {
        ZStack {
            if let level = activeLevel {
                GameView(level: level, onDismiss: { activeLevel = nil })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
            } else if showingLevelSelect {
                LevelSelectView(
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
                    onPlay:        { level in activeLevel = level },
                    onSecretMenu:  { showingLevelSelect = true }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal:   .move(edge: .leading)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: activeLevel != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: showingLevelSelect)
    }
}

#Preview {
    ContentView()
}
