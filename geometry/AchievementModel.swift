import Foundation

// MARK: - Achievement Model

enum AchievementTier: Int, CaseIterable, Comparable {
    case bronze = 1, silver, gold, platinum

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .bronze:   "BRONZE"
        case .silver:   "SILVER"
        case .gold:     "GOLD"
        case .platinum: "PLATINUM"
        }
    }

    var icon: String {
        switch self {
        case .bronze:   "bolt.fill"
        case .silver:   "target"
        case .gold:     "flame.fill"
        case .platinum: "crown.fill"
        }
    }
}

enum AchievementMetric {
    case levelsCompleted
    case perfectScores
    case totalScore
    case easyLevelsCleared
    case mediumLevelsCleared
    case hardLevelsCleared
    case expertLevelsCleared
    case branchingLevelsCleared
    case denseLevelsCleared
    case multiNodeLevelsCleared
    case firstAttemptClears
    case streakWins
    case astronautLevel
}

struct AchievementAccent {
    let hex: String
    static let sourceOrange = AchievementAccent(hex: "FF6A3D")
    static let sage         = AchievementAccent(hex: "C7D7C6")
    static let cyan         = AchievementAccent(hex: "5AC8D8")
    static let violet       = AchievementAccent(hex: "A78BFA")
    static let amber        = AchievementAccent(hex: "FFB800")
    static let rose         = AchievementAccent(hex: "F472B6")
    static let gold         = AchievementAccent(hex: "FFD700")
    static let crimson      = AchievementAccent(hex: "EF4444")
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let gcIdentifier: String
    let titleEN: String
    let titleES: String
    let titleFR: String
    let subtitleEN: String
    let subtitleES: String
    let subtitleFR: String
    let tier: AchievementTier
    let target: Int
    let metric: AchievementMetric
    let accent: AchievementAccent
    let icon: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Achievement State

enum AchievementState: Codable, Equatable {
    case locked
    case inProgress(current: Int)
    case unlocked(date: Date)

    var isUnlocked: Bool {
        if case .unlocked = self { return true }
        return false
    }

    var currentValue: Int {
        switch self {
        case .locked: 0
        case .inProgress(let v): v
        case .unlocked: -1
        }
    }

    var unlockDate: Date? {
        if case .unlocked(let d) = self { return d }
        return nil
    }
}

// MARK: - Game Event

enum GameEvent {
    case levelCleared(levelId: Int, difficulty: DifficultyTier, efficiency: Float, movesRemaining: Int, attemptCount: Int)
    case sessionOpened
}

// MARK: - Achievement Progress (persistence)

struct AchievementProgress: Codable {
    var states: [String: AchievementState] = [:]
    var firstAttemptClears: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        states = try container.decodeIfPresent([String: AchievementState].self, forKey: .states) ?? [:]
        firstAttemptClears = try container.decodeIfPresent(Int.self, forKey: .firstAttemptClears) ?? 0
    }
}
