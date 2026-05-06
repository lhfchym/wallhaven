import Foundation

public struct WallhavenSearchResponse: Decodable, Equatable, Sendable {
    public let data: [WallhavenWallpaper]
    public let meta: WallhavenMeta

    private enum CodingKeys: String, CodingKey {
        case data
        case meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        data = try container.decode([FailableDecodable<WallhavenWallpaper>].self, forKey: .data)
            .compactMap(\.value)
        meta = try container.decode(WallhavenMeta.self, forKey: .meta)
    }
}

public struct WallhavenWallpaper: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let shortURL: URL
    public let views: Int
    public let favorites: Int
    public let source: String
    public let purity: String
    public let category: String
    public let dimensionX: Int
    public let dimensionY: Int
    public let resolution: String
    public let ratio: String
    public let fileSize: Int
    public let fileType: String
    public let createdAt: String
    public let colors: [String]
    public let path: URL
    public let thumbs: WallhavenThumbs

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case shortURL = "short_url"
        case views
        case favorites
        case source
        case purity
        case category
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case resolution
        case ratio
        case fileSize = "file_size"
        case fileType = "file_type"
        case createdAt = "created_at"
        case colors
        case path
        case thumbs
    }
}

public struct WallhavenThumbs: Decodable, Equatable, Sendable {
    public let large: URL
    public let original: URL
    public let small: URL
}

public struct WallhavenMeta: Decodable, Equatable, Sendable {
    public let currentPage: Int
    public let lastPage: Int
    public let perPage: Int
    public let total: Int
    public let query: String?
    public let seed: String?

    private enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
        case query
        case seed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        currentPage = try container.decode(Int.self, forKey: .currentPage)
        lastPage = try container.decode(Int.self, forKey: .lastPage)
        perPage = try container.decode(Int.self, forKey: .perPage)
        total = try container.decode(Int.self, forKey: .total)
        query = try? container.decodeIfPresent(String.self, forKey: .query)
        seed = try container.decodeIfPresent(String.self, forKey: .seed)
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
