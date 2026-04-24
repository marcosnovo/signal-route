import Combine
import Foundation
import GameKit

// MARK: - VersusMatchmakingManager
/// Manages Game Center real-time matchmaking and data exchange for 1v1 Versus mode.
///
/// ## Lifecycle
///   1. `findMatch()` — programmatic auto-match via `GKMatchmaker.findMatch(for:)`
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
    private var searchTask: Task<Void, Never>?

    /// Callback fired when the shared level is ready (seed exchanged).
    /// VM builds the board in response, then calls `sendBoardReady()`.
    var onLevelReady: ((UInt64, VersusLevelConfig) -> Void)?

    /// Callback fired when both boards are ready and gameplay begins.
    /// VM starts the 30s timer in response.
    var onGameStart: (() -> Void)?

    /// Callback fired when a remote action arrives.
    var onRemoteAction: ((VersusAction) -> Void)?

    /// Callback fired when a remote state snapshot arrives.
    var onRemoteState: ((VersusPlayerSnapshot) -> Void)?

    /// Callback fired when the remote player reports their outcome.
    var onRemoteResult: ((VersusOutcome) -> Void)?

    /// Callback fired when the remote player's board-ready signal arrives.
    var onRemoteBoardReady: (() -> Void)?

    /// Callback fired when the remote player requests a rematch.
    var onRemoteRematch: (() -> Void)?

    private override init() {
        super.init()
        loadLocalPlayerInfo()
    }

    // MARK: - Public API

    /// Refresh local player info (call after GC auth changes).
    func loadLocalPlayerInfo() {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { return }
        matchState.localPlayerName = player.displayName
        Task {
            if let image = try? await player.loadPhoto(for: .small) {
                matchState.localPlayerAvatar = image
            }
        }
    }

    /// Start searching for an opponent via programmatic auto-match.
    /// Uses `GKMatchmaker.findMatch(for:)` — no Game Center UI presented.
    func findMatch() {
        guard VersusFeatureFlag.isMatchmakingAllowed else {
            #if DEBUG
            print("[VersusFlag] matchmaking blocked — isMatchmakingAllowed=false")
            #endif
            return
        }
        guard GKLocalPlayer.local.isAuthenticated else {
            matchState.error = "Game Center not authenticated"
            #if DEBUG
            print("[Versus] Cannot match — Game Center not authenticated")
            #endif
            return
        }
        guard matchState.phase == .idle else { return }

        matchState.reset()
        matchState.phase = .searching
        VersusAnalytics.shared.trackMatchmakingStarted()
        VersusTestHarness.shared.startSession()
        VersusTestHarness.shared.logSearchStarted()
        #if DEBUG
        print("[Versus] matchmaking started — searching for opponent")
        #endif

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

        searchTask = Task {
            do {
                let match = try await GKMatchmaker.shared().findMatch(for: request)
                guard !Task.isCancelled else { return }
                GKMatchmaker.shared().finishMatchmaking(for: match)
                handleMatchReady(match)
            } catch {
                guard !Task.isCancelled else { return }
                matchState.phase = .idle
                matchState.error = error.localizedDescription
                #if DEBUG
                print("[Versus] Matchmaking error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Cancel an in-progress search.
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        GKMatchmaker.shared().cancel()
        VersusAnalytics.shared.trackMatchmakingCancelled()
        VersusTestHarness.shared.logSearchCancelled()
        matchState.phase = .idle
        matchState.error = nil
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

    /// Signal that the local board has been generated and is ready for play.
    func sendBoardReady() {
        matchState.localBoardReady = true
        send(.boardReady)
        VersusTestHarness.shared.logLocalBoardReady()
        #if DEBUG
        print("[Versus] Sent boardReady (remote=\(matchState.remoteBoardReady))")
        #endif
        if matchState.bothBoardReady { handleBothBoardReady() }
    }

    /// Request a same-opponent rematch after a game ends.
    func sendRematch() {
        matchState.localWantsRematch = true
        send(.rematch)
        #if DEBUG
        print("[Versus] Sent rematch request (remote=\(matchState.remoteWantsRematch))")
        #endif
        if matchState.bothWantRematch { handleBothWantRematch() }
    }

    /// Tear down the current match and reset state.
    func disconnect() {
        searchTask?.cancel()
        searchTask = nil
        currentMatch?.disconnect()
        currentMatch = nil
        matchState.reset()
    }

    // MARK: - Private — Host election & seed exchange

    private func handleMatchReady(_ match: GKMatch) {
        currentMatch = match
        match.delegate = self
        matchState.phase = .matched
        #if DEBUG
        print("[Versus] match found — \(match.players.count) player(s)")
        #endif
        VersusAnalytics.shared.trackMatchFound(
            seed: 0,  // seed not yet exchanged
            isHost: false,  // not yet elected
            opponent: match.players.first?.displayName ?? "unknown"
        )
        VersusTestHarness.shared.logMatchFound(
            opponent: match.players.first?.displayName ?? "unknown",
            isHost: false  // updated below after election
        )

        // Resolve opponent display name and avatar
        if let opponent = match.players.first {
            matchState.opponentDisplayName = opponent.displayName
            Task {
                if let image = try? await opponent.loadPhoto(for: .small) {
                    matchState.opponentAvatar = image
                }
            }
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
            let config = VersusLevelConfig.defaultV3
            matchState.sharedSeed   = seed
            matchState.sharedConfig = config
            send(.ready(payload: VersusReadyPayload(seed: seed, config: config)))
            VersusTestHarness.shared.logSeedSent(seed)
            // Host builds board immediately — VM will call sendBoardReady() when done
            onLevelReady?(seed, config)
        }
        // Guest waits for .ready message → onLevelReady fires there
    }

    // MARK: - Private — Board-ready sync

    /// Called when both sides have confirmed board generation.
    /// Starts the countdown, then transitions to .playing and fires onGameStart.
    private func handleBothBoardReady() {
        guard matchState.phase == .matched else { return }
        matchState.phase = .countdown
        VersusTestHarness.shared.logCountdownStarted()
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard matchState.phase == .countdown else { return }
            matchState.phase = .playing
            VersusTestHarness.shared.logGameStarted()
            onGameStart?()
        }
    }

    // MARK: - Private — Rematch

    /// Called when both sides agree to rematch. Resets game state and starts a new round.
    private func handleBothWantRematch() {
        VersusAnalytics.shared.trackRematchAccepted()
        VersusTestHarness.shared.logRematchAccepted()
        #if DEBUG
        print("[Versus] Both want rematch — starting new round")
        #endif
        // Reset game state but keep match + player info alive
        matchState.localSnapshot      = .idle
        matchState.remoteSnapshot     = .idle
        matchState.localOutcome       = nil
        matchState.remoteOutcome      = nil
        matchState.localBoardReady    = false
        matchState.remoteBoardReady   = false
        matchState.localWantsRematch  = false
        matchState.remoteWantsRematch = false
        matchState.phase              = .matched

        if matchState.isHost {
            // Host generates a new seed
            let seed = UInt64.random(in: 1...UInt64.max)
            let config = matchState.sharedConfig ?? .defaultV3
            matchState.sharedSeed = seed
            send(.ready(payload: VersusReadyPayload(seed: seed, config: config)))
            VersusTestHarness.shared.logSeedSent(seed)
            onLevelReady?(seed, config)
        }
        // Guest waits for .ready → builds board → sendBoardReady
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
                VersusAnalytics.shared.trackMatchDisconnected(
                    phase: "\(matchState.phase)",
                    seed: matchState.sharedSeed
                )
                VersusTestHarness.shared.logDisconnect(phase: "\(matchState.phase)")
                onRemoteResult?(.disconnected)  // Notify VM so it can freeze + award forfeit
                checkMatchResolution()
                // Handle disconnect in ALL active phases
                if matchState.phase == .matched || matchState.phase == .countdown || matchState.phase == .playing {
                    matchState.phase = .finished
                }
            case .connected:
                #if DEBUG
                print("[Versus] Player connected: \(player.displayName)")
                #endif
                matchState.opponentDisplayName = player.displayName
                Task {
                    if let image = try? await player.loadPhoto(for: .small) {
                        matchState.opponentAvatar = image
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - Message handling

    private func handleReceivedMessage(_ message: VersusMessage) {
        switch message {
        case .ready(let payload):
            // Guest receives seed from host (also fires on rematch round)
            guard !matchState.isHost else { return }  // host ignores .ready
            matchState.sharedSeed   = payload.seed
            matchState.sharedConfig = payload.config
            VersusTestHarness.shared.logSeedReceived(payload.seed)
            #if DEBUG
            print("[Versus] Received seed=\(payload.seed) from host")
            #endif
            // Guest builds board — VM calls sendBoardReady() when done
            onLevelReady?(payload.seed, payload.config)

        case .boardReady:
            matchState.remoteBoardReady = true
            VersusTestHarness.shared.logRemoteBoardReady()
            onRemoteBoardReady?()
            #if DEBUG
            print("[Versus] Remote board ready (local=\(matchState.localBoardReady))")
            #endif
            if matchState.bothBoardReady { handleBothBoardReady() }

        case .action(let action):
            onRemoteAction?(action)

        case .state(let snapshot):
            matchState.remoteSnapshot = snapshot
            onRemoteState?(snapshot)

        case .result(let outcome):
            matchState.remoteOutcome = outcome
            onRemoteResult?(outcome)
            checkMatchResolution()

        case .rematch:
            matchState.remoteWantsRematch = true
            onRemoteRematch?()
            #if DEBUG
            print("[Versus] Remote wants rematch (local=\(matchState.localWantsRematch))")
            #endif
            if matchState.bothWantRematch { handleBothWantRematch() }
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

    /// V3 default: 5×9 split-board, medium difficulty, no move limit, 5 center beacons.
    static let defaultV3 = VersusLevelConfig(
        gridSize:      5,
        difficultyRaw: DifficultyTier.medium.rawValue,
        maxMoves:      999,
        numTargets:    5,
        objectiveType: LevelObjectiveType.normal.rawValue,
        levelType:     LevelType.singlePath.rawValue,
        isV3:          true
    )
}
