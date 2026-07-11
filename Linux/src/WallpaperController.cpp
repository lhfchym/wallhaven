#include "WallpaperController.h"

#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QScreen>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QDBusInterface>
#include <QDBusReply>

namespace {
constexpr auto kUserAgent = "WallhavenLinux/0.1 (Kubuntu Plasma)";
}

WallpaperController::WallpaperController(QObject *parent)
    : QObject(parent) {
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

void WallpaperController::search(
    const QString &query,
    const QString &category,
    const QString &purity,
    const QString &sorting
) {
    if (m_searching) {
        return;
    }

    QUrl url("https://wallhaven.cc/api/v1/search");
    QUrlQuery parameters;
    parameters.addQueryItem("q", query.trimmed());
    parameters.addQueryItem("categories", categoriesValue(category));
    parameters.addQueryItem("purity", purityValue(purity));
    parameters.addQueryItem("sorting", sorting);
    parameters.addQueryItem("atleast", m_displayResolution);
    url.setQuery(parameters);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    request.setTransferTimeout(15'000);

    m_searching = true;
    setErrorMessage({});
    setStatusMessage("正在从 Wallhaven 获取壁纸…");
    emit searchingChanged();

    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleSearchReply(reply); });
}

void WallpaperController::download(int index, bool setWhenFinished) {
    if (m_downloading || index < 0 || index >= m_wallpapers.size()) {
        return;
    }

    const QVariantMap wallpaper = m_wallpapers.at(index).toMap();
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
    download(index, true);
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

    m_wallpapers = results;
    emit wallpapersChanged();
    setStatusMessage(QString("已加载 %1 张适合 %2 的壁纸。").arg(results.size()).arg(m_displayResolution));
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
        {"thumbnail", thumbs.value("large").toString()},
        {"resolution", wallpaper.value("resolution").toString()},
        {"category", wallpaper.value("category").toString()},
        {"purity", wallpaper.value("purity").toString()},
        {"fileSize", wallpaper.value("file_size").toVariant()}
    };
}
