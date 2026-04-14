import SwiftUI
import UIKit

// MARK: - TicketRenderer
/// Generates a 1080×1080 shareable ticket image for a PlanetPass.
/// Purely vectorial — no external image assets required.
/// Uses UIGraphicsImageRenderer + Core Graphics for pixel-perfect output.
enum TicketRenderer {

    // MARK: - Public API

    /// Renders a 1080×1080 UIImage ticket for the given pass and player profile.
    ///
    /// `format.scale = 1.0` forces pixel-accurate output: the CGContext coordinates
    /// map 1-to-1 to pixels regardless of the device's display scale factor.
    ///
    /// `nonisolated` — UIGraphicsImageRenderer + Core Graphics drawing is documented
    /// thread-safe; this lets the call happen off the main thread via Task.detached.
    nonisolated static func render(pass: PlanetPass, profile: AstronautProfile) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1.0    // pixel-accurate: 1080 pt == 1080 px
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            drawTicket(pass: pass, profile: profile, in: size)
        }
    }

    // MARK: - Orchestration

    private static func drawTicket(pass: PlanetPass, profile: AstronautProfile, in size: CGSize) {
        let planet = Planet.catalog[min(pass.planetIndex, Planet.catalog.count - 1)]
        let accent = UIColor(planet.color)

        // Layer order: background → planet → astronaut → bars → text
        drawBackground(in: size)
        drawPlanetVisual(planetIndex: pass.planetIndex, accent: accent, in: size)
        drawAstronautSilhouette(accent: accent, in: size)
        drawLeftBar(accent: accent, height: size.height)
        drawTopBar(pass: pass, planet: planet, in: size, accent: accent)
        drawPlanetSection(pass: pass, planet: planet, in: size, accent: accent)
        drawEfficiency(pass: pass, in: size, accent: accent)
        hairline(x: 32, y: 742, width: size.width - 32, color: accent.withAlphaComponent(0.25))
        drawStats(pass: pass, profile: profile, in: size, accent: accent)
        drawFooter(pass: pass, in: size, accent: accent)
    }

    // MARK: - Planet Visual

    /// Cinematic planet integration — no circular mask.
    ///
    /// **Official asset path** (all current planets):
    ///   The image fills the full 1080×1080 canvas, then two directional gradients
    ///   fade it back toward the ticket background colour:
    ///     • Horizontal — left side fully dark (text zone), fades to transparent at ~62%
    ///     • Vertical   — bottom fully dark (stats zone), fades to transparent above ~52%
    ///   A subtle accent-tinted atmospheric overlay ties the image to the pass colour.
    ///   A soft right-edge glow replaces the visual presence the old circular ring gave.
    ///
    /// **Procedural fallback** (no asset assigned):
    ///   Original CGGradient sphere — lit hemisphere + terminator + specular + limb.
    ///   Preserved as a safety net; no current planet uses it.
    private static func drawPlanetVisual(planetIndex: Int, accent: UIColor, in size: CGSize) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Matches drawBackground's fill so gradient edges are seamless.
        let bg = UIColor(red: 0.040, green: 0.047, blue: 0.059, alpha: 1)
        let fullRect = CGRect(origin: .zero, size: size)

        if let img = PlanetVisualResolver.image(for: planetIndex) {
            // ── 1. Full-canvas planet image ───────────────────────────────────────
            // Square source drawn into the square canvas — no distortion, no crop.
            drawImageAspectFill(img, in: fullRect)

            // ── 2. Horizontal fade — text protection ──────────────────────────────
            // x=0–35%: fully covered  →  x=35–62%: fade  →  x=62%+: transparent
            if let hGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [bg.withAlphaComponent(1.0).cgColor,
                         bg.withAlphaComponent(1.0).cgColor,
                         bg.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 0.35, 0.62]
            ) {
                ctx.drawLinearGradient(hGrad,
                    start: .zero, end: CGPoint(x: size.width, y: 0),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }

            // ── 3. Vertical fade — stats/footer protection ────────────────────────
            // y=0–52%: transparent  →  y=52–72%: fade  →  y=72%+: fully covered
            if let vGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [bg.withAlphaComponent(0.0).cgColor,
                         bg.withAlphaComponent(0.0).cgColor,
                         bg.withAlphaComponent(0.80).cgColor,
                         bg.withAlphaComponent(1.0).cgColor] as CFArray,
                locations: [0.0, 0.52, 0.72, 1.0]
            ) {
                ctx.drawLinearGradient(vGrad,
                    start: .zero, end: CGPoint(x: 0, y: size.height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }

            // ── 4. Atmospheric tint ───────────────────────────────────────────────
            // Thin planet-colour wash binds the image to the pass's accent palette.
            accent.withAlphaComponent(0.13).setFill()
            UIRectFill(fullRect)

            // ── 5. Right-edge ambient glow ────────────────────────────────────────
            // Replaces the visual presence the old circular atmosphere ring gave.
            if let glow = CGGradient(
                colorsSpace: colorSpace,
                colors: [accent.withAlphaComponent(0.0).cgColor,
                         accent.withAlphaComponent(0.10).cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                ctx.drawLinearGradient(glow,
                    start: CGPoint(x: size.width * 0.60, y: 0),
                    end: CGPoint(x: size.width, y: 0),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }

        } else {
            // ── Procedural fallback: CGGradient sphere ────────────────────────────
            let cx: CGFloat = size.width  * 0.956
            let cy: CGFloat = size.height * 0.252
            let r:  CGFloat = 440
            let bodyRect    = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            // Atmospheric glow ring (even-odd clip)
            let atmosOuter: CGFloat = r + 90
            ctx.saveGState()
            let ringPath = CGMutablePath()
            ringPath.addEllipse(in: CGRect(x: cx - atmosOuter, y: cy - atmosOuter,
                                           width: atmosOuter * 2, height: atmosOuter * 2))
            ringPath.addEllipse(in: bodyRect)
            ctx.addPath(ringPath)
            ctx.clip(using: .evenOdd)
            if let grad = CGGradient(colorsSpace: colorSpace,
                                      colors: [accent.withAlphaComponent(0.0).cgColor,
                                               accent.withAlphaComponent(0.20).cgColor,
                                               accent.withAlphaComponent(0.0).cgColor] as CFArray,
                                      locations: [0.0, 0.32, 1.0]) {
                ctx.drawRadialGradient(grad,
                                       startCenter: CGPoint(x: cx, y: cy), startRadius: r - 2,
                                       endCenter:   CGPoint(x: cx, y: cy), endRadius:   atmosOuter,
                                       options: [])
            }
            ctx.restoreGState()

            // Planet body (circle clip)
            ctx.saveGState()
            ctx.addEllipse(in: bodyRect)
            ctx.clip()
            UIColor(red: 0.022, green: 0.026, blue: 0.040, alpha: 1).setFill()
            UIRectFill(bodyRect)

            let lightDx: CGFloat = -0.58
            let lightDy: CGFloat = -0.65
            let lightX = cx + lightDx * r
            let lightY = cy + lightDy * r
            if let litGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [accent.withAlphaComponent(0.70).cgColor,
                         accent.withAlphaComponent(0.32).cgColor,
                         accent.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 0.40, 0.82]
            ) {
                ctx.drawRadialGradient(litGrad,
                                       startCenter: CGPoint(x: lightX, y: lightY), startRadius: 0,
                                       endCenter:   CGPoint(x: cx, y: cy),         endRadius:   r * 1.25,
                                       options: [.drawsAfterEndLocation])
            }
            let termStart = CGPoint(x: cx - 0.12 * r, y: cy - 0.12 * r)
            let termEnd   = CGPoint(x: cx + 0.68 * r, y: cy + 0.74 * r)
            if let nightGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [UIColor.black.withAlphaComponent(0.0).cgColor,
                         UIColor.black.withAlphaComponent(0.58).cgColor,
                         UIColor.black.withAlphaComponent(0.92).cgColor] as CFArray,
                locations: [0.0, 0.44, 1.0]
            ) {
                ctx.drawLinearGradient(nightGrad, start: termStart, end: termEnd,
                                       options: [.drawsAfterEndLocation])
            }
            let specX = cx + lightDx * r * 0.46
            let specY = cy + lightDy * r * 0.46
            if let specGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [UIColor.white.withAlphaComponent(0.48).cgColor,
                         UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                ctx.drawRadialGradient(specGrad,
                                       startCenter: CGPoint(x: specX, y: specY), startRadius: 0,
                                       endCenter:   CGPoint(x: specX, y: specY), endRadius:   r * 0.24,
                                       options: [])
            }
            if let limbGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [UIColor.black.withAlphaComponent(0.0).cgColor,
                         UIColor.black.withAlphaComponent(0.0).cgColor,
                         UIColor.black.withAlphaComponent(0.48).cgColor] as CFArray,
                locations: [0.0, 0.62, 1.0]
            ) {
                ctx.drawRadialGradient(limbGrad,
                                       startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                                       endCenter:   CGPoint(x: cx, y: cy), endRadius:   r,
                                       options: [.drawsAfterEndLocation])
            }
            ctx.restoreGState()
            ctx.setStrokeColor(accent.withAlphaComponent(0.20).cgColor)
            ctx.setLineWidth(1.5)
            ctx.addEllipse(in: bodyRect)
            ctx.strokePath()
            ctx.setStrokeColor(accent.withAlphaComponent(0.18).cgColor)
            ctx.setLineWidth(8)
            ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r - 4,
                       startAngle: .pi * 0.52, endAngle: .pi * 1.50, clockwise: false)
            ctx.strokePath()
        }
    }

    /// Draws `image` scaled to aspect-fill `rect`, centring the crop.
    /// Used to place official planet images inside the circular planet clip region.
    private static func drawImageAspectFill(_ image: UIImage, in rect: CGRect) {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let imgAspect  = imgSize.width / imgSize.height
        let rectAspect = rect.width / rect.height
        let drawRect: CGRect
        if imgAspect > rectAspect {
            // Image is wider: crop left/right, fill height
            let h = rect.height
            let w = h * imgAspect
            drawRect = CGRect(x: rect.minX - (w - rect.width) / 2,
                              y: rect.minY, width: w, height: h)
        } else {
            // Image is taller: crop top/bottom, fill width
            let w = rect.width
            let h = w / imgAspect
            drawRect = CGRect(x: rect.minX, y: rect.minY - (h - rect.height) / 2,
                              width: w, height: h)
        }
        image.draw(in: drawRect)
    }

    // MARK: - Astronaut Silhouette

    /// Premium minimal helmet — dark sphere with visor, shoulder curves, lower-right corner.
    /// No arms, no torso, no cartoon details. Only the top portion is visible.
    private static func drawAstronautSilhouette(accent: UIColor, in size: CGSize) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Mostly off-canvas: only the top of the helmet and shoulder curves are visible
        let cx: CGFloat = 950
        let cy: CGFloat = 1010
        let r:  CGFloat = 128

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // ── Shoulder curves ──────────────────────────────────────────────────────
        // neckBaseY uses r*0.28 so the shoulder apex lands at ≈1046 — within canvas.
        // This makes the suit body visible as a dark mass below the helmet sphere.
        let neckBaseY = cy + r * 0.28   // ≈1046 (just inside the canvas bottom)
        let shoulderW: CGFloat = 220

        let shoulders = UIBezierPath()
        shoulders.move(to: CGPoint(x: cx - shoulderW, y: size.height + 60))
        shoulders.addCurve(
            to:           CGPoint(x: cx - 52,   y: neckBaseY + 5),
            controlPoint1: CGPoint(x: cx - shoulderW, y: neckBaseY + 72),
            controlPoint2: CGPoint(x: cx - 105,  y: neckBaseY + 10)
        )
        shoulders.addCurve(
            to:           CGPoint(x: cx + 52,   y: neckBaseY + 5),
            controlPoint1: CGPoint(x: cx - 10,  y: neckBaseY - 6),
            controlPoint2: CGPoint(x: cx + 10,  y: neckBaseY - 6)
        )
        shoulders.addCurve(
            to:           CGPoint(x: cx + shoulderW, y: size.height + 60),
            controlPoint1: CGPoint(x: cx + 105,  y: neckBaseY + 10),
            controlPoint2: CGPoint(x: cx + shoulderW, y: neckBaseY + 72)
        )
        shoulders.close()
        UIColor(red: 0.040, green: 0.046, blue: 0.065, alpha: 0.92).setFill()
        shoulders.fill()

        // Thin accent stroke traces the shoulder silhouette edge
        UIColor(white: 1.0, alpha: 0.06).setStroke()
        shoulders.lineWidth = 1.5
        shoulders.stroke()

        // ── Helmet body ──────────────────────────────────────────────────────────
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.clip()

        // Near-black base
        UIColor(red: 0.055, green: 0.062, blue: 0.085, alpha: 1).setFill()
        UIRectFill(CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        // Subtle lit gradient — light source upper-left, matching planet
        let helmetLitColors: [CGColor] = [
            UIColor.white.withAlphaComponent(0.12).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        let helmetLitLocations: [CGFloat] = [0.0, 1.0]
        if let grad = CGGradient(colorsSpace: colorSpace,
                                  colors: helmetLitColors as CFArray,
                                  locations: helmetLitLocations) {
            ctx.drawRadialGradient(grad,
                                   startCenter: CGPoint(x: cx - r * 0.38, y: cy - r * 0.42),
                                   startRadius: 0,
                                   endCenter:   CGPoint(x: cx, y: cy),
                                   endRadius:   r,
                                   options: [.drawsAfterEndLocation])
        }

        ctx.restoreGState()

        // Helmet outer rim
        ctx.setStrokeColor(accent.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(2.5)
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.strokePath()

        // ── Visor ────────────────────────────────────────────────────────────────
        let vw: CGFloat = r * 1.18
        let vh: CGFloat = r * 0.68
        let vx: CGFloat = cx
        let vy: CGFloat = cy + 4
        let visorRect = CGRect(x: vx - vw / 2, y: vy - vh / 2, width: vw, height: vh)

        ctx.saveGState()
        UIBezierPath(ovalIn: visorRect).addClip()

        // Near-black visor base
        UIColor(red: 0.012, green: 0.015, blue: 0.022, alpha: 1).setFill()
        UIRectFill(visorRect)

        // Accent colour reflection (subtle planet-colour tint)
        let visorReflColors: [CGColor] = [
            accent.withAlphaComponent(0.22).cgColor,
            accent.withAlphaComponent(0.0).cgColor,
        ]
        let visorReflLocations: [CGFloat] = [0.0, 1.0]
        if let grad = CGGradient(colorsSpace: colorSpace,
                                  colors: visorReflColors as CFArray,
                                  locations: visorReflLocations) {
            ctx.drawRadialGradient(grad,
                                   startCenter: CGPoint(x: vx - vw * 0.18, y: vy - vh * 0.22),
                                   startRadius: 0,
                                   endCenter:   CGPoint(x: vx, y: vy),
                                   endRadius:   max(vw, vh),
                                   options: [.drawsAfterEndLocation])
        }

        ctx.restoreGState()

        // Visor rim
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.10).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addEllipse(in: visorRect)
        ctx.strokePath()

        // ── Glare dot — specular highlight upper-left of visor ──────────────────
        let glareColors: [CGColor] = [
            UIColor.white.withAlphaComponent(0.52).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        let glareLocations: [CGFloat] = [0.0, 1.0]
        if let grad = CGGradient(colorsSpace: colorSpace,
                                  colors: glareColors as CFArray,
                                  locations: glareLocations) {
            let gx = vx - vw * 0.28
            let gy = vy - vh * 0.26
            ctx.drawRadialGradient(grad,
                                   startCenter: CGPoint(x: gx, y: gy), startRadius: 0,
                                   endCenter:   CGPoint(x: gx, y: gy), endRadius:   24,
                                   options: [])
        }
    }

    // MARK: - Background

    private static func drawBackground(in size: CGSize) {
        UIColor(red: 0.040, green: 0.047, blue: 0.059, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        // Extremely faint scan lines — texture only, no readability impact
        UIColor.white.withAlphaComponent(0.003).setFill()
        var y: CGFloat = 0
        while y < size.height {
            UIRectFill(CGRect(x: 0, y: y, width: size.width, height: 1))
            y += 5
        }
    }

    // MARK: - Left Bar

    private static func drawLeftBar(accent: UIColor, height: CGFloat) {
        accent.withAlphaComponent(0.90).setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 30, height: height))
        accent.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 30, height: 90))
    }

    // MARK: - Top Bar

    private static func drawTopBar(pass: PlanetPass, planet: Planet,
                                    in size: CGSize, accent: UIColor) {
        accent.withAlphaComponent(0.060).setFill()
        UIRectFill(CGRect(x: 30, y: 0, width: size.width - 30, height: 90))
        hairline(x: 30, y: 90, width: size.width - 30, color: accent.withAlphaComponent(0.30))

        draw("SIGNAL ROUTE", at: CGPoint(x: 66, y: 24),
             size: 22, weight: .bold, color: .white.withAlphaComponent(0.92), kern: 4)
        draw(pass.serialCode, at: CGPoint(x: 66, y: 54),
             size: 16, weight: .regular, color: .white.withAlphaComponent(0.72), kern: 2)

        let passLabel = pass.isEarned ? "PLANET PASS" : "TRAINING CLEARANCE"
        let passAttr = attr(passLabel, size: 22, weight: .bold, color: accent, kern: 3)
        passAttr.draw(at: CGPoint(x: size.width - passAttr.size().width - 48, y: 24))
        let diffAttr = attr(planet.difficulty.fullLabel, size: 14, weight: .semibold,
                            color: accent.withAlphaComponent(0.72), kern: 2)
        diffAttr.draw(at: CGPoint(x: size.width - diffAttr.size().width - 48, y: 54))
    }

    // MARK: - Planet Section

    private static func drawPlanetSection(pass: PlanetPass, planet: Planet,
                                           in size: CGSize, accent: UIColor) {
        let leftX: CGFloat = 66

        draw(planet.missionBrief, at: CGPoint(x: leftX, y: 112),
             size: 19, weight: .semibold, color: accent.withAlphaComponent(0.88), kern: 4)

        accent.withAlphaComponent(0.32).setFill()
        UIRectFill(CGRect(x: leftX, y: 143, width: 240, height: 0.5))

        // Planet name — large, full white
        let maxNameW = size.width - leftX - 80
        let nameFontSize = adaptiveFontSize(for: pass.planetName, maxWidth: maxNameW, base: 158)
        let nameAttr = NSAttributedString(string: pass.planetName, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: nameFontSize, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: -2.0
        ])
        nameAttr.draw(at: CGPoint(x: leftX - 4, y: 150))

        let accessLabel = pass.isEarned ? "ACCESS AUTHORIZED" : "IN TRAINING"
        draw(accessLabel, at: CGPoint(x: leftX, y: 382),
             size: 17, weight: .semibold, color: accent.withAlphaComponent(0.68), kern: 4)
    }

    // MARK: - Efficiency

    private static func drawEfficiency(pass: PlanetPass, in size: CGSize, accent: UIColor) {
        let leftX: CGFloat = 66
        let topY:  CGFloat = 434

        draw("MISSION EFFICIENCY", at: CGPoint(x: leftX, y: topY),
             size: 17, weight: .semibold, color: .white.withAlphaComponent(0.70), kern: 3)

        let effPct = Int((pass.efficiencyScore * 100).rounded())
        let bigAttr = NSAttributedString(string: "\(effPct)%", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 108, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: -1.0
        ])
        bigAttr.draw(at: CGPoint(x: leftX - 5, y: topY + 26))

        // 10-segment bar
        let filled = max(0, min(10, Int((pass.efficiencyScore * 10).rounded())))
        let barY: CGFloat = topY + 158
        let segW: CGFloat = 62, segH: CGFloat = 10, segGap: CGFloat = 6
        for i in 0..<10 {
            let segX = leftX + CGFloat(i) * (segW + segGap)
            let color = i < filled ? accent : UIColor.white.withAlphaComponent(0.10)
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: segX, y: barY, width: segW, height: segH),
                         cornerRadius: 2).fill()
        }
    }

    // MARK: - Stats

    private static func drawStats(pass: PlanetPass, profile: AstronautProfile,
                                   in size: CGSize, accent: UIColor) {
        let topY: CGFloat = 762
        let cells: [(String, String)] = [
            ("LEVEL",    String(format: "%02d", pass.levelReached)),
            ("MISSIONS", String(format: "%04d", pass.missionCount)),
            ("RANK",     profile.rankTitle),
            ("STATUS",   pass.isEarned ? "CLEARED" : "IN PROGRESS"),
        ]
        let cellW = (size.width - 30) / CGFloat(cells.count)
        for (i, (label, value)) in cells.enumerated() {
            let cellX = 30 + CGFloat(i) * cellW
            draw(label, at: CGPoint(x: cellX + 20, y: topY + 8),
                 size: 15, weight: .semibold, color: .white.withAlphaComponent(0.72), kern: 2)
            draw(value, at: CGPoint(x: cellX + 20, y: topY + 33),
                 size: 26, weight: .bold, color: .white, kern: 1)
            if i > 0 {
                accent.withAlphaComponent(0.18).setFill()
                UIRectFill(CGRect(x: cellX, y: topY, width: 0.5, height: 80))
            }
        }
    }

    // MARK: - Footer

    private static func drawFooter(pass: PlanetPass, in size: CGSize, accent: UIColor) {
        let y: CGFloat = 872
        accent.withAlphaComponent(0.055).setFill()
        UIRectFill(CGRect(x: 30, y: y, width: size.width - 30, height: size.height - y))
        hairline(x: 30, y: y, width: size.width - 30, color: accent.withAlphaComponent(0.24))

        draw(pass.serialCode, at: CGPoint(x: 66, y: y + 22),
             size: 32, weight: .bold, color: accent, kern: 3)
        draw(formattedDate(pass.timestamp), at: CGPoint(x: 66, y: y + 72),
             size: 16, weight: .regular, color: .white.withAlphaComponent(0.60), kern: 2)

        // Dim planet name watermark — right-aligned, low opacity
        let watermark = attr(pass.planetName, size: 18, weight: .black,
                             color: accent.withAlphaComponent(0.12), kern: 3)
        let wmW = watermark.size().width
        watermark.draw(at: CGPoint(x: size.width - wmW - 52, y: y + 50))
    }

    // MARK: - Helpers

    private static func hairline(x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor) {
        color.setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: 0.5))
    }

    private static func draw(_ text: String, at point: CGPoint,
                              size: CGFloat, weight: UIFont.Weight,
                              color: UIColor, kern: CGFloat = 0) {
        attr(text, size: size, weight: weight, color: color, kern: kern).draw(at: point)
    }

    private static func attr(_ text: String, size: CGFloat, weight: UIFont.Weight,
                              color: UIColor, kern: CGFloat = 0) -> NSAttributedString {
        var a: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        if kern != 0 { a[.kern] = kern }
        return NSAttributedString(string: text, attributes: a)
    }

    private static func adaptiveFontSize(for text: String,
                                          maxWidth: CGFloat, base: CGFloat) -> CGFloat {
        let font = UIFont.monospacedSystemFont(ofSize: base, weight: .black)
        let w = (text as NSString).size(withAttributes: [.font: font, .kern: -2.0]).width
        guard w > maxWidth else { return base }
        return floor(base * maxWidth / w)
    }

    private static let ticketDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private static func formattedDate(_ date: Date) -> String {
        ticketDateFormatter.string(from: date).uppercased()
    }
}

// MARK: - TicketCache

/// In-memory cache for rendered ticket images.
/// Keyed on the fields that affect the rendered output: planet, level, missions, efficiency.
/// @MainActor — only accessed from the main thread; no locking needed.
@MainActor
final class TicketCache {
    static let shared = TicketCache()
    private init() {}

    private var store: [String: UIImage] = [:]

    func image(for pass: PlanetPass) -> UIImage? {
        store[cacheKey(for: pass)]
    }

    func cache(_ image: UIImage, for pass: PlanetPass) {
        store[cacheKey(for: pass)] = image
    }

    /// Call when the player's pass data changes (e.g. after a level-up).
    func invalidateAll() {
        store.removeAll()
    }

    private func cacheKey(for pass: PlanetPass) -> String {
        let eff = Int((pass.efficiencyScore * 100).rounded())
        return "\(pass.planetIndex)-\(pass.levelReached)-\(pass.missionCount)-\(eff)-\(pass.isEarned)"
    }
}
