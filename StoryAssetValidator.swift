import UIKit

// MARK: - StoryImageManifest

/// Exhaustive list of every image asset name expected in Assets.xcassets for story beats.
///
/// Purpose: `StoryAssetValidator` compares this set against the beat catalog to detect:
///   - **orphan assets** — in manifest, but no beat references them (safe to remove)
///   - **catalog gaps**  — imageName in a beat that isn't in the manifest (add to manifest)
///
/// Update this list whenever you add or remove story images from the asset catalog.
enum StoryImageManifest {
    static let allNames: Set<String> = [
        // First launch / onboarding
        "intro_console",
        "intro_airlock",
        "intro_window",
        "intro_alert",
        "intro_repair",
        // First mission complete / sector 1
        "sector_earth_complete",
        // Rank up (shared across all three rank beats)
        "rank_up_promotion",
        // Mechanic unlocked
        "mechanic_rotations",
        "mechanic_interference_1",
        "mechanic_interference_2",
        "mechanic_autorotate",
        "one_way_relay",
        "network_decay",
        "locked_subsystem",
        "mechanic_timer",
        // Sector complete + pass unlocked (shared by paired beats)
        "sector_lunar_unlock",
        "sector_mars_unlock",
        "asteroid_belt_unlock",
        "jupiter_unlock",
        "saturn_unlock",
        "uranus_unlock",
        "deep_space_network",
        // Pass unlocked (dedicated per sector)
        "asteroid_belt_transit",
        "giant_approach",
        "ring_transit",
        "void_clearance",
        // Entering new sector
        "sector_lunar_intro",
        "sector_mars_intro",
        "asteroid_belt_entry",
        "gas_giant_grid",
        "ring_system",
        "deep_void",
    ]
}

// MARK: - StoryAssetValidator

/// Debug utility — validates every imageName in StoryBeatCatalog against the asset bundle.
/// Run at launch in DEBUG and on-demand from DevMenuView.
///
/// Error categories:
///   - **missing**:     imageName set but `UIImage(named:)` returns nil.
///   - **noImage**:     imageName is nil — beat renders without any visual.
///   - **duplicate**:   same imageName shared by multiple beats (warning; may be intentional).
///   - **placeholder**: imageName matches a placeholder/test naming pattern (always an error).
///   - **orphan**:      image in `StoryImageManifest` not referenced by any beat (safe to remove).
enum StoryAssetValidator {

    // MARK: - Types

    struct DuplicateMapping: Identifiable {
        var id: String { imageName }
        let imageName: String
        let beatIDs:   [String]     // 2+ beats sharing this image
    }

    struct Result {
        let checkedCount:      Int
        let missingAssets:     [String]              // imageNames not found in bundle
        let beatsWithNoImage:  [String]              // beat IDs where imageName == nil
        let duplicateMappings: [DuplicateMapping]    // same image used by 2+ beats
        let placeholderImages: [String]              // beat IDs whose imageName matches a placeholder pattern
        let orphanAssets:      [String]              // manifest names unused by any catalog beat

        /// True when there are no missing assets and no placeholder images in production beats.
        var isValid: Bool { missingAssets.isEmpty && placeholderImages.isEmpty }

        /// True when every beat has an imageName assigned.
        var hasAllImages: Bool { beatsWithNoImage.isEmpty }

        var errorCount:   Int { missingAssets.count + placeholderImages.count }
        var warningCount: Int { duplicateMappings.count + beatsWithNoImage.count + orphanAssets.count }
    }

    // MARK: - Per-beat status

    enum BeatAssetStatus: Equatable {
        case ok
        case noImage        // imageName is nil
        case missing        // asset not found in bundle
        case placeholder    // imageName matches placeholder pattern
        case duplicate      // imageName shared with at least one other beat
    }

    /// Returns the asset status for a single beat, given a prior validate() result.
    /// Efficient for per-row display — does not re-query the bundle.
    static func status(for beat: StoryBeat, in result: Result) -> BeatAssetStatus {
        guard let name = beat.imageName else { return .noImage }
        if result.placeholderImages.contains(beat.id)                               { return .placeholder }
        if result.missingAssets.contains(name)                                      { return .missing     }
        if result.duplicateMappings.contains(where: { $0.beatIDs.contains(beat.id) }) { return .duplicate   }
        return .ok
    }

    // MARK: - Validation

    /// Substrings that mark an imageName as a non-production placeholder.
    private static let placeholderPatterns: [String] = [
        "placeholder", "test_", "_test", "debug_", "_debug",
        "temp_", "_temp", "stub_", "_stub", "todo_", "fixme_",
    ]

    @discardableResult
    static func validate() -> Result {
        let beats = StoryBeatCatalog.beats

        // ── 1. Missing assets ──────────────────────────────────────────────────
        let imageNames = Set(beats.compactMap(\.imageName)).sorted()
        var missing: [String] = []
        for name in imageNames {
            if UIImage(named: name) == nil {
                missing.append(name)
                #if DEBUG
                print("❌ [StoryAssets] Missing asset: \(name)")
                #endif
            }
        }

        // ── 2. Beats with no image ─────────────────────────────────────────────
        let noImage = beats.filter { $0.imageName == nil }.map(\.id).sorted()
        #if DEBUG
        if !noImage.isEmpty {
            print("⚠️ [StoryAssets] \(noImage.count) beat(s) have no image: \(noImage.joined(separator: ", "))")
        }
        #endif

        // ── 3. Duplicate image mappings ────────────────────────────────────────
        var imageToBeats: [String: [String]] = [:]
        for beat in beats {
            guard let name = beat.imageName else { continue }
            imageToBeats[name, default: []].append(beat.id)
        }
        let duplicates = imageToBeats
            .filter  { $0.value.count > 1 }
            .map     { DuplicateMapping(imageName: $0.key, beatIDs: $0.value.sorted()) }
            .sorted  { $0.imageName < $1.imageName }
        #if DEBUG
        for d in duplicates {
            print("⚠️ [StoryAssets] Duplicate '\(d.imageName)' → \(d.beatIDs.joined(separator: ", "))")
        }
        #endif

        // ── 4. Placeholder images ──────────────────────────────────────────────
        let placeholders = beats.compactMap { beat -> String? in
            guard let name = beat.imageName else { return nil }
            let lower = name.lowercased()
            return placeholderPatterns.contains(where: { lower.contains($0) }) ? beat.id : nil
        }.sorted()
        #if DEBUG
        for id in placeholders { print("⚠️ [StoryAssets] Placeholder image in beat: \(id)") }
        #endif

        // ── 5. Orphan assets ───────────────────────────────────────────────────
        let usedNames = Set(beats.compactMap(\.imageName))
        let orphans   = StoryImageManifest.allNames.filter { !usedNames.contains($0) }.sorted()
        #if DEBUG
        for name in orphans { print("⚠️ [StoryAssets] Orphan asset (unused by catalog): \(name)") }
        #endif

        // ── Summary / fail-fast ───────────────────────────────────────────────
        #if DEBUG
        if missing.isEmpty && placeholders.isEmpty {
            print("✅ [StoryAssets] All \(imageNames.count) assets present, no placeholders")
        } else {
            assertionFailure("[StoryAssets] \(missing.count) missing, \(placeholders.count) placeholder(s) — fix before shipping")
        }
        #endif

        return Result(
            checkedCount:      imageNames.count,
            missingAssets:     missing,
            beatsWithNoImage:  noImage,
            duplicateMappings: duplicates,
            placeholderImages: placeholders,
            orphanAssets:      orphans
        )
    }
}
