import AppKit
import Foundation
import WallhavenCore

actor WallpaperThumbnailImageCache {
    static let shared = WallpaperThumbnailImageCache()

    private let limit = 240
    private var images: [URL: NSImage] = [:]
    private var accessOrder: [URL] = []

    func image(for url: URL) -> NSImage? {
        images[url]
    }

    func store(_ image: NSImage, for url: URL) {
        images[url] = image
        accessOrder.removeAll { $0 == url }
        accessOrder.append(url)

        while accessOrder.count > limit, let oldestURL = accessOrder.first {
            accessOrder.removeFirst()
            images[oldestURL] = nil
        }
    }
}

enum WallpaperThumbnailImageLoader {
    static func loadImage(for wallpaper: WallhavenWallpaper) async throws -> NSImage {
        try await loadImage(for: wallpaper, urls: wallpaper.thumbnailFallbackURLs)
    }

    static func loadPreviewImage(for wallpaper: WallhavenWallpaper) async throws -> NSImage {
        try await loadImage(for: wallpaper, urls: wallpaper.previewFallbackURLs)
    }

    private static func loadImage(for wallpaper: WallhavenWallpaper, urls: [URL]) async throws -> NSImage {
        var lastError: Error?

        for url in urls {
            if let cachedImage = await WallpaperThumbnailImageCache.shared.image(for: url) {
                return cachedImage
            }

            do {
                let image = try await loadImage(from: url)
                await WallpaperThumbnailImageCache.shared.store(image, for: url)
                return image
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? WallpaperThumbnailImageLoaderError.unableToLoadImage
    }

    private static func loadImage(from url: URL) async throws -> NSImage {
        var lastError: Error?

        for attempt in 0 ..< 3 {
            do {
                var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
                request.setValue("WallhavenMac/0.1", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WallpaperThumbnailImageLoaderError.unexpectedResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    throw WallpaperThumbnailImageLoaderError.unexpectedStatus(httpResponse.statusCode)
                }

                guard let image = NSImage(data: data), image.isValid else {
                    throw WallpaperThumbnailImageLoaderError.invalidImageData
                }

                return image
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
                }
            }
        }

        throw lastError ?? WallpaperThumbnailImageLoaderError.unableToLoadImage
    }
}

enum WallpaperThumbnailImageLoaderError: Error {
    case unexpectedResponse
    case unexpectedStatus(Int)
    case invalidImageData
    case unableToLoadImage
}

private extension WallhavenWallpaper {
    var thumbnailFallbackURLs: [URL] {
        uniqueURLs([thumbs.large, thumbs.original, thumbs.small])
    }

    var previewFallbackURLs: [URL] {
        uniqueURLs([thumbs.original, thumbs.large, thumbs.small])
    }

    func uniqueURLs(_ candidates: [URL]) -> [URL] {
        var urls: [URL] = []
        for url in candidates where !urls.contains(url) {
            urls.append(url)
        }
        return urls
    }
}
