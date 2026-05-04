import Foundation
import UIKit
import SwiftUI

// MARK: - ShareImageRenderer
/// Generates branded 1080×1080 share images for social media.
/// Two variants: victory (mission complete) and leaderboard (rank brag).
/// Purely vectorial — no external image assets required.
/// Uses UIGraphicsImageRenderer + Core Graphics for pixel-perfect output.
enum ShareImageRenderer {

    // MARK: - Colors (raw hex constants)

    private static let bgColor      = UIColor(red: 0.090, green: 0.090, blue: 0.090, alpha: 1) // #171717
    private static let cream        = UIColor(red: 0.941, green: 0.929, blue: 0.910, alpha: 1) // #F0EDE8
    private static let orange       = UIColor(red: 1.000, green: 0.416, blue: 0.239, alpha: 1) // #FF6A3D
    private static let midGray      = UIColor(red: 0.604, green: 0.604, blue: 0.604, alpha: 1) // #9A9A9A
    private static let sage         = UIColor(red: 0.851, green: 0.906, blue: 0.847, alpha: 1) // #D9E7D8
    private static let sageDarkText = UIColor(red: 0.075, green: 0.106, blue: 0.075, alpha: 1) // #131B13
    private static let dividerColor = UIColor.white.withAlphaComponent(0.08)

    // MARK: - Internal Localization

    /// Lightweight localization for share-image-only strings.
    /// Mirrors the AppStrings `t()` pattern but runs without SettingsStore dependency.
    private struct Strings {
        let lang: AppLanguage

        private func t(_ en: String, _ es: String, _ fr: String) -> String {
            switch lang {
            case .en: return en
            case .es: return es
            case .fr: return fr
            }
        }

        func missionComplete(_ id: Int) -> String {
            t("MISSION #\(id) COMPLETE",
              "MISIÓN #\(id) COMPLETADA",
              "MISSION #\(id) TERMINÉE")
        }

        var missionQuality: String {
            t("MISSION QUALITY", "CALIDAD DE MISIÓN", "QUALITÉ DE MISSION")
        }

        var scoreLabel: String { t("SCORE", "PUNTOS", "SCORE") }
        var movesLabel: String { t("MOVES", "MOVIMIENTOS", "COUPS") }
        var rankLabel:  String { t("RANK",  "RANGO",       "RANG") }

        var downloadCTA: String {
            t("Download on the App Store",
              "Descarga en la App Store",
              "Télécharger sur l'App Store")
        }

        var globalScore: String { t("GLOBAL SCORE", "PUNTUACIÓN GLOBAL", "SCORE GLOBAL") }

        func topPercent(_ pct: Int, total: Int) -> String {
            t("TOP \(pct)%  ·  of \(total) players",
              "TOP \(pct)%  ·  de \(total) jugadores",
              "TOP \(pct)%  ·  sur \(total) joueurs")
        }
    }

    // MARK: - Public API — Victory

    /// Renders a branded 1080×1080 victory share image.
    ///
    /// `nonisolated static` — UIGraphicsImageRenderer + Core Graphics drawing is
    /// documented thread-safe; this lets the call happen off the main thread via Task.detached.
    nonisolated static func renderVictory(
        missionId: Int,
        planetName: String,
        efficiency: Int,
        score: Int,
        movesUsed: Int,
        minMoves: Int,
        rankTitle: String,
        language: AppLanguage
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1.0
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            drawVictory(missionId: missionId, planetName: planetName,
                        efficiency: efficiency, score: score,
                        movesUsed: movesUsed, minMoves: minMoves,
                        rankTitle: rankTitle, language: language, in: size)
        }
    }

    // MARK: - Public API — Leaderboard

    /// Renders a branded 1080×1080 leaderboard share image.
    nonisolated static func renderLeaderboard(
        rank: Int,
        score: Int,
        totalPlayers: Int,
        boardName: String,
        topPercent: Int,
        playerName: String,
        language: AppLanguage
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1.0
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            drawLeaderboard(rank: rank, score: score, totalPlayers: totalPlayers,
                            boardName: boardName, topPercent: topPercent,
                            playerName: playerName, language: language, in: size)
        }
    }

    // MARK: - Public API — Share Sheet

    /// Presents a UIActivityViewController with the given image and text.
    /// Reuses the same topmost-VC traversal pattern used throughout the codebase.
    @MainActor static func presentShareSheet(image: UIImage, text: String) {
        let vc = UIActivityViewController(activityItems: [text, image], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        while let next = presenter.presentedViewController, !next.isBeingDismissed {
            presenter = next
        }

        vc.popoverPresentationController?.sourceView = presenter.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.maxY - 80,
            width: 0, height: 0
        )

        presenter.present(vc, animated: true)
    }

    // MARK: - Victory — Full Draw

    private static func drawVictory(
        missionId: Int, planetName: String, efficiency: Int, score: Int,
        movesUsed: Int, minMoves: Int, rankTitle: String,
        language: AppLanguage, in size: CGSize
    ) {
        let S = Strings(lang: language)

        // Background
        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Top brand strip
        drawTopStrip(in: size)

        // ── Main content ─────────────────────────────────────────────────────────
        let padX: CGFloat = 40
        var y: CGFloat = 120

        // "MISSION #XXX COMPLETE"
        draw(S.missionComplete(missionId), at: CGPoint(x: padX, y: y),
             size: 14, weight: .bold, color: cream, kern: 3)
        y += 36

        // Planet name — large orange
        let nameAttr = NSAttributedString(string: planetName.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 36, weight: .heavy),
            .foregroundColor: orange,
            .kern: 1.0
        ])
        nameAttr.draw(at: CGPoint(x: padX, y: y))
        y += 56

        // Divider
        hairline(x: padX, y: y, width: size.width - padX * 2, color: dividerColor)
        y += 32

        // Large efficiency display
        let effStr = "\(efficiency)"
        let effAttr = NSAttributedString(string: effStr, attributes: [
            .font: UIFont.systemFont(ofSize: 120, weight: .heavy),
            .foregroundColor: cream,
            .kern: -2.0
        ])
        let pctAttr = NSAttributedString(string: "%", attributes: [
            .font: UIFont.systemFont(ofSize: 48, weight: .heavy),
            .foregroundColor: orange,
            .kern: 0 as NSNumber
        ])
        let effWidth = effAttr.size().width
        effAttr.draw(at: CGPoint(x: padX, y: y))
        pctAttr.draw(at: CGPoint(x: padX + effWidth + 4, y: y + 54))
        y += 148

        // "MISSION QUALITY" label
        draw(S.missionQuality, at: CGPoint(x: padX, y: y),
             size: 10, weight: .regular, color: midGray, kern: 3)
        y += 36

        // Divider
        hairline(x: padX, y: y, width: size.width - padX * 2, color: dividerColor)
        y += 40

        // 3 stat cells in a row
        let cellW = (size.width - padX * 2) / 3.0
        let cells: [(String, String, UIColor)] = [
            (S.scoreLabel, "\(score)", orange),
            (S.movesLabel, "\(movesUsed)/\(minMoves)", cream),
            (S.rankLabel,  rankTitle.uppercased(), cream),
        ]
        for (i, (label, value, valueColor)) in cells.enumerated() {
            let cellX = padX + CGFloat(i) * cellW

            // Vertical divider between cells
            if i > 0 {
                dividerColor.setFill()
                UIRectFill(CGRect(x: cellX, y: y, width: 0.5, height: 80))
            }

            let labelX = i == 0 ? cellX : cellX + 16
            draw(label, at: CGPoint(x: labelX, y: y),
                 size: 10, weight: .semibold, color: midGray, kern: 2)
            draw(value, at: CGPoint(x: labelX, y: y + 26),
                 size: 28, weight: .bold, color: valueColor, kern: 1)
        }

        // Bottom sage strip
        drawBottomStrip(S: S, in: size)
    }

    // MARK: - Leaderboard — Full Draw

    private static func drawLeaderboard(
        rank: Int, score: Int, totalPlayers: Int, boardName: String,
        topPercent: Int, playerName: String,
        language: AppLanguage, in size: CGSize
    ) {
        let S = Strings(lang: language)

        // Background
        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Top brand strip
        drawTopStrip(in: size)

        // ── Main content (centered) ──────────────────────────────────────────────
        let centerX = size.width / 2.0
        var y: CGFloat = 160

        // Board name
        let boardAttr = attr(boardName.uppercased(), size: 12, weight: .regular, color: midGray, kern: 3)
        let boardW = boardAttr.size().width
        boardAttr.draw(at: CGPoint(x: centerX - boardW / 2, y: y))
        y += 48

        // Huge rank: "#" + number
        let hashAttr = NSAttributedString(string: "#", attributes: [
            .font: UIFont.systemFont(ofSize: 60, weight: .heavy),
            .foregroundColor: cream,
            .kern: 0 as NSNumber
        ])
        let rankNumAttr = NSAttributedString(string: "\(rank)", attributes: [
            .font: UIFont.systemFont(ofSize: 160, weight: .heavy),
            .foregroundColor: orange,
            .kern: -3.0
        ])
        let hashW = hashAttr.size().width
        let rankW = rankNumAttr.size().width
        let totalRankW = hashW + rankW + 4
        let rankStartX = centerX - totalRankW / 2
        // Baseline-align the "#" with the rank number (offset upward from the large number)
        hashAttr.draw(at: CGPoint(x: rankStartX, y: y + 68))
        rankNumAttr.draw(at: CGPoint(x: rankStartX + hashW + 4, y: y))
        y += 196

        // Score value
        let scoreAttr = NSAttributedString(string: "\(score)", attributes: [
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy),
            .foregroundColor: cream,
            .kern: 1.0
        ])
        let scoreW = scoreAttr.size().width
        scoreAttr.draw(at: CGPoint(x: centerX - scoreW / 2, y: y))
        y += 52

        // "TOP X% · of Y players"
        let topAttr = attr(S.topPercent(topPercent, total: totalPlayers),
                           size: 12, weight: .regular, color: midGray, kern: 2)
        let topW = topAttr.size().width
        topAttr.draw(at: CGPoint(x: centerX - topW / 2, y: y))
        y += 48

        // Divider
        let divW: CGFloat = 400
        hairline(x: centerX - divW / 2, y: y, width: divW, color: dividerColor)
        y += 40

        // Player name
        let nameAttr = NSAttributedString(string: playerName, attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: sage,
            .kern: 1.0
        ])
        let nameW = nameAttr.size().width
        nameAttr.draw(at: CGPoint(x: centerX - nameW / 2, y: y))

        // Bottom sage strip
        drawBottomStrip(S: S, in: size)
    }

    // MARK: - Shared Components

    /// Top brand strip — "SIGNAL VOID" left, "signalvoid.app" right.
    private static func drawTopStrip(in size: CGSize) {
        let stripH: CGFloat = 80

        // Subtle top bar tint
        UIColor.white.withAlphaComponent(0.03).setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: stripH))

        // Bottom hairline
        hairline(x: 0, y: stripH, width: size.width, color: dividerColor)

        // Brand name — left
        draw("\u{229E} SIGNAL VOID", at: CGPoint(x: 32, y: 28),
             size: 12, weight: .bold, color: cream, kern: 2)

        // URL — right
        let urlAttr = attr("signalvoid.app", size: 10, weight: .regular, color: midGray, kern: 1)
        let urlW = urlAttr.size().width
        urlAttr.draw(at: CGPoint(x: size.width - urlW - 32, y: 32))
    }

    /// Bottom sage-green bar — CTA left, brand watermark right.
    private static func drawBottomStrip(S: Strings, in size: CGSize) {
        let stripH: CGFloat = 60
        let y = size.height - stripH

        // Sage background
        sage.setFill()
        UIRectFill(CGRect(x: 0, y: y, width: size.width, height: stripH))

        // CTA text
        let ctaAttr = NSAttributedString(string: S.downloadCTA, attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: sageDarkText,
            .kern: 1.0
        ])
        let ctaW = ctaAttr.size().width
        ctaAttr.draw(at: CGPoint(x: size.width / 2 - ctaW / 2, y: y + 22))

        // Small brand watermark — right
        let brandAttr = NSAttributedString(string: "signal void", attributes: [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: sageDarkText.withAlphaComponent(0.50),
            .kern: 1.0
        ])
        let brandW = brandAttr.size().width
        brandAttr.draw(at: CGPoint(x: size.width - brandW - 20, y: y + 46))
    }

    // MARK: - Drawing Helpers

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
}
