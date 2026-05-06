import SwiftUI

struct WallhavenActionButton<Label: View>: View {
    let role: WallhavenActionButtonRole
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        role: WallhavenActionButtonRole = .secondary,
        isDisabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.isDisabled = isDisabled
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            guard !isDisabled else { return }
            action()
        } label: {
            label()
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .frame(minWidth: role.minimumWidth, minHeight: 30)
                .padding(.horizontal, 12)
                .foregroundStyle(role.foregroundColor(isDisabled: isDisabled))
                .background(role.backgroundColor(isDisabled: isDisabled), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(RoundedRectangle(cornerRadius: 7))
                .opacity(isDisabled ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(.isButton)
    }
}

enum WallhavenActionButtonRole {
    case primary
    case secondary
    case icon

    var minimumWidth: CGFloat {
        switch self {
        case .primary:
            104
        case .secondary:
            72
        case .icon:
            34
        }
    }

    func foregroundColor(isDisabled: Bool) -> Color {
        guard !isDisabled else { return .secondary }

        switch self {
        case .primary:
            return Color.white
        case .secondary, .icon:
            return Color.primary
        }
    }

    func backgroundColor(isDisabled: Bool) -> Color {
        guard !isDisabled else { return Color(nsColor: .controlBackgroundColor) }

        switch self {
        case .primary:
            return Color.accentColor
        case .secondary, .icon:
            return Color(nsColor: .controlBackgroundColor)
        }
    }
}
