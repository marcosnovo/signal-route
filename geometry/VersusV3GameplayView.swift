import SwiftUI

// MARK: - VersusV3GameplayView
/// Standard 5×5 versus board — identical layout to campaign game view.
///
/// Each player solves the same puzzle independently. First to connect source → target wins.
/// Timer, avatars, and rival progress overlay the standard board.
struct VersusV3GameplayView: View {

    @ObservedObject var vm: VersusV3ViewModel
    let matchState: VersusMatchState
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    var body: some View {
        VStack(spacing: 0) {
            // Timer + objective
            timerSection
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer().frame(height: 8)

            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.5))
                Text(S.versusReachTarget)
                    .font(AppTheme.mono(9, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.6))
            }

            Spacer().frame(height: 8)

            // Standard 5×5 board — same layout as campaign
            boardSection

            Spacer().frame(height: 10)

            // Bottom HUD: avatars + moves + rival progress
            bottomHUD
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        let progress = Double(vm.timeRemaining) / Double(VersusV3ViewModel.gameDuration)
        let timerColor: Color = {
            if vm.timeRemaining <= 5 { return AppTheme.danger }
            if vm.timeRemaining <= 10 { return Color(hex: "FFB800") }
            return AppTheme.accentPrimary
        }()

        return VStack(spacing: 4) {
            Text("\(vm.timeRemaining)")
                .font(AppTheme.mono(24, weight: .black))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: vm.timeRemaining)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.stroke)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(timerColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 1.0), value: vm.timeRemaining)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Board (same as campaign GameView)

    private var boardSection: some View {
        GeometryReader { geo in
            let gap: CGFloat     = AppTheme.gap
            let pad: CGFloat     = AppTheme.tilePadding
            let available        = geo.size.width - pad * 2 - gap * CGFloat(VersusV3ViewModel.gridSize - 1)
            let tileSize         = available / CGFloat(VersusV3ViewModel.gridSize)

            VStack(spacing: 0) {
                VStack(spacing: gap) {
                    ForEach(0..<VersusV3ViewModel.gridSize, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<VersusV3ViewModel.gridSize, id: \.self) { col in
                                TileView(
                                    tile:             vm.tiles[row][col],
                                    size:             tileSize,
                                    winPulse:         false,
                                    animationDelay:   0,
                                    signalHighlight:  false,
                                    isFailureCulprit: false,
                                    onTap:            { vm.tap(row: row, col: col) }
                                )
                            }
                        }
                    }
                }
                .padding(pad)
                .background(AppTheme.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .strokeBorder(AppTheme.sage.opacity(0.18), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 12)
    }

    // MARK: - Bottom HUD

    private var bottomHUD: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                // Local player
                HStack(spacing: 8) {
                    avatarCircle(image: localPlayerAvatar, size: 32)
                        .overlay(Circle().strokeBorder(AppTheme.accentPrimary.opacity(0.5), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(matchState.localPlayerName.uppercased())
                            .font(AppTheme.mono(7, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(S.versusMovesLabel)
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                            Text("\(vm.localTapCount)")
                                .font(AppTheme.mono(18, weight: .black))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer()

                // VS
                Text("VS")
                    .font(AppTheme.mono(10, weight: .black))
                    .kerning(2.0)
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.4))

                Spacer()

                // Rival
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(matchState.opponentDisplayName.uppercased())
                            .font(AppTheme.mono(7, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("\(vm.rivalProgressPercent)%")
                                .font(AppTheme.mono(18, weight: .black))
                                .foregroundStyle(rivalProgressColor)
                                .monospacedDigit()
                            Text(S.versusRivalHint)
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(AppTheme.sage.opacity(0.7))
                        }
                    }

                    avatarCircle(image: matchState.opponentAvatar, size: 32)
                        .overlay(Circle().strokeBorder(AppTheme.sage.opacity(0.5), lineWidth: 1))
                }
            }

            // Rival progress bar
            rivalProgressBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
        )
    }

    private var rivalProgressBar: some View {
        let percent = vm.rivalProgressPercent
        let progress = Double(percent) / 100.0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.stroke.opacity(0.5))
                RoundedRectangle(cornerRadius: 2)
                    .fill(rivalProgressColor)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.5), value: percent)
            }
        }
        .frame(height: 4)
    }

    private var rivalProgressColor: Color {
        let p = vm.rivalProgressPercent
        if p >= 75 { return AppTheme.danger }
        if p >= 45 { return Color(hex: "FFB800") }
        return AppTheme.sage
    }

    // MARK: - Avatar

    /// Prefer GC avatar from GameCenterManager (already loaded), fallback to matchState.
    private var localPlayerAvatar: UIImage? {
        GameCenterManager.shared.playerAvatar ?? matchState.localPlayerAvatar
    }

    private func avatarCircle(image: UIImage?, size: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.backgroundSecondary)
        .clipShape(Circle())
    }
}
