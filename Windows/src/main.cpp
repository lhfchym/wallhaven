#include "WallpaperController.h"

#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("Wallhaven");
    app.setApplicationDisplayName("Wallhaven for Windows");
    app.setOrganizationName("Wallhaven");
    app.setOrganizationDomain("dev.local");
    app.setWindowIcon(QIcon(":/wallhaven-icon.png"));
    QQuickStyle::setStyle("FluentWinUI3");

    qmlRegisterType<WallpaperController>("Wallhaven", 1, 0, "WallpaperController");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.loadFromModule("Wallhaven.Windows", "Main");

    return app.exec();
}
