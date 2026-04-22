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
///   7. Specular band      — wide elongated ellipse; tracks light source across wider travel range
///   8. Specular dot       — tight radial highlight at the highlight core
///   9. Bevel stroke       — light top-left / dark bottom-right → machined edge
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

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

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
    /// Damping factor applied to motion during an active drag gesture.
    /// Springs to 0.15 on drag start (drag dominates) and back to 1.0 on end.
    @State private var motionDragScale: Double = 1.0
    /// True while a drag gesture is active. Suppresses idle drift updates
    /// and dampens device-motion contribution so the drag feels deterministic.
    @State private var isDragging: Bool = false

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
    /// During drag (`isDragging`), `motionDragScale` reduces the contribution to ~0.15
    /// so the drag gesture reads cleanly without motion fighting it.
    private var mX: Double { motion.isAvailable ? motion.tiltX * motionScale * motionDragScale : 0 }
    private var mY: Double { motion.isAvailable ? motion.tiltY * motionScale * motionDragScale : 0 }

    /// Y-axis rotation driven by horizontal drag — two zones:
    ///
    /// **Zone 1** (|drag| ≤ 80 pt): linear 0 → ±8°, preserving the existing
    ///   premium tilt feel for everyday interaction.
    ///
    /// **Zone 2** (|drag| > 80 pt): tanh ramp toward ±108°. The hyperbolic
    ///   tangent gives natural resistance that stiffens as the card approaches
    ///   vertical — the back face first appears around 185–195 pt, requiring a
    ///   clearly intentional gesture.
    private var flipYDegrees: Double {
        let x    = Double(tilt.width)
        let sign: Double = x >= 0 ? 1.0 : -1.0
        let mag  = abs(x)
        guard mag > 0 else { return 0 }
        if mag <= 80 {
            return sign * (mag / 80.0) * 8.0
        }
        let excess = mag - 80
        let extra  = tanh(excess / 140.0 * 2.0) * 100.0
        return sign * (8.0 + extra)
    }

    /// True when the card has rotated past vertical and the back face is facing
    /// the viewer. Content swaps to `backFaceLayer` at this threshold; at 90°
    /// the card is edge-on so the transition is always invisible.
    private var isShowingBack: Bool { abs(activeTiltY) > 90 }

    // Active tilt = editorial rest + drag (flip ramp) + entry boost + idle drift + device motion
    // motion.tiltX (left/right phone tilt) drives Y rotation; tiltY drives X rotation.
    private var activeTiltX: Double { restTiltX + normY * maxTilt + entryTiltX + idleTiltX + mY * motionMaxTilt }
    private var activeTiltY: Double { restTiltY + flipYDegrees  + entryTiltY + idleTiltY + mX * motionMaxTilt }

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

    // ── Specular band ─────────────────────────────────────────────────────
    // The band uses wider travel (0.30 / 0.22) than the specular dot (0.18 / 0.12)
    // so it sweeps more expressively across the card surface, simulating the
    // broad reflection of a distant light source (e.g. a window or studio lamp).

    /// Band centre X — rests at 0.28 (upper-left), shifts right as card tilts left.
    private var bandX: Double { 0.28 - normX * 0.30 - mX * 0.22 }
    /// Band centre Y — rests at 0.26, drops as card tilts down.
    private var bandY: Double { 0.26 - normY * 0.20 - mY * 0.15 }

    /// Band intensity 0.0–1.0. Peaks at rest; dims as the band drifts from its
    /// natural upper-left position, matching the physics of surface reflection.
    private var specularBandIntensity: Double {
        let dx = bandX - 0.28
        let dy = bandY - 0.26
        return max(0.0, 1.0 - sqrt(dx * dx + dy * dy) * 2.6)
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
            edgeSlab                                         //  1 — always
            ticketImage                                      //  2 — always (anchors layout size)
                .opacity(isShowingBack ? 0 : 1)
            if isShowingBack {
                backFaceLayer                                //  back — pre-mirrored
                    .scaleEffect(x: -1, y: 1)
            } else {
                planetDepthLayer                             //  3
                astronautDepthLayer                          //  4
                innerShadow                                  //  5
                glossOverlay                                 //  6
                specularBand                                 //  7
                specularDot                                  //  8
            }
            bevelOverlay                                     //  8 — always
            exportBorder                                     //  9 — always
            tapGlow                                          // 10 — always
            if !isShowingBack {
                sheenSweep                                   // 11
                if !revealed { scanOverlay }                 // 12
            }
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
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        SoundManager.play(.ticketMove)
                        // Freeze any in-flight idle drift so it doesn't fight the gesture.
                        // Dampen motion to 15% — just enough to feel alive, not enough to blur drag intent.
                        withAnimation(.easeOut(duration: 0.12)) {
                            idleTiltX      = 0
                            idleTiltY      = 0
                            motionDragScale = 0.15
                        }
                    }
                    tilt = value.translation
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        tilt = .zero
                    }
                    // Restore full motion contribution after the spring settles
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.30)) {
                        motionDragScale = 1.0
                    }
                }
        )
        // Respond to export mode: settle idle + silence motion + flash border
        .onChange(of: isExporting) { _, exporting in
            if exporting {
                // Reset any in-progress drag and kill idle/motion so the card sits
                // at its canonical front-face rest before the share sheet opens.
                isDragging      = false
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    tilt        = .zero
                    idleTiltX   = 0
                    idleTiltY   = 0
                    motionScale = 0
                    motionDragScale = 1.0
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
        .onAppear    { motion.start(); SoundManager.play(.ticketOpen) }
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
            // Skip a cycle if exporting or if the user is actively dragging —
            // avoids idle animations fighting the settle/spring animations.
            if !isExporting && !isDragging {
                let y: Double = flip ? -1.1 : 1.1
                let x: Double = flip ? 0.6  : -0.6
                withAnimation(.easeInOut(duration: 3.2)) { idleTiltY = y }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                if !isExporting && !isDragging {
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
        let ty = Float(activeTiltY)
        let tx = Float(activeTiltX)
        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.holographic(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(ty),
                        .float(tx)
                    )
                )
            }
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

    /// 7. Specular band — a wide, elongated ellipse representing the broad reflection
    /// of a fixed light source on the card's laminated surface.
    ///
    /// Design rationale:
    ///   • `EllipticalGradient` ensures the falloff follows the ellipse shape, so
    ///     opacity reaches zero exactly at the edge — no hard boundary.
    ///   • The `rotationEffect` skews slightly with `normX` and `normY`, mimicking
    ///     how an anisotropic surface (brushed metal, holographic foil) changes its
    ///     reflection angle as the viewing direction changes.
    ///   • Max centre opacity is 0.17 — visible but never legibility-blocking.
    ///   • `.screen` blend adds light without multiplying or covering content.
    private var specularBand: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let a = specularBandIntensity
            Ellipse()
                .fill(
                    EllipticalGradient(
                        colors: [
                            .white.opacity(0.17 * a),
                            .white.opacity(0.06 * a),
                            .clear,
                        ],
                        center:              .center,
                        startRadiusFraction: 0.0,
                        endRadiusFraction:   0.85
                    )
                )
                .frame(width: w * 0.26, height: h * 0.56)
                .rotationEffect(.degrees(-20.0 + normX * 8.0 + normY * 3.0))
                .position(x: w * CGFloat(bandX), y: h * CGFloat(bandY))
        }
        .blendMode(.screen)
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

    // MARK: - Back face

    /// Reverse side of the pass — visible only during a deliberate lateral flip
    /// gesture (~185 pt of horizontal drag). Pre-mirrored at the call site with
    /// `scaleEffect(x: -1)` so content reads correctly once `rotation3DEffect`
    /// reflects it from behind.
    ///
    /// Visual hierarchy (top → bottom):
    ///   1. Dark navy gradient background
    ///   2. Telemetry canvas — horizontal scan lines + corner registration marks
    ///   3. Brand identity — icon + system name
    ///   4. Accent rule separator
    ///   5. Data strip — deterministic barcode-like pattern
    ///   6. System code line
    ///   7. Clearance line
    ///   8. Gradient border (accent top-left → white bottom-right)
    private var backFaceLayer: some View {
        ZStack {
            // 1. Background
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.036, green: 0.052, blue: 0.090),
                            Color(red: 0.018, green: 0.026, blue: 0.046),
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                )

            // 2. Telemetry canvas
            let accent = accentColor
            Canvas { ctx, size in
                // Horizontal scan lines
                let ls: CGFloat = 9
                for y in stride(from: ls * 2, through: size.height - ls, by: ls) {
                    var p = Path()
                    p.move(to: CGPoint(x: 18, y: y))
                    p.addLine(to: CGPoint(x: size.width - 18, y: y))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.025)), lineWidth: 0.5)
                }
                // Corner registration marks
                let m: CGFloat = 20; let arm: CGFloat = 7
                for (ox, oy): (CGFloat, CGFloat) in [
                    (m, m), (size.width - m, m),
                    (m, size.height - m), (size.width - m, size.height - m)
                ] {
                    var h = Path()
                    h.move(to: CGPoint(x: ox - arm, y: oy))
                    h.addLine(to: CGPoint(x: ox + arm, y: oy))
                    var v = Path()
                    v.move(to: CGPoint(x: ox, y: oy - arm))
                    v.addLine(to: CGPoint(x: ox, y: oy + arm))
                    ctx.stroke(h, with: .color(accent.opacity(0.28)), lineWidth: 0.75)
                    ctx.stroke(v, with: .color(accent.opacity(0.28)), lineWidth: 0.75)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 3 – 7. Identity + data content
            VStack(spacing: 0) {
                Spacer()

                // Brand
                VStack(spacing: 7) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 22, weight: .thin))
                        .foregroundStyle(accentColor.opacity(0.70))

                    Text("SIGNAL VOID")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                Spacer().frame(height: 14)

                // 4. Accent rule
                Rectangle()
                    .fill(accentColor.opacity(0.42))
                    .frame(height: 0.75)
                    .padding(.horizontal, 28)

                Spacer().frame(height: 12)

                // 5. Data strip
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(Self.stripOpacity(i)))
                            .frame(width: Self.stripWidth(i), height: 14)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 11)

                // 6. System code
                HStack(spacing: 6) {
                    Text("SRX-7")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.52))
                    Text("·")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.18))
                    Text(S.sectorTransitPass)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.white.opacity(0.28))
                }

                Spacer().frame(height: 9)

                // 7. Clearance
                Text(S.authorizedBearer)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.16))

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // 8. Gradient border
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [accentColor.opacity(0.20), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }

    // Deterministic barcode-like data strip — opacity and width patterns chosen so
    // the strip reads as "technical data" at a glance without being a real barcode.
    private static func stripOpacity(_ i: Int) -> Double {
        let p = [0.20, 0.06, 0.16, 0.04, 0.24, 0.08, 0.18, 0.05,
                 0.22, 0.04, 0.18, 0.08, 0.12, 0.22, 0.06, 0.16,
                 0.04, 0.20, 0.07, 0.14]
        return p[i % p.count]
    }

    private static func stripWidth(_ i: Int) -> CGFloat {
        let p: [CGFloat] = [1.5, 1, 3, 1, 2.5, 1.5, 1, 2, 1, 3.5,
                            1, 2, 1.5, 1, 3, 1.5, 1, 2.5, 1, 2]
        return p[i % p.count]
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
