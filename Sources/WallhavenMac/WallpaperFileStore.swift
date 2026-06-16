import Foundation
import WallhavenCore

protocol WallpaperFileStoring: Sendable {
    func downloadDirectory() async -> URL
    func setDownloadDirectory(_ directoryURL: URL?) async
    func ensureDownloadDirectory() async throws -> URL
    func downloadedWallpapers() async throws -> [DownloadedWallpaper]
    func deleteDownloadedWallpaper(_ wallpaper: DownloadedWallpaper) async throws
    func localURL(for wallpaper: WallhavenWallpaper) async -> URL
    func cachedURL(for wallpaper: WallhavenWallpaper) async -> URL?
    func downloadedURL(for wallpaper: WallhavenWallpaper) async throws -> URL
}

actor WallpaperFileStore: WallpaperFileStoring {
    private let fileManager: FileManager
    private let session: URLSession
    private let defaultDownloadDirectory: URL
    private var customDownloadDirectory: URL?

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        cacheDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.session = session

        defaultDownloadDirectory = fileManager
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WallhavenMac", isDirectory: true)
        customDownloadDirectory = cacheDirectory
    }

    func downloadDirectory() -> URL {
        customDownloadDirectory ?? defaultDownloadDirectory
    }

    func setDownloadDirectory(_ directoryURL: URL?) {
        customDownloadDirectory = directoryURL
    }

    func ensureDownloadDirectory() throws -> URL {
        let directoryURL = downloadDirectory()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    func downloadedWallpapers() async throws -> [DownloadedWallpaper] {
        let directoryURL = try ensureDownloadDirectory()
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .compactMap(downloadedWallpaper(from:))
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func deleteDownloadedWallpaper(_ wallpaper: DownloadedWallpaper) async throws {
        guard wallpaper.url.deletingLastPathComponent().standardizedFileURL == downloadDirectory().standardizedFileURL
        else {
            return
        }

        if fileManager.fileExists(atPath: wallpaper.url.path) {
            try fileManager.trashItem(at: wallpaper.url, resultingItemURL: nil)
        }
    }

    func localURL(for wallpaper: WallhavenWallpaper) -> URL {
        downloadDirectory().appendingPathComponent(fileName(for: wallpaper))
    }

    func cachedURL(for wallpaper: WallhavenWallpaper) -> URL? {
        let destinationURL = localURL(for: wallpaper)
        return fileManager.fileExists(atPath: destinationURL.path) ? destinationURL : nil
    }

    func downloadedURL(for wallpaper: WallhavenWallpaper) async throws -> URL {
        let destinationURL = localURL(for: wallpaper)

        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        _ = try ensureDownloadDirectory()

        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).download")

        do {
            do {
                let data = try await imageData(from: wallpaper.path)
                try data.write(to: temporaryURL, options: .atomic)
            } catch {
                try await curlDownload(from: wallpaper.path, to: temporaryURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        return destinationURL
    }

    private func imageData(from url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 0 ..< 3 {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                request.setValue("WallhavenMac/0.1", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WallpaperFileStoreError.unexpectedResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    throw WallpaperFileStoreError.unexpectedStatus(httpResponse.statusCode)
                }

                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error

                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(350_000_000 * (attempt + 1)))
                }
            }
        }

        throw lastError ?? WallpaperFileStoreError.unexpectedResponse
    }

    private func curlDownload(from url: URL, to destinationURL: URL) async throws {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--connect-timeout",
                "15",
                "--max-time",
                "120",
                "--user-agent",
                "WallhavenMac/0.1",
                "--output",
                destinationURL.path,
                url.absoluteString
            ]
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw WallpaperFileStoreError.curlFailed(
                    message ?? "curl exited with \(process.terminationStatus)."
                )
            }
        }.value
    }

    private func fileName(for wallpaper: WallhavenWallpaper) -> String {
        let pathExtension = wallpaper.path.pathExtension.isEmpty ? fallbackExtension(for: wallpaper) : wallpaper.path
            .pathExtension
        return "wallhaven-\(wallpaper.id)-\(wallpaper.resolution).\(pathExtension)"
    }

    private func fallbackExtension(for wallpaper: WallhavenWallpaper) -> String {
        switch wallpaper.fileType {
        case "image/png":
            "png"
        case "image/webp":
            "webp"
        default:
            "jpg"
        }
    }

    private func downloadedWallpaper(from url: URL) -> DownloadedWallpaper? {
        guard isSupportedImageFile(url) else { return nil }

        let resourceValues = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ])

        guard resourceValues?.isRegularFile != false else { return nil }

        let fileName = url.lastPathComponent
        let parsedName = parseDownloadedFileName(url.deletingPathExtension().lastPathComponent)
        let id = parsedName.wallhavenID ?? url.standardizedFileURL.path

        return DownloadedWallpaper(
            id: id,
            url: url,
            fileName: fileName,
            wallhavenID: parsedName.wallhavenID,
            resolution: parsedName.resolution,
            fileSize: resourceValues?.fileSize ?? 0,
            modifiedAt: resourceValues?.contentModificationDate ?? .distantPast
        )
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        ["jpg", "jpeg", "png", "webp", "heic", "tiff"].contains(url.pathExtension.lowercased())
    }

    private func parseDownloadedFileName(_ name: String) -> (wallhavenID: String?, resolution: String?) {
        let prefix = "wallhaven-"
        guard name.hasPrefix(prefix) else { return (nil, nil) }

        let remainder = String(name.dropFirst(prefix.count))
        let parts = remainder.split(separator: "-", maxSplits: 1).map(String.init)
        guard let wallhavenID = parts.first, !wallhavenID.isEmpty else { return (nil, nil) }

        let resolution = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        return (wallhavenID, resolution)
    }
}

enum WallpaperFileStoreError: Error, Equatable {
    case unexpectedResponse
    case unexpectedStatus(Int)
    case curlFailed(String)
}
