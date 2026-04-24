import SwiftUI

// MARK: - WidgetTheme
/// Replicates AppTheme colours and typography for the widget extension.
/// Widget extensions run in a separate process and cannot access main app code.
enum WidgetTheme {

    // MARK: Colours
    static let backgroundDark      = Color(hex: "171717")
    static let backgroundSecondary = Color(hex: "1F1F1F")
    static let surface             = Color(hex: "222222")
    static let surfaceElevated     = Color(hex: "2B2B2B")
    static let accentOrange        = Color(hex: "FF6A3D")
    static let sage                = Color(hex: "D9E7D8")
    static let sageMuted           = Color(hex: "C7D7C6")
    static let textPrimary         = Color(hex: "F0EDE8")
    static let textSecondary       = Color(hex: "9A9A9A")
    static let success             = Color(hex: "4DB87A")
    static let danger              = Color(hex: "E84040")

    // Ink color for text on sage backgrounds
    static let sageInk             = Color(hex: "2A2A2A")
    static let sageMid             = Color(hex: "2A2A2A").opacity(0.5)
    static let onDarkSub           = Color(hex: "9A9A9A")

    // MARK: Typography — Monospaced (labels, small text)
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Typography — Sans-serif (hero numbers, titles)
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: Score Formatting
    static func formattedScore(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func shortScore(_ value: Int) -> String {
        if value >= 1000 {
            return "\(value / 1000)K"
        }
        return "\(value)"
    }
}

// MARK: - Hex Color (widget-side)
// Duplicated from main app Theme.swift — widget extension is a separate module.
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
