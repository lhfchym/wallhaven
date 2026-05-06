import Foundation
import WallhavenCore

struct WallhavenUserPreferences: Equatable, Sendable {
    var apiKey: String
    var query: String
    var downloadDirectoryPath: String?
    var categories: WallhavenCategoryPreset
    var purity: WallhavenPurityPreset
    var sorting: WallhavenSorting

    init(
        apiKey: String = "",
        query: String = "",
        downloadDirectoryPath: String? = nil,
        categories: WallhavenCategoryPreset = .general,
        purity: WallhavenPurityPreset = .sfw,
        sorting: WallhavenSorting = .random
    ) {
        self.apiKey = apiKey
        self.query = query
        self.downloadDirectoryPath = downloadDirectoryPath
        self.categories = categories
        self.purity = purity
        self.sorting = sorting
    }

    var downloadDirectoryURL: URL? {
        guard let downloadDirectoryPath, !downloadDirectoryPath.isEmpty else { return nil }
        return URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
    }
}

enum WallhavenCategoryPreset: String, CaseIterable, Identifiable, Sendable {
    case general
    case anime
    case people
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:
            "General"
        case .anime:
            "Anime"
        case .people:
            "People"
        case .all:
            "All"
        }
    }

    var categories: WallhavenCategories {
        switch self {
        case .general:
            .general
        case .anime:
            .anime
        case .people:
            .people
        case .all:
            [.general, .anime, .people]
        }
    }
}

enum WallhavenPurityPreset: String, CaseIterable, Identifiable, Sendable {
    case sfw
    case sfwSketchy
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sfw:
            "SFW"
        case .sfwSketchy:
            "SFW+Sketchy"
        case .all:
            "All"
        }
    }

    var purity: WallhavenPurity {
        switch self {
        case .sfw:
            .sfw
        case .sfwSketchy:
            [.sfw, .sketchy]
        case .all:
            [.sfw, .sketchy, .nsfw]
        }
    }
}

protocol WallhavenUserPreferencesStoring: Sendable {
    func load() async -> WallhavenUserPreferences
    func save(_ preferences: WallhavenUserPreferences) async
}

actor WallhavenUserPreferencesStore: WallhavenUserPreferencesStoring {
    private enum Keys {
        static let query = "wallhaven.query"
        static let downloadDirectoryPath = "wallhaven.downloadDirectoryPath"
        static let categories = "wallhaven.categories"
        static let purity = "wallhaven.purity"
        static let sorting = "wallhaven.sorting"
    }

    private let defaults: UserDefaults
    private let apiKeyStore: WallhavenAPIKeyStoring

    init(
        defaults: UserDefaults = .standard,
        apiKeyStore: WallhavenAPIKeyStoring = WallhavenAPIKeyStore()
    ) {
        self.defaults = defaults
        self.apiKeyStore = apiKeyStore
    }

    func load() async -> WallhavenUserPreferences {
        let query = defaults.string(forKey: Keys.query) ?? ""
        let downloadDirectoryPath = defaults.string(forKey: Keys.downloadDirectoryPath)
        let categories = defaults.string(forKey: Keys.categories)
            .flatMap(WallhavenCategoryPreset.init(rawValue:)) ?? .general
        let purity = defaults.string(forKey: Keys.purity)
            .flatMap(WallhavenPurityPreset.init(rawValue:)) ?? .sfw
        let sorting = defaults.string(forKey: Keys.sorting)
            .flatMap(WallhavenSorting.init(rawValue:)) ?? .random

        return WallhavenUserPreferences(
            apiKey: apiKeyStore.loadAPIKey(),
            query: query,
            downloadDirectoryPath: downloadDirectoryPath,
            categories: categories,
            purity: purity,
            sorting: sorting
        )
    }

    func save(_ preferences: WallhavenUserPreferences) async {
        apiKeyStore.saveAPIKey(preferences.apiKey)
        defaults.set(preferences.query, forKey: Keys.query)
        if let downloadDirectoryPath = preferences.downloadDirectoryPath, !downloadDirectoryPath.isEmpty {
            defaults.set(downloadDirectoryPath, forKey: Keys.downloadDirectoryPath)
        } else {
            defaults.removeObject(forKey: Keys.downloadDirectoryPath)
        }
        defaults.set(preferences.categories.rawValue, forKey: Keys.categories)
        defaults.set(preferences.purity.rawValue, forKey: Keys.purity)
        defaults.set(preferences.sorting.rawValue, forKey: Keys.sorting)
    }
}
