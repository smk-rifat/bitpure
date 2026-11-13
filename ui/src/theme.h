#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>

class Theme : public QObject {
    Q_OBJECT

    // Family and Variant properties
    Q_PROPERTY(QString family READ family WRITE setFamily NOTIFY themeChanged)
    Q_PROPERTY(QString variant READ variant WRITE setVariant NOTIFY themeChanged)
    Q_PROPERTY(QString currentTheme READ currentTheme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QStringList availableFamilies READ availableFamilies CONSTANT)
    Q_PROPERTY(QStringList availableVariants READ availableVariants NOTIFY themeChanged)

    // Semantic design tokens
    Q_PROPERTY(QString background READ background NOTIFY changed)
    Q_PROPERTY(QString surface READ surface NOTIFY changed)
    Q_PROPERTY(QString surfaceElevated READ surfaceElevated NOTIFY changed)
    Q_PROPERTY(QString text READ text NOTIFY changed)
    Q_PROPERTY(QString textMuted READ textMuted NOTIFY changed)
    Q_PROPERTY(QString border READ border NOTIFY changed)
    Q_PROPERTY(QString borderHighlight READ borderHighlight NOTIFY changed)
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString selection READ selection NOTIFY changed)
    Q_PROPERTY(QString player READ player NOTIFY changed)
    Q_PROPERTY(QString lyricsCurrent READ lyricsCurrent NOTIFY changed)
    Q_PROPERTY(QString lyricsPrevious READ lyricsPrevious NOTIFY changed)
    Q_PROPERTY(QString lyricsInactive READ lyricsInactive NOTIFY changed)
    Q_PROPERTY(QString statusSuccess READ statusSuccess NOTIFY changed)
    Q_PROPERTY(QString statusWarning READ statusWarning NOTIFY changed)
    Q_PROPERTY(QString statusError READ statusError NOTIFY changed)

    // Legacy compatibility aliases
    Q_PROPERTY(QString foreground READ text NOTIFY changed)
    Q_PROPERTY(QString muted READ textMuted NOTIFY changed)
    Q_PROPERTY(QString darkBackground READ background NOTIFY changed)
    Q_PROPERTY(QString surfaceLighter READ surfaceElevated NOTIFY changed)
    Q_PROPERTY(QString yellow READ statusWarning NOTIFY changed)
    Q_PROPERTY(QString green READ statusSuccess NOTIFY changed)
    Q_PROPERTY(QString orange READ orange NOTIFY changed)
    Q_PROPERTY(QString red READ statusError NOTIFY changed)
    Q_PROPERTY(QString cyan READ accent NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)

public:
    explicit Theme(QObject *parent = nullptr);

    QString family() const { return m_family; }
    void setFamily(const QString &f);

    QString variant() const { return m_variant; }
    void setVariant(const QString &v);

    QString currentTheme() const { return m_variant; }
    void setTheme(const QString &name);

    Q_INVOKABLE void setFamilyAndVariant(const QString &fam, const QString &var);
    Q_INVOKABLE QStringList variantsForFamily(const QString &fam) const;

    QStringList availableFamilies() const;
    QStringList availableVariants() const;

    // Tokens
    QString background() const { return m_background; }
    QString surface() const { return m_surface; }
    QString surfaceElevated() const { return m_surfaceElevated; }
    QString text() const { return m_text; }
    QString textMuted() const { return m_textMuted; }
    QString border() const { return m_border; }
    QString borderHighlight() const { return m_borderHighlight; }
    QString accent() const { return m_accent; }
    QString selection() const { return m_selection; }
    QString player() const { return m_player; }
    QString lyricsCurrent() const { return m_lyricsCurrent; }
    QString lyricsPrevious() const { return m_lyricsPrevious; }
    QString lyricsInactive() const { return m_lyricsInactive; }
    QString statusSuccess() const { return m_statusSuccess; }
    QString statusWarning() const { return m_statusWarning; }
    QString statusError() const { return m_statusError; }
    QString orange() const { return m_orange; }
    int radius() const { return m_radius; }

signals:
    void changed();
    void themeChanged();

private:
    void applyPalette();

    QString m_family = "Gruvbox";
    QString m_variant = "Gruvbox Material Dark";

    QString m_background = "#282828";
    QString m_surface = "#32302f";
    QString m_surfaceElevated = "#3c3836";
    QString m_text = "#ebdbb2";
    QString m_textMuted = "#a89984";
    QString m_border = "#504945";
    QString m_borderHighlight = "#d79921";
    QString m_accent = "#d79921";
    QString m_selection = "#504945";
    QString m_player = "#1d2021";
    QString m_lyricsCurrent = "#fabd2f";
    QString m_lyricsPrevious = "#a89984";
    QString m_lyricsInactive = "#665c54";
    QString m_statusSuccess = "#b8bb26";
    QString m_statusWarning = "#fabd2f";
    QString m_statusError = "#fb4934";
    QString m_orange = "#fe8019";
    int m_radius = 2;
};
