#include "theme.h"
#include <QDir>
#include <QFile>
#include <QTextStream>

Theme::Theme(QObject *parent) : QObject(parent) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(100);
    connect(&m_debounce, &QTimer::timeout, this, &Theme::reload);

    QString configPath = QDir::homePath() + "/.config/omarchy/shell.json";
    if (QFile::exists(configPath)) {
        m_watcher.addPath(configPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
            m_debounce.start();
        });
    }

    reload();
}

void Theme::setTheme(const QString &name) {
    if (m_currentTheme != name) {
        m_currentTheme = name;
        reload();
        emit themeChanged();
    }
}

void Theme::reload() {
    if (m_currentTheme == "everforest") {
        m_accent = "#7fbbb3";
        m_background = "#272e33";
        m_darkBackground = "#232a2e";
        m_surface = "#2d353b";
        m_surfaceLighter = "#343f44";
        m_foreground = "#d3c6aa";
        m_muted = "#859289";
        m_border = "#3d484d";
        m_borderHighlight = "#7fbbb3";
        m_selection = "#343f44";
        m_yellow = "#dbbc7f";
        m_green = "#a7c080";
        m_orange = "#e09d7f";
        m_red = "#e67e80";
        m_cyan = "#83c092";
        m_radius = 2;
    } else if (m_currentTheme == "gruvbox") {
        m_accent = "#7daea3";
        m_background = "#282828";
        m_darkBackground = "#1d2021";
        m_surface = "#32302f";
        m_surfaceLighter = "#3c3836";
        m_foreground = "#d4be98";
        m_muted = "#928374";
        m_border = "#504945";
        m_borderHighlight = "#7daea3";
        m_selection = "#3c3836";
        m_yellow = "#d8a657";
        m_green = "#a9b665";
        m_orange = "#e1875c";
        m_red = "#ea6962";
        m_cyan = "#89b482";
        m_radius = 2;
    } else if (m_currentTheme == "nord") {
        m_accent = "#88c0d0";
        m_background = "#2e3440";
        m_darkBackground = "#242933";
        m_surface = "#3b4252";
        m_surfaceLighter = "#434c5e";
        m_foreground = "#eceff4";
        m_muted = "#616e88";
        m_border = "#4c566a";
        m_borderHighlight = "#88c0d0";
        m_selection = "#434c5e";
        m_yellow = "#ebcb8b";
        m_green = "#a3be8c";
        m_orange = "#d08770";
        m_red = "#bf616a";
        m_cyan = "#8fbcbb";
        m_radius = 2;
    } else if (m_currentTheme == "catppuccin") {
        m_accent = "#89b4fa";
        m_background = "#1e1e2e";
        m_darkBackground = "#181825";
        m_surface = "#24273a";
        m_surfaceLighter = "#313244";
        m_foreground = "#cdd6f4";
        m_muted = "#7f849c";
        m_border = "#45475a";
        m_borderHighlight = "#89b4fa";
        m_selection = "#363a4f";
        m_yellow = "#f9e2af";
        m_green = "#a6e3a1";
        m_orange = "#fab387";
        m_red = "#f38ba8";
        m_cyan = "#94e2d5";
        m_radius = 4;
    } else if (m_currentTheme == "rose-pine") {
        m_accent = "#9ccfd8";
        m_background = "#191724";
        m_darkBackground = "#14121e";
        m_surface = "#1f1d2e";
        m_surfaceLighter = "#26233a";
        m_foreground = "#e0def4";
        m_muted = "#6e6a86";
        m_border = "#3a3652";
        m_borderHighlight = "#9ccfd8";
        m_selection = "#2a273f";
        m_yellow = "#f6c177";
        m_green = "#31748f";
        m_orange = "#ebbcba";
        m_red = "#eb6f92";
        m_cyan = "#9ccfd8";
        m_radius = 2;
    } else if (m_currentTheme == "kanagawa") {
        m_accent = "#7aa89f";
        m_background = "#1f1f28";
        m_darkBackground = "#16161d";
        m_surface = "#2a2a37";
        m_surfaceLighter = "#363646";
        m_foreground = "#dcd7ba";
        m_muted = "#727169";
        m_border = "#434354";
        m_borderHighlight = "#7aa89f";
        m_selection = "#2d4f67";
        m_yellow = "#c0a36e";
        m_green = "#76946a";
        m_orange = "#ffa066";
        m_red = "#c34043";
        m_cyan = "#7aa89f";
        m_radius = 2;
    } else if (m_currentTheme == "matte-black") {
        m_accent = "#e5e5e5";
        m_background = "#121212";
        m_darkBackground = "#0a0a0a";
        m_surface = "#1a1a1a";
        m_surfaceLighter = "#242424";
        m_foreground = "#e5e5e5";
        m_muted = "#666666";
        m_border = "#333333";
        m_borderHighlight = "#888888";
        m_selection = "#2a2a2a";
        m_yellow = "#d4af37";
        m_green = "#80a080";
        m_orange = "#c87d55";
        m_red = "#b05050";
        m_cyan = "#709090";
        m_radius = 0;
    } else { // tokyo-night
        m_accent = "#7aa2f7";
        m_background = "#1a1b26";
        m_darkBackground = "#16161e";
        m_surface = "#1f2335";
        m_surfaceLighter = "#292e42";
        m_foreground = "#c0caf5";
        m_muted = "#565f89";
        m_border = "#2f354f";
        m_borderHighlight = "#7aa2f7";
        m_selection = "#283457";
        m_yellow = "#e0af68";
        m_green = "#9ece6a";
        m_orange = "#ff9e64";
        m_red = "#f7768e";
        m_cyan = "#7dcfff";
        m_radius = 2;
    }
    emit changed();
}

