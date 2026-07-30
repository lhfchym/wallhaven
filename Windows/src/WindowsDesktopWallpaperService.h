#pragma once

#include <QString>

class WindowsDesktopWallpaperService {
public:
    static bool isAvailable(QString *errorMessage = nullptr);
    static bool setWallpaper(const QString &filePath, QString *errorMessage = nullptr);
};
