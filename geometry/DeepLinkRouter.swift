import Foundation

// MARK: - DeepLinkRoute
/// Routes parsed from signalvoid:// URLs opened by widget taps.
enum DeepLinkRoute: Equatable {
    case home
    case missions
    case leaderboards
    case pass(planetIndex: Int)
    case dailyChallenge

    /// Parse a URL into a route. Returns nil for unrecognised URLs.
    static func from(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme == "signalvoid" else { return nil }
        let host = url.host() ?? ""
        switch host {
        case "home":         return .home
        case "missions":     return .missions
        case "leaderboards": return .leaderboards
        case "pass":
            if let idx = Int(url.pathComponents.last ?? "") {
                return .pass(planetIndex: idx)
            }
            return .home
        case "daily":
            return .dailyChallenge
        default:
            return .home
        }
    }
}
