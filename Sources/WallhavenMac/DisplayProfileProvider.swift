import AppKit
import WallhavenCore

enum DisplayProfileProvider {
    static func current() -> DisplayProfile {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return DisplayProfile(width: 1920, height: 1080)
        }

        return DisplayProfile(
            width: Int(screen.frame.width.rounded()),
            height: Int(screen.frame.height.rounded()),
            scale: screen.backingScaleFactor
        )
    }
}
