import Foundation

public struct WallpaperSearchRequest: Equatable, Sendable {
    public let preferences: WallpaperSearchPreferences
    public let display: DisplayProfile
    public let page: Int

    public init(
        preferences: WallpaperSearchPreferences,
        display: DisplayProfile,
        page: Int = 1
    ) {
        self.preferences = preferences
        self.display = display
        self.page = page
    }

    public func url(apiKey: String? = nil) -> URL {
        guard var components = URLComponents(string: "https://wallhaven.cc/api/v1/search") else {
            preconditionFailure("Invalid wallhaven search URL")
        }

        var queryItems = [
            URLQueryItem(name: "q", value: preferences.query),
            URLQueryItem(name: "categories", value: preferences.categories.apiValue),
            URLQueryItem(name: "purity", value: preferences.purity.apiValue),
            URLQueryItem(name: "sorting", value: preferences.sorting.rawValue),
            URLQueryItem(name: "ratios", value: display.aspectRatioQuery),
            URLQueryItem(name: "atleast", value: display.resolutionQuery),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let apiKey, !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            preconditionFailure("Unable to build wallhaven search URL")
        }

        return url
    }
}
