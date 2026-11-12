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
    src/theme.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/theme.cpp

RESOURCES += src/resources.qrc

