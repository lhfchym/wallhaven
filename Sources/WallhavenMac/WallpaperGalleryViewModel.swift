import AppKit
import Foundation
import WallhavenCore

@MainActor
final class WallpaperGalleryViewModel: ObservableObject {
    @Published private(set) var selectedSection: WallpaperGallerySection = .online
    @Published var query = ""
    @Published private(set) var display: DisplayProfile
    @Published private(set) var wallpapers: [WallhavenWallpaper] = []
    @Published private(set) var downloadedWallpapers: [DownloadedWallpaper] = []
    @Published var selectedWallpaper: WallhavenWallpaper?
    @Published var selectedDownloadedWallpaper: DownloadedWallpaper?
    @Published private(set) var isLoading = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isSettingWallpaper = false
    @Published private(set) var isDeletingDownloadedWallpaper = false
    @Published private(set) var downloadedWallpaperURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    @Published private(set) var meta: WallhavenMeta?
    @Published private(set) var preferences = WallhavenUserPreferences()
    @Published private(set) var downloadDirectoryURL: URL?

    private let client: WallhavenFetching
    private let fileStore: WallpaperFileStoring
    private let wallpaperSetter: DesktopWallpaperSetting
    private let historyStore: WallpaperHistoryStoring
    private let preferencesStore: WallhavenUserPreferencesStoring
    private var currentPage = 1
    private var currentSeed: String?

    init(
        client: WallhavenFetching = WallhavenClient(),
        fileStore: WallpaperFileStoring = WallpaperFileStore(),
        wallpaperSetter: DesktopWallpaperSetting = DesktopWallpaperSetter(),
        historyStore: WallpaperHistoryStoring = WallpaperHistoryStore(),
        preferencesStore: WallhavenUserPreferencesStoring = WallhavenUserPreferencesStore(),
        display: DisplayProfile = DisplayProfileProvider.current()
    ) {
        self.client = client
        self.fileStore = fileStore
        self.wallpaperSetter = wallpaperSetter
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.display = display
    }

    var canLoadMore: Bool {
        guard selectedSection == .online else { return false }
        guard let meta else { return false }
        return meta.currentPage < meta.lastPage
    }

    var statusText: String {
        if selectedSection == .downloaded {
            return copy.downloadedStatus(count: downloadedWallpapers.count)
        }

        if let meta {
            return copy.status(
                count: wallpapers.count,
                total: meta.total,
                displayMatchingStatus: displayMatchingStatus
            )
        }

        return displayMatchingStatus
    }

    func refreshDisplay() {
        display = DisplayProfileProvider.current()
    }

    func loadInitialWallpapers() {
        guard wallpapers.isEmpty, !isLoading else { return }

        Task {
            preferences = await preferencesStore.load()
            query = preferences.query
            await configureDownloadDirectory()
            await load(reset: true)
        }
    }

    func refresh() {
        guard selectedSection == .online else {
            startLoadingDownloadedWallpapers()
            return
        }

        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    func submitSearch() {
        selectedSection = .online
        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    func updateCategory(_ category: WallhavenCategoryPreset) {
        selectedSection = .online
        preferences.categories = category
        savePreferencesAndReload()
    }

    func updatePurity(_ purity: WallhavenPurityPreset) {
        selectedSection = .online
        preferences.purity = purity
        savePreferencesAndReload()
    }

    func updateSorting(_ sorting: WallhavenSorting) {
        selectedSection = .online
        preferences.sorting = sorting
        savePreferencesAndReload()
    }

    func updateAPIKey(_ apiKey: String) {
        preferences.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await preferencesStore.save(preferences)
        }
    }

    func updateSettings(
        apiKey: String,
        downloadDirectoryPath: String?,
        strictAspectRatio: Bool,
        language: WallhavenLanguage
    ) {
        preferences.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.downloadDirectoryPath = downloadDirectoryPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChangeAspectRatioMode = preferences.strictAspectRatio != strictAspectRatio
        preferences.strictAspectRatio = strictAspectRatio
        preferences.language = language

        Task {
            await saveCurrentPreferences()
            await configureDownloadDirectory()

            if let selectedWallpaper {
                downloadedWallpaperURL = await fileStore.cachedURL(for: selectedWallpaper)
            } else {
                downloadedWallpaperURL = nil
            }

            if didChangeAspectRatioMode {
                await load(reset: true)
            }
        }
    }

    func openDownloadDirectory() {
        Task {
            do {
                let directoryURL = try await fileStore.ensureDownloadDirectory()
                downloadDirectoryURL = directoryURL
                NSWorkspace.shared.open(directoryURL)
                successMessage = copy.openedDownloadFolder
                errorMessage = nil
            } catch {
                successMessage = nil
                errorMessage = "\(copy.openFolderFailedPrefix)\(readableMessage(for: error))"
                WallhavenDebugLog.recordError(
                    "Open download folder failed",
                    error: error,
                    details: ["directory": downloadDirectoryURL?.path ?? "unknown"]
                )
            }
        }
    }

    func showDownloadedWallpapers() {
        selectedSection = .downloaded
        errorMessage = nil
        successMessage = nil
        startLoadingDownloadedWallpapers()
    }

    func loadNextPage() {
        guard selectedSection == .online, canLoadMore, !isLoading else { return }

        Task {
            await load(reset: false)
        }
    }

    func select(_ wallpaper: WallhavenWallpaper) {
        selectedSection = .online
        selectedWallpaper = wallpaper
        downloadedWallpaperURL = nil
        successMessage = nil
        updateCachedDownloadStatus(for: wallpaper)
    }

    func select(_ wallpaper: DownloadedWallpaper) {
        selectedSection = .downloaded
        selectedDownloadedWallpaper = wallpaper
        successMessage = nil
        errorMessage = nil
    }

    func downloadSelectedWallpaper() {
        guard let selectedWallpaper, !isDownloading else { return }

        Task {
            await download(wallpaper: selectedWallpaper)
        }
    }

    func setSelectedWallpaper() {
        guard let selectedWallpaper, !isSettingWallpaper else { return }

        Task {
            await setWallpaper(selectedWallpaper)
        }
    }

    func setSelectedDownloadedWallpaper() {
        guard let selectedDownloadedWallpaper, !isSettingWallpaper else { return }

        Task {
            await setDownloadedWallpaper(selectedDownloadedWallpaper)
        }
    }

    func revealSelectedDownloadedWallpaper() {
        guard let selectedDownloadedWallpaper else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedDownloadedWallpaper.url])
    }

    func deleteDownloadedWallpaper(_ wallpaper: DownloadedWallpaper) {
        guard !isDeletingDownloadedWallpaper else { return }

        Task {
            await deleteDownloaded(wallpaper)
        }
    }
}

private extension WallpaperGalleryViewModel {
    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        if reset {
            refreshDisplay()
            currentPage = 1
            currentSeed = nil
        } else {
            currentPage += 1
        }

        let request = WallpaperSearchRequest(
            preferences: WallpaperSearchPreferences(
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                categories: preferences.categories.categories,
                purity: preferences.purity.purity,
                sorting: preferences.sorting,
                strictAspectRatio: preferences.strictAspectRatio
            ),
            display: display,
            page: currentPage,
            seed: currentSeed
        )

        do {
            let response = try await client.search(request, apiKey: preferences.apiKey)
            let displayWallpapers = await prioritizedWallpapers(from: response.data)
            meta = response.meta
            currentSeed = response.meta.seed

            if reset {
                wallpapers = displayWallpapers
                selectedWallpaper = displayWallpapers.first
                if let selectedWallpaper {
                    downloadedWallpaperURL = await fileStore.cachedURL(for: selectedWallpaper)
                } else {
                    downloadedWallpaperURL = nil
                }
            } else {
                wallpapers.append(contentsOf: displayWallpapers.filter { candidate in
                    !wallpapers.contains(where: { $0.id == candidate.id })
                })
            }

            await historyStore.recordDisplayed(displayWallpapers)
        } catch {
            if !reset {
                currentPage = max(currentPage - 1, 1)
            }
            errorMessage = readableMessage(for: error)
            logSearchFailure(error, request: request, reset: reset)
        }

        isLoading = false
    }

    private func download(wallpaper: WallhavenWallpaper) async {
        isDownloading = true
        errorMessage = nil
        successMessage = nil

        do {
            downloadedWallpaperURL = try await fileStore.downloadedURL(for: wallpaper)
            await refreshDownloadedWallpapersIfNeeded()
            if let downloadedWallpaperURL {
                successMessage = "\(copy.downloadSucceededPrefix)\(downloadedWallpaperURL.lastPathComponent)"
            } else {
                successMessage = "\(copy.downloadSucceededIDPrefix)\(wallpaper.id)."
            }
        } catch {
            errorMessage = "\(copy.downloadFailedPrefix)\(readableMessage(for: error))"
            WallhavenDebugLog.recordError(
                "Wallpaper download failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isDownloading = false
    }

    private func setDownloadedWallpaper(_ wallpaper: DownloadedWallpaper) async {
        isSettingWallpaper = true
        errorMessage = nil
        successMessage = nil

        do {
            try wallpaperSetter.setDesktopWallpaper(at: wallpaper.url)
            successMessage = copy.setWallpaperSucceeded(id: wallpaper.wallhavenID ?? wallpaper.fileName)
        } catch {
            errorMessage = "\(copy.setWallpaperFailedPrefix)\(readableMessage(for: error))"
            WallhavenDebugLog.recordError(
                "Set downloaded wallpaper failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isSettingWallpaper = false
    }

    private func setWallpaper(_ wallpaper: WallhavenWallpaper) async {
        isSettingWallpaper = true
        errorMessage = nil
        successMessage = nil

        do {
            let imageURL: URL
            if let downloadedWallpaperURL {
                imageURL = downloadedWallpaperURL
            } else {
                isDownloading = true
                imageURL = try await fileStore.downloadedURL(for: wallpaper)
                downloadedWallpaperURL = imageURL
                isDownloading = false
                await refreshDownloadedWallpapersIfNeeded()
            }

            try wallpaperSetter.setDesktopWallpaper(at: imageURL)
            await historyStore.recordSet(wallpaper)
            successMessage = copy.setWallpaperSucceeded(id: wallpaper.id)
        } catch {
            isDownloading = false
            errorMessage = "\(copy.setWallpaperFailedPrefix)\(readableMessage(for: error))"
            WallhavenDebugLog.recordError(
                "Set desktop wallpaper failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isSettingWallpaper = false
    }

    private func startLoadingDownloadedWallpapers() {
        Task {
            await loadDownloadedWallpapers()
        }
    }

    private func loadDownloadedWallpapers() async {
        isLoading = true
        errorMessage = nil

        do {
            let wallpapers = try await fileStore.downloadedWallpapers()
            downloadedWallpapers = wallpapers

            if let selectedDownloadedWallpaper,
               let updatedSelection = wallpapers.first(where: { $0.id == selectedDownloadedWallpaper.id })
            {
                self.selectedDownloadedWallpaper = updatedSelection
            } else {
                selectedDownloadedWallpaper = wallpapers.first
            }
        } catch {
            downloadedWallpapers = []
            selectedDownloadedWallpaper = nil
            errorMessage = "\(copy.loadedDownloadedFailedPrefix)\(readableMessage(for: error))"
            WallhavenDebugLog.recordError(
                "Load downloaded wallpapers failed",
                error: error,
                details: ["directory": downloadDirectoryURL?.path ?? "unknown"]
            )
        }

        isLoading = false
    }

    private func refreshDownloadedWallpapersIfNeeded() async {
        guard selectedSection == .downloaded else { return }
        await loadDownloadedWallpapers()
    }

    private func deleteDownloaded(_ wallpaper: DownloadedWallpaper) async {
        isDeletingDownloadedWallpaper = true
        errorMessage = nil
        successMessage = nil

        do {
            try await fileStore.deleteDownloadedWallpaper(wallpaper)
            successMessage = copy.deletedDownloadedWallpaper

            let wallpapers = try await fileStore.downloadedWallpapers()
            downloadedWallpapers = wallpapers
            if selectedDownloadedWallpaper?.id == wallpaper.id {
                selectedDownloadedWallpaper = wallpapers.first
            }
        } catch {
            errorMessage = "\(copy.deleteDownloadedFailedPrefix)\(readableMessage(for: error))"
            WallhavenDebugLog.recordError(
                "Delete downloaded wallpaper failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isDeletingDownloadedWallpaper = false
    }

    private func prioritizedWallpapers(from candidates: [WallhavenWallpaper]) async -> [WallhavenWallpaper] {
        let recentIDs = await historyStore.recentWallpaperIDs()
        return WallpaperDisplayPrioritizer.prioritize(candidates, display: display, recentIDs: recentIDs)
    }

    private func savePreferencesAndReload() {
        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    private func saveCurrentPreferences() async {
        preferences.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await preferencesStore.save(preferences)
    }

    func configureDownloadDirectory() async {
        await fileStore.setDownloadDirectory(preferences.downloadDirectoryURL)
        downloadDirectoryURL = await fileStore.downloadDirectory()
    }

    var copy: WallhavenCopy {
        WallhavenCopy(language: preferences.language)
    }

    var displayMatchingStatus: String {
        if preferences.strictAspectRatio {
            return "\(display.resolutionQuery) - \(display.aspectRatioQuery)"
        }

        return "\(display.resolutionQuery) - high-res crop fit"
    }

    func updateCachedDownloadStatus(for wallpaper: WallhavenWallpaper) {
        Task {
            let cachedURL = await fileStore.cachedURL(for: wallpaper)

            guard selectedWallpaper?.id == wallpaper.id else { return }

            downloadedWallpaperURL = cachedURL
        }
    }

    func readableMessage(for error: Error) -> String {
        if let clientError = error as? WallhavenClientError {
            switch clientError {
            case .unexpectedResponse:
                return "Unexpected wallhaven response."
            case let .unexpectedStatus(statusCode):
                return "wallhaven returned HTTP \(statusCode)."
            case let .curlFailed(message):
                return message
            }
        }

        if let fileStoreError = error as? WallpaperFileStoreError {
            switch fileStoreError {
            case .unexpectedResponse:
                return "Unexpected image download response."
            case let .unexpectedStatus(statusCode):
                return "Image download returned HTTP \(statusCode)."
            case let .curlFailed(message):
                return "Image download failed: \(message)"
            }
        }

        return error.localizedDescription
    }

    func logSearchFailure(_ error: Error, request: WallpaperSearchRequest, reset: Bool) {
        WallhavenDebugLog.recordError(
            "Wallpaper search failed",
            error: error,
            details: [
                "categories": preferences.categories.rawValue,
                "display_aspect": display.aspectRatioQuery,
                "display_resolution": display.resolutionQuery,
                "has_api_key": preferences.apiKey.isEmpty ? "false" : "true",
                "page": "\(currentPage)",
                "purity": preferences.purity.rawValue,
                "query": request.preferences.query,
                "request_url_without_api_key": request.url(apiKey: nil).absoluteString,
                "reset": "\(reset)",
                "sorting": preferences.sorting.rawValue,
                "strict_aspect_ratio": "\(preferences.strictAspectRatio)"
            ]
        )
    }

    func details(for wallpaper: WallhavenWallpaper) -> [String: String] {
        [
            "category": wallpaper.category,
            "download_directory": downloadDirectoryURL?.path ?? "unknown",
            "file_size": "\(wallpaper.fileSize)",
            "file_type": wallpaper.fileType,
            "id": wallpaper.id,
            "path": wallpaper.path.absoluteString,
            "purity": wallpaper.purity,
            "resolution": wallpaper.resolution,
            "thumb_large": wallpaper.thumbs.large.absoluteString,
            "thumb_original": wallpaper.thumbs.original.absoluteString,
            "thumb_small": wallpaper.thumbs.small.absoluteString
        ]
    }

    func details(for wallpaper: DownloadedWallpaper) -> [String: String] {
        [
            "file_name": wallpaper.fileName,
            "file_size": "\(wallpaper.fileSize)",
            "id": wallpaper.id,
            "path": wallpaper.url.path,
            "resolution": wallpaper.resolution ?? "unknown",
            "wallhaven_id": wallpaper.wallhavenID ?? "unknown"
        ]
    }
}

enum WallpaperGallerySection {
    case online
    case downloaded
}
