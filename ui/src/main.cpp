#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "backend.h"
#include "theme.h"
#include "settings_manager.h"
#include "system_monitor.h"
#include "mood_service.h"

int main(int argc, char *argv[]) {
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);

    qmlRegisterType<Theme>("Audioplayer", 1, 0, "Theme");
    qmlRegisterType<Backend>("Audioplayer", 1, 0, "Backend");
    qmlRegisterType<SettingsManager>("Audioplayer", 1, 0, "SettingsManager");
    qmlRegisterType<SystemMonitor>("Audioplayer", 1, 0, "SystemMonitor");
    qmlRegisterType<MoodService>("Audioplayer", 1, 0, "MoodService");

    QQmlApplicationEngine engine;

    Backend backend;
    Theme theme;

    // Apply persisted theme on startup before UI renders
    theme.setFamilyAndVariant(backend.settings()->themeFamily(), backend.settings()->themeVariant());

    QObject::connect(&theme, &Theme::themeChanged, [&]() {
        backend.settings()->setThemeFamily(theme.family());
        backend.settings()->setThemeVariant(theme.variant());
    });

    QObject::connect(backend.settings(), &SettingsManager::allSettingsReset, [&]() {
        theme.setFamilyAndVariant(backend.settings()->themeFamily(), backend.settings()->themeVariant());
    });

    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.rootContext()->setContextProperty("settingsManager", backend.settings());
    engine.rootContext()->setContextProperty("systemMonitor", backend.systemMonitor());
    engine.rootContext()->setContextProperty("moodService", backend.moodService());

    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}

