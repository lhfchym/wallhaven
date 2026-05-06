import Foundation

public struct WallpaperSearchPreferences: Equatable, Sendable {
    public var query: String
    public var categories: WallhavenCategories
    public var purity: WallhavenPurity
    public var sorting: WallhavenSorting

    public init(
        query: String = "",
        categories: WallhavenCategories = .general,
        purity: WallhavenPurity = .sfw,
        sorting: WallhavenSorting = .random
    ) {
        self.query = query
        self.categories = categories
        self.purity = purity
        self.sorting = sorting
    }
}

public struct WallhavenCategories: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let general = Self(rawValue: 1 << 2)
    public static let anime = Self(rawValue: 1 << 1)
    public static let people = Self(rawValue: 1 << 0)

    public var apiValue: String {
        optionSetAPIValue(order: [.general, .anime, .people])
    }
}

public struct WallhavenPurity: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sfw = Self(rawValue: 1 << 2)
    public static let sketchy = Self(rawValue: 1 << 1)
    public static let nsfw = Self(rawValue: 1 << 0)

    public var apiValue: String {
        optionSetAPIValue(order: [.sfw, .sketchy, .nsfw])
    }
}

public enum WallhavenSorting: String, CaseIterable, Identifiable, Sendable {
    case dateAdded = "date_added"
    case favorites
    case random
    case relevance
    case toplist
    case views

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dateAdded:
            "Latest"
        case .favorites:
            "Favorites"
        case .random:
            "Random"
        case .relevance:
            "Relevance"
        case .toplist:
            "Toplist"
        case .views:
            "Views"
        }
    }
}

private extension OptionSet where RawValue == Int {
    func optionSetAPIValue(order: [Self]) -> String {
        order.map { rawValue & $0.rawValue == $0.rawValue ? "1" : "0" }.joined()
    }
}
