import SwiftUI
import UserNotifications

@main
struct geometryApp: App {
    @StateObject private var gcManager   = GameCenterManager.shared
    @StateObject private var entitlement = EntitlementStore.shared
    @StateObject private var storeKit    = StoreKitManager.shared
    @StateObject private var cloudSave   = CloudSaveManager.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// Coordinates the launch splash. Drives audio + StoreKit init concurrently
    /// with a 3-second hard cap. Stored as @State so SwiftUI tracks isDone changes.
    @State private var splash = SplashCoordinator()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Game UI is rendered first so it is warm when the splash exits.
                ContentView()
                    .environmentObject(gcManager)
                    .environmentObject(SettingsStore.shared)
                    .environmentObject(entitlement)
                    .environmentObject(storeKit)
                    .environmentObject(cloudSave)

                // Splash overlay — removed once coordinator signals done.
                if !splash.isDone {
                    SplashView(coordinator: splash)
                        .transition(
                            .opacity.combined(with: .scale(scale: 1.04))
                        )
                        .zIndex(999)
                }
            }
            .animation(.easeOut(duration: 0.55), value: splash.isDone)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    AudioManager.shared.handleForeground()
                case .background:
                    AudioManager.shared.handleBackground()
                default:
                    break
                }
            }
            .task {
                // Game Center auth is fire-and-forget — not a splash gate.
                gcManager.authenticate()
                // Coordinator runs audio + StoreKit concurrently (max 3 s).
                // Sonic logo is played inside run() after the SFX pool is ready.
                await splash.run(storeKit: storeKit)
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
