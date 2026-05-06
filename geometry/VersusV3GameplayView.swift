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

            if vm.isOvertime {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                    Text("SUDDEN DEATH")
                        .font(AppTheme.mono(10, weight: .black))
                        .adaptiveKerning(2.0)
                        .foregroundStyle(AppTheme.danger)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.5))
                    Text(S.versusReachTarget)
                        .font(AppTheme.mono(9, weight: .bold))
                        .adaptiveKerning(1.5)
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.6))
                }
            }

            Spacer().frame(height: 8)

            // Standard 5×5 board — same layout as campaign
            boardSection

            Spacer().frame(height: 6)

            // Power-up buttons
            if !vm.activePowerUps.isEmpty {
                powerUpHUD
            }

            Spacer().frame(height: 6)

            // Bottom HUD: avatars + moves + rival progress
            bottomHUD
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        let progress = Double(vm.timeRemaining) / Double(VersusV3ViewModel.gameDuration(for: vm.gridSize))
        let timerColor: Color = {
            if vm.timeRemaining <= 5 { return AppTheme.danger }
            if vm.timeRemaining <= 10 { return Color(hex: "FFB800") }
            return AppTheme.accentPrimary
        }()

        let freezeColor = Color(hex: "5BC0EB")
        let displayColor = vm.isTimerFrozen ? freezeColor : (vm.rushFlash ? AppTheme.danger : timerColor)

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                if vm.isTimerFrozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(freezeColor)
                        .transition(.scale.combined(with: .opacity))
                }
                Text("\(vm.timeRemaining)")
                    .font(AppTheme.mono(24, weight: .black))
                    .foregroundStyle(displayColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: vm.timeRemaining)
            }
            .animation(.easeInOut(duration: 0.3), value: vm.isTimerFrozen)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.stroke)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(displayColor)
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
            let gridSize         = vm.gridSize
            let available        = geo.size.width - pad * 2 - gap * CGFloat(gridSize - 1)
            let tileSize         = available / CGFloat(gridSize)

            VStack(spacing: 0) {
                VStack(spacing: gap) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                TileView(
                                    tile:             vm.tiles[row][col],
                                    size:             tileSize,
                                    winPulse:         vm.winPulse,
                                    animationDelay:   Double(row + col) * 0.038,
                                    signalHighlight:  vm.signalFrontRow == row && vm.signalFrontCol == col,
                                    isFailureCulprit: false,
                                    onTap:            { vm.tap(row: row, col: col) }
                                )
                                .overlay(
                                    ghostOverlay(row: row, col: col, size: tileSize)
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
                            .adaptiveKerning(0.5)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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
                    .adaptiveKerning(2.0)
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.4))

                Spacer()

                // Rival
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(matchState.opponentDisplayName.uppercased())
                            .font(AppTheme.mono(7, weight: .bold))
                            .adaptiveKerning(0.5)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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

    // MARK: - Power-up HUD

    private var powerUpHUD: some View {
        HStack(spacing: 10) {
            ForEach(Array(vm.activePowerUps.enumerated()), id: \.offset) { _, type in
                let c = Color(hex: type.color)
                Button(action: { vm.usePowerUp(type) }) {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14, weight: .bold))
                        Text(type.label)
                            .font(AppTheme.mono(11, weight: .black))
                            .adaptiveKerning(0.8)
                    }
                    .foregroundStyle(c)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(c.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(c.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: c.opacity(0.2), radius: 4, y: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: vm.activePowerUps.count)
    }

    // MARK: - Ghost Overlay

    @ViewBuilder
    private func ghostOverlay(row: Int, col: Int, size: CGFloat) -> some View {
        if vm.ghostRow == row && vm.ghostCol == col {
            ZStack {
                Circle()
                    .fill(AppTheme.sage.opacity(0.1))
                Circle()
                    .strokeBorder(AppTheme.sage.opacity(0.5), lineWidth: 2)
            }
            .frame(width: size * 0.8, height: size * 0.8)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.5), value: vm.ghostRow)
        }
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
