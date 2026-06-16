import Foundation

struct DownloadedWallpaper: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let fileName: String
    let wallhavenID: String?
    let resolution: String?
    let fileSize: Int
    let modifiedAt: Date

    var displayName: String {
        wallhavenID.map { "#\($0)" } ?? fileName
    }

    var displayResolution: String {
        resolution ?? "-"
    }
}
