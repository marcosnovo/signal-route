import SwiftUI

// MARK: - VersusV3GameplayView
/// Three-column split-board layout for V3 versus mode.
///
/// Layout: [Local panel (4 cols)] [Center beacons (1 col)] [Opponent panel (4 cols)]
/// Local player is ALWAYS on the left, opponent on the right.
/// The ViewModel handles coordinate remapping so display order matches.
struct VersusV3GameplayView: View {

    @ObservedObject var vm: VersusV3ViewModel
    let matchState: VersusMatchState
    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    // Layout constants
    private let centerWidth: CGFloat = 20
    private let gapSize: CGFloat = 3
    private let outerPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // HUD bar
            versusHUD
                .padding(.horizontal, 12)
                .padding(.top, 4)

            // Timer bar
            timerBar
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Spacer().frame(height: 12)

            // Split board
            GeometryReader { geo in
                let availableWidth = geo.size.width - outerPadding * 2
                let totalGaps = gapSize * 8  // 8 gaps between 9 columns
                let tileSize = (availableWidth - centerWidth - totalGaps) / 8
                let panelWidth = tileSize * 4 + gapSize * 3

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Left panel (local player)
                    localPanel(tileSize: tileSize)
                        .frame(width: panelWidth)

                    Spacer().frame(width: gapSize)

                    // Center beacons
                    centerColumn(tileSize: tileSize)
                        .frame(width: centerWidth)

                    Spacer().frame(width: gapSize)

                    // Right panel (opponent)
                    opponentPanel(tileSize: tileSize)
                        .frame(width: panelWidth)

                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.horizontal, outerPadding)

            Spacer().frame(height: 16)
        }
    }

    // MARK: - HUD

    private var versusHUD: some View {
        HStack(spacing: 0) {
            // Local player info
            HStack(spacing: 6) {
                if let avatar = matchState.localPlayerAvatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(AppTheme.accentPrimary.opacity(0.5), lineWidth: 0.75))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(matchState.localPlayerName.uppercased())
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(AppTheme.accentPrimary)
                        .lineLimit(1)
                    Text(S.yourSide)
                        .font(AppTheme.mono(7, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.6))
                    Text(S.tapsCount(vm.localTapCount))
                        .font(AppTheme.mono(8, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            // VS badge + connection dot
            VStack(spacing: 2) {
                Text("VS")
                    .font(AppTheme.mono(14, weight: .black))
                    .kerning(2.0)
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.7))
                Circle()
                    .fill(matchState.remoteOutcome == .disconnected ? AppTheme.danger : AppTheme.success)
                    .frame(width: 4, height: 4)
            }

            Spacer()

            // Opponent info
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(matchState.opponentDisplayName.uppercased())
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(AppTheme.sage)
                        .lineLimit(1)
                    Text(S.rivalSide)
                        .font(AppTheme.mono(7, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(AppTheme.sage.opacity(0.6))
                    Text(S.tapsCount(vm.remoteTapCount))
                        .font(AppTheme.mono(8, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let avatar = matchState.opponentAvatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(AppTheme.sage.opacity(0.5), lineWidth: 0.75))
                }
            }
        }
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        let progress = Double(vm.timeRemaining) / Double(VersusV3ViewModel.gameDuration)
        let timerColor: Color = {
            if vm.timeRemaining <= 5 { return AppTheme.danger }
            if vm.timeRemaining <= 10 { return Color(hex: "FFB800") }
            return AppTheme.accentPrimary
        }()

        return VStack(spacing: 4) {
            // Time text
            Text("\(vm.timeRemaining)")
                .font(AppTheme.mono(20, weight: .black))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: vm.timeRemaining)

            // Progress bar
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

    // MARK: - Local Panel (Left — interactive)

    private func localPanel(tileSize: CGFloat) -> some View {
        let displayGrid = vm.displayTiles()
        return VStack(spacing: gapSize) {
            ForEach(0..<VersusV3ViewModel.rows, id: \.self) { row in
                HStack(spacing: gapSize) {
                    ForEach(0..<4, id: \.self) { col in
                        let displayCol = col  // local panel = display cols 0-3
                        TileView(
                            tile: displayGrid[row][displayCol],
                            size: tileSize,
                            winPulse: false,
                            animationDelay: 0,
                            signalHighlight: false,
                            isFailureCulprit: false,
                            onTap: {
                                vm.handleLocalTap(displayRow: row, displayCol: displayCol)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Opponent Panel (Right — non-interactive, dimmed)

    private func opponentPanel(tileSize: CGFloat) -> some View {
        let displayGrid = vm.displayTiles()
        return VStack(spacing: gapSize) {
            ForEach(0..<VersusV3ViewModel.rows, id: \.self) { row in
                HStack(spacing: gapSize) {
                    ForEach(0..<4, id: \.self) { col in
                        let displayCol = col + 5  // opponent panel = display cols 5-8
                        TileView(
                            tile: displayGrid[row][displayCol],
                            size: tileSize,
                            winPulse: false,
                            animationDelay: 0,
                            signalHighlight: false,
                            isFailureCulprit: false,
                            onTap: {}
                        )
                        .allowsHitTesting(false)
                        .opacity(0.65)
                    }
                }
            }
        }
    }

    // MARK: - Center Column

    private func centerColumn(tileSize: CGFloat) -> some View {
        let localCenterReached = vm.displayCenterReached(for: vm.localPlayer)
        let opponentPlayer: VersusPlayer = vm.localPlayer == .p1 ? .p2 : .p1
        let opponentCenterReached = vm.displayCenterReached(for: opponentPlayer)

        return VStack(spacing: 2) {
            Image(systemName: "target")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.sage.opacity(0.5))

            VStack(spacing: gapSize) {
                ForEach(0..<VersusV3ViewModel.rows, id: \.self) { row in
                    CenterBeaconTile(
                        size: tileSize,
                        beaconWidth: centerWidth,
                        localReached: localCenterReached.contains(row),
                        opponentReached: opponentCenterReached.contains(row)
                    )
                }
            }
        }
    }
}

// MARK: - CenterBeaconTile
/// A narrow beacon tile in the center objective column.
/// Glows orange when the local player reaches it, sage when the opponent does.
private struct CenterBeaconTile: View {
    let size: CGFloat       // tile height (matches panel tile size)
    let beaconWidth: CGFloat
    let localReached: Bool
    let opponentReached: Bool

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 2)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(borderColor, lineWidth: 0.75)
                )

            // Inner indicator circle
            Circle()
                .fill(indicatorColor)
                .frame(width: beaconWidth * 0.45, height: beaconWidth * 0.45)
                .shadow(color: glowColor, radius: glowRadius)
        }
        .frame(width: beaconWidth, height: size)
    }

    private var backgroundColor: Color {
        if localReached { return Color(hex: "221A14") }       // warm
        if opponentReached { return Color(hex: "192319") }    // sage tint
        return AppTheme.backgroundSecondary
    }

    private var borderColor: Color {
        if localReached { return AppTheme.accentPrimary.opacity(0.5) }
        if opponentReached { return AppTheme.sage.opacity(0.5) }
        return AppTheme.stroke
    }

    private var indicatorColor: Color {
        if localReached { return AppTheme.accentPrimary }
        if opponentReached { return AppTheme.sage }
        return Color.white.opacity(0.12)
    }

    private var glowColor: Color {
        if localReached { return AppTheme.accentPrimary.opacity(0.6) }
        if opponentReached { return AppTheme.sage.opacity(0.5) }
        return .clear
    }

    private var glowRadius: CGFloat {
        (localReached || opponentReached) ? 6 : 0
    }
}
