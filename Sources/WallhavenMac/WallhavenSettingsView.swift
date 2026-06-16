import AppKit
import SwiftUI

struct WallhavenSettingsView: View {
    @State private var apiKey: String
    @State private var downloadDirectoryPath: String
    @State private var strictAspectRatio: Bool
    @State private var language: WallhavenLanguage

    let defaultDownloadDirectoryURL: URL?
    let onSave: (String, String?, Bool, WallhavenLanguage) -> Void
    let onCancel: () -> Void

    init(
        apiKey: String,
        downloadDirectoryPath: String?,
        strictAspectRatio: Bool,
        language: WallhavenLanguage,
        defaultDownloadDirectoryURL: URL?,
        onSave: @escaping (String, String?, Bool, WallhavenLanguage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _apiKey = State(initialValue: apiKey)
        _downloadDirectoryPath = State(initialValue: downloadDirectoryPath ?? "")
        _strictAspectRatio = State(initialValue: strictAspectRatio)
        _language = State(initialValue: language)
        self.defaultDownloadDirectoryURL = defaultDownloadDirectoryURL
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.settingsTitle)
                .font(.headline)

            Text(copy.languageTitle)
                .font(.subheadline)
                .fontWeight(.medium)

            Picker(copy.languageTitle, selection: $language) {
                ForEach(WallhavenLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            SecureField(copy.apiKeyPlaceholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Text(copy.apiKeyHelp)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text(copy.downloadFolderTitle)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                TextField(copy.defaultDownloadFolder, text: $downloadDirectoryPath)
                    .textFieldStyle(.roundedBorder)

                Button(copy.choose) {
                    chooseDownloadDirectory()
                }

                Button(copy.useDefault) {
                    downloadDirectoryPath = ""
                }
            }

            Text(activeDownloadDirectoryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            Divider()

            Toggle(copy.strictAspectRatio, isOn: $strictAspectRatio)

            Text(copy.strictAspectRatioHelp)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button(copy.cancel) {
                    onCancel()
                }

                Button(copy.save) {
                    onSave(apiKey, normalizedDownloadDirectoryPath, strictAspectRatio, language)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520)
    }

    private var copy: WallhavenCopy {
        WallhavenCopy(language: language)
    }

    private var normalizedDownloadDirectoryPath: String? {
        let trimmedPath = downloadDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPath.isEmpty ? nil : trimmedPath
    }

    private var activeDownloadDirectoryText: String {
        if let normalizedDownloadDirectoryPath {
            return normalizedDownloadDirectoryPath
        }

        return defaultDownloadDirectoryURL?.path ?? copy.defaultDownloadFolder
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = copy.choosePanelPrompt

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
