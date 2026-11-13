#include "theme.h"
#include <QDebug>

Theme::Theme(QObject *parent) : QObject(parent) {
    applyPalette();
}

QStringList Theme::availableFamilies() const {
    return {
        "Gruvbox",
        "Catppuccin",
        "Everforest",
        "VS Code",
        "IntelliJ IDEA",
        "Dracula"
    };
}

QStringList Theme::variantsForFamily(const QString &fam) const {
    if (fam == "Gruvbox") {
        return {
            "Gruvbox Material Dark",
            "Gruvbox Material Dark Soft",
            "Gruvbox Material Dark Medium",
            "Gruvbox Material Dark Hard"
        };
    } else if (fam == "Catppuccin") {
        return {
            "Mocha",
            "Macchiato",
            "Frappe",
            "Latte"
        };
    } else if (fam == "Everforest") {
        return {
            "Dark Soft",
            "Dark Medium",
            "Dark Hard"
        };
    } else if (fam == "VS Code") {
        return {
            "Dark+",
            "Dark Modern"
        };
    } else if (fam == "IntelliJ IDEA") {
        return {
            "Darcula",
            "New UI Dark"
        };
    } else if (fam == "Dracula") {
        return {
            "Dracula"
        };
    }
    return { "Default" };
}

QStringList Theme::availableVariants() const {
    return variantsForFamily(m_family);
}

void Theme::setFamily(const QString &f) {
    if (m_family != f && availableFamilies().contains(f)) {
        m_family = f;
        QStringList vars = variantsForFamily(f);
        m_variant = vars.first();
        applyPalette();
        emit themeChanged();
        emit changed();
    }
}

void Theme::setVariant(const QString &v) {
    if (m_variant != v) {
        m_variant = v;
        applyPalette();
        emit themeChanged();
        emit changed();
    }
}

void Theme::setFamilyAndVariant(const QString &fam, const QString &var) {
    bool changedState = false;
    if (m_family != fam && availableFamilies().contains(fam)) {
        m_family = fam;
        changedState = true;
    }
    if (m_variant != var) {
        m_variant = var;
        changedState = true;
    }
    if (changedState) {
        applyPalette();
        emit themeChanged();
        emit changed();
    }
}

void Theme::setTheme(const QString &name) {
    // Check if name is a variant or family
    for (const QString &fam : availableFamilies()) {
        QStringList vars = variantsForFamily(fam);
        if (vars.contains(name)) {
            setFamilyAndVariant(fam, name);
            return;
        }
        if (fam.compare(name, Qt::CaseInsensitive) == 0) {
            setFamily(fam);
            return;
        }
    }
    // Fallback search
    if (name.contains("Gruvbox", Qt::CaseInsensitive)) {
        setFamily("Gruvbox");
    } else if (name.contains("Catppuccin", Qt::CaseInsensitive)) {
        setFamily("Catppuccin");
    } else if (name.contains("Everforest", Qt::CaseInsensitive)) {
        setFamily("Everforest");
    } else if (name.contains("VS Code", Qt::CaseInsensitive) || name.contains("code", Qt::CaseInsensitive)) {
        setFamily("VS Code");
    } else if (name.contains("IntelliJ", Qt::CaseInsensitive) || name.contains("idea", Qt::CaseInsensitive)) {
        setFamily("IntelliJ IDEA");
    } else if (name.contains("Dracula", Qt::CaseInsensitive)) {
        setFamily("Dracula");
    }
}

void Theme::applyPalette() {
    m_radius = 4;

    if (m_family == "Gruvbox") {
        if (m_variant == "Gruvbox Material Dark Soft") {
            m_background = "#32302f";
            m_surface = "#3c3836";
            m_surfaceElevated = "#504945";
            m_text = "#ebdbb2";
            m_textMuted = "#928374";
            m_border = "#504945";
            m_borderHighlight = "#d79921";
            m_accent = "#d79921";
            m_selection = "#504945";
            m_player = "#282828";
            m_lyricsCurrent = "#fabd2f";
            m_lyricsPrevious = "#a89984";
            m_lyricsInactive = "#665c54";
            m_statusSuccess = "#b8bb26";
            m_statusWarning = "#fabd2f";
            m_statusError = "#fb4934";
            m_orange = "#fe8019";
        } else if (m_variant == "Gruvbox Material Dark Hard") {
            m_background = "#1d2021";
            m_surface = "#282828";
            m_surfaceElevated = "#32302f";
            m_text = "#ebdbb2";
            m_textMuted = "#a89984";
            m_border = "#3c3836";
            m_borderHighlight = "#fabd2f";
            m_accent = "#fabd2f";
            m_selection = "#3c3836";
            m_player = "#141617";
            m_lyricsCurrent = "#fabd2f";
            m_lyricsPrevious = "#a89984";
            m_lyricsInactive = "#504945";
            m_statusSuccess = "#b8bb26";
            m_statusWarning = "#fabd2f";
            m_statusError = "#fb4934";
            m_orange = "#fe8019";
        } else {
            // Material Dark / Medium default
            m_background = "#282828";
            m_surface = "#32302f";
            m_surfaceElevated = "#3c3836";
            m_text = "#ebdbb2";
            m_textMuted = "#a89984";
            m_border = "#504945";
            m_borderHighlight = "#d79921";
            m_accent = "#d79921";
            m_selection = "#504945";
            m_player = "#1d2021";
            m_lyricsCurrent = "#fabd2f";
            m_lyricsPrevious = "#a89984";
            m_lyricsInactive = "#665c54";
            m_statusSuccess = "#b8bb26";
            m_statusWarning = "#fabd2f";
            m_statusError = "#fb4934";
            m_orange = "#fe8019";
        }
    } else if (m_family == "Catppuccin") {
        if (m_variant == "Latte") {
            m_background = "#eff1f5";
            m_surface = "#e6e9ef";
            m_surfaceElevated = "#dce0e8";
            m_text = "#4c4f69";
            m_textMuted = "#6c6f85";
            m_border = "#ccd0da";
            m_borderHighlight = "#1e66f5";
            m_accent = "#1e66f5";
            m_selection = "#bcc0cc";
            m_player = "#e6e9ef";
            m_lyricsCurrent = "#1e66f5";
            m_lyricsPrevious = "#6c6f85";
            m_lyricsInactive = "#9ca0b0";
            m_statusSuccess = "#40a02b";
            m_statusWarning = "#df8e1d";
            m_statusError = "#d20f39";
            m_orange = "#fe640b";
        } else if (m_variant == "Macchiato") {
            m_background = "#24273a";
            m_surface = "#363a4f";
            m_surfaceElevated = "#494d64";
            m_text = "#cad3f5";
            m_textMuted = "#a5adcb";
            m_border = "#494d64";
            m_borderHighlight = "#8aadf4";
            m_accent = "#8aadf4";
            m_selection = "#5b6078";
            m_player = "#1e2030";
            m_lyricsCurrent = "#8aadf4";
            m_lyricsPrevious = "#a5adcb";
            m_lyricsInactive = "#5b6078";
            m_statusSuccess = "#a6da95";
            m_statusWarning = "#eed49f";
            m_statusError = "#ed8796";
            m_orange = "#f5a97f";
        } else if (m_variant == "Frappe") {
            m_background = "#303446";
            m_surface = "#414559";
            m_surfaceElevated = "#51576d";
            m_text = "#c6d0f5";
            m_textMuted = "#a5adce";
            m_border = "#51576d";
            m_borderHighlight = "#8caaee";
            m_accent = "#8caaee";
            m_selection = "#626880";
            m_player = "#292c3c";
            m_lyricsCurrent = "#8caaee";
            m_lyricsPrevious = "#a5adce";
            m_lyricsInactive = "#626880";
            m_statusSuccess = "#a6d189";
            m_statusWarning = "#e5c890";
            m_statusError = "#e78284";
            m_orange = "#ef9f76";
        } else {
            // Mocha default
            m_background = "#1e1e2e";
            m_surface = "#313244";
            m_surfaceElevated = "#45475a";
            m_text = "#cdd6f4";
            m_textMuted = "#a6adc8";
            m_border = "#45475a";
            m_borderHighlight = "#89b4fa";
            m_accent = "#89b4fa";
            m_selection = "#585b70";
            m_player = "#181825";
            m_lyricsCurrent = "#89b4fa";
            m_lyricsPrevious = "#a6adc8";
            m_lyricsInactive = "#585b70";
            m_statusSuccess = "#a6e3a1";
            m_statusWarning = "#f9e2af";
            m_statusError = "#f38ba8";
            m_orange = "#fab387";
        }
    } else if (m_family == "Everforest") {
        if (m_variant == "Dark Soft") {
            m_background = "#333c43";
            m_surface = "#3a464c";
            m_surfaceElevated = "#435259";
            m_text = "#d3c6aa";
            m_textMuted = "#859289";
            m_border = "#4f5b58";
            m_borderHighlight = "#7fbbb3";
            m_accent = "#7fbbb3";
            m_selection = "#435259";
            m_player = "#2d353b";
            m_lyricsCurrent = "#a7c080";
            m_lyricsPrevious = "#859289";
            m_lyricsInactive = "#4f5b58";
            m_statusSuccess = "#a7c080";
            m_statusWarning = "#dbbc7f";
            m_statusError = "#e67e80";
            m_orange = "#e69875";
        } else if (m_variant == "Dark Hard") {
            m_background = "#272e33";
            m_surface = "#2e383c";
            m_surfaceElevated = "#374247";
            m_text = "#d3c6aa";
            m_textMuted = "#7a8478";
            m_border = "#414b50";
            m_borderHighlight = "#7fbbb3";
            m_accent = "#7fbbb3";
            m_selection = "#374247";
            m_player = "#1e2326";
            m_lyricsCurrent = "#a7c080";
            m_lyricsPrevious = "#7a8478";
            m_lyricsInactive = "#414b50";
            m_statusSuccess = "#a7c080";
            m_statusWarning = "#dbbc7f";
            m_statusError = "#e67e80";
            m_orange = "#e69875";
        } else {
            // Dark Medium default
            m_background = "#2d353b";
            m_surface = "#343f44";
            m_surfaceElevated = "#3d484d";
            m_text = "#d3c6aa";
            m_textMuted = "#859289";
            m_border = "#475258";
            m_borderHighlight = "#a7c080";
            m_accent = "#a7c080";
            m_selection = "#3d484d";
            m_player = "#232a2e";
            m_lyricsCurrent = "#a7c080";
            m_lyricsPrevious = "#859289";
            m_lyricsInactive = "#475258";
            m_statusSuccess = "#a7c080";
            m_statusWarning = "#dbbc7f";
            m_statusError = "#e67e80";
            m_orange = "#e69875";
        }
    } else if (m_family == "VS Code") {
        if (m_variant == "Dark Modern") {
            m_background = "#181818";
            m_surface = "#1f1f1f";
            m_surfaceElevated = "#2b2b2b";
            m_text = "#e0e0e0";
            m_textMuted = "#999999";
            m_border = "#383838";
            m_borderHighlight = "#3794ff";
            m_accent = "#3794ff";
            m_selection = "#264f78";
            m_player = "#121212";
            m_lyricsCurrent = "#3794ff";
            m_lyricsPrevious = "#999999";
            m_lyricsInactive = "#555555";
            m_statusSuccess = "#89d185";
            m_statusWarning = "#cca700";
            m_statusError = "#f14c4c";
            m_orange = "#d18616";
        } else {
            // Dark+ default
            m_background = "#1e1e1e";
            m_surface = "#252526";
            m_surfaceElevated = "#2d2d2d";
            m_text = "#cccccc";
            m_textMuted = "#858585";
            m_border = "#3c3c3c";
            m_borderHighlight = "#007acc";
            m_accent = "#007acc";
            m_selection = "#094771";
            m_player = "#181818";
            m_lyricsCurrent = "#4fc1ff";
            m_lyricsPrevious = "#858585";
            m_lyricsInactive = "#505050";
            m_statusSuccess = "#89d185";
            m_statusWarning = "#cca700";
            m_statusError = "#f14c4c";
            m_orange = "#ce9178";
        }
    } else if (m_family == "IntelliJ IDEA") {
        if (m_variant == "New UI Dark") {
            m_background = "#1e1f22";
            m_surface = "#2b2d30";
            m_surfaceElevated = "#393b40";
            m_text = "#dfe1e5";
            m_textMuted = "#868a91";
            m_border = "#43454a";
            m_borderHighlight = "#3574f0";
            m_accent = "#3574f0";
            m_selection = "#2e436e";
            m_player = "#191a1c";
            m_lyricsCurrent = "#3574f0";
            m_lyricsPrevious = "#868a91";
            m_lyricsInactive = "#4e5157";
            m_statusSuccess = "#57965c";
            m_statusWarning = "#f5d24b";
            m_statusError = "#e55757";
            m_orange = "#e08855";
        } else {
            // Darcula default
            m_background = "#2b2b2b";
            m_surface = "#313335";
            m_surfaceElevated = "#3c3f41";
            m_text = "#a9b7c6";
            m_textMuted = "#808080";
            m_border = "#4e5254";
            m_borderHighlight = "#4a88c7";
            m_accent = "#4a88c7";
            m_selection = "#214283";
            m_player = "#232525";
            m_lyricsCurrent = "#ffc66d";
            m_lyricsPrevious = "#808080";
            m_lyricsInactive = "#555555";
            m_statusSuccess = "#629755";
            m_statusWarning = "#bbb529";
            m_statusError = "#bc3f3c";
            m_orange = "#cc7832";
        }
    } else if (m_family == "Dracula") {
        m_background = "#282a36";
        m_surface = "#343746";
        m_surfaceElevated = "#44475a";
        m_text = "#f8f8f2";
        m_textMuted = "#6272a4";
        m_border = "#44475a";
        m_borderHighlight = "#bd93f9";
        m_accent = "#bd93f9";
        m_selection = "#44475a";
        m_player = "#21222c";
        m_lyricsCurrent = "#50fa7b";
        m_lyricsPrevious = "#f1fa8c";
        m_lyricsInactive = "#6272a4";
        m_statusSuccess = "#50fa7b";
        m_statusWarning = "#ffb86c";
        m_statusError = "#ff5555";
        m_orange = "#ffb86c";
    }
}
