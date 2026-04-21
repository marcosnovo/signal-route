import Combine
import Foundation
import GameKit

// MARK: - VersusMatchmakingManager
/// Manages Game Center real-time matchmaking and data exchange for 1v1 Versus mode.
///
/// ## Lifecycle
///   1. `findMatch()` — presents GKMatchmakerViewController or starts auto-match
///   2. On match found → elect host (lowest gamePlayerID), host sends `.ready` with seed
///   3. Both players generate identical boards from the shared seed
///   4. Taps and state snapshots flow via `.action` / `.state` messages
///   5. On win/loss → `.result` sent, match transitions to `.finished`
///
/// ## Threading
///   All public API and published state live on `@MainActor`.
@MainActor
final class VersusMatchmakingManager: NSObject, ObservableObject {

    static let shared = VersusMatchmakingManager()

    // ── State ────────────────────────────────────────────────────────────
    let matchState = VersusMatchState()

    // ── GK objects ───────────────────────────────────────────────────────
    private var currentMatch: GKMatch?
    private var matchmakerVC: GKMatchmakerViewController?

    /// Callback fired when the shared level is ready (seed received/sent).
    /// VersusViewModel listens to this to start the game.
    var onLevelReady: ((UInt64, VersusLevelConfig) -> Void)?

    /// Callback fired when a remote action arrives.
    var onRemoteAction: ((VersusAction) -> Void)?

    /// Callback fired when a remote state snapshot arrives.
    var onRemoteState: ((VersusPlayerSnapshot) -> Void)?

    /// Callback fired when the remote player reports their outcome.
    var onRemoteResult: ((VersusOutcome) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Start searching for an opponent. Requires GC authentication.
    func findMatch() {
        guard GKLocalPlayer.local.isAuthenticated else {
            #if DEBUG
            print("[Versus] Cannot match — Game Center not authenticated")
            #endif
            return
        }
        guard matchState.phase == .idle else { return }

        matchState.reset()
        matchState.phase = .searching

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

        // Present the standard matchmaker UI
        guard let vc = GKMatchmakerViewController(matchRequest: request) else {
            matchState.phase = .idle
            return
        }
        vc.matchmakerDelegate = self
        matchmakerVC = vc
        presentViewController(vc)
    }

    /// Cancel an in-progress search.
    func cancelSearch() {
        matchmakerVC?.dismiss(animated: true)
        matchmakerVC = nil
        GKMatchmaker.shared().cancel()
        matchState.phase = .idle
        #if DEBUG
        print("[Versus] Search cancelled")
        #endif
    }

    /// Send the local player's tap action to the opponent.
    func sendAction(_ action: VersusAction) {
        send(.action(payload: action))
    }

    /// Send the local player's current board snapshot.
    func sendState(_ snapshot: VersusPlayerSnapshot) {
        matchState.localSnapshot = snapshot
        send(.state(payload: snapshot))
    }

    /// Send the local player's game outcome.
    func sendResult(_ outcome: VersusOutcome) {
        matchState.localOutcome = outcome
        send(.result(payload: outcome))
        checkMatchResolution()
    }

    /// Tear down the current match and reset state.
    func disconnect() {
        currentMatch?.disconnect()
        currentMatch = nil
        matchmakerVC?.dismiss(animated: true)
        matchmakerVC = nil
        matchState.reset()
    }

    // MARK: - Private — Host election & seed exchange

    private func handleMatchReady(_ match: GKMatch) {
        currentMatch = match
        match.delegate = self
        matchmakerVC?.dismiss(animated: true)
        matchmakerVC = nil
        matchState.phase = .matched

        // Resolve opponent display name
        if let opponent = match.players.first {
            matchState.opponentDisplayName = opponent.displayName
        }

        // Host election: lexicographically lower gamePlayerID is host
        let localID = GKLocalPlayer.local.gamePlayerID
        let isHost: Bool
        if let opponent = match.players.first {
            isHost = localID < opponent.gamePlayerID
        } else {
            isHost = true  // fallback: if no opponent info yet, assume host
        }
        matchState.isHost = isHost

        #if DEBUG
        print("[Versus] Match ready — isHost=\(isHost)  opponent=\(matchState.opponentDisplayName)")
        #endif

        if isHost {
            // Generate seed and send .ready to guest
            let seed = UInt64.random(in: 1...UInt64.max)
            let config = VersusLevelConfig.defaultV1
            matchState.sharedSeed   = seed
            matchState.sharedConfig = config
            send(.ready(payload: VersusReadyPayload(seed: seed, config: config)))
            beginCountdown()
        }
        // Guest waits for .ready message
    }

    private func beginCountdown() {
        matchState.phase = .countdown
        // Short delay before gameplay starts — gives both sides time to build the board
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard matchState.phase == .countdown else { return }
            matchState.phase = .playing
            onLevelReady?(matchState.sharedSeed, matchState.sharedConfig ?? .defaultV1)
        }
    }

    private func checkMatchResolution() {
        if matchState.isResolved {
            matchState.phase = .finished
        }
    }

    // MARK: - Private — Send

    private func send(_ message: VersusMessage) {
        guard let match = currentMatch, let data = message.encoded() else { return }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            #if DEBUG
            print("[Versus] Send failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Private — Present VC

    private func presentViewController(_ vc: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              var presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        // Walk to topmost presented VC
        while let next = presenter.presentedViewController, !next.isBeingDismissed {
            presenter = next
        }
        presenter.present(vc, animated: true)
    }
}

// MARK: - GKMatchmakerViewControllerDelegate

extension VersusMatchmakingManager: GKMatchmakerViewControllerDelegate {

    nonisolated func matchmakerViewControllerWasCancelled(
        _ viewController: GKMatchmakerViewController
    ) {
        Task { @MainActor in
            matchmakerVC = nil
            matchState.phase = .idle
            #if DEBUG
            print("[Versus] Matchmaker cancelled by user")
            #endif
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            matchmakerVC = nil
            matchState.phase = .idle
            #if DEBUG
            print("[Versus] Matchmaker error: \(error.localizedDescription)")
            #endif
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController,
        didFind match: GKMatch
    ) {
        Task { @MainActor in
            handleMatchReady(match)
        }
    }
}

// MARK: - GKMatchDelegate

extension VersusMatchmakingManager: GKMatchDelegate {

    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        Task { @MainActor in
            guard let message = VersusMessage.decode(from: data) else { return }
            handleReceivedMessage(message)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .disconnected:
                #if DEBUG
                print("[Versus] Opponent disconnected: \(player.displayName)")
                #endif
                matchState.remoteOutcome = .disconnected
                checkMatchResolution()
                if matchState.phase == .playing || matchState.phase == .countdown {
                    matchState.phase = .finished
                }
            case .connected:
                #if DEBUG
                print("[Versus] Player connected: \(player.displayName)")
                #endif
            default:
                break
            }
        }
    }

    // MARK: - Message handling

    private func handleReceivedMessage(_ message: VersusMessage) {
        switch message {
        case .ready(let payload):
            // Guest receives seed from host
            guard !matchState.isHost else { return }  // host ignores .ready
            matchState.sharedSeed   = payload.seed
            matchState.sharedConfig = payload.config
            #if DEBUG
            print("[Versus] Received seed=\(payload.seed) from host")
            #endif
            beginCountdown()

        case .action(let action):
            onRemoteAction?(action)

        case .state(let snapshot):
            matchState.remoteSnapshot = snapshot
            onRemoteState?(snapshot)

        case .result(let outcome):
            matchState.remoteOutcome = outcome
            onRemoteResult?(outcome)
            checkMatchResolution()
        }
    }
}

// MARK: - Default V1 Config

extension VersusLevelConfig {
    /// V1 default: 5×5, medium difficulty, 15 moves, 2 targets, normal objective, branching paths.
    static let defaultV1 = VersusLevelConfig(
        gridSize:      5,
        difficultyRaw: DifficultyTier.medium.rawValue,
        maxMoves:      15,
        numTargets:    2,
        objectiveType: LevelObjectiveType.normal.rawValue,
        levelType:     LevelType.branching.rawValue
    )
}
