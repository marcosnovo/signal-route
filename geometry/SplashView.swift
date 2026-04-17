import SwiftUI

// MARK: - SplashView
/// Premium launch splash. Four visual layers:
///   1. Dot grid   — subtle orange technical texture
///   2. Radial glow — slow breathing, centered
///   3. Signal nodes — 8 sparse pulsing nodes around the perimeter
///   4. Logo + signal-line progress indicator
struct SplashView: View {

    let coordinator: SplashCoordinator

    @State private var contentAppeared = false
    @State private var glowOpacity: Double = 0.05

    var body: some View {
        ZStack {
            // ── Layer 0: Base ─────────────────────────────────────────────
            AppTheme.backgroundPrimary
                .ignoresSafeArea()

            // ── Layer 1: Technical dot grid ───────────────────────────────
            SplashDotGrid()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── Layer 2: Breathing radial glow ────────────────────────────
            RadialGradient(
                colors: [AppTheme.accentPrimary.opacity(glowOpacity), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Layer 3: Perimeter signal nodes ───────────────────────────
            SplashNodeField()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── Layer 4: Logo + loader ─────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                logoBlock
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 18)

                Spacer()

                // In-universe status copy — localized (S5)
                Text(networkingCopy)
                    .font(AppTheme.mono(7, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    .kerning(2)
                    .opacity(contentAppeared ? 1 : 0)
                    .padding(.bottom, 18)

                SignalProgressLine(
                    isAudioReady:  coordinator.isAudioReady,
                    isStoresReady: coordinator.isStoresReady
                )
                .opacity(contentAppeared ? 1 : 0)
                .padding(.horizontal, 48)
                .padding(.bottom, 54)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Logo block

    private var logoBlock: some View {
        VStack(spacing: 14) {
            // Decorative rule with diamond accent
            HStack(spacing: 10) {
                AppTheme.accentPrimary
                    .frame(width: 22, height: 1.5)
                    .opacity(0.55)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.65))
                AppTheme.accentPrimary
                    .frame(width: 22, height: 1.5)
                    .opacity(0.55)
            }

            Text("SIGNAL ROUTE")
                .font(AppTheme.mono(32, weight: .black))
                .foregroundStyle(Color.white)
                .kerning(5)

            AppTheme.accentPrimary
                .frame(width: 190, height: 1.5)

            Text("MISSION CONTROL INTERFACE")
                .font(AppTheme.mono(8, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .kerning(3)
        }
    }

    // MARK: - Branding copy (S5)

    /// Localized in-universe status line read once at view mount.
    /// Reads directly from the SettingsStore singleton — no environmentObject needed.
    private var networkingCopy: String {
        switch SettingsStore.shared.language {
        case .es: return "INICIALIZANDO RED"
        case .fr: return "INITIALISATION DU RÉSEAU"
        case .en: return "INITIALIZING NETWORK"
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.12)) {
            contentAppeared = true
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.14
        }
    }
}

// MARK: - SplashDotGrid
/// Canvas dot grid — very subtle orange texture with center-bright vignette.

private struct SplashDotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 40
            let r:    CGFloat = 0.85
            let cx = size.width  * 0.5
            let cy = size.height * 0.5
            let maxD = sqrt(cx * cx + cy * cy)

            var x: CGFloat = step * 0.5
            while x < size.width + step {
                var y: CGFloat = step * 0.5
                while y < size.height + step {
                    let d = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
                    // Vignette: dots brightest at center (t=1), dim at corners (t=0)
                    let t = 1.0 - min(d / maxD, 1.0)
                    let opacity = 0.025 + t * 0.045
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(Color(hex: "FF6A3D").opacity(opacity))
                    )
                    y += step
                }
                x += step
            }
        }
    }
}

// MARK: - SplashNodeField
/// 8 sparse signal nodes placed around the screen perimeter, each pulsing
/// on an independent async loop — same technique as BackgroundSignalNodes.

private let kSplashNodes: [(xRel: CGFloat, yRel: CGFloat, delay: Double, period: Double)] = [
    (0.10, 0.19, 0.0,  7.5),
    (0.88, 0.17, 2.2,  9.0),
    (0.06, 0.52, 1.4,  8.0),
    (0.93, 0.59, 3.1,  6.8),
    (0.18, 0.84, 0.8, 11.0),
    (0.80, 0.81, 4.2,  8.5),
    (0.47, 0.11, 1.9,  7.0),
    (0.63, 0.91, 2.7, 10.0),
]

private struct SplashNodeField: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(Array(kSplashNodes.enumerated()), id: \.offset) { _, def in
                SplashNodeDot(delay: def.delay, period: def.period)
                    .position(
                        x: def.xRel * geo.size.width,
                        y: def.yRel * geo.size.height
                    )
            }
        }
    }
}

private struct SplashNodeDot: View {
    let delay:  Double
    let period: Double

    @State private var opacity: Double  = 0.05
    @State private var scale:   CGFloat = 1.0

    var body: some View {
        ZStack {
            // Halo ring
            Circle()
                .strokeBorder(AppTheme.accentPrimary.opacity(opacity * 0.55), lineWidth: 0.6)
                .frame(width: 18, height: 18)
                .scaleEffect(scale * 1.3)
            // Core dot
            Circle()
                .fill(AppTheme.accentPrimary)
                .frame(width: 4, height: 4)
                .opacity(opacity)
                .shadow(color: AppTheme.accentPrimary.opacity(min(opacity * 1.5, 0.55)), radius: 5)
        }
        .task { await pulseLoop() }
    }

    private func pulseLoop() async {
        try? await Task.sleep(nanoseconds: ns(delay))
        while !Task.isCancelled {
            let peak = Double.random(in: 0.30...0.52)
            withAnimation(.easeOut(duration: 0.25)) {
                opacity = peak
                scale   = CGFloat.random(in: 1.12...1.28)
            }
            try? await Task.sleep(nanoseconds: ns(Double.random(in: 0.30...0.55)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.55)) {
                opacity = 0.05
                scale   = 1.0
            }
            try? await Task.sleep(nanoseconds: ns(period))
        }
    }

    private func ns(_ s: Double) -> UInt64 { UInt64(max(0, s) * 1_000_000_000) }
}

// MARK: - SignalProgressLine
/// In-universe loading indicator: a horizontal signal track that fills from
/// left → centre (AUDIO ready) → right (STORES ready), with three node
/// markers and dim → bright labels.

private struct SignalProgressLine: View {
    let isAudioReady:  Bool
    let isStoresReady: Bool

    /// 0.0 → 0.5 → 1.0 as subsystems come online.
    private var fillFraction: CGFloat {
        if isAudioReady && isStoresReady { return 1.0 }
        if isAudioReady                  { return 0.5 }
        return 0.0
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let mid = geo.size.height * 0.5
                let trackH: CGFloat = 1.5
                let nodeD:  CGFloat = 7
                let haloD:  CGFloat = 14

                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: w, height: trackH)
                    .position(x: w * 0.5, y: mid)

                // Animated fill (left-anchored, grows right)
                Capsule()
                    .fill(AppTheme.accentPrimary)
                    .frame(width: w * fillFraction, height: trackH)
                    .shadow(color: AppTheme.accentPrimary.opacity(0.55), radius: 4)
                    // Centre the capsule so its left edge stays at x=0
                    .position(x: w * fillFraction * 0.5, y: mid)
                    .animation(.easeOut(duration: 0.55), value: fillFraction)

                // Three nodes at 0 %, 50 %, 100 %
                ForEach([0, 1, 2], id: \.self) { i in
                    let xPos = CGFloat(i) * w * 0.5
                    let lit  = i == 0 || (i == 1 && isAudioReady) || (i == 2 && isStoresReady)
                    ZStack {
                        if lit {
                            Circle()
                                .fill(AppTheme.accentPrimary.opacity(0.28))
                                .frame(width: haloD, height: haloD)
                        }
                        Circle()
                            .fill(lit ? AppTheme.accentPrimary : Color.white.opacity(0.12))
                            .frame(width: nodeD, height: nodeD)
                            .shadow(color: lit ? AppTheme.accentPrimary.opacity(0.7) : .clear, radius: 5)
                    }
                    .position(x: xPos, y: mid)
                    .animation(.easeOut(duration: 0.35), value: lit)
                }
            }
            .frame(height: 20)

            // Subsystem labels
            HStack {
                Text("AUDIO")
                    .font(AppTheme.mono(7, weight: .semibold))
                    .foregroundStyle(
                        isAudioReady
                            ? AppTheme.textSecondary
                            : AppTheme.textSecondary.opacity(0.30)
                    )
                    .kerning(1.5)
                    .animation(.easeOut(duration: 0.25), value: isAudioReady)

                Spacer()

                Text("STORES")
                    .font(AppTheme.mono(7, weight: .semibold))
                    .foregroundStyle(
                        isStoresReady
                            ? AppTheme.textSecondary
                            : AppTheme.textSecondary.opacity(0.30)
                    )
                    .kerning(1.5)
                    .animation(.easeOut(duration: 0.25), value: isStoresReady)
            }
        }
    }
}
