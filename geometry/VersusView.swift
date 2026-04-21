import SwiftUI
import GameKit

// MARK: - VersusView
/// Full-screen versus mode container. Transitions through lobby → game → result.
///
/// Hidden behind `VersusFeatureFlag.isEnabled`. Presented as a `fullScreenCover`
/// from ContentView. Does NOT interact with campaign stores.
struct VersusView: View {

    @EnvironmentObject private var versusManager: VersusMatchmakingManager
    @EnvironmentObject private var settings: SettingsStore

    let onDismiss: () -> Void

    @StateObject private var versusVM: VersusViewModel

    init(matchManager: VersusMatchmakingManager, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _versusVM = StateObject(wrappedValue: VersusViewModel(matchManager: matchManager))
    }

    private var matchState: VersusMatchState { versusManager.matchState }

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
        }
        .onDisappear {
            versusVM.tearDown()
        }
    }

    // MARK: - Lobby (Idle)

    private var versusLobby: some View {
        VStack(spacing: 24) {
            Spacer()

            versusHeader

            // Find Match button
            Button(action: { versusManager.findMatch() }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("FIND MATCH")
                        .font(AppTheme.mono(14, weight: .bold))
                        .kerning(1.2)
                }
                .foregroundStyle(AppTheme.backgroundPrimary)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(AppTheme.accentPrimary)
                .clipShape(Capsule())
            }

            // GC status
            gcStatusLabel

            Spacer()

            closeButton
        }
        .padding()
    }

    // MARK: - Searching

    private var versusSearching: some View {
        VStack(spacing: 24) {
            Spacer()

            versusHeader

            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.accentPrimary)
                Text("SEARCHING FOR OPPONENT...")
                    .font(AppTheme.mono(12, weight: .bold))
                    .kerning(1.0)
                    .foregroundStyle(AppTheme.sage)
            }

            Button(action: { versusManager.cancelSearch() }) {
                Text("CANCEL")
                    .font(AppTheme.mono(11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(AppTheme.danger)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(AppTheme.danger.opacity(0.5), lineWidth: 0.75)
                    )
            }

            Spacer()

            closeButton
        }
        .padding()
    }

    // MARK: - Countdown

    private var versusCountdown: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("MATCHED!")
                .font(AppTheme.mono(18, weight: .black))
                .kerning(2.0)
                .foregroundStyle(AppTheme.accentPrimary)

            Text("vs \(matchState.opponentDisplayName)")
                .font(AppTheme.mono(13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("GENERATING BOARD...")
                .font(AppTheme.mono(11, weight: .medium))
                .kerning(0.8)
                .foregroundStyle(AppTheme.sage)

            ProgressView()
                .tint(AppTheme.sage)

            Spacer()
        }
        .padding()
    }

    // MARK: - Gameplay

    private var versusGameplay: some View {
        VStack(spacing: 0) {
            // Opponent HUD
            opponentHUD
                .padding(.horizontal, 16)
                .padding(.top, 8)

            TechDivider()

            // Local game board
            if let level = versusVM.level {
                GameView(
                    level: level,
                    onDismiss: {
                        versusManager.sendResult(.lost)
                        versusManager.disconnect()
                        onDismiss()
                    }
                )
                .id(level.seed) // Force recreation on level change
            } else {
                Spacer()
                Text("WAITING FOR BOARD...")
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Result

    private var versusResult: some View {
        VStack(spacing: 24) {
            Spacer()

            resultIcon
            resultTitle
            resultSubtitle

            Spacer()

            // Play Again
            Button(action: {
                versusManager.disconnect()
                versusManager.findMatch()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("PLAY AGAIN")
                        .font(AppTheme.mono(13, weight: .bold))
                        .kerning(1.0)
                }
                .foregroundStyle(AppTheme.backgroundPrimary)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(AppTheme.accentPrimary)
                .clipShape(Capsule())
            }

            closeButton
        }
        .padding()
    }

    // MARK: - Subviews

    private var versusHeader: some View {
        VStack(spacing: 8) {
            Text("VERSUS")
                .font(AppTheme.mono(28, weight: .black))
                .kerning(4.0)
                .foregroundStyle(AppTheme.accentPrimary)
            Text("1 v 1  REAL-TIME")
                .font(AppTheme.mono(11, weight: .medium))
                .kerning(2.0)
                .foregroundStyle(AppTheme.sage)
        }
    }

    private var gcStatusLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(GKLocalPlayer.local.isAuthenticated ? AppTheme.success : AppTheme.danger)
                .frame(width: 6, height: 6)
            Text(GKLocalPlayer.local.isAuthenticated ? "GAME CENTER CONNECTED" : "GAME CENTER REQUIRED")
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var opponentHUD: some View {
        let snap = matchState.remoteSnapshot
        return HStack(spacing: 12) {
            TechLabel(text: "OPPONENT", color: AppTheme.accentPrimary)
            Spacer()
            miniStat("MOVES", "\(snap.movesUsed)")
            miniStat("TARGETS", "\(snap.targetsOnline)/\(snap.totalTargets)")
            miniStat("STATUS", snap.status.uppercased())
        }
        .padding(.vertical, 8)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(AppTheme.mono(7, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
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
            case .pending:
                ProgressView().tint(AppTheme.sage)
            }
        }
    }

    private var resultTitle: some View {
        Text({
            switch matchState.localResult {
            case .win:              return "VICTORY"
            case .winByDisconnect:  return "OPPONENT DISCONNECTED"
            case .lose:             return "DEFEAT"
            case .loseByDisconnect: return "CONNECTION LOST"
            case .pending:          return "RESOLVING..."
            }
        }())
        .font(AppTheme.mono(22, weight: .black))
        .kerning(2.0)
        .foregroundStyle(matchState.localResult == .win || matchState.localResult == .winByDisconnect
                         ? AppTheme.accentPrimary : AppTheme.danger)
    }

    private var resultSubtitle: some View {
        Text("vs \(matchState.opponentDisplayName)")
            .font(AppTheme.mono(12, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private var closeButton: some View {
        Button(action: {
            versusManager.disconnect()
            onDismiss()
        }) {
            Text("EXIT")
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
