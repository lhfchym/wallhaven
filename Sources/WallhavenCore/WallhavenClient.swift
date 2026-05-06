import Foundation

public protocol WallhavenFetching: Sendable {
    func search(_ request: WallpaperSearchRequest) async throws -> WallhavenSearchResponse
}

public final class WallhavenClient: WallhavenFetching {
    private let apiKey: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        decoder = JSONDecoder()
    }

    public func search(_ request: WallpaperSearchRequest) async throws -> WallhavenSearchResponse {
        let (data, response) = try await session.data(from: request.url(apiKey: apiKey))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WallhavenClientError.unexpectedResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw WallhavenClientError.unexpectedStatus(httpResponse.statusCode)
        }

        return try decoder.decode(WallhavenSearchResponse.self, from: data)
    }
}

public enum WallhavenClientError: Error, Equatable {
    case unexpectedResponse
    case unexpectedStatus(Int)
}
