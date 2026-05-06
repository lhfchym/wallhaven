import AppKit
import SwiftUI

struct WallhavenSettingsView: View {
    @State private var apiKey: String
    @State private var downloadDirectoryPath: String

    let defaultDownloadDirectoryURL: URL?
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    init(
        apiKey: String,
        downloadDirectoryPath: String?,
        defaultDownloadDirectoryURL: URL?,
        onSave: @escaping (String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _apiKey = State(initialValue: apiKey)
        _downloadDirectoryPath = State(initialValue: downloadDirectoryPath ?? "")
        self.defaultDownloadDirectoryURL = defaultDownloadDirectoryURL
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

            Divider()

            Text("Download Folder")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                TextField("Default Pictures/WallhavenMac", text: $downloadDirectoryPath)
                    .textFieldStyle(.roundedBorder)

                Button("Choose...") {
                    chooseDownloadDirectory()
                }

                Button("Default") {
                    downloadDirectoryPath = ""
                }
            }

            Text(activeDownloadDirectoryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }

                Button("Save") {
                    onSave(apiKey, normalizedDownloadDirectoryPath)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520)
    }

    private var normalizedDownloadDirectoryPath: String? {
        let trimmedPath = downloadDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPath.isEmpty ? nil : trimmedPath
    }

    private var activeDownloadDirectoryText: String {
        if let normalizedDownloadDirectoryPath {
            return normalizedDownloadDirectoryPath
        }

        return defaultDownloadDirectoryURL?.path ?? "Default Pictures/WallhavenMac"
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if let normalizedDownloadDirectoryPath {
            panel.directoryURL = URL(fileURLWithPath: normalizedDownloadDirectoryPath, isDirectory: true)
        } else {
            panel.directoryURL = defaultDownloadDirectoryURL
        }

        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectoryPath = url.path
        }
    }
}
