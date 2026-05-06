import AppKit
import SwiftUI
import WallhavenCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 520, height: 620)
        popover.contentViewController = NSHostingController(rootView: WallpaperGalleryPrototypeView())
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "WH"
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

struct WallpaperGalleryPrototypeView: View {
    private let display = DisplayProfile(width: 1512, height: 982, scale: 2)
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wallhaven")
                        .font(.headline)
                    Text("\(display.resolutionQuery) - \(display.aspectRatioQuery)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Spacer()

                Button("Refresh") {}
                    .buttonStyle(.borderedProminent)
            }

            TextField("Search wallpapers", text: .constant(""))
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0 ..< 18, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tileColor(index))
                            .aspectRatio(16 / 10, contentMode: .fit)
                            .overlay(alignment: .bottomLeading) {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .padding(6)
                                    .foregroundStyle(.white)
                            }
                    }
                }
            }

            HStack {
                Button("Preview") {}
                Button("Set Wallpaper") {}
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }

    private func tileColor(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .teal, .green, .orange, .pink, .indigo]
        return colors[index % colors.count].opacity(0.72)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
