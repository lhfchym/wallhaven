import Foundation
import Testing

@testable import WallhavenCore

@Test func displayProfileBuildsWallhavenQueries() {
    let display = DisplayProfile(width: 1512, height: 982, scale: 2)

    #expect(display.resolutionQuery == "3024x1964")
    #expect(display.aspectRatioQuery == "756x491")
}

@Test func searchRequestIncludesDisplayResolutionByDefault() {
    let request = WallpaperSearchRequest(
        preferences: WallpaperSearchPreferences(query: "city night"),
        display: DisplayProfile(width: 1920, height: 1080),
        page: 2,
        seed: "abc123"
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
    #expect(queryItems["ratios"] == nil)
    #expect(queryItems["atleast"] == "1920x1080")
    #expect(queryItems["page"] == "2")
    #expect(queryItems["seed"] == "abc123")
}

@Test func searchRequestIncludesRatioWhenStrictAspectRatioIsEnabled() {
    let request = WallpaperSearchRequest(
        preferences: WallpaperSearchPreferences(strictAspectRatio: true),
        display: DisplayProfile(width: 1920, height: 1080)
    )

    let url = request.url()
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = Dictionary(uniqueKeysWithValues: components?.queryItems?
        .map { ($0.name, $0.value ?? "") } ?? []
    )

    #expect(queryItems["ratios"] == "16x9")
    #expect(queryItems["atleast"] == "1920x1080")
}

@Test func searchResponseDecodesObjectQueryAsNil() throws {
    let json = """
    {
      "data": [],
      "meta": {
        "current_page": 1,
        "last_page": 1,
        "per_page": 24,
        "total": 0,
        "query": { "id": 1, "tag": "anime" },
        "seed": "abc123"
      }
    }
    """

    let response = try JSONDecoder().decode(WallhavenSearchResponse.self, from: Data(json.utf8))

    #expect(response.meta.query == nil)
    #expect(response.meta.seed == "abc123")
}

@Test func searchResponseSkipsMalformedWallpaperItems() throws {
    let data = Data(searchResponseWithMalformedWallpaperJSON.utf8)
    let response = try JSONDecoder().decode(WallhavenSearchResponse.self, from: data)

    #expect(response.data.map(\.id) == ["good"])
    #expect(response.meta.total == 2)
}

private let searchResponseWithMalformedWallpaperJSON = """
{
  "data": [
    {
      "id": "bad-url",
      "url": 42,
      "short_url": "https://whvn.cc/bad",
      "views": 1,
      "favorites": 2,
      "source": "",
      "purity": "sfw",
      "category": "general",
      "dimension_x": 3000,
      "dimension_y": 1943,
      "resolution": "3000x1943",
      "ratio": "1.54",
      "file_size": 1024,
      "file_type": "image/jpeg",
      "created_at": "2026-05-06 00:00:00",
      "colors": ["#ffffff"],
      "path": "https://w.wallhaven.cc/full/ba/wallhaven-bad.jpg",
      "thumbs": {
        "large": "https://th.wallhaven.cc/lg/ba/bad.jpg",
        "original": "https://th.wallhaven.cc/orig/ba/bad.jpg",
        "small": "https://th.wallhaven.cc/small/ba/bad.jpg"
      }
    },
    {
      "id": "good",
      "url": "https://wallhaven.cc/w/good",
      "short_url": "https://whvn.cc/good",
      "views": 1,
      "favorites": 2,
      "source": "",
      "purity": "sfw",
      "category": "general",
      "dimension_x": 3000,
      "dimension_y": 1943,
      "resolution": "3000x1943",
      "ratio": "1.54",
      "file_size": 1024,
      "file_type": "image/jpeg",
      "created_at": "2026-05-06 00:00:00",
      "colors": ["#ffffff"],
      "path": "https://w.wallhaven.cc/full/go/wallhaven-good.jpg",
      "thumbs": {
        "large": "https://th.wallhaven.cc/lg/go/good.jpg",
        "original": "https://th.wallhaven.cc/orig/go/good.jpg",
        "small": "https://th.wallhaven.cc/small/go/good.jpg"
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 24,
    "total": 2,
    "seed": "abc123"
  }
}
"""
