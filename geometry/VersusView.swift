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

    @State private var countdownDigit: Int? = nil

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
                versusResult
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
        VStack(spacing: 0) {
            Spacer()

            versusHeader

            Spacer().frame(height: 36)

            // Local player avatar
            playerAvatar(
                image: matchState.localPlayerAvatar,
                name: matchState.localPlayerName,
                accentColor: AppTheme.accentPrimary,
                size: 80
            )

            Spacer().frame(height: 36)

            // Find Match button
            Button(action: {
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
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(AppTheme.accentPrimary)
                .clipShape(Capsule())
            }
            .disabled(!GKLocalPlayer.local.isAuthenticated)
            .opacity(GKLocalPlayer.local.isAuthenticated ? 1 : 0.4)

            Spacer().frame(height: 16)

            gcStatusLabel

            Spacer()

            closeButton()
        }
        .padding()
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
                avatarCircle(image: matchState.localPlayerAvatar, size: 72)
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
            Button(action: { versusManager.cancelSearch() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(S.versusCancel)
                        .font(AppTheme.mono(11, weight: .bold))
                        .kerning(0.8)
                }
                .foregroundStyle(AppTheme.danger)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .overlay(
                    Capsule().strokeBorder(AppTheme.danger.opacity(0.5), lineWidth: 0.75)
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
                    image: matchState.localPlayerAvatar,
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
        }
        .padding()
        .onChange(of: matchState.phase) { _, newPhase in
            if newPhase == .countdown {
                startCountdownSequence()
            } else if newPhase != .countdown {
                countdownDigit = nil
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
        VersusV3GameplayView(vm: versusV3VM, matchState: matchState)
    }

    // MARK: - Result

    private var versusResult: some View {
        VStack(spacing: 24) {
            Spacer()

            resultIcon
            resultTitle
            resultSubtitle
            resultReason

            Spacer()

            // Rematch (same opponent) — only if opponent didn't disconnect
            if matchState.localResult != .winByDisconnect && matchState.localResult != .loseByDisconnect {
                if matchState.localWantsRematch {
                    // Waiting for opponent
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
                        VersusAnalytics.shared.trackRematchRequested()
                        versusV3VM.resetForRematch()
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
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(AppTheme.accentPrimary)
                        .clipShape(Capsule())
                    }
                    .breathingCTA()
                }
            }

            closeButton(label: S.backToHome)
        }
        .padding()
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
        .font(AppTheme.mono(9, weight: .medium))
        .kerning(0.8)
        .foregroundStyle(AppTheme.textSecondary)
    }

    private func closeButton(label: String? = nil) -> some View {
        Button(action: {
            versusManager.disconnect()
            onDismiss()
        }) {
            Text(label ?? S.versusExit)
                .font(AppTheme.mono(11, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .overlay(
                    Capsule().strokeBorder(AppTheme.textSecondary.opacity(0.3), lineWidth: 0.75)
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
