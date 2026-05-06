import Foundation
import WallhavenCore

protocol WallpaperHistoryStoring: Sendable {
    func recentWallpaperIDs() async -> Set<String>
    func recordDisplayed(_ wallpapers: [WallhavenWallpaper]) async
    func recordSet(_ wallpaper: WallhavenWallpaper) async
}

actor WallpaperHistoryStore: WallpaperHistoryStoring {
    private let fileManager: FileManager
    private let historyURL: URL
    private let maxEntries: Int

    init(
        fileManager: FileManager = .default,
        historyURL: URL? = nil,
        maxEntries: Int = 240
    ) {
        self.fileManager = fileManager
        self.maxEntries = maxEntries

        if let historyURL {
            self.historyURL = historyURL
        } else {
            self.historyURL = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WallhavenMac", isDirectory: true)
                .appendingPathComponent("history.json")
        }
    }

    func recentWallpaperIDs() async -> Set<String> {
        let history = loadHistory()
        return Set(history.entries.map(\.id))
    }

    func recordDisplayed(_ wallpapers: [WallhavenWallpaper]) async {
        updateHistory { history in
            for wallpaper in wallpapers {
                history.upsert(
                    id: wallpaper.id,
                    resolution: wallpaper.resolution,
                    category: wallpaper.category,
                    purity: wallpaper.purity,
                    event: .displayed
                )
            }
        }
    }

    func recordSet(_ wallpaper: WallhavenWallpaper) async {
        updateHistory { history in
            history.upsert(
                id: wallpaper.id,
                resolution: wallpaper.resolution,
                category: wallpaper.category,
                purity: wallpaper.purity,
                event: .setAsWallpaper
            )
        }
    }

    private func updateHistory(_ update: (inout WallpaperHistory) -> Void) {
        var history = loadHistory()
        update(&history)
        history.entries.sort { $0.updatedAt > $1.updatedAt }
        history.entries = Array(history.entries.prefix(maxEntries))
        saveHistory(history)
    }

    private func loadHistory() -> WallpaperHistory {
        guard let data = try? Data(contentsOf: historyURL) else {
            return WallpaperHistory(entries: [])
        }

        return (try? JSONDecoder().decode(WallpaperHistory.self, from: data)) ?? WallpaperHistory(entries: [])
    }

    private func saveHistory(_ history: WallpaperHistory) {
        do {
            try fileManager.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(history)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save wallpaper history: \(error)")
        }
    }
}

private struct WallpaperHistory: Codable {
    var entries: [WallpaperHistoryEntry]

    mutating func upsert(
        id: String,
        resolution: String,
        category: String,
        purity: String,
        event: WallpaperHistoryEvent
    ) {
        let entry = WallpaperHistoryEntry(
            id: id,
            resolution: resolution,
            category: category,
            purity: purity,
            lastEvent: event,
            updatedAt: Date()
        )

        entries.removeAll { $0.id == id }
        entries.insert(entry, at: 0)
    }
}

private struct WallpaperHistoryEntry: Codable {
    let id: String
    let resolution: String
    let category: String
    let purity: String
    let lastEvent: WallpaperHistoryEvent
    let updatedAt: Date
}

private enum WallpaperHistoryEvent: String, Codable {
    case displayed
    case setAsWallpaper
}
