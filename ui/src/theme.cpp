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
    if (m_currentTheme == "catppuccin") {
        m_accent = "#89b4fa";
        m_background = "#1e1e2e";
        m_darkBackground = "#161622";
        m_surface = "#313244";
        m_surfaceLighter = "#45475a";
        m_foreground = "#cdd6f4";
        m_muted = "#585b70";
        m_border = "#45475a";
        m_borderHighlight = "#89b4fa";
        m_selection = "#45475a";
        m_yellow = "#f9e2af";
        m_green = "#a6e3a1";
        m_orange = "#f6b6ab";
        m_red = "#f38ba8";
        m_cyan = "#94e2d5";
        m_radius = 2;
    } else if (m_currentTheme == "catppuccin-latte") {
        m_accent = "#1e66f5";
        m_background = "#eff1f5";
        m_darkBackground = "#e3e4e8";
        m_surface = "#dce0e8";
        m_surfaceLighter = "#ccd0da";
        m_foreground = "#4c4f69";
        m_muted = "#acb0be";
        m_border = "#ccd0da";
        m_borderHighlight = "#1e66f5";
        m_selection = "#ccd0da";
        m_yellow = "#df8e1d";
        m_green = "#40a02b";
        m_orange = "#d84e2b";
        m_red = "#d20f39";
        m_cyan = "#179299";
        m_radius = 2;
    } else if (m_currentTheme == "ethereal") {
        m_accent = "#7d82d9";
        m_background = "#060B1E";
        m_darkBackground = "#040816";
        m_surface = "#131a3a";
        m_surfaceLighter = "#252e56";
        m_foreground = "#ffcead";
        m_muted = "#6d7db6";
        m_border = "#252e56";
        m_borderHighlight = "#7d82d9";
        m_selection = "#252e56";
        m_yellow = "#E9BB4F";
        m_green = "#92a593";
        m_orange = "#eb8b54";
        m_red = "#ED5B5A";
        m_cyan = "#a3bfd1";
        m_radius = 2;
    } else if (m_currentTheme == "everforest") {
        m_accent = "#7fbbb3";
        m_background = "#2d353b";
        m_darkBackground = "#21272c";
        m_surface = "#343f44";
        m_surfaceLighter = "#3d484d";
        m_foreground = "#d3c6aa";
        m_muted = "#475258";
        m_border = "#3d484d";
        m_borderHighlight = "#7fbbb3";
        m_selection = "#3d484d";
        m_yellow = "#dbbc7f";
        m_green = "#a7c080";
        m_orange = "#e09d7f";
        m_red = "#e67e80";
        m_cyan = "#83c092";
        m_radius = 2;
    } else if (m_currentTheme == "flexoki-light") {
        m_accent = "#205EA6";
        m_background = "#FFFCF0";
        m_darkBackground = "#f2efe4";
        m_surface = "#E6E4D9";
        m_surfaceLighter = "#CECDC3";
        m_foreground = "#100F0F";
        m_muted = "#B7B5AC";
        m_border = "#CECDC3";
        m_borderHighlight = "#205EA6";
        m_selection = "#CECDC3";
        m_yellow = "#D0A215";
        m_green = "#879A39";
        m_orange = "#d0772b";
        m_red = "#D14D41";
        m_cyan = "#3AA99F";
        m_radius = 2;
    } else if (m_currentTheme == "gruvbox") {
        m_accent = "#7daea3";
        m_background = "#282828";
        m_darkBackground = "#1e1e1e";
        m_surface = "#3c3836";
        m_surfaceLighter = "#504945";
        m_foreground = "#d4be98";
        m_muted = "#665c54";
        m_border = "#504945";
        m_borderHighlight = "#7daea3";
        m_selection = "#504945";
        m_yellow = "#d8a657";
        m_green = "#a9b665";
        m_orange = "#e1875c";
        m_red = "#ea6962";
        m_cyan = "#89b482";
        m_radius = 2;
    } else if (m_currentTheme == "hackerman") {
        m_accent = "#82FB9C";
        m_background = "#0B0C16";
        m_darkBackground = "#080910";
        m_surface = "#151828";
        m_surfaceLighter = "#1f253a";
        m_foreground = "#ddf7ff";
        m_muted = "#2d3450";
        m_border = "#1f253a";
        m_borderHighlight = "#82FB9C";
        m_selection = "#1f253a";
        m_yellow = "#50f7d4";
        m_green = "#4fe88f";
        m_orange = "#50f7a3";
        m_red = "#50f872";
        m_cyan = "#7cf8f7";
        m_radius = 2;
    } else if (m_currentTheme == "jade-horse") {
        m_accent = "#8bcbb1";
        m_background = "#142620";
        m_darkBackground = "#0f1e19";
        m_surface = "#203b31";
        m_surfaceLighter = "#2b5147";
        m_foreground = "#dfede5";
        m_muted = "#64887b";
        m_border = "#2b5147";
        m_borderHighlight = "#8bcbb1";
        m_selection = "#2b5147";
        m_yellow = "#c5cc91";
        m_green = "#8bcbb1";
        m_orange = "#d2ab8d";
        m_red = "#d88d91";
        m_cyan = "#86c7c5";
        m_radius = 2;
    } else if (m_currentTheme == "kanagawa") {
        m_accent = "#dcd7ba";
        m_background = "#1f1f28";
        m_darkBackground = "#17171e";
        m_surface = "#223249";
        m_surfaceLighter = "#363646";
        m_foreground = "#dcd7ba";
        m_muted = "#54546D";
        m_border = "#363646";
        m_borderHighlight = "#dcd7ba";
        m_selection = "#363646";
        m_yellow = "#c0a36e";
        m_green = "#76946a";
        m_orange = "#c17158";
        m_red = "#c34043";
        m_cyan = "#6a9589";
        m_radius = 2;
    } else if (m_currentTheme == "last-horizon") {
        m_accent = "#b59790";
        m_background = "#0c0b0c";
        m_darkBackground = "#090809";
        m_surface = "#0c0b0c";
        m_surfaceLighter = "#584e51";
        m_foreground = "#FAFCFB";
        m_muted = "#584e51";
        m_border = "#584e51";
        m_borderHighlight = "#b59790";
        m_selection = "#584e51";
        m_yellow = "#6B5E73";
        m_green = "#87a9b0";
        m_orange = "#e09d7f";
        m_red = "#c38b7b";
        m_cyan = "#a5a0b6";
        m_radius = 2;
    } else if (m_currentTheme == "lumon") {
        m_accent = "#8bc9eb";
        m_background = "#16242d";
        m_darkBackground = "#101b21";
        m_surface = "#1b2d40";
        m_surfaceLighter = "#243d56";
        m_foreground = "#d6e2ee";
        m_muted = "#304860";
        m_border = "#243d56";
        m_borderHighlight = "#8bc9eb";
        m_selection = "#243d56";
        m_yellow = "#6fa4c9";
        m_green = "#5e95bc";
        m_orange = "#8bc9eb";
        m_red = "#4d86b0";
        m_cyan = "#b4e4f6";
        m_radius = 2;
    } else if (m_currentTheme == "lupine") {
        m_accent = "#3264eb";
        m_background = "#fafafa";
        m_darkBackground = "#ececec";
        m_surface = "#f5f5f5";
        m_surfaceLighter = "#d0d0d0";
        m_foreground = "#212121";
        m_muted = "#9e9e9e";
        m_border = "#d0d0d0";
        m_borderHighlight = "#3264eb";
        m_selection = "#d0d0d0";
        m_yellow = "#026fde";
        m_green = "#4a2fd0";
        m_orange = "#026fde";
        m_red = "#c900c4";
        m_cyan = "#0c67de";
        m_radius = 2;
    } else if (m_currentTheme == "matte-black") {
        m_accent = "#e68e0d";
        m_background = "#121212";
        m_darkBackground = "#0d0d0d";
        m_surface = "#1e1e1e";
        m_surfaceLighter = "#2a2a2a";
        m_foreground = "#bebebe";
        m_muted = "#333333";
        m_border = "#2a2a2a";
        m_borderHighlight = "#e68e0d";
        m_selection = "#2a2a2a";
        m_yellow = "#b91c1c";
        m_green = "#FFC107";
        m_orange = "#c63d3d";
        m_red = "#D35F5F";
        m_cyan = "#bebebe";
        m_radius = 2;
    } else if (m_currentTheme == "miasma") {
        m_accent = "#78824b";
        m_background = "#222222";
        m_darkBackground = "#191919";
        m_surface = "#2c2c2c";
        m_surfaceLighter = "#383838";
        m_foreground = "#c2c2b0";
        m_muted = "#666666";
        m_border = "#383838";
        m_borderHighlight = "#78824b";
        m_selection = "#383838";
        m_yellow = "#b36d43";
        m_green = "#5f875f";
        m_orange = "#8d6242";
        m_red = "#685742";
        m_cyan = "#c9a554";
        m_radius = 2;
    } else if (m_currentTheme == "nord") {
        m_accent = "#81a1c1";
        m_background = "#2e3440";
        m_darkBackground = "#222730";
        m_surface = "#3b4252";
        m_surfaceLighter = "#434c5e";
        m_foreground = "#d8dee9";
        m_muted = "#4c566a";
        m_border = "#434c5e";
        m_borderHighlight = "#81a1c1";
        m_selection = "#434c5e";
        m_yellow = "#ebcb8b";
        m_green = "#a3be8c";
        m_orange = "#d5967a";
        m_red = "#bf616a";
        m_cyan = "#88c0d0";
        m_radius = 2;
    } else if (m_currentTheme == "retro-82") {
        m_accent = "#faa968";
        m_background = "#05182e";
        m_darkBackground = "#031222";
        m_surface = "#0a2540";
        m_surfaceLighter = "#134e5a";
        m_foreground = "#f6dcac";
        m_muted = "#2a6b78";
        m_border = "#134e5a";
        m_borderHighlight = "#faa968";
        m_selection = "#134e5a";
        m_yellow = "#e97b3c";
        m_green = "#028391";
        m_orange = "#faa968";
        m_red = "#f85525";
        m_cyan = "#8cbfb8";
        m_radius = 2;
    } else if (m_currentTheme == "ristretto") {
        m_accent = "#f38d70";
        m_background = "#2c2525";
        m_darkBackground = "#211b1b";
        m_surface = "#3d2f2a";
        m_surfaceLighter = "#403e41";
        m_foreground = "#e6d9db";
        m_muted = "#72696a";
        m_border = "#403e41";
        m_borderHighlight = "#f38d70";
        m_selection = "#403e41";
        m_yellow = "#f9cc6c";
        m_green = "#adda78";
        m_orange = "#fb9a77";
        m_red = "#fd6883";
        m_cyan = "#85dacc";
        m_radius = 2;
    } else if (m_currentTheme == "rose-pine") {
        m_accent = "#56949f";
        m_background = "#faf4ed";
        m_darkBackground = "#ede7e1";
        m_surface = "#f2e9e1";
        m_surfaceLighter = "#dfdad9";
        m_foreground = "#575279";
        m_muted = "#cecacd";
        m_border = "#dfdad9";
        m_borderHighlight = "#56949f";
        m_selection = "#dfdad9";
        m_yellow = "#ea9d34";
        m_green = "#286983";
        m_orange = "#cf8057";
        m_red = "#b4637a";
        m_cyan = "#d7827e";
        m_radius = 2;
    } else if (m_currentTheme == "solitude") {
        m_accent = "#798186";
        m_background = "#101315";
        m_darkBackground = "#0c0e10";
        m_surface = "#101315";
        m_surfaceLighter = "#343d41";
        m_foreground = "#cacccc";
        m_muted = "#4b4e55";
        m_border = "#343d41";
        m_borderHighlight = "#798186";
        m_selection = "#343d41";
        m_yellow = "#d9dbdc";
        m_green = "#9fa5a9";
        m_orange = "#e09d7f";
        m_red = "#565d60";
        m_cyan = "#707070";
        m_radius = 2;
    } else if (m_currentTheme == "starship") {
        m_accent = "#ff9f0a";
        m_background = "#1c1c1e";
        m_darkBackground = "#161618";
        m_surface = "#2c2c2e";
        m_surfaceLighter = "#3a3a3c";
        m_foreground = "#f5f5f7";
        m_muted = "#8e8e93";
        m_border = "#3a3a3c";
        m_borderHighlight = "#ff9f0a";
        m_selection = "#3a3a3c";
        m_yellow = "#ffc27a";
        m_green = "#ff9f0a";
        m_orange = "#ff6a3d";
        m_red = "#ff5f4a";
        m_cyan = "#a6dcef";
        m_radius = 2;
    } else if (m_currentTheme == "tokyo-night") {
        m_accent = "#7aa2f7";
        m_background = "#1a1b26";
        m_darkBackground = "#13141c";
        m_surface = "#24283b";
        m_surfaceLighter = "#292e42";
        m_foreground = "#a9b1d6";
        m_muted = "#414868";
        m_border = "#292e42";
        m_borderHighlight = "#7aa2f7";
        m_selection = "#292e42";
        m_yellow = "#e0af68";
        m_green = "#9ece6a";
        m_orange = "#eb927b";
        m_red = "#f7768e";
        m_cyan = "#449dab";
        m_radius = 2;
    } else if (m_currentTheme == "vantablack") {
        m_accent = "#8d8d8d";
        m_background = "#000000";
        m_darkBackground = "#090909";
        m_surface = "#1a1a1a";
        m_surfaceLighter = "#1a1a1a";
        m_foreground = "#ffffff";
        m_muted = "#7a7a7a";
        m_border = "#1a1a1a";
        m_borderHighlight = "#8d8d8d";
        m_selection = "#1a1a1a";
        m_yellow = "#cecece";
        m_green = "#b6b6b6";
        m_orange = "#b9b9b9";
        m_red = "#a4a4a4";
        m_cyan = "#b0b0b0";
        m_radius = 2;
    } else if (m_currentTheme == "white") {
        m_accent = "#6e6e6e";
        m_background = "#ffffff";
        m_darkBackground = "#f5f5f5";
        m_surface = "#c0c0c0";
        m_surfaceLighter = "#c0c0c0";
        m_foreground = "#000000";
        m_muted = "#808080";
        m_border = "#c0c0c0";
        m_borderHighlight = "#6e6e6e";
        m_selection = "#c0c0c0";
        m_yellow = "#4a4a4a";
        m_green = "#3a3a3a";
        m_orange = "#e09d7f";
        m_red = "#2a2a2a";
        m_cyan = "#3e3e3e";
        m_radius = 2;
    } else {
        m_accent = "#7fbbb3"; m_background = "#2d353b"; m_darkBackground = "#21272c";
        m_surface = "#343f44"; m_surfaceLighter = "#3d484d"; m_foreground = "#d3c6aa";
        m_muted = "#475258"; m_border = "#3d484d"; m_borderHighlight = "#7fbbb3";
        m_selection = "#3d484d"; m_yellow = "#dbbc7f"; m_green = "#a7c080";
        m_orange = "#e09d7f"; m_red = "#e67e80"; m_cyan = "#83c092"; m_radius = 2;
    }
    emit changed();
}
