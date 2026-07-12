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
#include <QProcess>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrlQuery>
#include <QWindow>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusUnixFileDescriptor>
#include <KWallet>

namespace {
constexpr auto kUserAgent = "WallhavenLinux/0.1 (Kubuntu Plasma)";
constexpr qint64 kMaximumDownloadBytes = 100 * 1024 * 1024;

QString safeFileComponent(const QString &value, const QString &fallback) {
    QString result;
    for (const QChar character : value) {
        if (character.isLetterOrNumber() || character == '-' || character == '_') result.append(character);
    }
    return result.isEmpty() ? fallback : result;
}

QString wallpaperFilePath(const QString &directory, const QVariantMap &wallpaper) {
    const QUrl source(wallpaper.value("path").toString());
    QString extension = safeFileComponent(QFileInfo(source.path()).suffix().toLower(), "jpg");
    if (extension.size() > 5) extension = "jpg";
    return directory + "/wallhaven-" + safeFileComponent(wallpaper.value("id").toString(), "unknown")
        + "-" + safeFileComponent(wallpaper.value("resolution").toString(), "image") + "." + extension;
}
}

WallpaperController::WallpaperController(QObject *parent)
    : QObject(parent) {
    QSettings settings;
    m_query = settings.value("search/query").toString();
    m_category = settings.value("search/category", "general").toString();
    m_purity = settings.value("search/purity", "sfw").toString();
    m_sorting = settings.value("search/sorting", "toplist").toString();
    m_legacyApiKey = settings.value("account/apiKey").toString();
    m_strictAspectRatio = settings.value("search/strictAspectRatio", false).toBool();
    m_downloadDirectory = settings.value("storage/downloadDirectory").toString();
    m_language = settings.value("ui/language", "zh-Hans").toString();
    updateDisplayResolution();
    ensureDownloadDirectory();
    refreshDesktopCapability();

    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, [this] {
        updateDisplayResolution();
    });
    connect(qGuiApp, &QGuiApplication::screenAdded, this, [this](QScreen *) {
        updateDisplayResolution();
    });
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, [this](QScreen *) {
        updateDisplayResolution();
    });
    // KWallet may show an unlock dialog. Defer it until Qt has created the window and event loop.
    QTimer::singleShot(0, this, &WallpaperController::loadApiKeyFromKWallet);
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
QString WallpaperController::language() const { return m_language; }

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
    const QString directory = ensureDownloadDirectory();
    if (directory.isEmpty()) return;
    const QString cachedPath = wallpaperFilePath(directory, wallpaper);
    if (QFileInfo::exists(cachedPath)) {
        if (setWhenFinished) {
            setWallpaperFile(cachedPath);
        } else {
            QDesktopServices::openUrl(QUrl::fromLocalFile(cachedPath));
            setStatusMessage(localized("壁纸已下载，已在文件管理器中打开。", "Wallpaper is already downloaded and was opened in the file manager."));
        }
        return;
    }
    const QUrl url(wallpaper.value("path").toString());
    if (!url.isValid()) {
        setErrorMessage(localized("该壁纸没有有效的下载地址。", "This wallpaper has no valid download URL."));
        return;
    }

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    request.setTransferTimeout(120'000);

    m_downloading = true;
    setErrorMessage({});
    setStatusMessage(localized("正在下载 #", "Downloading #") + wallpaper.value("id").toString() + "…");
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
        setWallpaperFile(wallpaper.value("localPath").toString());
        return;
    }
    download(index, true);
}

void WallpaperController::showSection(const QString &section) {
    if (section == "downloaded") {
        cancelActiveSearch();
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
    requestSearch(false);
}

void WallpaperController::deleteDownloaded(int index) {
    if (m_section != "downloaded" || index < 0 || index >= m_wallpapers.size()) {
        return;
    }
    const QString path = m_wallpapers.at(index).toMap().value("localPath").toString();
    if (QFile::remove(path)) {
        loadDownloadedWallpapers();
        setStatusMessage(localized("已删除下载的壁纸。", "Downloaded wallpaper deleted."));
    } else {
        setErrorMessage(localized("无法删除文件：", "Cannot delete file: ") + path);
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
    saveApiKeyToKWallet();
}

void WallpaperController::setDownloadDirectory(const QUrl &directory) {
    const QString path = directory.isLocalFile() ? directory.toLocalFile() : directory.toString();
    if (path.isEmpty()) return;
    if (!QDir().mkpath(path) || !QFileInfo(path).isDir() || !QFileInfo(path).isWritable()) {
        setErrorMessage(localized("下载目录不可创建或不可写：", "The download folder cannot be created or written: ") + path);
        return;
    }
    m_downloadDirectory = path;
    persistPreferences();
    emit downloadDirectoryChanged();
}

void WallpaperController::chooseDownloadDirectory() {
    auto *dialog = new QProcess(this);
    connect(dialog, &QProcess::errorOccurred, this, [this, dialog](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            setErrorMessage(localized("无法启动 KDE 目录选择器。", "Unable to start the KDE folder picker."));
            dialog->deleteLater();
        }
    });
    connect(dialog, &QProcess::finished, this, [this, dialog](int exitCode, QProcess::ExitStatus exitStatus) {
        const QString selectedPath = QString::fromUtf8(dialog->readAllStandardOutput()).trimmed();
        if (exitStatus == QProcess::NormalExit && exitCode == 0 && !selectedPath.isEmpty()) {
            setDownloadDirectory(QUrl::fromLocalFile(selectedPath));
            setStatusMessage(localized("下载目录已更新为：", "Download folder updated to: ") + selectedPath);
        } else if (exitStatus != QProcess::NormalExit) {
            setErrorMessage(localized("KDE 目录选择器意外退出。", "KDE folder picker closed unexpectedly."));
        }
        dialog->deleteLater();
    });
    dialog->start("kdialog", {"--title", localized("选择壁纸下载目录", "Choose wallpaper download folder"), "--getexistingdirectory", ensureDownloadDirectory()});
}

void WallpaperController::setStrictAspectRatio(bool enabled) {
    if (m_strictAspectRatio == enabled) return;
    m_strictAspectRatio = enabled;
    persistPreferences();
    emit strictAspectRatioChanged();
}

void WallpaperController::setLanguage(const QString &language) {
    const QString normalized = language == "en" ? "en" : "zh-Hans";
    if (m_language == normalized) return;
    m_language = normalized;
    persistPreferences();
    emit languageChanged();
}

void WallpaperController::openDownloadDirectory() {
    const QString path = ensureDownloadDirectory();
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(path))) {
        setErrorMessage(localized("无法打开下载目录：", "Cannot open download folder: ") + path);
    }
}

void WallpaperController::refreshDesktopCapability() {
    QDBusInterface plasma(
        "org.kde.plasmashell",
        "/PlasmaShell",
        "org.kde.PlasmaShell",
        QDBusConnection::sessionBus()
    );
    QDBusInterface portal(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.Wallpaper",
        QDBusConnection::sessionBus()
    );
    const bool directPlasmaAvailable = plasma.isValid();
    const bool portalAvailable = portal.isValid();
    const bool available = directPlasmaAvailable || portalAvailable;
    if (m_plasmaAvailable != available) {
        m_plasmaAvailable = available;
        emit plasmaAvailableChanged();
    }

    if (directPlasmaAvailable) {
        setErrorMessage({});
        setStatusMessage(localized("KDE Plasma 壁纸服务已就绪。", "KDE Plasma wallpaper service is ready."));
    } else if (portalAvailable) {
        setErrorMessage({});
        setStatusMessage(localized("XDG 壁纸门户已就绪。", "XDG Wallpaper Portal is ready."));
    } else {
        setErrorMessage(localized("未检测到 Plasma 或 XDG 壁纸服务；请从桌面会话启动应用。", "Neither Plasma nor the XDG wallpaper service was detected; launch the app from a desktop session."));
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

QString WallpaperController::localized(const QString &chinese, const QString &english) const {
    return m_language == "en" ? english : chinese;
}

void WallpaperController::updateDisplayResolution() {
    const QScreen *screen = qGuiApp->primaryScreen();
    const QSize logicalSize = screen ? screen->size() : QSize(1920, 1080);
    const qreal scale = screen ? screen->devicePixelRatio() : 1.0;
    const QSize size(qRound(logicalSize.width() * scale), qRound(logicalSize.height() * scale));
    const QString resolution = QString::number(size.width()) + "x" + QString::number(size.height());
    if (m_displayResolution != resolution) {
        m_displayResolution = resolution;
        emit displayResolutionChanged();
    }
}

void WallpaperController::cancelActiveSearch() {
    ++m_searchGeneration;
    if (m_activeSearchReply) {
        m_activeSearchReply->abort();
        m_activeSearchReply = nullptr;
    }
    if (m_searching) {
        m_searching = false;
        emit searchingChanged();
    }
}

void WallpaperController::handleSearchReply(QNetworkReply *reply, quint64 generation, int page, bool reset) {
    const auto cleanup = qScopeGuard([reply] { reply->deleteLater(); });
    if (reply == m_activeSearchReply) m_activeSearchReply = nullptr;
    if (generation != m_searchGeneration || m_section != "online") return;

    m_searching = false;
    emit searchingChanged();

    if (reply->error() != QNetworkReply::NoError) {
        setErrorMessage(localized("搜索失败：", "Search failed: ") + reply->errorString());
        setStatusMessage({});
        if (!reset) emit pageAppendFinished(false);
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(reply->readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        setErrorMessage(localized("Wallhaven 返回了无法读取的数据。", "Wallhaven returned unreadable data."));
        setStatusMessage({});
        if (!reset) emit pageAppendFinished(false);
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
    if (reset) {
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
    m_currentPage = page;
    m_wallpapers = m_onlineWallpapers;
    emit wallpapersChanged();
    emit paginationChanged();
    if (!reset) emit pageAppendFinished(true);
    setStatusMessage(localized(QString("已加载 %1 / %2 张适合 %3 的壁纸。").arg(m_onlineWallpapers.size()).arg(meta.value("total").toInt(m_onlineWallpapers.size())).arg(m_displayResolution),
        QString("Loaded %1 / %2 wallpapers suitable for %3.").arg(m_onlineWallpapers.size()).arg(meta.value("total").toInt(m_onlineWallpapers.size())).arg(m_displayResolution)));
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
        setErrorMessage(localized("下载失败：", "Download failed: ") + reply->errorString());
        setStatusMessage({});
        return;
    }

    const QString directory = ensureDownloadDirectory();
    if (directory.isEmpty()) return;
    const QByteArray payload = reply->readAll();
    const qint64 advertisedSize = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
    const QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString();
    if (payload.isEmpty() || payload.size() > kMaximumDownloadBytes || advertisedSize > kMaximumDownloadBytes
        || (!contentType.isEmpty() && !contentType.startsWith("image/", Qt::CaseInsensitive))) {
        setErrorMessage(localized("下载的内容不是可接受的图片文件。", "The download did not contain an acceptable image file."));
        setStatusMessage({});
        return;
    }
    const QString filePath = wallpaperFilePath(directory, wallpaper);
    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly) || file.write(payload) != payload.size() || !file.commit()) {
        setErrorMessage(localized("无法保存壁纸到：", "Cannot save wallpaper to: ") + filePath);
        setStatusMessage({});
        return;
    }
    if (m_section == "downloaded") {
        loadDownloadedWallpapers();
    }

    if (setWhenFinished) {
        setWallpaperFile(filePath);
    } else {
        setStatusMessage(localized("下载完成：", "Download complete: ") + QFileInfo(filePath).fileName());
    }
}

void WallpaperController::setWallpaperFile(const QString &filePath) {
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
    if (plasma.isValid()) {
        auto *watcher = new QDBusPendingCallWatcher(plasma.asyncCall("evaluateScript", script), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, filePath] {
            if (!watcher->isError()) {
                setErrorMessage({});
                setStatusMessage(localized("已设为 Plasma 桌面壁纸：", "Set as Plasma wallpaper: ") + QFileInfo(filePath).fileName());
            } else {
                setPortalWallpaper(filePath);
            }
            watcher->deleteLater();
        });
        setStatusMessage(localized("正在请求 Plasma 设置壁纸…", "Requesting Plasma wallpaper change…"));
        return;
    }
    setPortalWallpaper(filePath);
}

void WallpaperController::setPortalWallpaper(const QString &filePath) {
    if (m_pendingPortalImage) {
        QDBusConnection::sessionBus().disconnect(
            QString(), m_pendingPortalRequestPath, "org.freedesktop.portal.Request", "Response", this,
            SLOT(handlePortalResponse(uint,QVariantMap))
        );
        m_pendingPortalImage->deleteLater();
        m_pendingPortalImage = nullptr;
    }
    auto *image = new QFile(filePath, this);
    if (!image->open(QIODevice::ReadOnly)) {
        image->deleteLater();
        setErrorMessage(localized("无法打开壁纸文件：", "Cannot open wallpaper file: ") + filePath);
        return;
    }

    QDBusInterface portal(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.Wallpaper",
        QDBusConnection::sessionBus()
    );
    if (!portal.isValid()) {
        image->deleteLater();
        setErrorMessage(localized("没有可用的壁纸服务。", "No wallpaper service is available."));
        return;
    }

    QVariantMap options;
    options.insert("show-preview", true);
    options.insert("set-on", "background");
    const QString token = QString::number(QRandomGenerator::system()->generate64(), 16);
    options.insert("handle_token", token);
    QString sender = QDBusConnection::sessionBus().baseService();
    sender.replace(':', '_');
    sender.replace('.', '_');
    const QString expectedPath = "/org/freedesktop/portal/desktop/request/" + sender + "/" + token;
    const QDBusUnixFileDescriptor descriptor(image->handle());

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.connect(
            QString(), expectedPath, "org.freedesktop.portal.Request", "Response", this,
            SLOT(handlePortalResponse(uint,QVariantMap))
        )) {
        image->deleteLater();
        setErrorMessage(localized("无法监听 XDG 壁纸门户响应。", "Unable to listen for the XDG Wallpaper Portal response."));
        return;
    }
    m_pendingPortalImage = image;
    m_pendingPortalRequestPath = expectedPath;
    m_pendingPortalFilePath = filePath;
    auto *watcher = new QDBusPendingCallWatcher(
        portal.asyncCallWithArgumentList("SetWallpaperFile", {QString(), QVariant::fromValue(descriptor), options}), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        if (watcher->isError()) {
            QDBusConnection::sessionBus().disconnect(
                QString(), m_pendingPortalRequestPath, "org.freedesktop.portal.Request", "Response", this,
                SLOT(handlePortalResponse(uint,QVariantMap))
            );
            if (m_pendingPortalImage) m_pendingPortalImage->deleteLater();
            m_pendingPortalImage = nullptr;
            m_pendingPortalRequestPath.clear();
            m_pendingPortalFilePath.clear();
            setErrorMessage(localized("XDG 壁纸门户拒绝请求：", "XDG Wallpaper Portal rejected the request: ") + watcher->error().message());
        }
        watcher->deleteLater();
    });
    setStatusMessage(localized("正在等待系统确认壁纸更改…", "Waiting for system confirmation of the wallpaper change…"));
}

void WallpaperController::handlePortalResponse(uint response, const QVariantMap &) {
    QDBusConnection::sessionBus().disconnect(
        QString(), m_pendingPortalRequestPath, "org.freedesktop.portal.Request", "Response", this,
        SLOT(handlePortalResponse(uint,QVariantMap))
    );
    if (m_pendingPortalImage) m_pendingPortalImage->deleteLater();
    const QString filePath = m_pendingPortalFilePath;
    m_pendingPortalImage = nullptr;
    m_pendingPortalRequestPath.clear();
    m_pendingPortalFilePath.clear();

    if (response == 0) {
        setErrorMessage({});
        setStatusMessage(localized("已通过系统门户设为桌面壁纸：", "Set as desktop wallpaper through the system portal: ") + QFileInfo(filePath).fileName());
    } else if (response == 1) {
        setErrorMessage({});
        setStatusMessage(localized("已取消壁纸预览。", "Wallpaper preview was cancelled."));
    } else {
        setErrorMessage(localized("XDG 壁纸门户未能设置壁纸。", "The XDG Wallpaper Portal could not set the wallpaper."));
    }
}

QString WallpaperController::ensureDownloadDirectory() {
    if (!m_downloadDirectory.isEmpty()) {
        if (QDir().mkpath(m_downloadDirectory) && QFileInfo(m_downloadDirectory).isDir() && QFileInfo(m_downloadDirectory).isWritable()) {
            return m_downloadDirectory;
        }
        setErrorMessage(localized("下载目录不可创建或不可写：", "The download folder cannot be created or written: ") + m_downloadDirectory);
        return {};
    }

    QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (pictures.isEmpty()) {
        pictures = QDir::homePath() + "/Pictures";
    }
    const QString path = pictures + "/WallhavenLinux";
    if (!QDir().mkpath(path) || !QFileInfo(path).isWritable()) {
        setErrorMessage(localized("无法创建默认下载目录：", "Unable to create the default download folder: ") + path);
        return {};
    }
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
    if (purity == "all") return "111";
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
    if (!reset && m_searching) return;
    const quint64 generation = ++m_searchGeneration;
    if (m_activeSearchReply) {
        m_activeSearchReply->abort();
        m_activeSearchReply = nullptr;
    }
    const int page = reset ? 1 : m_currentPage + 1;
    const QString seed = reset ? QString() : m_seed;
    if (reset) {
        m_lastPage = 1;
    }

    QUrl url("https://wallhaven.cc/api/v1/search");
    QUrlQuery parameters;
    parameters.addQueryItem("q", m_query);
    parameters.addQueryItem("categories", categoriesValue(m_category));
    parameters.addQueryItem("purity", purityValue(m_purity));
    parameters.addQueryItem("sorting", m_sorting);
    parameters.addQueryItem("atleast", m_displayResolution);
    parameters.addQueryItem("page", QString::number(page));
    if (!seed.isEmpty()) parameters.addQueryItem("seed", seed);
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
    setStatusMessage(page == 1 ? localized("正在从 Wallhaven 获取壁纸…", "Fetching wallpapers from Wallhaven…") : localized("正在加载下一页壁纸…", "Loading the next wallpaper page…"));
    emit searchingChanged();
    QNetworkReply *reply = m_network.get(request);
    m_activeSearchReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, page, reset] { handleSearchReply(reply, generation, page, reset); });
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
        const QString resolution = separator >= 0 ? remainder.mid(separator + 1) : localized("本地图片", "Local image");
        downloaded.append(QVariantMap {
            {"id", id},
            {"fileName", file.fileName()},
            {"localPath", file.absoluteFilePath()},
            {"thumbnail", QUrl::fromLocalFile(file.absoluteFilePath())},
            {"resolution", resolution},
            {"category", localized("已下载", "Downloaded")},
            {"purity", localized("本地", "Local")},
            {"pageUrl", QString("https://wallhaven.cc/w/%1").arg(id)}
        });
    }
    m_wallpapers = downloaded;
    emit wallpapersChanged();
    setErrorMessage({});
    setStatusMessage(localized(QString("下载库中有 %1 张壁纸。").arg(downloaded.size()), QString("The download library has %1 wallpapers.").arg(downloaded.size())));
}

void WallpaperController::persistPreferences() {
    QSettings settings;
    settings.setValue("search/query", m_query);
    settings.setValue("search/category", m_category);
    settings.setValue("search/purity", m_purity);
    settings.setValue("search/sorting", m_sorting);
    settings.setValue("search/strictAspectRatio", m_strictAspectRatio);
    settings.setValue("storage/downloadDirectory", m_downloadDirectory);
    settings.setValue("ui/language", m_language);
}

void WallpaperController::loadApiKeyFromKWallet() {
    const quint64 generation = m_credentialGeneration;
    const QWindow *window = qGuiApp->focusWindow();
    auto *wallet = KWallet::Wallet::openWallet(
        KWallet::Wallet::LocalWallet(), window ? window->winId() : 0, KWallet::Wallet::Asynchronous
    );
    if (!wallet) {
        m_apiKey = m_legacyApiKey;
        emit apiKeyChanged();
        return;
    }
    connect(wallet, &KWallet::Wallet::walletOpened, this, [this, wallet, generation](bool success) {
        const auto cleanup = qScopeGuard([wallet] { wallet->deleteLater(); });
        if (!success || generation != m_credentialGeneration) return;
        if (!wallet->hasFolder("WallhavenLinux") && !wallet->createFolder("WallhavenLinux")) {
            m_apiKey = m_legacyApiKey;
            emit apiKeyChanged();
            return;
        }
        QString storedKey;
        if (wallet->setFolder("WallhavenLinux") && wallet->readPassword("apiKey", storedKey) == 0 && !storedKey.isEmpty()) {
            m_apiKey = storedKey;
            emit apiKeyChanged();
        } else if (!m_legacyApiKey.isEmpty()) {
            m_apiKey = m_legacyApiKey;
            emit apiKeyChanged();
            saveApiKeyToKWallet();
        }
    });
}

void WallpaperController::saveApiKeyToKWallet() {
    const quint64 generation = ++m_credentialGeneration;
    const QString apiKey = m_apiKey;
    const QWindow *window = qGuiApp->focusWindow();
    auto *wallet = KWallet::Wallet::openWallet(
        KWallet::Wallet::LocalWallet(), window ? window->winId() : 0, KWallet::Wallet::Asynchronous
    );
    if (!wallet) {
        setErrorMessage(localized("无法打开 KDE Wallet。", "Unable to open KDE Wallet."));
        return;
    }
    connect(wallet, &KWallet::Wallet::walletOpened, this, [this, wallet, generation, apiKey](bool success) {
        const auto cleanup = qScopeGuard([wallet] { wallet->deleteLater(); });
        if (generation != m_credentialGeneration) return;
        if (!success) {
            setErrorMessage(localized("KDE Wallet 拒绝了保存 API Key 的请求。", "KDE Wallet declined the API key save request."));
        } else if (!wallet->hasFolder("WallhavenLinux") && !wallet->createFolder("WallhavenLinux")) {
            setErrorMessage(localized("无法创建 KDE Wallet 存储区。", "Unable to create the KDE Wallet storage folder."));
        } else if (!wallet->setFolder("WallhavenLinux")
            || (apiKey.isEmpty() ? wallet->removeEntry("apiKey") : wallet->writePassword("apiKey", apiKey)) != 0
            || wallet->sync() != 0) {
            setErrorMessage(localized("无法保存 API Key 到 KDE Wallet。", "Unable to save the API key to KDE Wallet."));
        } else {
            QSettings().remove("account/apiKey");
            setErrorMessage({});
        }
    });
}
