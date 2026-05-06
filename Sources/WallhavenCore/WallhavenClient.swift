import Foundation

public protocol WallhavenFetching: Sendable {
    func search(_ request: WallpaperSearchRequest, apiKey: String?) async throws -> WallhavenSearchResponse
}

public final class WallhavenClient: WallhavenFetching {
    private let apiKey: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    public convenience init(apiKey: String? = nil) {
        self.init(apiKey: apiKey, session: Self.makeDefaultSession())
    }

    public init(apiKey: String? = nil, session: URLSession) {
        self.apiKey = apiKey
        self.session = session
        decoder = JSONDecoder()
    }

    public func search(
        _ request: WallpaperSearchRequest,
        apiKey: String? = nil
    ) async throws -> WallhavenSearchResponse {
        let apiKey = apiKey ?? self.apiKey
        var urlRequest = URLRequest(
            url: request.url(apiKey: apiKey),
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 15
        )
        urlRequest.setValue("WallhavenMac/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WallhavenClientError.unexpectedResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw WallhavenClientError.unexpectedStatus(httpResponse.statusCode)
        }

        return try decoder.decode(WallhavenSearchResponse.self, from: data)
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }
}

public enum WallhavenClientError: Error, Equatable {
    case unexpectedResponse
    case unexpectedStatus(Int)
}
