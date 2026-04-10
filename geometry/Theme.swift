import SwiftUI

// MARK: - Hex Color Convenience
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

// MARK: - AppTheme
/// Sci-fi / mission-control design system.
enum AppTheme {
    // MARK: Colours
    static let backgroundPrimary   = Color(hex: "171717")
    static let backgroundSecondary = Color(hex: "1F1F1F")
    static let surface             = Color(hex: "222222")
    static let surfaceElevated     = Color(hex: "2B2B2B")
    static let accentPrimary       = Color(hex: "FF6A3D")   // orange
    static let accentSecondary     = Color(hex: "D9E7D8")   // sage
    static let textPrimary         = Color(hex: "F0EDE8")   // off-white
    static let textSecondary       = Color(hex: "5E5E5E")   // technical gray
    static let stroke              = Color.white.opacity(0.08)
    static let strokeBright        = Color.white.opacity(0.15)
    static let danger              = Color(hex: "E84040")
    static let success             = Color(hex: "4DB87A")

    // Backward-compat aliases used by existing code
    static let background   = backgroundPrimary
    static let accent       = accentPrimary
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "FF6A3D"), Color(hex: "FF9550")],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: Typography
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func techLabel(_ size: CGFloat = 9) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // MARK: Spacing / Layout
    static let gap: CGFloat          = 5
    static let tilePadding: CGFloat  = 14
    static let cornerRadius: CGFloat = 3
    static let cardRadius: CGFloat   = 6
    static let strokeWidth: CGFloat  = 0.5

    // MARK: Pipe rendering (fractions of tile size)
    static let pipeOuter: CGFloat = 0.24
    static let pipeInner: CGFloat = 0.10
    static let nodeRatio: CGFloat = 0.22
}

// MARK: - BackgroundGrid
/// Subtle technical grid drawn in the background of panels.
struct BackgroundGrid: View {
    var spacing: CGFloat = 28
    var opacity: Double  = 0.045

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - TechDivider
struct TechDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.stroke)
            .frame(height: 0.5)
    }
}

// MARK: - TechLabel (small uppercase label)
struct TechLabel: View {
    let text: String
    var color: Color = AppTheme.textSecondary

    var body: some View {
        Text(text)
            .font(AppTheme.mono(8, weight: .semibold))
            .foregroundStyle(color)
            .kerning(1.5)
    }
}
