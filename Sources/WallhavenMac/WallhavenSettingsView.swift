import AppKit
import SwiftUI

struct WallhavenSettingsView: View {
    @State private var apiKey: String
    @State private var downloadDirectoryPath: String
    @State private var strictAspectRatio: Bool

    let defaultDownloadDirectoryURL: URL?
    let onSave: (String, String?, Bool) -> Void
    let onCancel: () -> Void

    init(
        apiKey: String,
        downloadDirectoryPath: String?,
        strictAspectRatio: Bool,
        defaultDownloadDirectoryURL: URL?,
        onSave: @escaping (String, String?, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _apiKey = State(initialValue: apiKey)
        _downloadDirectoryPath = State(initialValue: downloadDirectoryPath ?? "")
        _strictAspectRatio = State(initialValue: strictAspectRatio)
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

            Divider()

            Toggle("Strict aspect ratio", isOn: $strictAspectRatio)

            Text("When enabled, searches only return wallpapers matching this display's exact ratio.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }

                Button("Save") {
                    onSave(apiKey, normalizedDownloadDirectoryPath, strictAspectRatio)
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
