import Foundation
import WallhavenCore

struct WallhavenUserPreferences: Equatable, Sendable {
    var apiKey: String
    var categories: WallhavenCategoryPreset
    var purity: WallhavenPurityPreset
    var sorting: WallhavenSorting

    init(
        apiKey: String = "",
        categories: WallhavenCategoryPreset = .general,
        purity: WallhavenPurityPreset = .sfw,
        sorting: WallhavenSorting = .random
    ) {
        self.apiKey = apiKey
        self.categories = categories
        self.purity = purity
        self.sorting = sorting
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
        let categories = defaults.string(forKey: Keys.categories)
            .flatMap(WallhavenCategoryPreset.init(rawValue:)) ?? .general
        let purity = defaults.string(forKey: Keys.purity)
            .flatMap(WallhavenPurityPreset.init(rawValue:)) ?? .sfw
        let sorting = defaults.string(forKey: Keys.sorting)
            .flatMap(WallhavenSorting.init(rawValue:)) ?? .random

        return WallhavenUserPreferences(
            apiKey: apiKeyStore.loadAPIKey(),
            categories: categories,
            purity: purity,
            sorting: sorting
        )
    }

    func save(_ preferences: WallhavenUserPreferences) async {
        apiKeyStore.saveAPIKey(preferences.apiKey)
        defaults.set(preferences.categories.rawValue, forKey: Keys.categories)
        defaults.set(preferences.purity.rawValue, forKey: Keys.purity)
        defaults.set(preferences.sorting.rawValue, forKey: Keys.sorting)
    }
}
