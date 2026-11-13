#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QFontDatabase>

class SettingsManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString themeFamily READ themeFamily WRITE setThemeFamily NOTIFY themeFamilyChanged)
    Q_PROPERTY(QString themeVariant READ themeVariant WRITE setThemeVariant NOTIFY themeVariantChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged)
    Q_PROPERTY(double fontSizeScale READ fontSizeScale WRITE setFontSizeScale NOTIFY fontSizeScaleChanged)
    Q_PROPERTY(int fontSizeLevel READ fontSizeLevel WRITE setFontSizeLevel NOTIFY fontSizeLevelChanged)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY reducedMotionChanged)
    Q_PROPERTY(bool isBitPerfect READ isBitPerfect WRITE setIsBitPerfect NOTIFY isBitPerfectChanged)
    Q_PROPERTY(QString activeDeviceId READ activeDeviceId WRITE setActiveDeviceId NOTIFY activeDeviceIdChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int activeEqPreset READ activeEqPreset WRITE setActiveEqPreset NOTIFY activeEqPresetChanged)
    Q_PROPERTY(double preamp READ preamp WRITE setPreamp NOTIFY preampChanged)
    Q_PROPERTY(int shuffleMode READ shuffleMode WRITE setShuffleMode NOTIFY shuffleModeChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(QString musicFolder READ musicFolder WRITE setMusicFolder NOTIFY musicFolderChanged)
    Q_PROPERTY(bool lyricsTranslate READ lyricsTranslate WRITE setLyricsTranslate NOTIFY lyricsTranslateChanged)
    Q_PROPERTY(QString lyricsTargetLang READ lyricsTargetLang WRITE setLyricsTargetLang NOTIFY lyricsTargetLangChanged)

    Q_PROPERTY(QStringList availableFonts READ availableFonts CONSTANT)
    Q_PROPERTY(QStringList curatedFonts READ curatedFonts CONSTANT)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString themeFamily() const { return m_themeFamily; }
    void setThemeFamily(const QString &f);

    QString themeVariant() const { return m_themeVariant; }
    void setThemeVariant(const QString &v);

    QString fontFamily() const { return m_fontFamily; }
    void setFontFamily(const QString &f);

    double fontSizeScale() const { return m_fontSizeScale; }
    void setFontSizeScale(double s);

    int fontSizeLevel() const { return m_fontSizeLevel; }
    void setFontSizeLevel(int level);

    bool reducedMotion() const { return m_reducedMotion; }
    void setReducedMotion(bool r);

    bool isBitPerfect() const { return m_isBitPerfect; }
    void setIsBitPerfect(bool b);

    QString activeDeviceId() const { return m_activeDeviceId; }
    void setActiveDeviceId(const QString &id);

    double volume() const { return m_volume; }
    void setVolume(double v);

    int activeEqPreset() const { return m_activeEqPreset; }
    void setActiveEqPreset(int p);

    double preamp() const { return m_preamp; }
    void setPreamp(double p);

    int shuffleMode() const { return m_shuffleMode; }
    void setShuffleMode(int m);

    int repeatMode() const { return m_repeatMode; }
    void setRepeatMode(int m);

    QString musicFolder() const { return m_musicFolder; }
    void setMusicFolder(const QString &path);

    bool lyricsTranslate() const { return m_lyricsTranslate; }
    void setLyricsTranslate(bool t);

    QString lyricsTargetLang() const { return m_lyricsTargetLang; }
    void setLyricsTargetLang(const QString &lang);

    QStringList availableFonts() const;
    QStringList curatedFonts() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    Q_INVOKABLE void resetAllSettings();

signals:
    void themeFamilyChanged();
    void themeVariantChanged();
    void fontFamilyChanged();
    void fontSizeScaleChanged();
    void fontSizeLevelChanged();
    void reducedMotionChanged();
    void isBitPerfectChanged();
    void activeDeviceIdChanged();
    void volumeChanged();
    void activeEqPresetChanged();
    void preampChanged();
    void shuffleModeChanged();
    void repeatModeChanged();
    void musicFolderChanged();
    void lyricsTranslateChanged();
    void lyricsTargetLangChanged();
    void allSettingsReset();

private:
    QString settingsFilePath() const;

    QString m_themeFamily = "Gruvbox";
    QString m_themeVariant = "Gruvbox Material Dark";
    QString m_fontFamily = "System Default";
    double m_fontSizeScale = 1.0;
    int m_fontSizeLevel = 1; // 0=Small, 1=Default, 2=Large, 3=Extra Large
    bool m_reducedMotion = false;
    bool m_isBitPerfect = true;
    QString m_activeDeviceId = "hw:1,0";
    double m_volume = 1.0;
    int m_activeEqPreset = 0;
    double m_preamp = 0.0;
    int m_shuffleMode = 0;
    int m_repeatMode = 0;
    QString m_musicFolder = "/home/smk/Music_LL";
    bool m_lyricsTranslate = false;
    QString m_lyricsTargetLang = "en";
};

