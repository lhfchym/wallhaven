import SwiftUI

struct WallhavenSettingsView: View {
    @State private var apiKey: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(
        apiKey: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _apiKey = State(initialValue: apiKey)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.headline)

            SecureField("wallhaven API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Text("Stored in macOS Keychain. Required for NSFW results and account-specific wallhaven settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }

                Button("Save") {
                    onSave(apiKey)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 420)
    }
}
