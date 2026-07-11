#include "WallpaperController.h"

#include <algorithm>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QDBusInterface>
#include <QDBusReply>

namespace {
constexpr auto kUserAgent = "WallhavenLinux/0.1 (Kubuntu Plasma)";
}

WallpaperController::WallpaperController(QObject *parent)
    : QObject(parent) {
    QSettings settings;
    m_query = settings.value("search/query").toString();
    m_category = settings.value("search/category", "general").toString();
    m_purity = settings.value("search/purity", "sfw").toString();
    m_sorting = settings.value("search/sorting", "toplist").toString();
    m_apiKey = settings.value("account/apiKey").toString();
    m_strictAspectRatio = settings.value("search/strictAspectRatio", false).toBool();
    m_downloadDirectory = settings.value("storage/downloadDirectory").toString();
    updateDisplayResolution();
    ensureDownloadDirectory();
    refreshDesktopCapability();

    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, [this] {
        updateDisplayResolution();
    });
}

QVariantList WallpaperController::wallpapers() const { return m_wallpapers; }
bool WallpaperController::searching() const { return m_searching; }
bool WallpaperController::downloading() const { return m_downloading; }
QString WallpaperController::statusMessage() const { return m_statusMessage; }
QString WallpaperController::errorMessage() const { return m_errorMessage; }
QString WallpaperController::displayResolution() const { return m_displayResolution; }
QString WallpaperController::downloadDirectory() const { return m_downloadDirectory; }
bool WallpaperController::plasmaAvailable() const { return m_plasmaAvailable; }
QString WallpaperController::section() const { return m_section; }
bool WallpaperController::canLoadMore() const { return m_section == "online" && m_currentPage < m_lastPage; }
QString WallpaperController::apiKey() const { return m_apiKey; }
bool WallpaperController::strictAspectRatio() const { return m_strictAspectRatio; }

void WallpaperController::search(
    const QString &query,
    const QString &category,
    const QString &purity,
    const QString &sorting
) {
    m_query = query.trimmed();
    m_category = category;
    m_purity = purity;
    m_sorting = sorting;
    if (m_section != "online") {
        m_section = "online";
        emit sectionChanged();
    }
    persistPreferences();
    requestSearch(true);
}

void WallpaperController::download(int index, bool setWhenFinished) {
    if (m_downloading || index < 0 || index >= m_wallpapers.size()) {
        return;
    }

    const QVariantMap wallpaper = m_wallpapers.at(index).toMap();
    const QString cachedPath = ensureDownloadDirectory() + "/wallhaven-" + wallpaper.value("id").toString()
        + "-" + wallpaper.value("resolution").toString() + "." + QFileInfo(QUrl(wallpaper.value("path").toString()).path()).suffix();
    if (QFileInfo::exists(cachedPath)) {
        if (setWhenFinished) {
            if (setPlasmaWallpaper(cachedPath)) setStatusMessage("已设为 Plasma 桌面壁纸：" + QFileInfo(cachedPath).fileName());
        } else {
            QDesktopServices::openUrl(QUrl::fromLocalFile(cachedPath));
            setStatusMessage("壁纸已下载，已在文件管理器中打开。");
        }
        return;
    }
    const QUrl url(wallpaper.value("path").toString());
    if (!url.isValid()) {
        setErrorMessage("该壁纸没有有效的下载地址。");
        return;
    }

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    request.setTransferTimeout(120'000);

    m_downloading = true;
    setErrorMessage({});
    setStatusMessage("正在下载 #" + wallpaper.value("id").toString() + "…");
    emit downloadingChanged();

    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, wallpaper, setWhenFinished] {
        handleDownloadReply(reply, wallpaper, setWhenFinished);
    });
}

void WallpaperController::setWallpaper(int index) {
    if (index < 0 || index >= m_wallpapers.size()) {
        return;
    }
    const QVariantMap wallpaper = m_wallpapers.at(index).toMap();
    if (m_section == "downloaded") {
        if (setPlasmaWallpaper(wallpaper.value("localPath").toString())) {
            setStatusMessage("已设为 Plasma 桌面壁纸：" + wallpaper.value("fileName").toString());
        }
        return;
    }
    download(index, true);
}

void WallpaperController::showSection(const QString &section) {
    if (section == "downloaded") {
        m_section = "downloaded";
        loadDownloadedWallpapers();
    } else {
        m_section = "online";
        m_wallpapers = m_onlineWallpapers;
        emit wallpapersChanged();
    }
    emit sectionChanged();
}

void WallpaperController::refresh() {
    if (m_section == "downloaded") {
        loadDownloadedWallpapers();
    } else {
        requestSearch(true);
    }
}

void WallpaperController::loadNextPage() {
    if (!canLoadMore() || m_searching) {
        return;
    }
    ++m_currentPage;
    requestSearch(false);
}

void WallpaperController::deleteDownloaded(int index) {
    if (m_section != "downloaded" || index < 0 || index >= m_wallpapers.size()) {
        return;
    }
    const QString path = m_wallpapers.at(index).toMap().value("localPath").toString();
    if (QFile::remove(path)) {
        loadDownloadedWallpapers();
        setStatusMessage("已删除下载的壁纸。");
    } else {
        setErrorMessage("无法删除文件：" + path);
    }
}

void WallpaperController::openPage(int index) {
    if (index < 0 || index >= m_wallpapers.size()) {
        return;
    }
    const QVariantMap wallpaper = m_wallpapers.at(index).toMap();
    const QString page = wallpaper.value("pageUrl").toString();
    if (!page.isEmpty()) {
        QDesktopServices::openUrl(QUrl(page));
    }
}

void WallpaperController::setApiKey(const QString &apiKey) {
    const QString normalized = apiKey.trimmed();
    if (m_apiKey == normalized) return;
    m_apiKey = normalized;
    persistPreferences();
    emit apiKeyChanged();
}

void WallpaperController::setDownloadDirectory(const QUrl &directory) {
    const QString path = directory.isLocalFile() ? directory.toLocalFile() : directory.toString();
    if (path.isEmpty()) return;
    QDir().mkpath(path);
    m_downloadDirectory = path;
    persistPreferences();
    emit downloadDirectoryChanged();
}

void WallpaperController::setStrictAspectRatio(bool enabled) {
    if (m_strictAspectRatio == enabled) return;
    m_strictAspectRatio = enabled;
    persistPreferences();
    emit strictAspectRatioChanged();
}

void WallpaperController::openDownloadDirectory() {
    const QString path = ensureDownloadDirectory();
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(path))) {
        setErrorMessage("无法打开下载目录：" + path);
    }
}

void WallpaperController::refreshDesktopCapability() {
    QDBusInterface plasma(
        "org.kde.plasmashell",
        "/PlasmaShell",
        "org.kde.PlasmaShell",
        QDBusConnection::sessionBus()
    );
    const bool available = plasma.isValid();
    if (m_plasmaAvailable != available) {
        m_plasmaAvailable = available;
        emit plasmaAvailableChanged();
    }

    if (available) {
        setStatusMessage("KDE Plasma 壁纸服务已就绪。");
    } else {
        setErrorMessage("未检测到 KDE Plasma 会话 D-Bus；请从 Plasma 桌面会话启动应用。");
    }
}

void WallpaperController::setStatusMessage(const QString &message) {
    if (m_statusMessage == message) {
        return;
    }
    m_statusMessage = message;
    emit statusMessageChanged();
}

void WallpaperController::setErrorMessage(const QString &message) {
    if (m_errorMessage == message) {
        return;
    }
    m_errorMessage = message;
    emit errorMessageChanged();
}

void WallpaperController::updateDisplayResolution() {
    const QScreen *screen = qGuiApp->primaryScreen();
    const QSize size = screen ? screen->size() : QSize(1920, 1080);
    const QString resolution = QString::number(size.width()) + "x" + QString::number(size.height());
    if (m_displayResolution != resolution) {
        m_displayResolution = resolution;
        emit displayResolutionChanged();
    }
}

void WallpaperController::handleSearchReply(QNetworkReply *reply) {
    m_searching = false;
    emit searchingChanged();

    const auto cleanup = qScopeGuard([reply] { reply->deleteLater(); });
    if (reply->error() != QNetworkReply::NoError) {
        if (m_currentPage > 1) --m_currentPage;
        setErrorMessage("搜索失败：" + reply->errorString());
        setStatusMessage({});
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(reply->readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        setErrorMessage("Wallhaven 返回了无法读取的数据。");
        setStatusMessage({});
        return;
    }

    QVariantList results;
    for (const QJsonValue &item : document.object().value("data").toArray()) {
        if (item.isObject()) {
            results.append(wallpaperFromJson(item.toObject()));
        }
    }

    const QJsonObject meta = document.object().value("meta").toObject();
    m_lastPage = meta.value("last_page").toInt(1);
    m_seed = meta.value("seed").toString();
    if (m_currentPage == 1) {
        m_onlineWallpapers = results;
    } else {
        for (const QVariant &candidate : results) {
            const QString id = candidate.toMap().value("id").toString();
            const bool duplicate = std::any_of(m_onlineWallpapers.cbegin(), m_onlineWallpapers.cend(), [&id](const QVariant &existing) {
                return existing.toMap().value("id").toString() == id;
            });
            if (!duplicate) m_onlineWallpapers.append(candidate);
        }
    }
    m_wallpapers = m_onlineWallpapers;
    emit wallpapersChanged();
    emit paginationChanged();
    setStatusMessage(QString("已加载 %1 / %2 张适合 %3 的壁纸。")
        .arg(m_onlineWallpapers.size())
        .arg(meta.value("total").toInt(m_onlineWallpapers.size()))
        .arg(m_displayResolution));
}

void WallpaperController::handleDownloadReply(
    QNetworkReply *reply,
    const QVariantMap &wallpaper,
    bool setWhenFinished
) {
    m_downloading = false;
    emit downloadingChanged();

    const auto cleanup = qScopeGuard([reply] { reply->deleteLater(); });
    if (reply->error() != QNetworkReply::NoError) {
        setErrorMessage("下载失败：" + reply->errorString());
        setStatusMessage({});
        return;
    }

    const QString directory = ensureDownloadDirectory();
    const QUrl source(wallpaper.value("path").toString());
    QString extension = QFileInfo(source.path()).suffix();
    if (extension.isEmpty()) {
        extension = "jpg";
    }
    const QString filePath = directory + "/wallhaven-" + wallpaper.value("id").toString()
        + "-" + wallpaper.value("resolution").toString() + "." + extension;

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(reply->readAll()) < 0) {
        setErrorMessage("无法保存壁纸到：" + filePath);
        setStatusMessage({});
        return;
    }
    file.close();

    if (m_section == "downloaded") {
        loadDownloadedWallpapers();
    }

    if (setWhenFinished) {
        if (setPlasmaWallpaper(filePath)) {
            setStatusMessage("已下载并设为 Plasma 桌面壁纸：" + QFileInfo(filePath).fileName());
        }
    } else {
        setStatusMessage("下载完成：" + QFileInfo(filePath).fileName());
    }
}

bool WallpaperController::setPlasmaWallpaper(const QString &filePath) {
    refreshDesktopCapability();
    if (!m_plasmaAvailable) {
        return false;
    }

    const QString imageUrl = QUrl::fromLocalFile(filePath).toString(QUrl::FullyEncoded);
    const QString script = QStringLiteral(R"(
        var allDesktops = desktops();
        for (var i = 0; i < allDesktops.length; i++) {
            var desktop = allDesktops[i];
            desktop.wallpaperPlugin = "org.kde.image";
            desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
            desktop.writeConfig("Image", "%1");
        }
    )").arg(imageUrl);

    QDBusInterface plasma(
        "org.kde.plasmashell",
        "/PlasmaShell",
        "org.kde.PlasmaShell",
        QDBusConnection::sessionBus()
    );
    const QDBusMessage reply = plasma.call("evaluateScript", script);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage("Plasma 拒绝设置壁纸：" + reply.errorMessage());
        return false;
    }
    setErrorMessage({});
    return true;
}

QString WallpaperController::ensureDownloadDirectory() {
    if (!m_downloadDirectory.isEmpty()) {
        QDir().mkpath(m_downloadDirectory);
        return m_downloadDirectory;
    }

    QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (pictures.isEmpty()) {
        pictures = QDir::homePath() + "/Pictures";
    }
    const QString path = pictures + "/WallhavenLinux";
    QDir().mkpath(path);
    m_downloadDirectory = path;
    emit downloadDirectoryChanged();
    return m_downloadDirectory;
}

QString WallpaperController::categoriesValue(const QString &category) const {
    if (category == "anime") return "010";
    if (category == "people") return "001";
    if (category == "all") return "111";
    return "100";
}

QString WallpaperController::purityValue(const QString &purity) const {
    if (purity == "sketchy") return "110";
    return "100";
}

QVariantMap WallpaperController::wallpaperFromJson(const QJsonObject &wallpaper) const {
    const QJsonObject thumbs = wallpaper.value("thumbs").toObject();
    return {
        {"id", wallpaper.value("id").toString()},
        {"path", wallpaper.value("path").toString()},
        {"pageUrl", wallpaper.value("url").toString()},
        {"thumbnail", thumbs.value("large").toString()},
        {"resolution", wallpaper.value("resolution").toString()},
        {"category", wallpaper.value("category").toString()},
        {"purity", wallpaper.value("purity").toString()},
        {"fileSize", wallpaper.value("file_size").toVariant()}
    };
}

void WallpaperController::requestSearch(bool reset) {
    if (m_searching) return;
    if (reset) {
        m_currentPage = 1;
        m_lastPage = 1;
        m_seed.clear();
    }

    QUrl url("https://wallhaven.cc/api/v1/search");
    QUrlQuery parameters;
    parameters.addQueryItem("q", m_query);
    parameters.addQueryItem("categories", categoriesValue(m_category));
    parameters.addQueryItem("purity", purityValue(m_purity));
    parameters.addQueryItem("sorting", m_sorting);
    parameters.addQueryItem("atleast", m_displayResolution);
    parameters.addQueryItem("page", QString::number(m_currentPage));
    if (!m_seed.isEmpty()) parameters.addQueryItem("seed", m_seed);
    if (m_strictAspectRatio) {
        const QStringList dimensions = m_displayResolution.split('x');
        if (dimensions.size() == 2) {
            int a = dimensions[0].toInt();
            int b = dimensions[1].toInt();
            while (b != 0) { const int remainder = a % b; a = b; b = remainder; }
            const int gcd = qMax(a, 1);
            parameters.addQueryItem("ratios", QString("%1x%2").arg(dimensions[0].toInt() / gcd).arg(dimensions[1].toInt() / gcd));
        }
    }
    if (!m_apiKey.isEmpty()) parameters.addQueryItem("apikey", m_apiKey);
    url.setQuery(parameters);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    request.setTransferTimeout(15'000);
    m_searching = true;
    setErrorMessage({});
    setStatusMessage(m_currentPage == 1 ? "正在从 Wallhaven 获取壁纸…" : "正在加载下一页壁纸…");
    emit searchingChanged();
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleSearchReply(reply); });
}

void WallpaperController::loadDownloadedWallpapers() {
    const QDir directory(ensureDownloadDirectory());
    QVariantList downloaded;
    const QFileInfoList files = directory.entryInfoList(
        {"*.jpg", "*.jpeg", "*.png", "*.webp", "*.heic", "*.tiff"},
        QDir::Files,
        QDir::Time
    );
    for (const QFileInfo &file : files) {
        const QString base = file.completeBaseName();
        const QString prefix = "wallhaven-";
        const QString remainder = base.startsWith(prefix) ? base.mid(prefix.size()) : base;
        const int separator = remainder.indexOf('-');
        const QString id = separator >= 0 ? remainder.left(separator) : remainder;
        const QString resolution = separator >= 0 ? remainder.mid(separator + 1) : "本地图片";
        downloaded.append(QVariantMap {
            {"id", id},
            {"fileName", file.fileName()},
            {"localPath", file.absoluteFilePath()},
            {"thumbnail", QUrl::fromLocalFile(file.absoluteFilePath())},
            {"resolution", resolution},
            {"category", "已下载"},
            {"purity", "本地"},
            {"pageUrl", QString("https://wallhaven.cc/w/%1").arg(id)}
        });
    }
    m_wallpapers = downloaded;
    emit wallpapersChanged();
    setErrorMessage({});
    setStatusMessage(QString("下载库中有 %1 张壁纸。").arg(downloaded.size()));
}

void WallpaperController::persistPreferences() {
    QSettings settings;
    settings.setValue("search/query", m_query);
    settings.setValue("search/category", m_category);
    settings.setValue("search/purity", m_purity);
    settings.setValue("search/sorting", m_sorting);
    settings.setValue("search/strictAspectRatio", m_strictAspectRatio);
    settings.setValue("storage/downloadDirectory", m_downloadDirectory);
    settings.setValue("account/apiKey", m_apiKey);
}
