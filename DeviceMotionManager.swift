import Combine
import CoreMotion
import Foundation

// MARK: - DeviceMotionManager
/// Lightweight CoreMotion wrapper that publishes two smoothed, normalised tilt values
/// derived from the device gravity vector.
///
/// ## Coordinate mapping
///   `tiltX` ← `gravity.x`      — left/right phone tilt, 0 when upright
///   `tiltY` ← `gravity.y + 1`  — forward/back phone tilt, 0 when upright (~−1 when upright gravity.y)
///
/// Both values are low-pass filtered (α = 0.88) and clamped to ±1.
/// The working range is ±0.35 gravity units (≈ ±20° of physical tilt).
///
/// ## Usage
///   Call `start()` when the view appears, `stop()` when it disappears.
///   Observe `tiltX` and `tiltY` (both `@Published`) in your SwiftUI view.
///   When `isAvailable` is `false` (Simulator, some iPad configs), both values stay 0.
final class DeviceMotionManager: ObservableObject {

    // MARK: - Shared singleton
    static let shared = DeviceMotionManager()

    // MARK: - Published state
    @Published private(set) var tiltX: Double = 0   // left/right,   ±1
    @Published private(set) var tiltY: Double = 0   // forward/back, ±1

    // MARK: - Public interface
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0   // 30 Hz — enough for smooth parallax
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        // Leave last published values in place so the card doesn't snap on stop.
    }

    /// Smoothly decay both tilt values toward zero.
    /// Call this when the export sheet is presented so the card settles to its canonical rest.
    func decayToZero() {
        smoothX = 0
        smoothY = 0
        tiltX   = 0
        tiltY   = 0
    }

    // MARK: - Private

    private let manager  = CMMotionManager()
    private var smoothX: Double = 0
    private var smoothY: Double = 0

    /// Low-pass coefficient. Higher = smoother but slower to respond.
    private let alpha: Double = 0.88
    /// Working range in gravity units.  ±0.35 g ≈ ±20° of physical tilt.
    private let range: Double = 0.35

    private init() {}

    private func process(_ motion: CMDeviceMotion) {
        // gravity.x: 0 when upright, positive when phone tilts right
        // gravity.y: ≈ -1 when upright (portrait), offset so 0 = natural holding angle
        let rawX = motion.gravity.x
        let rawY = motion.gravity.y + 1.0

        let nx = max(-1, min(1, rawX / range))
        let ny = max(-1, min(1, rawY / range))

        smoothX = smoothX * alpha + nx * (1 - alpha)
        smoothY = smoothY * alpha + ny * (1 - alpha)

        tiltX = smoothX
        tiltY = smoothY
    }
}
