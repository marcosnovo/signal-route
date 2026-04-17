import SwiftUI
import UserNotifications

@main
struct geometryApp: App {
    @StateObject private var gcManager   = GameCenterManager.shared
    @StateObject private var entitlement = EntitlementStore.shared
    @StateObject private var storeKit    = StoreKitManager.shared
    @StateObject private var cloudSave   = CloudSaveManager.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .environmentObject(SettingsStore.shared)
                .environmentObject(entitlement)
                .environmentObject(storeKit)
                .environmentObject(cloudSave)
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

// MARK: - AppDelegate
/// Sets up UNUserNotificationCenterDelegate so notification banners
/// appear even when the app is in the foreground.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show banner + play sound even while app is active
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
