import Foundation

// MARK: - VersusMessage
/// Codable envelope for all data exchanged over a GKMatch connection.
///
/// Messages are JSON-encoded and sent via `GKMatch.sendData(toAllPlayers:with:)`.
/// Every message carries a `sequenceNumber` for ordering / duplicate detection.
enum VersusMessage: Codable {
    /// Host → Guest: shared seed + level configuration.
    case ready(payload: VersusReadyPayload)
    /// Either → Either: a tile tap the local player just performed.
    case action(payload: VersusAction)
    /// Either → Either: periodic snapshot of the sender's board state.
    case state(payload: VersusPlayerSnapshot)
    /// Either → Either: the sender's game just ended.
    case result(payload: VersusOutcome)
}

// MARK: - Ready Payload

/// Sent by the host once the match is established.
/// The guest uses `seed` + `config` to generate the identical board locally.
struct VersusReadyPayload: Codable {
    let seed:   UInt64
    let config: VersusLevelConfig
}

/// Level parameters exchanged at match start.
/// Uses raw primitive types so we don't need Codable conformance on game enums.
struct VersusLevelConfig: Codable {
    let gridSize:       Int      // 4, 5, or 6
    let difficultyRaw:  Int      // DifficultyTier.rawValue (1–4)
    let maxMoves:       Int
    let numTargets:     Int
    let objectiveType:  String   // LevelObjectiveType.rawValue ("normal", etc.)
    let levelType:      String   // LevelType.rawValue ("LINEAR", etc.)
}

// MARK: - Action

/// A single tile tap. Sent immediately after the local player taps.
struct VersusAction: Codable {
    let row:        Int
    let col:        Int
    let moveNumber: Int       // 1-based move counter (for ordering)
    let timestamp:  TimeInterval  // `Date().timeIntervalSince1970`
}

// MARK: - Player Snapshot

/// Periodic snapshot of a player's board state.
/// Sent after every tap so the opponent's HUD stays up-to-date.
struct VersusPlayerSnapshot: Codable {
    let movesUsed:     Int
    let movesLeft:     Int
    let targetsOnline: Int
    let totalTargets:  Int
    let activeNodes:   Int
    let status:        String   // "playing", "won", "lost"
}

extension VersusPlayerSnapshot {
    static let idle = VersusPlayerSnapshot(
        movesUsed: 0, movesLeft: 0, targetsOnline: 0,
        totalTargets: 0, activeNodes: 0, status: "playing"
    )
}

// MARK: - Outcome

/// Sent when the local player's game ends.
enum VersusOutcome: String, Codable {
    case won
    case lost
    case disconnected
}

// MARK: - Encoding Helpers

extension VersusMessage {
    /// Encode to JSON Data for GKMatch transmission.
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decode from GKMatch received data.
    static func decode(from data: Data) -> VersusMessage? {
        try? JSONDecoder().decode(VersusMessage.self, from: data)
    }
}
