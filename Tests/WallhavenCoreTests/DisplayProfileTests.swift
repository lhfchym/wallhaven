import Foundation
import Testing

@testable import WallhavenCore

@Test func displayProfileBuildsWallhavenQueries() {
    let display = DisplayProfile(width: 1512, height: 982, scale: 2)

    #expect(display.resolutionQuery == "3024x1964")
    #expect(display.aspectRatioQuery == "756x491")
}

@Test func searchRequestIncludesDisplayMatchingParameters() {
    let request = WallpaperSearchRequest(
        preferences: WallpaperSearchPreferences(query: "city night"),
        display: DisplayProfile(width: 1920, height: 1080)
    )

    let url = request.url()
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = Dictionary(uniqueKeysWithValues: components?.queryItems?
        .map { ($0.name, $0.value ?? "") } ?? []
    )

    #expect(queryItems["q"] == "city night")
    #expect(queryItems["categories"] == "100")
    #expect(queryItems["purity"] == "100")
    #expect(queryItems["sorting"] == "random")
    #expect(queryItems["ratios"] == "16x9")
    #expect(queryItems["atleast"] == "1920x1080")
}
