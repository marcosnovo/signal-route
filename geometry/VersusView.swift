import Combine
import SwiftUI
import GameKit

// MARK: - VersusView
/// Full-screen versus mode container. Transitions through lobby → search → countdown → game → result.
///
/// Hidden behind `VersusFeatureFlag.isEnabled`. Presented as a `fullScreenCover`
/// from ContentView. Does NOT interact with campaign stores.
///
/// V2: Custom branded matchmaking UI — no GKMatchmakerViewController dependency.
struct VersusView: View {

    @EnvironmentObject private var versusManager: VersusMatchmakingManager
    @EnvironmentObject private var settings: SettingsStore

    let onDismiss: () -> Void

    @StateObject private var versusV3VM: VersusV3ViewModel

    init(matchManager: VersusMatchmakingManager, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _versusV3VM = StateObject(wrappedValue: VersusV3ViewModel(matchManager: matchManager))
    }

    private var matchState: VersusMatchState { versusManager.matchState }
    private var S: AppStrings { AppStrings(lang: settings.language) }

    private var localPlayerAvatar: UIImage? {
        GameCenterManager.shared.playerAvatar ?? matchState.localPlayerAvatar
    }

    @State private var countdownDigit: Int? = nil
    @State private var findMatchPulsing = false
    @State private var selectedDifficulty: DifficultyTier = .medium
    @State private var selectedGridSize: Int = 5

    // Mystery box
    @State private var mysteryBoxOpened = false
    @State private var mysteryBoxReward: VersusPowerUpType? = nil
    @State private var showDiscardPicker = false

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            switch matchState.phase {
            case .idle:
                versusLobby
            case .searching:
                versusSearching
            case .matched, .countdown:
                versusCountdown
            case .playing:
                versusGameplay
            case .finished:
                if versusV3VM.showingWinAnimation {
                    versusGameplay
                } else {
                    versusResult
                }
            }

            // Error toast overlay
            if let error = matchState.error {
                VStack {
                    errorBanner(error)
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: matchState.phase)
        .onDisappear {
            versusV3VM.tearDown()
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.danger)
            Text(message.uppercased())
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
            Spacer()
            Button(action: { matchState.error = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.danger.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
    }

    // MARK: - Lobby (Idle)

    private var versusLobby: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                versusHeader

                Spacer().frame(height: 24)

                playerAvatar(
                    image: localPlayerAvatar,
                    name: matchState.localPlayerName,
                    accentColor: AppTheme.accentPrimary,
                    size: 72
                )

                Spacer().frame(height: 28)

                // Find Match button
                Button(action: {
                    SoundManager.play(.tapPrimary)
                    HapticsManager.medium()
                    VersusAnalytics.shared.trackCTATap(gcAuthenticated: GKLocalPlayer.local.isAuthenticated)
                    versusManager.findMatch()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                        Text(S.findMatch)
                            .font(AppTheme.mono(14, weight: .bold))
                            .kerning(1.2)
                    }
                    .foregroundStyle(AppTheme.backgroundPrimary)
                    .frame(width: 260, height: 50)
                    .background(AppTheme.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .disabled(!GKLocalPlayer.local.isAuthenticated)
                .opacity(GKLocalPlayer.local.isAuthenticated ? 1 : 0.4)
                .shadow(color: AppTheme.accentPrimary.opacity(findMatchPulsing ? 0.30 : 0.08),
                        radius: 12, y: 2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        findMatchPulsing = true
                    }
                }

                Spacer().frame(height: 10)

                gcStatusLabel

                Spacer().frame(height: 28)

                // Bot section (difficulty picker is here — only for solo test)
                botSection
                    .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                versusFeatureToggles
                    .padding(.horizontal, 20)

                Spacer().frame(height: 28)

                closeButton()
            }
            .padding()
        }
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        VStack(spacing: 8) {
            Text(S.versusDifficulty)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                ForEach(DifficultyTier.allCases) { tier in
                    let isSelected = tier == selectedDifficulty
                    Button(action: {
                        SoundManager.play(.tapPrimary)
                        HapticsManager.light()
                        selectedDifficulty = tier
                    }) {
                        Text(S.difficultyFullLabel(tier))
                            .font(AppTheme.mono(9, weight: isSelected ? .black : .bold))
                            .kerning(0.6)
                            .foregroundStyle(isSelected ? AppTheme.backgroundPrimary : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(isSelected ? AppTheme.accentPrimary : AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isSelected ? Color.clear : AppTheme.stroke,
                                        lineWidth: 0.75
                                    )
                            )
                    }
                }
            }
        }
    }

    // MARK: - Feature Toggles

    private var versusFeatureToggles: some View {
        VStack(spacing: 8) {
            Text("CONFIG")
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 0) {
                featureToggleRow(
                    icon: "eye.fill",
                    label: "RIVAL GHOST",
                    color: AppTheme.sage,
                    isOn: Binding(
                        get: { VersusFeatureFlag.isRivalGhostEnabled },
                        set: { VersusFeatureFlag.setRivalGhostEnabled($0) }
                    )
                )
            }
            .background(AppTheme.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AppTheme.stroke.opacity(0.4), lineWidth: 0.5)
            )
        }
    }

    private func featureToggleRow(icon: String, label: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Grid Size Picker

    private var gridSizePicker: some View {
        VStack(spacing: 8) {
            Text(S.versusBoardSize)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                ForEach([4, 5, 6], id: \.self) { size in
                    let isSelected = size == selectedGridSize
                    Button(action: {
                        SoundManager.play(.tapPrimary)
                        HapticsManager.light()
                        selectedGridSize = size
                    }) {
                        Text("\(size)×\(size)")
                            .font(AppTheme.mono(11, weight: isSelected ? .black : .bold))
                            .kerning(0.6)
                            .foregroundStyle(isSelected ? AppTheme.backgroundPrimary : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(isSelected ? AppTheme.accentPrimary : AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isSelected ? Color.clear : AppTheme.stroke,
                                        lineWidth: 0.75
                                    )
                            )
                    }
                }
            }
        }
    }

    // MARK: - Bot Section

    private var botSection: some View {
        VStack(spacing: 10) {
            Text(S.versusChooseBot)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(AppTheme.textSecondary)

            difficultyPicker

            gridSizePicker

            HStack(spacing: 8) {
                botButton(difficulty: .easy, label: S.versusBotEasy, icon: VersusBotDifficulty.easy.botIcon)
                botButton(difficulty: .medium, label: S.versusBotMedium, icon: VersusBotDifficulty.medium.botIcon)
                botButton(difficulty: .hard, label: S.versusBotHard, icon: VersusBotDifficulty.hard.botIcon)
            }

            Text(S.versusSoloHint)
                .font(AppTheme.mono(7, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func botButton(difficulty: VersusBotDifficulty, label: String, icon: String) -> some View {
        Button(action: {
            SoundManager.play(.tapPrimary)
            HapticsManager.light()
            versusManager.startSoloTest(botDifficulty: difficulty, difficulty: selectedDifficulty, gridSize: selectedGridSize)
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(AppTheme.mono(8, weight: .bold))
                    .kerning(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(AppTheme.sage)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppTheme.sage.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.25), lineWidth: 0.75)
            )
        }
    }

    // MARK: - Searching

    private var versusSearching: some View {
        VStack(spacing: 0) {
            Spacer()

            // Small header
            Text(S.versus)
                .font(AppTheme.mono(16, weight: .black))
                .kerning(3.0)
                .foregroundStyle(AppTheme.accentPrimary.opacity(0.6))

            Spacer().frame(height: 32)

            // Pulsing avatar with scanning ring
            ZStack {
                // Outer pulsing rings
                PulsingRing(color: AppTheme.accentPrimary, delay: 0)
                PulsingRing(color: AppTheme.accentPrimary, delay: 0.8)
                PulsingRing(color: AppTheme.accentPrimary, delay: 1.6)

                // Avatar
                avatarCircle(image: localPlayerAvatar, size: 72)
            }
            .frame(width: 160, height: 160)

            Spacer().frame(height: 8)

            Text(matchState.localPlayerName.uppercased())
                .font(AppTheme.mono(11, weight: .bold))
                .kerning(1.0)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer().frame(height: 28)

            // Scanning indicator
            VStack(spacing: 10) {
                ScanningDots()
                Text(S.searchingForOpponent)
                    .font(AppTheme.mono(11, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(AppTheme.sage)
            }

            Spacer().frame(height: 32)

            // Cancel button
            Button(action: {
                SoundManager.play(.tapPrimary)
                versusManager.cancelSearch()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(S.versusCancel)
                        .font(AppTheme.mono(11, weight: .bold))
                        .kerning(0.8)
                }
                .foregroundStyle(AppTheme.danger)
                .frame(width: 200, height: 40)
                .background(AppTheme.danger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 0.75)
                )
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Countdown (Matched)

    private var versusCountdown: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(S.matchFound)
                .font(AppTheme.mono(12, weight: .bold))
                .kerning(2.0)
                .foregroundStyle(AppTheme.sage)

            Spacer().frame(height: 28)

            // Face-off: local vs opponent
            HStack(spacing: 0) {
                // Local player
                playerAvatar(
                    image: localPlayerAvatar,
                    name: matchState.localPlayerName,
                    accentColor: AppTheme.accentPrimary,
                    size: 64
                )

                // Connection dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(AppTheme.accentPrimary.opacity(0.3))
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.horizontal, 8)

                // VS badge
                Text("VS")
                    .font(AppTheme.mono(24, weight: .black))
                    .kerning(3.0)
                    .foregroundStyle(AppTheme.accentPrimary)
                    .shadow(color: AppTheme.accentPrimary.opacity(0.4), radius: 8, x: 0, y: 0)

                // Connection dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(AppTheme.sage.opacity(0.3))
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.horizontal, 8)

                // Opponent
                playerAvatar(
                    image: matchState.opponentAvatar,
                    name: matchState.opponentDisplayName,
                    accentColor: AppTheme.sage,
                    size: 64
                )
            }

            Spacer().frame(height: 32)

            // Countdown digit overlay or board generation status
            if let digit = countdownDigit {
                Text(digit > 0 ? "\(digit)" : S.versusGo)
                    .font(AppTheme.mono(digit > 0 ? 72 : 42, weight: .black))
                    .kerning(digit > 0 ? 0 : 2.0)
                    .foregroundStyle(digit > 0 ? AppTheme.textPrimary : AppTheme.accentPrimary)
                    .contentTransition(.numericText())
                    .shadow(color: AppTheme.accentPrimary.opacity(0.5), radius: 12, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.3), value: countdownDigit)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(AppTheme.sage)
                    Text(S.secondRace)
                        .font(AppTheme.mono(12, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(AppTheme.accentPrimary)
                    Text(S.generatingBoard)
                        .font(AppTheme.mono(10, weight: .medium))
                        .kerning(1.0)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Cancel button — available during matched + countdown
            Button(action: {
                SoundManager.play(.tapPrimary)
                versusManager.disconnect()
                onDismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(S.versusCancel)
                        .font(AppTheme.mono(11, weight: .bold))
                        .kerning(0.8)
                }
                .foregroundStyle(AppTheme.danger)
                .frame(width: 200, height: 40)
                .background(AppTheme.danger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 0.75)
                )
            }
            .padding(.bottom, 16)
        }
        .padding()
        .onChange(of: matchState.phase) { _, newPhase in
            if newPhase == .countdown {
                startCountdownSequence()
            } else if newPhase != .countdown {
                countdownDigit = nil
            }
            // Timeout: if stuck in .matched for 15s, show error
            if newPhase == .matched {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(15))
                    if matchState.phase == .matched {
                        matchState.error = S.versusConnectionTimeout
                    }
                }
            }
        }
    }

    private func startCountdownSequence() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard matchState.phase == .countdown else { return }
            withAnimation { countdownDigit = 3 }

            try? await Task.sleep(for: .seconds(1.0))
            guard matchState.phase == .countdown else { return }
            withAnimation { countdownDigit = 2 }

            try? await Task.sleep(for: .seconds(1.0))
            guard matchState.phase == .countdown else { return }
            withAnimation { countdownDigit = 1 }

            try? await Task.sleep(for: .milliseconds(700))
            guard matchState.phase == .countdown else { return }
            withAnimation { countdownDigit = 0 } // GO!
        }
    }

    // MARK: - Gameplay

    private var versusGameplay: some View {
        ZStack(alignment: .topLeading) {
            VersusV3GameplayView(vm: versusV3VM, matchState: matchState)

            // Forfeit button (top-left)
            Button(action: {
                versusManager.forfeitAndDisconnect()
                onDismiss()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                    Text(S.versusExit)
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.6)
                }
                .foregroundStyle(AppTheme.danger.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.backgroundPrimary.opacity(0.85))
                .overlay(
                    Capsule().strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 0.75)
                )
                .clipShape(Capsule())
            }
            .padding(.leading, 12)
            .padding(.top, 8)
        }
    }

    // MARK: - Result

    private var versusResult: some View {
        let localWon: Bool? = {
            switch matchState.localResult {
            case .win, .winByDisconnect: return true
            case .lose, .loseByDisconnect: return false
            case .draw, .pending: return nil
            }
        }()

        return VStack(spacing: 0) {
            Spacer()

            // Result title
            resultIcon
                .padding(.bottom, 12)
            resultTitle
                .padding(.bottom, 6)
            resultReason
                .padding(.bottom, 12)

            // Score + streak (winner only)
            if localWon == true && versusV3VM.winScore > 0 {
                VStack(spacing: 4) {
                    Text("+\(versusV3VM.winScore) PTS")
                        .font(AppTheme.mono(22, weight: .black))
                        .kerning(1.5)
                        .foregroundStyle(AppTheme.accentPrimary)
                    if versusV3VM.winStreakMultiplier > 1.0 {
                        Text("\(versusV3VM.currentStreak) STREAK \u{00D7}\(String(format: "%.1f", versusV3VM.winStreakMultiplier))")
                            .font(AppTheme.mono(10, weight: .bold))
                            .kerning(1.0)
                            .foregroundStyle(AppTheme.sage)
                    }
                }
                .padding(.bottom, 20)
            }

            // Face-off card: player LEFT, opponent RIGHT
            HStack(spacing: 0) {
                // Local player — always left
                resultPlayerColumn(
                    avatar: localPlayerAvatar,
                    name: matchState.localPlayerName,
                    won: localWon,
                    moves: versusV3VM.localTapCount,
                    accentColor: localWon == true ? AppTheme.accentPrimary : AppTheme.danger
                )

                // VS separator
                VStack(spacing: 4) {
                    Text("VS")
                        .font(AppTheme.mono(12, weight: .black))
                        .kerning(2.0)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    Rectangle()
                        .fill(AppTheme.stroke)
                        .frame(width: 0.5, height: 24)
                }
                .frame(width: 40)

                // Opponent — always right
                resultPlayerColumn(
                    avatar: matchState.opponentAvatar,
                    name: matchState.opponentDisplayName,
                    won: localWon.map { !$0 },
                    moves: versusV3VM.remoteTapCount,
                    accentColor: localWon == false ? AppTheme.accentPrimary : AppTheme.danger
                )
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(AppTheme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppTheme.stroke, lineWidth: 0.5)
            )
            .padding(.horizontal, 28)

            // Mystery box — every 3 consecutive wins
            if localWon == true && VersusFeatureFlag.isPowerUpsEnabled {
                mysteryBoxSection
                    .padding(.top, 16)
            }

            Spacer()

            // Rematch (same opponent) — only if opponent didn't disconnect
            if matchState.localResult != .winByDisconnect && matchState.localResult != .loseByDisconnect {
                if matchState.localWantsRematch {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.sage)
                        Text(S.waitingForOpponent)
                            .font(AppTheme.mono(10, weight: .bold))
                            .kerning(1.0)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    Button(action: {
                        SoundManager.play(.tapPrimary)
                        HapticsManager.medium()
                        VersusAnalytics.shared.trackRematchRequested()
                        versusV3VM.resetForRematch()
                        mysteryBoxOpened = false
                        mysteryBoxReward = nil
                        showDiscardPicker = false
                        versusManager.sendRematch()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text(S.versusRematch)
                                .font(AppTheme.mono(13, weight: .bold))
                                .kerning(1.0)
                        }
                        .foregroundStyle(AppTheme.backgroundPrimary)
                        .frame(width: 200, height: 46)
                        .background(AppTheme.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                    .breathingCTA()
                }
            }

            closeButton(label: S.backToHome)
        }
        .padding()
    }

    /// A single player column in the result face-off card.
    /// `won`: true = won, false = lost, nil = draw
    private func resultPlayerColumn(
        avatar: UIImage?, name: String, won: Bool?, moves: Int, accentColor: Color
    ) -> some View {
        let borderColor: Color = {
            guard let won else { return AppTheme.sage }
            return won ? AppTheme.accentPrimary : AppTheme.danger
        }()
        let badgeText: String = {
            guard let won else { return S.versusDraw }
            return won ? S.versusWon : S.versusLost
        }()
        let badgeColor: Color = {
            guard let won else { return AppTheme.sage }
            return won ? AppTheme.accentPrimary : AppTheme.danger
        }()

        return VStack(spacing: 8) {
            // Avatar
            avatarCircle(image: avatar, size: 56)
                .overlay(
                    Circle()
                        .strokeBorder(borderColor.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: borderColor.opacity(0.3), radius: 8)

            // Name
            Text(name.uppercased())
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            // Win/Loss badge
            Text(badgeText)
                .font(AppTheme.mono(10, weight: .black))
                .kerning(1.5)
                .foregroundStyle(badgeColor)

            // Moves count
            Text(S.tapsCount(moves))
                .font(AppTheme.mono(8, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mystery Box

    private var shouldShowMysteryBox: Bool {
        let streak = VersusScoring.winStreak
        return streak > 0 && streak % 3 == 0
    }

    @State private var mysteryBoxPulsing = false

    private var mysteryBoxSection: some View {
        let gold = Color(hex: "FFB800")

        return VStack(spacing: 12) {
            if shouldShowMysteryBox && !mysteryBoxOpened {
                Button(action: openMysteryBox) {
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.6), radius: 8)
                            .scaleEffect(mysteryBoxPulsing ? 1.08 : 0.95)

                        Text("MYSTERY BOX")
                            .font(AppTheme.mono(14, weight: .black))
                            .kerning(2.0)
                            .foregroundStyle(gold)

                        Text("TAP TO OPEN · \(VersusScoring.winStreak) WIN STREAK")
                            .font(AppTheme.mono(9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(gold.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(gold.opacity(0.5), lineWidth: 1.2)
                    )
                    .shadow(color: gold.opacity(mysteryBoxPulsing ? 0.25 : 0.08), radius: 12, y: 2)
                }
                .padding(.horizontal, 28)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        mysteryBoxPulsing = true
                    }
                }
            }

            if let reward = mysteryBoxReward, mysteryBoxOpened {
                if showDiscardPicker {
                    discardPickerView(newReward: reward)
                        .padding(.horizontal, 28)
                } else {
                    rewardRevealView(reward)
                        .padding(.horizontal, 28)
                }
            }
        }
    }

    private func openMysteryBox() {
        SoundManager.play(.win)
        HapticsManager.heavy()
        let reward = VersusPowerUpInventory.randomReward()
        mysteryBoxReward = reward
        mysteryBoxOpened = true

        if VersusPowerUpInventory.isFull {
            showDiscardPicker = true
        } else {
            VersusPowerUpInventory.add(reward)
        }
    }

    private func rewardRevealView(_ type: VersusPowerUpType) -> some View {
        let c = Color(hex: type.color)
        return VStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(c)
                .shadow(color: c.opacity(0.5), radius: 6)

            Text(type.label)
                .font(AppTheme.mono(16, weight: .black))
                .kerning(1.5)
                .foregroundStyle(c)

            Text("ADDED TO INVENTORY (\(VersusPowerUpInventory.items.count)/\(VersusPowerUpInventory.maxSlots))")
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(c.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(c.opacity(0.4), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }

    private func discardPickerView(newReward: VersusPowerUpType) -> some View {
        VStack(spacing: 8) {
            Text("INVENTORY FULL — DISCARD ONE")
                .font(AppTheme.mono(9, weight: .black))
                .kerning(1.0)
                .foregroundStyle(AppTheme.danger)

            ForEach(Array(VersusPowerUpInventory.items.enumerated()), id: \.offset) { idx, type in
                Button(action: {
                    VersusPowerUpInventory.remove(at: idx)
                    VersusPowerUpInventory.add(newReward)
                    showDiscardPicker = false
                    HapticsManager.light()
                }) {
                    discardRow(type: type, label: "DISCARD")
                }
            }

            Button(action: {
                showDiscardPicker = false
                HapticsManager.light()
            }) {
                discardRow(type: newReward, label: "DISCARD NEW")
            }
        }
        .padding(12)
        .background(AppTheme.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 0.75)
        )
    }

    private func discardRow(type: VersusPowerUpType, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: type.color))
            Text(type.label)
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(label)
                .font(AppTheme.mono(8, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(AppTheme.danger)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.danger.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Shared Subviews

    private var versusHeader: some View {
        VStack(spacing: 8) {
            Text(S.versus)
                .font(AppTheme.mono(28, weight: .black))
                .kerning(4.0)
                .foregroundStyle(AppTheme.accentPrimary)
            Text(S.versusSubtitle)
                .font(AppTheme.mono(11, weight: .medium))
                .kerning(2.0)
                .foregroundStyle(AppTheme.sage)
        }
    }

    private func playerAvatar(image: UIImage?, name: String, accentColor: Color, size: CGFloat) -> some View {
        VStack(spacing: 8) {
            avatarCircle(image: image, size: size)
                .overlay(
                    Circle()
                        .strokeBorder(accentColor.opacity(0.6), lineWidth: 1.5)
                )

            Text(name.uppercased())
                .font(AppTheme.mono(10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func avatarCircle(image: UIImage?, size: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.backgroundSecondary)
        .clipShape(Circle())
    }

    private var gcStatusLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(GKLocalPlayer.local.isAuthenticated ? AppTheme.success : AppTheme.danger)
                .frame(width: 6, height: 6)
            Text(GKLocalPlayer.local.isAuthenticated ? S.gameCenterConnected : S.gameCenterRequired)
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var resultIcon: some View {
        Group {
            switch matchState.localResult {
            case .win, .winByDisconnect:
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accentPrimary)
            case .lose, .loseByDisconnect:
                Image(systemName: "xmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.danger)
            case .draw:
                Image(systemName: "equal.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.sage)
            case .pending:
                ProgressView().tint(AppTheme.sage)
            }
        }
    }

    private var resultTitle: some View {
        Text({
            switch matchState.localResult {
            case .win:              return S.victory
            case .winByDisconnect:  return S.opponentDisconnected
            case .lose:             return S.defeat
            case .loseByDisconnect: return S.connectionLost
            case .draw:             return S.versusDraw
            case .pending:          return S.resolving
            }
        }())
        .font(AppTheme.mono(22, weight: .black))
        .kerning(2.0)
        .foregroundStyle({
            switch matchState.localResult {
            case .win, .winByDisconnect: return AppTheme.accentPrimary
            case .draw:                  return AppTheme.sage
            default:                     return AppTheme.danger
            }
        }())
    }

    private var resultSubtitle: some View {
        HStack(spacing: 8) {
            if let avatar = matchState.opponentAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            }
            Text(S.vsLabel(matchState.opponentDisplayName))
                .font(AppTheme.mono(12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var resultReason: some View {
        Text({
            switch matchState.localResult {
            case .win:              return S.reasonConnectedFirst
            case .lose:             return S.reasonRivalConnected
            case .draw:             return S.reasonEvenProgress
            case .winByDisconnect:  return S.reasonRivalLeft
            case .loseByDisconnect: return S.reasonYouLeft
            case .pending:          return ""
            }
        }())
        .font(AppTheme.mono(10, weight: .medium))
        .kerning(0.8)
        .foregroundStyle(AppTheme.textSecondary)
    }

    private func closeButton(label: String? = nil) -> some View {
        Button(action: {
            SoundManager.play(.tapPrimary)
            versusManager.disconnect()
            onDismiss()
        }) {
            Text(label ?? S.versusExit)
                .font(AppTheme.mono(11, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 200, height: 40)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.textSecondary.opacity(0.2), lineWidth: 0.75)
                )
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Pulsing Ring Animation

private struct PulsingRing: View {
    let color: Color
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .strokeBorder(color.opacity(animate ? 0 : 0.4), lineWidth: 1.5)
            .scaleEffect(animate ? 2.2 : 0.8)
            .opacity(animate ? 0 : 0.8)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.4)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - Scanning Dots Animation

private struct ScanningDots: View {
    @State private var activeIndex = 0
    private let dotCount = 3
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { i in
                Circle()
                    .fill(i == activeIndex ? AppTheme.accentPrimary : AppTheme.textSecondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(i == activeIndex ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: activeIndex)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % dotCount
        }
    }
}
