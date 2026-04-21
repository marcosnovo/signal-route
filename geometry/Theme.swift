import SwiftUI
import UIKit

// MARK: - UIImage normalization
extension UIImage {
    /// Forces the image through a 32-bpp RGBA graphics context.
    ///
    /// Asset-catalog JPEGs are 24-bpp (no alpha channel). CoreGraphics'
    /// block-based decoder expects 32-bpp and logs:
    ///   "kCGImageBlockFormatBGRx8 is called for 24-bpp (8-bpc) image"
    /// (rdar://143602439). Re-drawing through UIGraphicsImageRenderer
    /// normalises the pixel format and silences the warning.
    var normalizedForDisplay: UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(at: .zero) }
    }
}

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
    static let accentSecondary     = Color(hex: "D9E7D8")   // sage (light)
    static let sage                = Color(hex: "C7D7C6")   // muted sage — functional labels & data guides
    static let surfacePrimary      = sage                    // #C7D7C6 light functional surface
    static let textPrimary         = Color(hex: "F0EDE8")   // off-white
    static let textSecondary       = Color(hex: "9A9A9A")   // technical gray (AA+ contrast on dark bg)
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
/// Drifts diagonally at ~1.4 px/s (one cell per 20 s) to suggest a live system.
struct BackgroundGrid: View {
    var spacing: CGFloat = 28
    var opacity: Double  = 0.045

    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            // Start one cell before origin so the grid tiles seamlessly as phase increases
            let start = phase.truncatingRemainder(dividingBy: spacing) - spacing
            var x = start
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = start
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = spacing
            }
        }
    }
}

// MARK: - TechDivider
struct TechDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.sage.opacity(0.14))
            .frame(height: 0.5)
    }
}

// MARK: - BreathingCTA
/// Combines a gentle scale pulse (1.0 → 1.04 → 1.0) with a soft colour glow.
/// Full breath cycle ≈ 3 s. Designed for primary action buttons.
struct BreathingCTA: ViewModifier {
    let color: Color

    @State private var expanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(expanded ? 1.04 : 1.0)
            // Fixed radius — animating radius forces a shadow re-blur every frame.
            // Only the color opacity animates, which is a cheap blend operation.
            .shadow(color: color.opacity(expanded ? 0.42 : 0.06), radius: 10)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    expanded = true
                }
            }
    }
}

extension View {
    func breathingCTA(color: Color = AppTheme.accentPrimary) -> some View {
        modifier(BreathingCTA(color: color))
    }
}

// MARK: - PulsingGlow
/// Soft repeating shadow that breathes at a slow cadence.
/// Pairs well with status dots, difficulty badges, and "ONLINE"-type indicators.
struct PulsingGlow: ViewModifier {
    let color: Color
    var duration: Double = 1.8

    @State private var bright = false

    func body(content: Content) -> some View {
        content
            // Fixed radius — only opacity animates. Avoids shadow re-blur every frame.
            .shadow(color: color.opacity(bright ? 0.52 : 0.06), radius: 5)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

extension View {
    func pulsingGlow(color: Color, duration: Double = 1.8) -> some View {
        modifier(PulsingGlow(color: color, duration: duration))
    }
}

// MARK: - TechLabel (small uppercase label)
struct TechLabel: View {
    let text: String
    var color: Color = AppTheme.textSecondary

    var body: some View {
        Text(text)
            .font(AppTheme.mono(9, weight: .semibold))
            .foregroundStyle(color)
            .kerning(1.5)
    }
}
