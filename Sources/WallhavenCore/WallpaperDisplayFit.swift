import Foundation

public struct WallpaperDisplayFit: Equatable, Sendable {
    public enum Tier: Int, Sendable {
        case excellent
        case good
        case usable
        case limited
    }

    public let score: Double
    public let cropLoss: Double
    public let canCoverDisplay: Bool
    public let tier: Tier

    public static func evaluate(
        imageWidth: Int,
        imageHeight: Int,
        display: DisplayProfile
    ) -> WallpaperDisplayFit {
        let displayWidth = Double(display.pixelWidth)
        let displayHeight = Double(display.pixelHeight)
        let sourceWidth = Double(imageWidth)
        let sourceHeight = Double(imageHeight)

        guard sourceWidth > 0, sourceHeight > 0, displayWidth > 0, displayHeight > 0 else {
            return WallpaperDisplayFit(score: 0, cropLoss: 1, canCoverDisplay: false, tier: .limited)
        }

        let fillScale = max(displayWidth / sourceWidth, displayHeight / sourceHeight)
        let scaledWidth = sourceWidth * fillScale
        let scaledHeight = sourceHeight * fillScale
        let scaledArea = scaledWidth * scaledHeight
        let displayArea = displayWidth * displayHeight
        let cropLoss = clamp((scaledArea - displayArea) / scaledArea)
        let canCoverDisplay = imageWidth >= display.pixelWidth && imageHeight >= display.pixelHeight

        // Images below native display size remain visible in search results, but should not outrank
        // wallpapers that can fill the desktop without upscaling.
        let nativeCoverage = min(sourceWidth / displayWidth, sourceHeight / displayHeight)
        let coverageFactor = canCoverDisplay ? 1 : min(max(nativeCoverage, 0), 1) * 0.45
        let score = clamp((1 - cropLoss) * coverageFactor)

        return WallpaperDisplayFit(
            score: score,
            cropLoss: cropLoss,
            canCoverDisplay: canCoverDisplay,
            tier: tier(canCoverDisplay: canCoverDisplay, cropLoss: cropLoss)
        )
    }

    public static func evaluate(
        wallpaper: WallhavenWallpaper,
        display: DisplayProfile
    ) -> WallpaperDisplayFit {
        evaluate(imageWidth: wallpaper.dimensionX, imageHeight: wallpaper.dimensionY, display: display)
    }

    private static func tier(canCoverDisplay: Bool, cropLoss: Double) -> Tier {
        guard canCoverDisplay else { return .limited }

        if cropLoss <= 0.03 {
            return .excellent
        }

        if cropLoss <= 0.18 {
            return .good
        }

        return .usable
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
