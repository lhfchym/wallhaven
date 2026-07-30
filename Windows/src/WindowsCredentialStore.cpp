#include "WindowsCredentialStore.h"

#include <QByteArray>

#include <Windows.h>
#include <wincred.h>

namespace {
constexpr wchar_t kCredentialTarget[] = L"dev.local.wallhaven/api-key";

QString windowsErrorMessage(DWORD error) {
    wchar_t *buffer = nullptr;
    const DWORD length = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr,
        error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        reinterpret_cast<wchar_t *>(&buffer),
        0,
        nullptr
    );

    QString message;
    if (length > 0 && buffer) {
        message = QString::fromWCharArray(buffer, static_cast<qsizetype>(length)).trimmed();
    } else {
        message = QStringLiteral("Windows error %1").arg(error);
    }
    if (buffer) {
        LocalFree(buffer);
    }
    return message;
}
}

QString WindowsCredentialStore::loadApiKey(QString *errorMessage) {
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(kCredentialTarget, CRED_TYPE_GENERIC, 0, &credential)) {
        const DWORD error = GetLastError();
        if (error != ERROR_NOT_FOUND && errorMessage) {
            *errorMessage = windowsErrorMessage(error);
        }
        return {};
    }

    const QByteArray payload(
        reinterpret_cast<const char *>(credential->CredentialBlob),
        static_cast<qsizetype>(credential->CredentialBlobSize)
    );
    const QString apiKey = QString::fromUtf8(payload);
    CredFree(credential);
    return apiKey;
}

bool WindowsCredentialStore::saveApiKey(
    const QString &apiKey,
    QString *errorMessage
) {
    const QString normalized = apiKey.trimmed();
    if (normalized.isEmpty()) {
        if (CredDeleteW(kCredentialTarget, CRED_TYPE_GENERIC, 0)) {
            return true;
        }
        const DWORD error = GetLastError();
        if (error == ERROR_NOT_FOUND) {
            return true;
        }
        if (errorMessage) {
            *errorMessage = windowsErrorMessage(error);
        }
        return false;
    }

    const QByteArray payload = normalized.toUtf8();
    if (payload.size() > CRED_MAX_CREDENTIAL_BLOB_SIZE) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("The API key is too large for Windows Credential Manager.");
        }
        return false;
    }

    CREDENTIALW credential {};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = const_cast<wchar_t *>(kCredentialTarget);
    credential.CredentialBlobSize = static_cast<DWORD>(payload.size());
    credential.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char *>(payload.constData()));
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.UserName = const_cast<wchar_t *>(L"wallhaven");

    if (!CredWriteW(&credential, 0)) {
        if (errorMessage) {
            *errorMessage = windowsErrorMessage(GetLastError());
        }
        return false;
    }
    return true;
}
