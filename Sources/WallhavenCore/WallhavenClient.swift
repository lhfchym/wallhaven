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

        let data = try await data(for: urlRequest)

        return try decoder.decode(WallhavenSearchResponse.self, from: data)
    }

    private func data(for request: URLRequest) async throws -> Data {
        var lastError: Error?

        for attempt in 0 ..< 3 {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WallhavenClientError.unexpectedResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    throw WallhavenClientError.unexpectedStatus(httpResponse.statusCode)
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

        if let url = request.url {
            return try await Self.curlData(from: url)
        }

        throw lastError ?? WallhavenClientError.unexpectedResponse
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    private static func curlData(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--connect-timeout",
                "10",
                "--max-time",
                "30",
                "--user-agent",
                "WallhavenMac/0.1",
                url.absoluteString
            ]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw WallhavenClientError.curlFailed(message ?? "curl exited with \(process.terminationStatus).")
            }

            return data
        }.value
    }
}

public enum WallhavenClientError: Error, Equatable {
    case unexpectedResponse
    case unexpectedStatus(Int)
    case curlFailed(String)
}
