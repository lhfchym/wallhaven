import AppKit
import SwiftUI

struct MacActionButton: NSViewRepresentable {
    let title: String?
    let systemImageName: String?
    let isPrimary: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        isPrimary: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        systemImageName = nil
        self.isPrimary = isPrimary
        self.isDisabled = isDisabled
        self.action = action
    }

    init(
        systemImageName: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        title = nil
        self.systemImageName = systemImageName
        isPrimary = false
        self.isDisabled = isDisabled
        self.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.isBordered = true
        button.refusesFirstResponder = true
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action

        if let title {
            button.title = title
            button.image = nil
            button.imagePosition = .noImage
        } else if let systemImageName {
            button.title = ""
            button.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: nil)
            button.imagePosition = .imageOnly
        }

        button.isEnabled = !isDisabled
        button.contentTintColor = isPrimary ? .controlAccentColor : nil
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}
