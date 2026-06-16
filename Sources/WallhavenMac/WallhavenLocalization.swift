import Foundation
import WallhavenCore

struct WallhavenCopy {
    let language: WallhavenLanguage

    var settingsTitle: String { text(chinese: "设置", english: "Settings") }
    var languageTitle: String { text(chinese: "语言", english: "Language") }
    var apiKeyPlaceholder: String { text(chinese: "wallhaven API key", english: "wallhaven API key") }
    var apiKeyHelp: String {
        text(
            chinese: "存储在 macOS 钥匙串。NSFW 结果和账户相关 wallhaven 设置需要 API Key。",
            english: "Stored in macOS Keychain. Required for NSFW results and account-specific wallhaven settings."
        )
    }

    var downloadFolderTitle: String { text(chinese: "下载文件夹", english: "Download Folder") }
    var defaultDownloadFolder: String { text(chinese: "默认 图片/WallhavenMac", english: "Default Pictures/WallhavenMac") }
    var choose: String { text(chinese: "选择...", english: "Choose...") }
    var choosePanelPrompt: String { text(chinese: "选择", english: "Choose") }
    var useDefault: String { text(chinese: "默认", english: "Default") }
    var strictAspectRatio: String { text(chinese: "严格比例匹配", english: "Strict aspect ratio") }
    var strictAspectRatioHelp: String {
        text(
            chinese: "开启后，只搜索与当前显示器精确比例匹配的壁纸。",
            english: "When enabled, searches only return wallpapers matching this display's exact ratio."
        )
    }

    var cancel: String { text(chinese: "取消", english: "Cancel") }
    var save: String { text(chinese: "保存", english: "Save") }
    var searchPlaceholder: String { text(chinese: "今日搜索热门\"地球\"", english: "Search wallpapers") }
    var hottest: String { text(chinese: "最热", english: "Top") }
    var latest: String { text(chinese: "最新", english: "Latest") }
    var favoriteRanking: String { text(chinese: "收藏排行", english: "Favorites") }
    var downloaded: String { text(chinese: "已下载", english: "Downloaded") }
    var downloadedWallpapersTitle: String { text(chinese: "已下载壁纸", english: "Downloaded Wallpapers") }
    var noDownloadedWallpapers: String { text(chinese: "没有已下载壁纸", english: "No Downloaded Wallpapers") }
    var emptyDownloadedHelp: String {
        text(chinese: "下载过的壁纸会显示在这里。", english: "Downloaded wallpapers will appear here.")
    }

    var downloadedStatus: String { text(chinese: "已下载", english: "Downloaded") }
    var showInFinder: String { text(chinese: "在 Finder 中显示", english: "Reveal in Finder") }
    var openDownloadFolder: String { text(chinese: "打开下载文件夹", english: "Open Download Folder") }
    var categoryAndPurity: String { text(chinese: "分类&色调", english: "Category & Purity") }
    var category: String { text(chinese: "分类", english: "Category") }
    var purity: String { text(chinese: "色调", english: "Purity") }
    var sorting: String { text(chinese: "排序", english: "Sorting") }
    var refreshing: String { text(chinese: "刷新中...", english: "Refreshing...") }
    var refreshData: String { text(chinese: "刷新数据", english: "Refresh Data") }
    var apiKeyConfigured: String { text(chinese: "API Key 已配置", english: "API Key configured") }
    var settingsHelp: String { text(chinese: "设置", english: "Settings") }
    var loadingWallpapers: String { text(chinese: "正在加载壁纸", english: "Loading Wallpapers") }
    var noWallpapers: String { text(chinese: "没有壁纸", english: "No Wallpapers") }
    var emptyGalleryHelp: String { text(chinese: "换个关键词或者刷新试试。", english: "Try another search or refresh.") }
    var refresh: String { text(chinese: "刷新", english: "Refresh") }
    var nextPage: String { text(chinese: "下一页", english: "Next Page") }
    var loadingMoreWallpapers: String { text(chinese: "正在加载更多壁纸...", english: "Loading more wallpapers...") }
    var scrollToLoadMore: String { text(chinese: "继续滚动加载", english: "Scroll to load more") }
    var displayPreviewTitle: String { text(chinese: "显示器结构预览", english: "Display Preview") }
    var builtInDisplay: String { text(chinese: "内建视网膜显示器", english: "Built-in Retina Display") }
    var selectedWallpaper: String { text(chinese: "选中的壁纸", english: "Selected Wallpaper") }
    var download: String { text(chinese: "下载", english: "Download") }
    var revealInFinder: String { text(chinese: "在 Finder 中显示", english: "Reveal in Finder") }
    var settingWallpaper: String { text(chinese: "设置中...", english: "Setting...") }
    var setWallpaper: String { text(chinese: "设置为壁纸", english: "Set Wallpaper") }
    var openPage: String { text(chinese: "打开页面", english: "Open Page") }
    var selectWallpaper: String { text(chinese: "选择一张壁纸", english: "Select a wallpaper") }
    var selectWallpaperFromGallery: String { text(chinese: "从中间选择一张壁纸", english: "Select a wallpaper from the gallery")
    }

    var feedback: String { text(chinese: "意见反馈", english: "Feedback") }
    var openedDownloadFolder: String { text(chinese: "已打开下载文件夹。", english: "Opened download folder.") }
    var openFolderFailedPrefix: String { text(chinese: "打开文件夹失败：", english: "Open folder failed: ") }
    var deleteDownloadedFailedPrefix: String { text(chinese: "移到废纸篓失败：", english: "Move to Trash failed: ") }
    var deletedDownloadedWallpaper: String { text(chinese: "已移到废纸篓。", english: "Moved to Trash.") }
    var loadedDownloadedFailedPrefix: String { text(
        chinese: "读取已下载壁纸失败：",
        english: "Load downloaded wallpapers failed: "
    ) }
    var downloadSucceededPrefix: String { text(chinese: "下载成功：", english: "Download succeeded: ") }
    var downloadSucceededIDPrefix: String { text(chinese: "下载成功：#", english: "Download succeeded: #") }
    var downloadFailedPrefix: String { text(chinese: "下载失败：", english: "Download failed: ") }
    var setWallpaperFailedPrefix: String { text(chinese: "设置壁纸失败：", english: "Set wallpaper failed: ") }

    func status(count: Int, total: Int, displayMatchingStatus: String) -> String {
        switch language {
        case .chinese:
            "\(count) / \(total) - \(displayMatchingStatus)"
        case .english:
            "\(count) of \(total) - \(displayMatchingStatus)"
        }
    }

    func downloadedStatus(count: Int) -> String {
        switch language {
        case .chinese:
            "\(count) 张已下载壁纸"
        case .english:
            "\(count) downloaded wallpapers"
        }
    }

    func setWallpaperSucceeded(id: String) -> String {
        text(chinese: "已将 #\(id) 设置为壁纸。", english: "Set #\(id) as wallpaper.")
    }

    func categoryLabel(_ category: WallhavenCategoryPreset) -> String {
        switch (language, category) {
        case (.chinese, .general):
            "普通"
        case (.chinese, .anime):
            "动漫"
        case (.chinese, .people):
            "人物"
        case (.chinese, .all):
            "全部"
        case (.english, .general):
            "General"
        case (.english, .anime):
            "Anime"
        case (.english, .people):
            "People"
        case (.english, .all):
            "All"
        }
    }

    func purityLabel(_ purity: WallhavenPurityPreset) -> String {
        switch (language, purity) {
        case (.chinese, .sfw):
            "安全"
        case (.chinese, .sfwSketchy):
            "安全+擦边"
        case (.chinese, .all):
            "全部"
        case (.english, .sfw):
            "SFW"
        case (.english, .sfwSketchy):
            "SFW+Sketchy"
        case (.english, .all):
            "All"
        }
    }

    func sortingLabel(_ sorting: WallhavenSorting) -> String {
        switch (language, sorting) {
        case (.chinese, .dateAdded):
            "最新"
        case (.chinese, .favorites):
            "收藏排行"
        case (.chinese, .random):
            "随机"
        case (.chinese, .relevance):
            "相关度"
        case (.chinese, .toplist):
            "最热"
        case (.chinese, .views):
            "浏览量"
        case (.english, .dateAdded):
            "Latest"
        case (.english, .favorites):
            "Favorites"
        case (.english, .random):
            "Random"
        case (.english, .relevance):
            "Relevance"
        case (.english, .toplist):
            "Toplist"
        case (.english, .views):
            "Views"
        }
    }

    private func text(chinese: String, english: String) -> String {
        switch language {
        case .chinese:
            chinese
        case .english:
            english
        }
    }
}
