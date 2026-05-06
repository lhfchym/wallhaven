import SwiftUI

struct MacActionButton: View {
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

    var body: some View {
        Button {
            guard !isDisabled else { return }
            action()
        } label: {
            Group {
                if let title {
                    Text(title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(isPrimary ? .accentColor : .primary)
        .controlSize(.large)
        .disabled(isDisabled)
    }
}
