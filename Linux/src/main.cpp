#include "WallpaperController.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("Wallhaven Linux");
    app.setOrganizationName("WallhavenLinux");
    app.setDesktopFileName("dev.local.WallhavenLinux");

    qmlRegisterType<WallpaperController>("Wallhaven", 1, 0, "WallpaperController");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.loadFromModule("Wallhaven.Linux", "Main");

    return app.exec();
}
