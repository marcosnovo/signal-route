import SwiftUI

// MARK: - BackgroundSystem
/// Single entry point for all background atmosphere layers.
///
/// Layer order (back → front):
///   1. BackgroundGrid     — drifting technical grid lines (structure)
///   2. BackgroundSignalNodes — asynchronous pulsing dots (state / presence)
///   3. BackgroundEnergyLine  — occasional sweeping signal (event / flow)
///
/// Design rules shared across all layers:
///   • Base opacity  ≤ 0.08   — nearly invisible at rest
///   • Peak opacity  ≤ 0.55   — visible but never competing with UI content
///   • Palette       — orange (accent), sage (secondary), white (neutral)
///   • Zero hit testing — all decoration, never intercepting touches
struct BackgroundSystem: View {

    var body: some View {
        ZStack {
            BackgroundGrid()
            BackgroundSignalNodes()
            BackgroundEnergyLine()
        }
        .allowsHitTesting(false)
    }
}
