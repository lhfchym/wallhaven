import Foundation
import WallhavenCore

@MainActor
final class WallpaperGalleryViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var display: DisplayProfile
    @Published private(set) var wallpapers: [WallhavenWallpaper] = []
    @Published var selectedWallpaper: WallhavenWallpaper?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var meta: WallhavenMeta?

    private let client: WallhavenFetching
    private var currentPage = 1
    private var currentSeed: String?

    init(
        client: WallhavenFetching = WallhavenClient(),
        display: DisplayProfile = DisplayProfileProvider.current()
    ) {
        self.client = client
        self.display = display
    }

    var canLoadMore: Bool {
        guard let meta else { return false }
        return meta.currentPage < meta.lastPage
    }

    var statusText: String {
        if let meta {
            return "\(wallpapers.count) of \(meta.total) - \(display.resolutionQuery) - \(display.aspectRatioQuery)"
        }

        return "\(display.resolutionQuery) - \(display.aspectRatioQuery)"
    }

    func refreshDisplay() {
        display = DisplayProfileProvider.current()
    }

    func loadInitialWallpapers() {
        guard wallpapers.isEmpty, !isLoading else { return }

        Task {
            await load(reset: true)
        }
    }

    func refresh() {
        Task {
            await load(reset: true)
        }
    }

    func submitSearch() {
        Task {
            await load(reset: true)
        }
    }

    func loadNextPage() {
        guard canLoadMore, !isLoading else { return }

        Task {
            await load(reset: false)
        }
    }

    func select(_ wallpaper: WallhavenWallpaper) {
        selectedWallpaper = wallpaper
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil

        if reset {
            refreshDisplay()
            currentPage = 1
            currentSeed = nil
        } else {
            currentPage += 1
        }

        let request = WallpaperSearchRequest(
            preferences: WallpaperSearchPreferences(query: query.trimmingCharacters(in: .whitespacesAndNewlines)),
            display: display,
            page: currentPage,
            seed: currentSeed
        )

        do {
            let response = try await client.search(request)
            meta = response.meta
            currentSeed = response.meta.seed

            if reset {
                wallpapers = response.data
                selectedWallpaper = response.data.first
            } else {
                wallpapers.append(contentsOf: response.data.filter { candidate in
                    !wallpapers.contains(where: { $0.id == candidate.id })
                })
            }
        } catch {
            if !reset {
                currentPage = max(currentPage - 1, 1)
            }
            errorMessage = readableMessage(for: error)
        }

        isLoading = false
    }

    private func readableMessage(for error: Error) -> String {
        if let clientError = error as? WallhavenClientError {
            switch clientError {
            case .unexpectedResponse:
                return "Unexpected wallhaven response."
            case let .unexpectedStatus(statusCode):
                return "wallhaven returned HTTP \(statusCode)."
            }
        }

        return error.localizedDescription
    }
}
