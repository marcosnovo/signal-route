import SwiftUI

// MARK: - SplashCoordinator
/// Central coordinator for the launch-splash loading sequence.
///
/// Drives two concurrent tasks (audio preparation + StoreKit) alongside a
/// synchronous store warm-up, and enforces a 3-second hard timeout so the
/// player always enters the game within the cap even if a subsystem stalls.
///
/// Essential vs non-essential distinction:
///   • Essential (gates entry):   audio synthesis, StoreKit entitlements
///   • Non-essential (warm only): ProgressionStore profile decode
///   • Fire-and-forget:           Game Center auth (handled in geometryApp)
///
/// Usage:
/// ```swift
/// @State private var splash = SplashCoordinator()
/// // …
/// .task { await splash.run(storeKit: storeKit) }
/// ```
@MainActor
@Observable
final class SplashCoordinator {

    // MARK: - Subsystem readiness

    private(set) var isAudioReady  = false
    private(set) var isStoresReady = false
    private(set) var hasTimedOut   = false

    /// `true` when all essential subsystems are ready **or** the 3-second cap fires.
    /// Removing the splash overlay from the hierarchy should be keyed to this value.
    var isDone: Bool { (isAudioReady && isStoresReady) || hasTimedOut }

    // MARK: - Launch sequence

    /// Starts the loading sequence. Call exactly once from `geometryApp.body.task`.
    ///
    /// Steps:
    ///   1. Warm synchronous stores on the main thread (microseconds — no flag needed)
    ///   2. Arm the 3-second hard-cap timeout
    ///   3. Run audio prep and StoreKit concurrently
    ///   4. (DEBUG) log per-subsystem and total timings
    func run(storeKit: StoreKitManager) async {
        #if DEBUG
        let splashStart = Date()
        #endif

        // ── 1. Synchronous store warm-up ─────────────────────────────────────
        // Pre-decode the player profile from UserDefaults JSON so the first
        // HomeView render is instant. Total cost: ~3–8 ms, main thread.
        warmSyncStores()

        // ── 2. 3-second hard-cap timeout ─────────────────────────────────────
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            #if DEBUG
            if !self.isDone {
                print("[Splash] ⚠️ Timeout fired — audio:\(self.isAudioReady) stores:\(self.isStoresReady)")
            }
            #endif
            self.hasTimedOut = true
        }

        // ── 3. Concurrent essential loading ──────────────────────────────────
        await withTaskGroup(of: Void.self) { group in

            // Audio: SoundManager.prepare() + MusicSynthesizer.buildAll()
            // Heavy work runs on a utility-priority detached task inside prepare().
            group.addTask { @MainActor in
                #if DEBUG
                let t = Date()
                #endif
                await AudioManager.shared.prepare()
                self.isAudioReady = true
                #if DEBUG
                print(String(format: "[Splash] ✓ Audio ready  %.2fs", Date().timeIntervalSince(t)))
                #endif
            }

            // StoreKit: entitlement check + product load
            group.addTask { @MainActor in
                #if DEBUG
                let t = Date()
                #endif
                await storeKit.checkEntitlements()
                await storeKit.loadProduct()
                self.isStoresReady = true
                #if DEBUG
                print(String(format: "[Splash] ✓ Stores ready %.2fs", Date().timeIntervalSince(t)))
                #endif
            }
        }

        #if DEBUG
        let total    = Date().timeIntervalSince(splashStart)
        let timedOut = hasTimedOut ? " ⚠️ TIMED OUT" : ""
        print(String(format: "[Splash] Total %.2fs%@", total, timedOut))
        #endif
    }

    // MARK: - Private

    /// Warm synchronous data stores before async work begins.
    /// All reads are UserDefaults + JSON decode — no I/O suspension.
    private func warmSyncStores() {
        _ = ProgressionStore.profile   // pre-decode AstronautProfile JSON
    }
}
