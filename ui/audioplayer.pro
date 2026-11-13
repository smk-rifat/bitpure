QT += core gui qml quick quickcontrols2 network

CONFIG += c++17 release
TARGET = bitpure
TEMPLATE = app

INCLUDEPATH += \
    src \
    /usr/include/alsa

LIBS += \
    -L$$PWD/../target/debug -lapp_core \
    -lasound \
    -Wl,-rpath,$$PWD/../target/debug

HEADERS += \
    src/backend.h \
    src/theme.h \
    src/settings_manager.h \
    src/mood_service.h \
    src/system_monitor.h \
    src/translation_service.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/theme.cpp \
    src/settings_manager.cpp \
    src/mood_service.cpp \
    src/system_monitor.cpp \
    src/translation_service.cpp

RESOURCES += src/resources.qrc

