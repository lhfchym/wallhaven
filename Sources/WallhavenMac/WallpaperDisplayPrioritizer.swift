import Foundation
import WallhavenCore

enum WallpaperDisplayPrioritizer {
    static func prioritize(
        _ candidates: [WallhavenWallpaper],
        display: DisplayProfile,
        recentIDs: Set<String>
    ) -> [WallhavenWallpaper] {
        candidates
            .enumerated()
            .sorted { lhs, rhs in
                let lhsIsRecent = recentIDs.contains(lhs.element.id)
                let rhsIsRecent = recentIDs.contains(rhs.element.id)
                if lhsIsRecent != rhsIsRecent {
                    return !lhsIsRecent
                }

                let lhsFit = WallpaperDisplayFit.evaluate(wallpaper: lhs.element, display: display)
                let rhsFit = WallpaperDisplayFit.evaluate(wallpaper: rhs.element, display: display)
                if lhsFit.tier != rhsFit.tier {
                    return lhsFit.tier.rawValue < rhsFit.tier.rawValue
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
