import AppKit
import SwiftUI
import WallhavenCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var isTerminating = false

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureWindow()
        configureStatusItem()
        showWindow()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        guard !isTerminating else { return false }

        showWindow()
        return true
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }

    func applicationWillTerminate(_: Notification) {
        tearDownStatusItem()
        tearDownWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    private func configureWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WallhavenMac"
        window.contentViewController = NSHostingController(rootView: WallpaperGalleryView())
        window.center()
        window.setFrameAutosaveName("WallhavenMacMainWindow")
        self.window = window
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "WallhavenMac")
        item.button?.image?.isTemplate = true
        item.button?.action = #selector(toggleWindow)
        item.button?.target = self
        statusItem = item
    }

    @objc private func toggleWindow() {
        guard !isTerminating else { return }

        if window?.isVisible == true, NSApp.isActive {
            window?.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        guard !isTerminating, let window else { return }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()
    }

    private func tearDownStatusItem() {
        statusItem?.button?.target = nil
        statusItem?.button?.action = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        statusItem = nil
    }

    private func tearDownWindow() {
        window?.orderOut(nil)
        window?.contentViewController = nil
        window = nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
