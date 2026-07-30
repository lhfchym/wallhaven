#include "WindowsDesktopWallpaperService.h"

#include <QDir>
#include <QFileInfo>

#include <Windows.h>
#include <ShObjIdl_core.h>
#include <wrl/client.h>

namespace {
using Microsoft::WRL::ComPtr;

class ComApartment final {
public:
    ComApartment() {
        const HRESULT result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        initialized = result == S_OK || result == S_FALSE;
        usable = initialized || result == RPC_E_CHANGED_MODE;
        initializationResult = result;
    }

    ~ComApartment() {
        if (initialized) {
            CoUninitialize();
        }
    }

    bool isUsable() const { return usable; }
    HRESULT result() const { return initializationResult; }

private:
    bool initialized = false;
    bool usable = false;
    HRESULT initializationResult = E_FAIL;
};

QString messageForHRESULT(HRESULT result) {
    wchar_t *buffer = nullptr;
    const DWORD length = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr,
        static_cast<DWORD>(result),
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        reinterpret_cast<wchar_t *>(&buffer),
        0,
        nullptr
    );

    QString message;
    if (length > 0 && buffer) {
        message = QString::fromWCharArray(buffer, static_cast<qsizetype>(length)).trimmed();
    } else {
        message = QStringLiteral("HRESULT 0x%1").arg(static_cast<quint32>(result), 8, 16, QLatin1Char('0'));
    }
    if (buffer) {
        LocalFree(buffer);
    }
    return message;
}

bool createDesktopWallpaper(
    ComApartment &apartment,
    ComPtr<IDesktopWallpaper> &desktopWallpaper,
    QString *errorMessage
) {
    if (!apartment.isUsable()) {
        if (errorMessage) {
            *errorMessage = messageForHRESULT(apartment.result());
        }
        return false;
    }

    const HRESULT result = CoCreateInstance(
        CLSID_DesktopWallpaper,
        nullptr,
        CLSCTX_ALL,
        IID_PPV_ARGS(&desktopWallpaper)
    );
    if (FAILED(result)) {
        if (errorMessage) {
            *errorMessage = messageForHRESULT(result);
        }
        return false;
    }
    return true;
}
}

bool WindowsDesktopWallpaperService::isAvailable(QString *errorMessage) {
    ComApartment apartment;
    ComPtr<IDesktopWallpaper> desktopWallpaper;
    return createDesktopWallpaper(apartment, desktopWallpaper, errorMessage);
}

bool WindowsDesktopWallpaperService::setWallpaper(
    const QString &filePath,
    QString *errorMessage
) {
    const QFileInfo file(filePath);
    if (!file.exists() || !file.isFile()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Wallpaper file does not exist: %1").arg(filePath);
        }
        return false;
    }

    ComApartment apartment;
    ComPtr<IDesktopWallpaper> desktopWallpaper;
    if (!createDesktopWallpaper(apartment, desktopWallpaper, errorMessage)) {
        return false;
    }

    const QString nativePath = QDir::toNativeSeparators(file.absoluteFilePath());
    HRESULT result = desktopWallpaper->SetPosition(DWPOS_FILL);
    if (FAILED(result)) {
        if (errorMessage) {
            *errorMessage = messageForHRESULT(result);
        }
        return false;
    }

    result = desktopWallpaper->SetWallpaper(nullptr, nativePath.toStdWString().c_str());
    if (FAILED(result)) {
        if (errorMessage) {
            *errorMessage = messageForHRESULT(result);
        }
        return false;
    }
    return true;
}
