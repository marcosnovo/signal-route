import SwiftUI

@main
struct geometryApp: App {
    @StateObject private var gcManager   = GameCenterManager.shared
    @StateObject private var entitlement = EntitlementStore.shared
    @StateObject private var storeKit    = StoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .environmentObject(SettingsStore.shared)
                .environmentObject(entitlement)
                .environmentObject(storeKit)
                .task {
                    gcManager.authenticate()
                    await SoundManager.prepare()
                    // Restore premium across reinstalls / new devices
                    await storeKit.checkEntitlements()
                    await storeKit.loadProduct()
                    #if DEBUG
                    StoryAssetValidator.validate()
                    #endif
                }
        }
    }
}
