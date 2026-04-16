import UIKit

// MARK: - PlanetArtDirection

/// Per-planet cinematic framing parameters for the shareable pass card.
///
/// - `imageName`: asset name in `Assets.xcassets`
/// - `scale`: canvas multiplier — 1.0 fills the canvas exactly, >1.0 zooms in
/// - `offsetX`: pixels to shift the image right (positive) after centering
/// - `offsetY`: pixels to shift the image down (positive) after centering
/// - `atmosphereOpacity`: accent-tint overlay strength (0 = none, 1 = opaque)
/// - `horizontalFadeClear`: X fraction (0–1) where the left dark-zone fully clears
/// - `verticalFadeStart`: Y fraction (0–1) where the bottom fade begins
struct PlanetArtDirection {
    let imageName: String
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let atmosphereOpacity: CGFloat
    /// X fraction (0–1) where horizontal bg gradient reaches full transparency.
    /// Left of 0.35 is always fully covered regardless of this value.
    let horizontalFadeClear: CGFloat
    /// Y fraction (0–1) where the bottom fade-to-dark begins.
    /// Fade completes (fully opaque) at `verticalFadeStart + 0.20`.
    let verticalFadeStart: CGFloat
}

// MARK: - PlanetVisualResolver

/// Single source of truth that maps each planet (by catalog index) to its official
/// in-game image asset *and* cinematic framing parameters.
///
/// | Planet ID | Name          | Asset name            |
/// |-----------|---------------|-----------------------|
/// | 0         | EARTH ORBIT   | planet_earth          |
/// | 1         | MOON          | planet_moon           |
/// | 2         | MARS          | planet_mars           |
/// | 3         | ASTEROID BELT | asteroid_belt_unlock  |
/// | 4         | JUPITER       | jupiter_unlock        |
/// | 5         | SATURN        | saturn_unlock         |
/// | 6         | URANUS        | uranus_unlock         |
/// | 7         | NEPTUNE       | planet_void_space     |
enum PlanetVisualResolver {

    // MARK: - Art Direction

    /// Returns the cinematic art direction for the given planet catalog index,
    /// or `nil` if no official asset is assigned (triggers procedural fallback).
    static func artDirection(for planetIndex: Int) -> PlanetArtDirection? {
        switch planetIndex {
        case 0: // Earth — globe pushed right into the clear zone
            return PlanetArtDirection(imageName: "planet_earth",
                                     scale: 1.20, offsetX: 260, offsetY: 0,
                                     atmosphereOpacity: 0.13,
                                     horizontalFadeClear: 0.62, verticalFadeStart: 0.52)
        case 1: // Moon — subtle zoom, shifted up slightly for surface texture
            return PlanetArtDirection(imageName: "planet_moon",
                                     scale: 1.15, offsetX: 100, offsetY: -60,
                                     atmosphereOpacity: 0.07,
                                     horizontalFadeClear: 0.60, verticalFadeStart: 0.52)
        case 2: // Mars — horizon line shifted down-right, surface fills bottom
            return PlanetArtDirection(imageName: "planet_mars",
                                     scale: 1.20, offsetX: 100, offsetY: 140,
                                     atmosphereOpacity: 0.18,
                                     horizontalFadeClear: 0.60, verticalFadeStart: 0.65)
        case 3: // Asteroid Belt — slight zoom, centred
            return PlanetArtDirection(imageName: "asteroid_belt_unlock",
                                     scale: 1.05, offsetX: 40, offsetY: 0,
                                     atmosphereOpacity: 0.14,
                                     horizontalFadeClear: 0.55, verticalFadeStart: 0.50)
        case 4: // Jupiter — planet body pushed far right, bands visible
            return PlanetArtDirection(imageName: "jupiter_unlock",
                                     scale: 1.20, offsetX: 300, offsetY: 30,
                                     atmosphereOpacity: 0.12,
                                     horizontalFadeClear: 0.60, verticalFadeStart: 0.52)
        case 5: // Saturn — earlier horizontal clear to show rings
            return PlanetArtDirection(imageName: "saturn_unlock",
                                     scale: 1.05, offsetX: 60, offsetY: 0,
                                     atmosphereOpacity: 0.13,
                                     horizontalFadeClear: 0.52, verticalFadeStart: 0.52)
        case 6: // Uranus — strong cyan atmosphere tint
            return PlanetArtDirection(imageName: "uranus_unlock",
                                     scale: 1.15, offsetX: 140, offsetY: 0,
                                     atmosphereOpacity: 0.20,
                                     horizontalFadeClear: 0.60, verticalFadeStart: 0.52)
        case 7: // Neptune / Void Space — full-canvas, strong blue atmosphere
            return PlanetArtDirection(imageName: "planet_void_space",
                                     scale: 1.00, offsetX: 0, offsetY: 0,
                                     atmosphereOpacity: 0.25,
                                     horizontalFadeClear: 0.62, verticalFadeStart: 0.50)
        default:
            return nil
        }
    }

    // MARK: - Convenience

    /// Asset name in `Assets.xcassets` for the given planet catalog index.
    static func assetName(for planetIndex: Int) -> String? {
        artDirection(for: planetIndex)?.imageName
    }

    /// Loads and returns the official `UIImage` for the given planet catalog index.
    ///
    /// `UIImage(named:)` is thread-safe and caches internally — safe to call from
    /// `Task.detached` (as used by `TicketRenderer`).
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
