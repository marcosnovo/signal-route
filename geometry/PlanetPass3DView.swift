import SwiftUI

// MARK: - PlanetPass3DView
/// Premium fake-3D ticket display built entirely in SwiftUI.
///
/// ## Two modes
///
/// **Preview mode** (default)
///   Full interactive experience: drag parallax, idle drift, entry animation,
///   gloss / specular / bevel layers.
///
/// **Export mode** (`isExporting = true`)
///   Set by the parent before presenting the share sheet.
///   The idle drift stops, the card springs to its canonical resting tilt,
///   and a brief border flash signals "capture".
///   The *actual exported image* is always the raw `UIImage` from `TicketRenderer`
///   (1080 × 1080, CGContext-rendered) — never a screenshot of this SwiftUI view.
///   This ensures the shared image is always pixel-perfect regardless of
///   whatever tilt or drag position the interactive view was in.
///
/// ## Layer stack (back → front)
///   1. Edge slab          — dark offset rect → physical card thickness
///   2. Ticket image       — the CGContext-rendered pass at native resolution
///   3. Planet depth       — screen-blend glow at planet position; parallax −8 pt/unit → furthest plane
///   4. Astronaut depth    — screen-blend catch-lights at helmet position; parallax −4 pt/unit → mid-plane
///   5. Inner shadow       — gradient darkening at top / bottom → surface curvature
///   6. Gloss overlay      — angled gradient whose anchors shift with tilt → fixed light source
///   7. Specular dot       — tight radial highlight that travels with tilt
///   8. Bevel stroke       — light top-left / dark bottom-right → machined edge
///   9. Export border      — bright white flash on isExporting → "capture" cue
///  10. Tap glow           — brief white flash on tap → physical press feedback
///  11. Sheen sweep        — one-time diagonal flash on appear → premium reveal
///  12. Scan overlay       — first-open reveal animation only
///
/// ## Entry animation (≈ 1.0 s)
///   Phase 1 — rise & appear   0.00–0.35 s
///   Phase 2 — spring settle   0.25–0.75 s
///   Phase 3 — sheen sweep     0.40–0.95 s
///
/// ## Interaction
///   Drag → two-axis rotation3DEffect + per-layer parallax; springs back on release.
///   Tap  → scale pulse + white flash + light haptic.
///   Idle → slow Lissajous-like drift when untouched; stops during export.
struct PlanetPass3DView: View {
    let image: UIImage

    var scanFraction: CGFloat = 1
    var revealed:     Bool    = true
    var accentColor:  Color   = AppTheme.accentPrimary
    /// Set to `true` by the parent just before the share sheet opens.
    /// Stops idle, springs the card to rest, and fires an export-border flash.
    var isExporting:  Bool    = false

    // ── Entry animation ───────────────────────────────────────────────────
    @State private var entryOpacity: Double  = 0.0
    @State private var entryOffsetY: CGFloat = 22
    @State private var entryScale:   CGFloat = 0.92
    @State private var entryTiltX:   Double  = 5.0
    @State private var entryTiltY:   Double  = -7.0

    // ── Idle drift ────────────────────────────────────────────────────────
    @State private var idleTiltX: Double = 0
    @State private var idleTiltY: Double = 0

    // ── Drag interaction ──────────────────────────────────────────────────
    @State private var tilt: CGSize = .zero

    // ── Tap feedback ──────────────────────────────────────────────────────
    @State private var tapScale:     CGFloat = 1.0
    @State private var tapGlowAlpha: Double  = 0.0

    // ── Export cue ───────────────────────────────────────────────────────
    /// Opacity of the bright white border flash on export trigger.
    @State private var exportBorderAlpha: Double = 0.0

    // ── Sheen sweep ───────────────────────────────────────────────────────
    @State private var sheenX: CGFloat = -0.5

    // ── Device motion ────────────────────────────────────────────────────
    @ObservedObject private var motion: DeviceMotionManager = .shared
    /// Animated scale applied to the motion contribution.
    /// Springs to 0 during export so the card settles to its canonical rest.
    @State private var motionScale: Double = 1.0

    // ── Tilt parameters ───────────────────────────────────────────────────
    private let restTiltX:    Double  =  3.5
    private let restTiltY:    Double  = -5.0
    private let maxTilt:      Double  =  8.0
    private let dragScale:    CGFloat = 80
    private let motionMaxTilt: Double =  6.0   // ±6° max from device motion

    // ── Helpers ───────────────────────────────────────────────────────────

    private func norm(_ v: CGFloat) -> Double {
        Double(max(-1.0, min(1.0, v / dragScale)))
    }

    private var normX: Double { norm(tilt.width)  }
    private var normY: Double { norm(tilt.height) }

    /// Smoothed, scaled device-motion contributions. Zero when not available.
    private var mX: Double { motion.isAvailable ? motion.tiltX * motionScale : 0 }
    private var mY: Double { motion.isAvailable ? motion.tiltY * motionScale : 0 }

    // Active tilt = editorial rest + drag + entry boost + idle drift + device motion
    // motion.tiltX (left/right phone tilt) drives Y rotation; tiltY drives X rotation.
    private var activeTiltX: Double { restTiltX + normY * maxTilt + entryTiltX + idleTiltX + mY * motionMaxTilt }
    private var activeTiltY: Double { restTiltY + normX * maxTilt + entryTiltY + idleTiltY + mX * motionMaxTilt }

    private var glossShiftX: Double { -normX * 0.14 - mX * 0.11 }
    private var glossShiftY: Double { -normY * 0.10 - mY * 0.08 }

    // Wider motion travel — now matches drag sensitivity
    private var specularX: Double { 0.30 - normX * 0.18 - mX * 0.16 }
    private var specularY: Double { 0.18 - normY * 0.10 - mY * 0.12 }

    /// Specular intensity 0.30–1.0.
    /// Peaks when the highlight is at its rest position (aligned with the simulated
    /// upper-left light source), fades as it drifts away with tilt.
    /// Physical analogy: the reflection "blooms" when it bounces straight back at
    /// the viewer's eye, and diffuses when the reflection angle diverges.
    private var specularIntensity: Double {
        let dx = specularX - 0.30
        let dy = specularY - 0.18
        return max(0.30, 1.0 - sqrt(dx * dx + dy * dy) * 2.4)
    }

    /// Gloss strip brightness 0.60–1.25.
    /// Slightly stronger when the card tilts toward the light (upper-left),
    /// slightly dimmer when tilting away.
    private var glossIntensity: Double {
        max(0.60, min(1.25, 1.0 - mX * 0.28 - mY * 0.18))
    }

    /// Bevel light-edge opacity (top-left corner).
    /// Brightens when the card tilts toward the light source.
    private var bevelLightOpacity: Double {
        let toward = (-normX - normY - mX - mY) * 0.25   // positive = tilted toward light
        return max(0.10, min(0.50, 0.30 + toward * 0.18))
    }

    /// Bevel dark-edge opacity (bottom-right corner).
    /// Deepens when the card tilts away from the light source.
    private var bevelDarkOpacity: Double {
        let away = (normX + normY + mX + mY) * 0.25     // positive = tilted away from light
        return max(0.08, min(0.38, 0.20 + away * 0.14))
    }

    private var displayScale: CGFloat { entryScale * tapScale }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            edgeSlab             //  1
            ticketImage          //  2
            planetDepthLayer     //  3
            astronautDepthLayer  //  4
            innerShadow          //  5
            glossOverlay         //  6
            specularDot          //  7
            bevelOverlay         //  8
            exportBorder         //  9
            tapGlow              // 10
            sheenSweep           // 11
            if !revealed { scanOverlay }   // 12
        }
        .rotation3DEffect(.degrees(activeTiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(activeTiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.55), radius: 5,  x: 2, y: 5)
        .shadow(
            color:  .black.opacity(0.30),
            radius: 30,
            x: 6  + CGFloat(normX) * 8 + CGFloat(mX) * 5,
            y: 18 + CGFloat(normY) * 8 + CGFloat(mY) * 4
        )
        .scaleEffect(displayScale)
        .offset(y: entryOffsetY)
        .opacity(entryOpacity)
        .onTapGesture { handleTap() }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in tilt = value.translation }
                .onEnded   { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        tilt = .zero
                    }
                }
        )
        // Respond to export mode: settle idle + silence motion + flash border
        .onChange(of: isExporting) { _, exporting in
            if exporting {
                // Kill idle drift and motion tilt so the card sits at its canonical rest
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    idleTiltX   = 0
                    idleTiltY   = 0
                    motionScale = 0
                }
                motion.decayToZero()
                // Brief bright border flash — "capture" signal
                withAnimation(.easeOut(duration: 0.10)) { exportBorderAlpha = 0.90 }
                Task {
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    withAnimation(.easeOut(duration: 0.35)) { exportBorderAlpha = 0.0 }
                }
            } else {
                // Share sheet dismissed — restore motion contribution
                withAnimation(.spring(response: 0.50, dampingFraction: 0.70)) {
                    motionScale = 1.0
                }
            }
        }
        .onAppear    { motion.start() }
        .onDisappear { motion.stop()  }
        .task { await runEntrySequence() }
        .task { await runIdleMotion()   }
    }

    // MARK: - Interaction

    private func handleTap() {
        HapticsManager.light()
        withAnimation(.easeOut(duration: 0.09)) { tapScale = 0.96 }
        Task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.50)) { tapScale = 1.0 }
        }
        withAnimation(.easeOut(duration: 0.07)) { tapGlowAlpha = 0.09 }
        Task {
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.easeOut(duration: 0.26)) { tapGlowAlpha = 0.0 }
        }
    }

    // MARK: - Entry sequence

    private func runEntrySequence() async {
        // Phase 1 — Rise & appear
        withAnimation(.easeOut(duration: 0.35)) {
            entryOpacity = 1.0
            entryOffsetY = 0
            entryScale   = 1.02
        }
        // Phase 2 — Settle
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.spring(response: 0.52, dampingFraction: 0.64)) {
            entryScale = 1.0
            entryTiltX = 0
            entryTiltY = 0
        }
        // Phase 3 sheen is handled by sheenSweep layer's onAppear.
    }

    // MARK: - Idle drift

    private func runIdleMotion() async {
        try? await Task.sleep(nanoseconds: 950_000_000)
        var flip = false
        while !Task.isCancelled {
            // Skip a cycle if exporting so idle doesn't fight the settle animation
            if !isExporting {
                let y: Double = flip ? -1.1 : 1.1
                let x: Double = flip ? 0.6  : -0.6
                withAnimation(.easeInOut(duration: 3.2)) { idleTiltY = y }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                if !isExporting {
                    withAnimation(.easeInOut(duration: 4.5)) { idleTiltX = x }
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            flip.toggle()
        }
    }

    // MARK: - Layers

    private var edgeSlab: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.62))
            .offset(x: 3 + CGFloat(normX) * 4, y: 9 + CGFloat(normY) * 5)
    }

    private var ticketImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// 3. Planet depth layer — additive glow at the planet's canvas position.
    ///
    /// Coordinates are expressed as fractions of the 1:1 ticket canvas so they
    /// align precisely with what TicketRenderer drew at 1080 × 1080:
    ///   planet centre: (0.956, 0.252), radius 0.407 of canvas width
    ///
    /// Parallax factor –8 / –6 pt makes the planet appear furthest from the
    /// viewer — it lags behind the card surface as the card tilts.
    /// `.screen` blend mode means it adds light to the existing dark background
    /// without ever covering or doubling the rendered content.
    private var planetDepthLayer: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    let w  = geo.size.width
                    let cx = w * 0.956
                    let cy = w * 0.252   // square canvas → height == width
                    let r  = w * 0.407

                    ZStack {
                        // Outer atmosphere halo — soft ring around the limb
                        RadialGradient(
                            colors: [
                                .clear,
                                accentColor.opacity(0.16),
                                accentColor.opacity(0.05),
                                .clear,
                            ],
                            center:      .center,
                            startRadius: r * 0.80,
                            endRadius:   r * 1.30
                        )
                        .frame(width: r * 2.60, height: r * 2.60)

                        // Lit hemisphere — focused glow from the upper-left light source
                        RadialGradient(
                            colors: [
                                .white.opacity(0.14),
                                accentColor.opacity(0.10),
                                .clear,
                            ],
                            center:      UnitPoint(x: 0.33, y: 0.28),
                            startRadius: 0,
                            endRadius:   r
                        )
                        .frame(width: r * 2, height: r * 2)
                        .clipShape(Circle())
                    }
                    .position(x: cx, y: cy)
                }
            )
            .blendMode(.screen)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .offset(
                x: CGFloat(normX) * -8 + CGFloat(mX) * -5,
                y: CGFloat(normY) * -6 + CGFloat(mY) * -4
            )
            .allowsHitTesting(false)
    }

    /// 4. Astronaut depth layer — additive catch-lights at the helmet position.
    ///
    /// Canvas fractions (from TicketRenderer at 1080 × 1080):
    ///   helmet centre: (0.880, 0.935), radius 0.119 of canvas width
    ///   The helmet is partially cropped at the bottom — intentional.
    ///
    /// Parallax factor –4 / –3 pt places the astronaut between the planet
    /// (deepest) and the gloss / text layers (on the card surface).
    private var astronautDepthLayer: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    let w  = geo.size.width
                    let cx = w * 0.880
                    let cy = w * 0.935
                    let r  = w * 0.119

                    ZStack {
                        // Helmet rim catch-light — soft white radial from upper-left
                        RadialGradient(
                            colors: [
                                .white.opacity(0.20),
                                .white.opacity(0.06),
                                .clear,
                            ],
                            center:      UnitPoint(x: 0.30, y: 0.25),
                            startRadius: 0,
                            endRadius:   r
                        )
                        .frame(width: r * 2, height: r * 2)
                        .clipShape(Circle())

                        // Visor reflection sliver — bright tight spot
                        RadialGradient(
                            colors: [.white.opacity(0.30), .clear],
                            center:      UnitPoint(x: 0.28, y: 0.32),
                            startRadius: 0,
                            endRadius:   r * 0.38
                        )
                        .frame(width: r * 2, height: r * 2)
                        .clipShape(Circle())
                    }
                    .position(x: cx, y: cy)
                }
            )
            .blendMode(.screen)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .offset(
                x: CGFloat(normX) * -4 + CGFloat(mX) * -3,
                y: CGFloat(normY) * -3 + CGFloat(mY) * -2
            )
            .allowsHitTesting(false)
    }

    private var innerShadow: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.13), .clear],
                startPoint: .top,
                endPoint:   UnitPoint(x: 0.5, y: 0.17)
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.11)],
                startPoint: UnitPoint(x: 0.5, y: 0.83),
                endPoint:   .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }

    private var glossOverlay: some View {
        let g = glossIntensity
        return RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.13 * g), location: 0.00),
                        .init(color: .white.opacity(0.06 * g), location: 0.38),
                        .init(color: .clear,                   location: 0.56),
                    ],
                    startPoint: UnitPoint(x: 0.10 + glossShiftX, y: glossShiftY),
                    endPoint:   UnitPoint(x: 0.90 + glossShiftX, y: 1.00 + glossShiftY)
                )
            )
            .allowsHitTesting(false)
    }

    private var specularDot: some View {
        let a = specularIntensity   // 0.30–1.0
        return RadialGradient(
            colors: [
                .white.opacity(0.07 + a * 0.20),   // 0.13 (dim) → 0.27 (bright)
                .white.opacity(0.02 + a * 0.05),   // 0.04 → 0.07
                .clear,
            ],
            center:      UnitPoint(x: specularX, y: specularY),
            startRadius: 0,
            endRadius:   45 + (1.0 - a) * 60    // 45 (sharp aligned) → 105 (diffuse swept)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }

    private var bevelOverlay: some View {
        let lo = bevelLightOpacity
        let do_ = bevelDarkOpacity
        return RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(lo),        location: 0.00),
                        .init(color: .white.opacity(lo * 0.30), location: 0.30),
                        .init(color: .black.opacity(do_ * 0.30), location: 0.70),
                        .init(color: .black.opacity(do_),        location: 1.00),
                    ],
                    startPoint: UnitPoint(x: 0.0, y: 0.0),
                    endPoint:   UnitPoint(x: 1.0, y: 1.0)
                ),
                lineWidth: 1.0
            )
            .allowsHitTesting(false)
    }

    /// Export capture cue — a bright white border that briefly flashes when
    /// `isExporting` becomes true, signalling "this pass is being prepared for export".
    private var exportBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.white.opacity(exportBorderAlpha), lineWidth: 1.5)
            .allowsHitTesting(false)
    }

    private var tapGlow: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.white.opacity(tapGlowAlpha))
            .allowsHitTesting(false)
    }

    private var sheenSweep: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.0),
                    .init(color: .white.opacity(0.26), location: 0.5),
                    .init(color: .clear,               location: 1.0),
                ],
                startPoint: .leading,
                endPoint:   .trailing
            )
            .frame(width: 54)
            .rotationEffect(.degrees(-26), anchor: .center)
            .offset(x: sheenX * w - 27)
            .frame(maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 0.55).delay(0.4)) { sheenX = 1.5 }
        }
    }

    private var scanOverlay: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    let h = geo.size.height
                    Rectangle()
                        .fill(AppTheme.backgroundPrimary)
                        .frame(height: max(0, h * (1 - scanFraction)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    if scanFraction < 1 {
                        LinearGradient(
                            stops: [
                                .init(color: .clear,                    location: 0.0),
                                .init(color: accentColor.opacity(0.92), location: 0.5),
                                .init(color: .clear,                    location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint:   .bottom
                        )
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)
                        .offset(y: h * scanFraction - 4)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
    }
}
