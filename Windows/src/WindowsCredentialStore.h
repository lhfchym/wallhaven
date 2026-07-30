#pragma once

#include <QString>

class WindowsCredentialStore {
public:
    static QString loadApiKey(QString *errorMessage = nullptr);
    static bool saveApiKey(const QString &apiKey, QString *errorMessage = nullptr);
};
