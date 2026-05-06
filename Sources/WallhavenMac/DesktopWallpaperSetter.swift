import AppKit
import Foundation

protocol DesktopWallpaperSetting: Sendable {
    func setDesktopWallpaper(at imageURL: URL) throws
}

struct DesktopWallpaperSetter: DesktopWallpaperSetting {
    func setDesktopWallpaper(at imageURL: URL) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(
                imageURL,
                for: screen,
                options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true
                ]
            )
        }
    }
}
