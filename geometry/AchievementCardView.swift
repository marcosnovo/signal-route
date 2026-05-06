import SwiftUI

// MARK: - AchievementCardView

struct AchievementCardView: View {
    let achievement: Achievement
    let state: AchievementState
    var revealProgress: Double = 1.0
    var gcImage: UIImage? = nil

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var sheenX: CGFloat = -0.5

    private let cornerR: CGFloat = 28
    private var accent: Color { Color(hex: achievement.accent.hex) }

    var body: some View {
        ZStack {
            if revealProgress < 0.01 {
                wireframeCard
            } else {
                revealedCard
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Wireframe (locked)

    private var wireframeCard: some View {
        RoundedRectangle(cornerRadius: cornerR, style: .continuous)
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.08))

                    Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                        .font(AppTheme.mono(24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.10))

                    Text(localizedSubtitle)
                        .font(AppTheme.mono(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.15))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineLimit(3)
                }
            }
    }

    // MARK: - Revealed card (in-progress / unlocked)

    private var revealedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .fill(cardBackground)

            VStack(alignment: .leading, spacing: 0) {
                heroImage
                Spacer(minLength: 4)
                cardTitle
                    .padding(.horizontal, 24)
                Spacer(minLength: 10)
                statsRow
                    .padding(.horizontal, 24)
                Spacer(minLength: 6)
                cardFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .opacity(revealProgress)

            innerShadowLayer
            glossLayer
            specularLayer

            if !state.isUnlocked {
                RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                    .fill(Color.black.opacity(0.45))
            }

            sheenLayer

            bevelBorder
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                accent.opacity(0.08 * revealProgress),
                Color(hex: "0D0D0D").opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shine Layers

    private var innerShadowLayer: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.15)
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.10)],
                startPoint: UnitPoint(x: 0.5, y: 0.85),
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
        .allowsHitTesting(false)
    }

    private var glossLayer: some View {
        RoundedRectangle(cornerRadius: cornerR, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.11), location: 0.00),
                        .init(color: .white.opacity(0.04), location: 0.36),
                        .init(color: .clear,                location: 0.54),
                    ],
                    startPoint: UnitPoint(x: 0.08, y: 0.0),
                    endPoint:   UnitPoint(x: 0.92, y: 1.0)
                )
            )
            .allowsHitTesting(false)
    }

    private var specularLayer: some View {
        RadialGradient(
            colors: [
                .white.opacity(0.14),
                .white.opacity(0.04),
                .clear,
            ],
            center:      UnitPoint(x: 0.28, y: 0.16),
            startRadius: 0,
            endRadius:   80
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
        .allowsHitTesting(false)
    }

    private var sheenLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.0),
                    .init(color: .white.opacity(0.20), location: 0.5),
                    .init(color: .clear,               location: 1.0),
                ],
                startPoint: .leading,
                endPoint:   .trailing
            )
            .frame(width: 48)
            .rotationEffect(.degrees(-26), anchor: .center)
            .offset(x: sheenX * w - 24)
            .frame(maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
        .allowsHitTesting(false)
        .onAppear {
            sheenX = -0.5
            withAnimation(.easeIn(duration: 0.6).delay(0.35)) { sheenX = 1.5 }
        }
    }

    private var bevelBorder: some View {
        RoundedRectangle(cornerRadius: cornerR, style: .continuous)
            .strokeBorder(
                state.isUnlocked
                    ? AnyShapeStyle(LinearGradient(
                        stops: [
                            .init(color: accent.opacity(0.50), location: 0.00),
                            .init(color: .white.opacity(0.18), location: 0.30),
                            .init(color: .white.opacity(0.06), location: 0.70),
                            .init(color: accent.opacity(0.25), location: 1.00),
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ))
                    : AnyShapeStyle(LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.15), location: 0.00),
                            .init(color: .white.opacity(0.06), location: 0.30),
                            .init(color: .black.opacity(0.06), location: 0.70),
                            .init(color: .black.opacity(0.12), location: 1.00),
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )),
                lineWidth: 1.2
            )
            .allowsHitTesting(false)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            if let img = gcImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .saturation(state.isUnlocked ? 1.0 : 0.0)
                    .opacity(state.isUnlocked ? 1.0 : 0.35)
            } else {
                accent.opacity(0.08)
                Image(systemName: achievement.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(accent.opacity(state.isUnlocked ? 0.6 : 0.15))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipped()
        .overlay(alignment: .topTrailing) {
            Text(achievement.tier.label)
                .font(AppTheme.mono(8, weight: .semibold))
                .adaptiveKerning(1.5)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(12)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Color(hex: "0D0D0D").opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
        }
        .overlay(alignment: .center) {
            if !state.isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Title

    private var cardTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedTitle)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if state.isUnlocked {
                Text(localizedSubtitle)
                    .font(AppTheme.mono(10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: progressLabel, unit: "", label: S.achievementProgress)
            Spacer()
            statCell(value: dateLabel, unit: "", label: S.achievementDate)
            Spacer()
            statCell(value: "\(achievement.tier.rawValue)", unit: "/4", label: "TIER")
        }
    }

    private func statCell(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppTheme.mono(18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppTheme.mono(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            Text(label)
                .font(AppTheme.mono(7, weight: .semibold))
                .adaptiveKerning(1)
                .foregroundStyle(.white.opacity(0.30))
        }
    }

    // MARK: - Footer

    private var cardFooter: some View {
        VStack(spacing: 10) {
            if case .inProgress(let current) = state {
                progressBar(current: current)
            } else if state.isUnlocked {
                unlockedBadge
            } else {
                lockedBadge
            }
        }
    }

    private func progressBar(current: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent.opacity(0.65))
                        .frame(width: geo.size.width * CGFloat(current) / CGFloat(max(1, achievement.target)))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(current) / \(achievement.target)")
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(accent.opacity(0.70))
                Spacer()
                Text("\(Int(Double(current) / Double(max(1, achievement.target)) * 100))%")
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var unlockedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(S.achievementCompleted)
                .font(AppTheme.mono(9, weight: .bold))
                .adaptiveKerning(1)
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .medium))
            Text(S.achievementLocked)
                .font(AppTheme.mono(9, weight: .bold))
                .adaptiveKerning(1)
        }
        .foregroundStyle(.white.opacity(0.20))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var localizedTitle: String {
        switch settings.language {
        case .es: achievement.titleES
        case .fr: achievement.titleFR
        case .ja: achievement.titleJA
        default:  achievement.titleEN
        }
    }

    private var localizedSubtitle: String {
        switch settings.language {
        case .es: achievement.subtitleES
        case .fr: achievement.subtitleFR
        case .ja: achievement.subtitleJA
        default:  achievement.subtitleEN
        }
    }

    private var progressLabel: String {
        switch state {
        case .locked: "0/\(achievement.target)"
        case .inProgress(let c): "\(c)/\(achievement.target)"
        case .unlocked: "\(achievement.target)/\(achievement.target)"
        }
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        return f
    }()

    private var dateLabel: String {
        if let date = state.unlockDate {
            return Self.dateFmt.string(from: date)
        }
        return "\u{2014}"
    }

    private var accessibilityText: String {
        if state.isUnlocked {
            return "\(S.achievementCompleted): \(localizedTitle). \(localizedSubtitle)"
        } else {
            return "\(S.achievementLocked): \(localizedSubtitle)"
        }
    }
}
