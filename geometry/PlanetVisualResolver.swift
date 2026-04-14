import UIKit

// MARK: - PlanetVisualResolver
/// Single source of truth that maps each planet (by catalog index) to its official
/// in-game image asset. Used by TicketRenderer for the shareable pass image and by
/// any other surface that needs the canonical visual for a destination.
///
/// ## Asset mapping
///
/// | Planet ID | Name          | Asset name            | Source file             |
/// |-----------|---------------|-----------------------|-------------------------|
/// | 0         | EARTH ORBIT   | planet_earth          | earth.jpg               |
/// | 1         | MOON          | planet_moon           | moon.jpg                |
/// | 2         | MARS          | planet_mars           | mars.jpg                |
/// | 3         | ASTEROID BELT | asteroid_belt_unlock  | asteroid_belt_unlock.jpg|
/// | 4         | JUPITER       | jupiter_unlock        | jupiter_unlock.jpg      |
/// | 5         | SATURN        | saturn_unlock         | saturn_unlock.jpg       |
/// | 6         | URANUS        | uranus_unlock         | uranus_unlock.jpg       |
/// | 7         | NEPTUNE       | planet_void_space     | void_space.jpg          |
///
/// Planets with no assigned asset return `nil` — callers should fall back
/// gracefully (TicketRenderer uses its procedural CGGradient sphere).
enum PlanetVisualResolver {

    // MARK: - Lookup

    /// Asset name in `Assets.xcassets` for the given planet catalog index.
    /// Returns `nil` if no official asset is assigned for that planet.
    static func assetName(for planetIndex: Int) -> String? {
        switch planetIndex {
        case 0: return "planet_earth"
        case 1: return "planet_moon"
        case 2: return "planet_mars"
        case 3: return "asteroid_belt_unlock"
        case 4: return "jupiter_unlock"
        case 5: return "saturn_unlock"
        case 6: return "uranus_unlock"
        case 7: return "planet_void_space"
        default: return nil
        }
    }

    /// Loads and returns the official `UIImage` for the given planet catalog index.
    ///
    /// `UIImage(named:)` is thread-safe and caches internally — safe to call from
    /// `Task.detached` (as used by `TicketRenderer`).
    ///
    /// Returns `nil` when the asset doesn't exist or the index has no mapping.
    /// In DEBUG builds a console warning is printed for missing assets.
    static func image(for planetIndex: Int) -> UIImage? {
        guard let name = assetName(for: planetIndex) else { return nil }
        let image = UIImage(named: name)
        #if DEBUG
        if image == nil {
            print("[PlanetVisualResolver] ⚠️ Missing asset '\(name)' for planet index \(planetIndex)")
        }
        #endif
        return image
    }
}
