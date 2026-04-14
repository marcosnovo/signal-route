import UIKit

// MARK: - StoryAssetValidator
/// Debug utility — checks every imageName in StoryBeatCatalog exists in the asset bundle.
/// Run at launch in DEBUG and on-demand from DevMenuView.
enum StoryAssetValidator {

    struct Result {
        let checkedCount: Int
        let missingAssets: [String]
        var isValid: Bool { missingAssets.isEmpty }
    }

    @discardableResult
    static func validate() -> Result {
        let imageNames = Set(StoryBeatCatalog.beats.compactMap(\.imageName)).sorted()
        var missing: [String] = []

        for name in imageNames {
            if UIImage(named: name) == nil {
                missing.append(name)
                print("❌ [StoryAssets] Missing: \(name)")
            }
        }

        if missing.isEmpty {
            print("✅ [StoryAssets] All \(imageNames.count) assets present")
        } else {
            assertionFailure("[StoryAssets] \(missing.count) missing: \(missing.joined(separator: ", "))")
        }

        return Result(checkedCount: imageNames.count, missingAssets: missing)
    }
}
