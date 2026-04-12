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
    /// Without this, the default screen scale (2× or 3×) causes the image to be
    /// 2160 or 3240 pixels wide while all drawing coordinates still assume 1080 —
    /// producing a clipped, undersized composition in the share sheet.
    static func render(pass: PlanetPass, profile: AstronautProfile) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1.0    // pixel-accurate: 1080 pt == 1080 px
        format.opaque = true   // no alpha channel needed; avoids premultiplied artefacts
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            drawTicket(pass: pass, profile: profile, in: size)
        }
    }

    // MARK: - Orchestration

    private static func drawTicket(pass: PlanetPass, profile: AstronautProfile, in size: CGSize) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let planet = Planet.catalog[min(pass.planetIndex, Planet.catalog.count - 1)]
        let accent = UIColor(planet.color)

        drawBackground(in: size)
        drawOrbitalArcs(ctx: ctx, in: size, accent: accent)
        drawGridDots(ctx: ctx, in: size, accent: accent)
        drawLeftBar(accent: accent, height: size.height)
        drawTopBar(pass: pass, planet: planet, in: size, accent: accent)
        drawPlanetSection(pass: pass, planet: planet, in: size, accent: accent)
        drawEfficiency(pass: pass, in: size, accent: accent)
        hairline(x: 32, y: 742, width: size.width - 32, color: accent.withAlphaComponent(0.25))
        drawStats(pass: pass, profile: profile, in: size, accent: accent)
        drawFooter(pass: pass, in: size, accent: accent)
    }

    // MARK: - Layers

    private static func drawBackground(in size: CGSize) {
        // Base dark fill
        UIColor(red: 0.040, green: 0.047, blue: 0.059, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        // Subtle scan lines for texture
        UIColor.white.withAlphaComponent(0.010).setFill()
        var y: CGFloat = 0
        while y < size.height { UIRectFill(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 5 }
    }

    private static func drawOrbitalArcs(ctx: CGContext, in size: CGSize, accent: UIColor) {
        ctx.saveGState()
        let center = CGPoint(x: size.width * 0.92, y: size.height * 0.34)
        // Outer ring
        ctx.setStrokeColor(accent.withAlphaComponent(0.07).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addArc(center: center, radius: 430, startAngle: .pi * 0.50, endAngle: .pi * 1.50, clockwise: false)
        ctx.strokePath()
        // Mid ring
        ctx.setStrokeColor(accent.withAlphaComponent(0.12).cgColor)
        ctx.setLineWidth(0.8)
        ctx.addArc(center: center, radius: 310, startAngle: .pi * 0.55, endAngle: .pi * 1.45, clockwise: false)
        ctx.strokePath()
        // Inner ring
        ctx.setStrokeColor(accent.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(0.5)
        ctx.addArc(center: center, radius: 195, startAngle: .pi * 0.62, endAngle: .pi * 1.38, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawGridDots(ctx: CGContext, in size: CGSize, accent: UIColor) {
        ctx.saveGState()
        accent.withAlphaComponent(0.11).setFill()
        let startX: CGFloat = size.width * 0.56
        let startY: CGFloat = size.height * 0.09
        let spacing: CGFloat = 44
        let r: CGFloat = 1.8
        for row in 0..<6 {
            for col in 0..<9 {
                let x = startX + CGFloat(col) * spacing
                let y = startY + CGFloat(row) * spacing
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
        ctx.restoreGState()
    }

    private static func drawLeftBar(accent: UIColor, height: CGFloat) {
        accent.withAlphaComponent(0.88).setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 30, height: height))
        // Brighter cap for the top section
        accent.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 30, height: 90))
    }

    private static func drawTopBar(pass: PlanetPass, planet: Planet, in size: CGSize, accent: UIColor) {
        accent.withAlphaComponent(0.055).setFill()
        UIRectFill(CGRect(x: 30, y: 0, width: size.width - 30, height: 90))
        hairline(x: 30, y: 90, width: size.width - 30, color: accent.withAlphaComponent(0.28))

        // Left: brand + serial
        draw("SIGNAL ROUTE", at: CGPoint(x: 66, y: 24),
             size: 22, weight: .bold, color: .white.withAlphaComponent(0.45), kern: 4)
        draw(pass.serialCode, at: CGPoint(x: 66, y: 54),
             size: 16, weight: .regular, color: .white.withAlphaComponent(0.28), kern: 2)

        // Right: pass type + difficulty
        let passAttr = attr("PLANET PASS", size: 22, weight: .bold, color: accent.withAlphaComponent(0.90), kern: 3)
        passAttr.draw(at: CGPoint(x: size.width - passAttr.size().width - 48, y: 24))

        let diffAttr = attr(planet.difficulty.fullLabel, size: 14, weight: .regular,
                            color: accent.withAlphaComponent(0.55), kern: 2)
        diffAttr.draw(at: CGPoint(x: size.width - diffAttr.size().width - 48, y: 54))
    }

    private static func drawPlanetSection(pass: PlanetPass, planet: Planet, in size: CGSize, accent: UIColor) {
        let leftX: CGFloat = 66

        // Mission brief label
        draw(planet.missionBrief, at: CGPoint(x: leftX, y: 112),
             size: 19, weight: .regular, color: accent.withAlphaComponent(0.65), kern: 4)

        // Short accent line
        accent.withAlphaComponent(0.22).setFill()
        UIRectFill(CGRect(x: leftX, y: 143, width: 240, height: 0.5))

        // Planet name — adaptive size to fit any name width
        let maxNameW = size.width - leftX - 80
        let nameFontSize = adaptiveFontSize(for: pass.planetName, maxWidth: maxNameW, base: 158)
        let nameAttr = NSAttributedString(string: pass.planetName, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: nameFontSize, weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(0.93),
            .kern: -2.0
        ])
        nameAttr.draw(at: CGPoint(x: leftX - 4, y: 150))

        // ACCESS AUTHORIZED tag
        draw("ACCESS AUTHORIZED", at: CGPoint(x: leftX, y: 382),
             size: 17, weight: .semibold, color: .white.withAlphaComponent(0.22), kern: 4)
    }

    private static func drawEfficiency(pass: PlanetPass, in size: CGSize, accent: UIColor) {
        let leftX: CGFloat = 66
        let topY: CGFloat = 434

        draw("MISSION EFFICIENCY", at: CGPoint(x: leftX, y: topY),
             size: 17, weight: .regular, color: .white.withAlphaComponent(0.32), kern: 3)

        // Big % figure
        let effPct = Int((pass.efficiencyScore * 100).rounded())
        let bigAttr = NSAttributedString(string: "\(effPct)%", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 108, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: -1.0
        ])
        bigAttr.draw(at: CGPoint(x: leftX - 5, y: topY + 26))

        // 10-segment efficiency bar
        let filled = max(0, min(10, Int((pass.efficiencyScore * 10).rounded())))
        let barY: CGFloat = topY + 158
        let segW: CGFloat = 62, segH: CGFloat = 10, segGap: CGFloat = 6
        for i in 0..<10 {
            let segX = leftX + CGFloat(i) * (segW + segGap)
            let color = i < filled ? accent.withAlphaComponent(0.90) : UIColor.white.withAlphaComponent(0.10)
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: segX, y: barY, width: segW, height: segH),
                         cornerRadius: 2).fill()
        }
    }

    private static func drawStats(pass: PlanetPass, profile: AstronautProfile, in size: CGSize, accent: UIColor) {
        let topY: CGFloat = 762
        let cells: [(String, String)] = [
            ("LEVEL",    String(format: "%02d", pass.levelReached)),
            ("MISSIONS", String(format: "%04d", pass.missionCount)),
            ("RANK",     profile.rankTitle),
            ("STATUS",   "CLEARED"),
        ]
        let cellW = (size.width - 30) / CGFloat(cells.count)
        for (i, (label, value)) in cells.enumerated() {
            let cellX = 30 + CGFloat(i) * cellW
            draw(label, at: CGPoint(x: cellX + 20, y: topY + 8),
                 size: 15, weight: .regular, color: .white.withAlphaComponent(0.28), kern: 2)
            draw(value, at: CGPoint(x: cellX + 20, y: topY + 33),
                 size: 26, weight: .bold, color: .white.withAlphaComponent(0.88), kern: 1)
            if i > 0 {
                accent.withAlphaComponent(0.15).setFill()
                UIRectFill(CGRect(x: cellX, y: topY, width: 0.5, height: 80))
            }
        }
    }

    private static func drawFooter(pass: PlanetPass, in size: CGSize, accent: UIColor) {
        let y: CGFloat = 872
        accent.withAlphaComponent(0.05).setFill()
        UIRectFill(CGRect(x: 30, y: y, width: size.width - 30, height: size.height - y))
        hairline(x: 30, y: y, width: size.width - 30, color: accent.withAlphaComponent(0.22))

        // Serial code
        draw(pass.serialCode, at: CGPoint(x: 66, y: y + 22),
             size: 32, weight: .bold, color: accent.withAlphaComponent(0.90), kern: 3)
        // Date
        draw(formattedDate(pass.timestamp), at: CGPoint(x: 66, y: y + 72),
             size: 16, weight: .regular, color: .white.withAlphaComponent(0.28), kern: 2)

        // QR placeholder (right)
        drawQRPlaceholder(origin: CGPoint(x: size.width - 194, y: y + 10), totalSize: 98, accent: accent)
    }

    // MARK: - QR Placeholder
    /// Deterministic decorative pattern that reads as a QR code visually.
    private static func drawQRPlaceholder(origin: CGPoint, totalSize: CGFloat, accent: UIColor) {
        let pattern: [[Bool]] = [
            [true,  true,  true,  false, true,  false, true ],
            [true,  false, true,  true,  false, true,  true ],
            [true,  true,  true,  false, false, false, true ],
            [false, true,  false, true,  true,  false, false],
            [true,  true,  true,  false, true,  true,  true ],
            [false, false, true,  true,  false, true,  false],
            [true,  false, true,  false, true,  true,  true ],
        ]
        let n = pattern.count
        let cell = totalSize / CGFloat(n)
        for r in 0..<n {
            for c in 0..<n {
                let x = origin.x + CGFloat(c) * cell + 1
                let y = origin.y + CGFloat(r) * cell + 1
                let color = pattern[r][c]
                    ? accent.withAlphaComponent(0.65)
                    : UIColor.white.withAlphaComponent(0.05)
                color.setFill()
                UIRectFill(CGRect(x: x, y: y, width: cell - 2, height: cell - 2))
            }
        }
        // Outer frame
        UIColor.white.withAlphaComponent(0.18).setStroke()
        UIBezierPath(rect: CGRect(x: origin.x, y: origin.y,
                                  width: totalSize, height: totalSize)).stroke()
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

    /// Scales down font size to fit `text` within `maxWidth` at the given base size.
    private static func adaptiveFontSize(for text: String, maxWidth: CGFloat, base: CGFloat) -> CGFloat {
        let font = UIFont.monospacedSystemFont(ofSize: base, weight: .black)
        let w = (text as NSString).size(withAttributes: [.font: font, .kern: -2.0]).width
        guard w > maxWidth else { return base }
        return floor(base * maxWidth / w)
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: date).uppercased()
    }
}
