#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QVariantList>

class QNetworkReply;

class WallpaperController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList wallpapers READ wallpapers NOTIFY wallpapersChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString displayResolution READ displayResolution NOTIFY displayResolutionChanged)
    Q_PROPERTY(QString downloadDirectory READ downloadDirectory NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(bool plasmaAvailable READ plasmaAvailable NOTIFY plasmaAvailableChanged)

public:
    explicit WallpaperController(QObject *parent = nullptr);

    QVariantList wallpapers() const;
    bool searching() const;
    bool downloading() const;
    QString statusMessage() const;
    QString errorMessage() const;
    QString displayResolution() const;
    QString downloadDirectory() const;
    bool plasmaAvailable() const;

    Q_INVOKABLE void search(const QString &query, const QString &category, const QString &purity, const QString &sorting);
    Q_INVOKABLE void download(int index, bool setWhenFinished = false);
    Q_INVOKABLE void setWallpaper(int index);
    Q_INVOKABLE void openDownloadDirectory();
    Q_INVOKABLE void refreshDesktopCapability();

signals:
    void wallpapersChanged();
    void searchingChanged();
    void downloadingChanged();
    void statusMessageChanged();
    void errorMessageChanged();
    void displayResolutionChanged();
    void downloadDirectoryChanged();
    void plasmaAvailableChanged();

private:
    void setStatusMessage(const QString &message);
    void setErrorMessage(const QString &message);
    void updateDisplayResolution();
    void handleSearchReply(QNetworkReply *reply);
    void handleDownloadReply(QNetworkReply *reply, const QVariantMap &wallpaper, bool setWhenFinished);
    bool setPlasmaWallpaper(const QString &filePath);
    QString ensureDownloadDirectory();
    QString categoriesValue(const QString &category) const;
    QString purityValue(const QString &purity) const;
    QVariantMap wallpaperFromJson(const QJsonObject &wallpaper) const;

    QNetworkAccessManager m_network;
    QVariantList m_wallpapers;
    bool m_searching = false;
    bool m_downloading = false;
    bool m_plasmaAvailable = false;
    QString m_statusMessage;
    QString m_errorMessage;
    QString m_displayResolution;
    QString m_downloadDirectory;
};
