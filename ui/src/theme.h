#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QColor>

class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentTheme READ currentTheme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString background READ background NOTIFY changed)
    Q_PROPERTY(QString darkBackground READ darkBackground NOTIFY changed)
    Q_PROPERTY(QString surface READ surface NOTIFY changed)
    Q_PROPERTY(QString surfaceLighter READ surfaceLighter NOTIFY changed)
    Q_PROPERTY(QString foreground READ foreground NOTIFY changed)
    Q_PROPERTY(QString muted READ muted NOTIFY changed)
    Q_PROPERTY(QString border READ border NOTIFY changed)
    Q_PROPERTY(QString borderHighlight READ borderHighlight NOTIFY changed)
    Q_PROPERTY(QString selection READ selection NOTIFY changed)
    Q_PROPERTY(QString yellow READ yellow NOTIFY changed)
    Q_PROPERTY(QString green READ green NOTIFY changed)
    Q_PROPERTY(QString orange READ orange NOTIFY changed)
    Q_PROPERTY(QString red READ red NOTIFY changed)
    Q_PROPERTY(QString cyan READ cyan NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(QStringList availableThemes READ availableThemes CONSTANT)

public:
    explicit Theme(QObject *parent = nullptr);

    QString currentTheme() const { return m_currentTheme; }
    void setTheme(const QString &name);

    QString accent() const { return m_accent; }
    QString background() const { return m_background; }
    QString darkBackground() const { return m_darkBackground; }
    QString surface() const { return m_surface; }
    QString surfaceLighter() const { return m_surfaceLighter; }
    QString foreground() const { return m_foreground; }
    QString muted() const { return m_muted; }
    QString border() const { return m_border; }
    QString borderHighlight() const { return m_borderHighlight; }
    QString selection() const { return m_selection; }
    QString yellow() const { return m_yellow; }
    QString green() const { return m_green; }
    QString orange() const { return m_orange; }
    QString red() const { return m_red; }
    QString cyan() const { return m_cyan; }
    int radius() const { return m_radius; }

    QStringList availableThemes() const {
        return {
            "everforest", "gruvbox", "tokyo-night", "nord",
            "catppuccin", "rose-pine", "kanagawa", "matte-black",
            "hackerman", "retro-82", "lumon", "solitude",
            "starship", "ristretto", "jade-horse", "miasma",
            "ethereal", "last-horizon", "catppuccin-latte", "flexoki-light",
            "lupine", "vantablack", "white"
        };
    }

signals:
    void changed();
    void themeChanged();

private slots:
    void reload();

private:
    QString m_currentTheme = "everforest";
    QString m_accent = "#7fbbb3";
    QString m_background = "#232a2e";
    QString m_darkBackground = "#1e2326";
    QString m_surface = "#2d353b";
    QString m_surfaceLighter = "#343f44";
    QString m_foreground = "#d3c6aa";
    QString m_muted = "#859289";
    QString m_border = "#475258";
    QString m_borderHighlight = "#7fbbb3";
    QString m_selection = "#3d484d";
    QString m_yellow = "#dbbc7f";
    QString m_green = "#a7c080";
    QString m_orange = "#e09d7f";
    QString m_red = "#e67e80";
    QString m_cyan = "#83c092";
    int m_radius = 2;

    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};

