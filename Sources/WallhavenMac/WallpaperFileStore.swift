import Foundation
import WallhavenCore

protocol WallpaperFileStoring: Sendable {
    func downloadDirectory() async -> URL
    func setDownloadDirectory(_ directoryURL: URL?) async
    func ensureDownloadDirectory() async throws -> URL
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

        let (temporaryURL, response) = try await session.download(from: wallpaper.path)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WallpaperFileStoreError.unexpectedResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw WallpaperFileStoreError.unexpectedStatus(httpResponse.statusCode)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
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
}

enum WallpaperFileStoreError: Error, Equatable {
    case unexpectedResponse
    case unexpectedStatus(Int)
}
