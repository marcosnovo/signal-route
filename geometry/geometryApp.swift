import SwiftUI

@main
struct geometryApp: App {
    @StateObject private var gcManager = GameCenterManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .task {
                    gcManager.authenticate()
                    await SoundManager.prepare()
                }
        }
    }
}
