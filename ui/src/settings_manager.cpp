#include "settings_manager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFontDatabase>
#include <QDebug>

SettingsManager::SettingsManager(QObject *parent) : QObject(parent) {
    load();
}

QString SettingsManager::settingsFilePath() const {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    return dir + "/settings.json";
}

QStringList SettingsManager::curatedFonts() const {
    return {
        "System Default",
        "JetBrains Mono",
        "Inter",
        "Fira Code",
        "Source Code Pro",
        "Noto Sans",
        "Roboto",
        "Cantarell"
    };
}

QStringList SettingsManager::availableFonts() const {
    QStringList list = {"System Default"};
    QStringList sys = QFontDatabase::families();
    for (const QString &f : curatedFonts()) {
        if (f != "System Default" && sys.contains(f) && !list.contains(f)) {
            list.append(f);
        }
    }
    // Append other common monospaced/clean fonts
    for (const QString &f : sys) {
        if (!list.contains(f) && (f.contains("Mono", Qt::CaseInsensitive) || f.contains("Sans", Qt::CaseInsensitive))) {
            list.append(f);
            if (list.size() > 30) break;
        }
    }
    return list;
}

void SettingsManager::setThemeFamily(const QString &f) {
    if (m_themeFamily != f && !f.trimmed().isEmpty()) {
        m_themeFamily = f.trimmed();
        emit themeFamilyChanged();
        save();
    }
}

void SettingsManager::setThemeVariant(const QString &v) {
    if (m_themeVariant != v && !v.trimmed().isEmpty()) {
        m_themeVariant = v.trimmed();
        emit themeVariantChanged();
        save();
    }
}

void SettingsManager::setFontFamily(const QString &f) {
    if (m_fontFamily != f && !f.trimmed().isEmpty()) {
        m_fontFamily = f.trimmed();
        emit fontFamilyChanged();
        save();
    }
}

void SettingsManager::setFontSizeScale(double s) {
    if (qAbs(m_fontSizeScale - s) > 0.01) {
        m_fontSizeScale = qBound(0.75, s, 1.50);
        emit fontSizeScaleChanged();
        save();
    }
}

void SettingsManager::setFontSizeLevel(int level) {
    if (m_fontSizeLevel != level) {
        m_fontSizeLevel = qBound(0, level, 3);
        emit fontSizeLevelChanged();
        switch (m_fontSizeLevel) {
            case 0: setFontSizeScale(0.85); break; // Small
            case 1: setFontSizeScale(1.00); break; // Default
            case 2: setFontSizeScale(1.15); break; // Large
            case 3: setFontSizeScale(1.30); break; // Extra Large
        }
    }
}

void SettingsManager::setReducedMotion(bool r) {
    if (m_reducedMotion != r) {
        m_reducedMotion = r;
        emit reducedMotionChanged();
        save();
    }
}

void SettingsManager::setIsBitPerfect(bool b) {
    if (m_isBitPerfect != b) {
        m_isBitPerfect = b;
        emit isBitPerfectChanged();
        save();
    }
}

void SettingsManager::setActiveDeviceId(const QString &id) {
    if (m_activeDeviceId != id && !id.isEmpty()) {
        m_activeDeviceId = id;
        emit activeDeviceIdChanged();
        save();
    }
}

void SettingsManager::setVolume(double v) {
    if (qAbs(m_volume - v) > 0.001) {
        m_volume = qBound(0.0, v, 1.0);
        emit volumeChanged();
        save();
    }
}

void SettingsManager::setActiveEqPreset(int p) {
    if (m_activeEqPreset != p) {
        m_activeEqPreset = p;
        emit activeEqPresetChanged();
        save();
    }
}

void SettingsManager::setPreamp(double p) {
    if (qAbs(m_preamp - p) > 0.05) {
        m_preamp = qBound(-12.0, p, 12.0);
        emit preampChanged();
        save();
    }
}

void SettingsManager::setShuffleMode(int m) {
    if (m_shuffleMode != m) {
        m_shuffleMode = m;
        emit shuffleModeChanged();
        save();
    }
}

void SettingsManager::setRepeatMode(int m) {
    if (m_repeatMode != m) {
        m_repeatMode = m;
        emit repeatModeChanged();
        save();
    }
}

void SettingsManager::setMusicFolder(const QString &path) {
    if (m_musicFolder != path && !path.trimmed().isEmpty()) {
        m_musicFolder = path.trimmed();
        emit musicFolderChanged();
        save();
    }
}

void SettingsManager::setLyricsTranslate(bool t) {
    if (m_lyricsTranslate != t) {
        m_lyricsTranslate = t;
        emit lyricsTranslateChanged();
        save();
    }
}

void SettingsManager::setLyricsTargetLang(const QString &lang) {
    if (m_lyricsTargetLang != lang && !lang.isEmpty()) {
        m_lyricsTargetLang = lang;
        emit lyricsTargetLangChanged();
        save();
    }
}

void SettingsManager::load() {
    QFile f(settingsFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return;
    QJsonObject obj = doc.object();

    if (obj.contains("themeFamily")) m_themeFamily = obj["themeFamily"].toString();
    if (obj.contains("themeVariant")) m_themeVariant = obj["themeVariant"].toString();
    if (obj.contains("fontFamily")) m_fontFamily = obj["fontFamily"].toString();
    if (obj.contains("fontSizeScale")) m_fontSizeScale = obj["fontSizeScale"].toDouble(1.0);
    if (obj.contains("fontSizeLevel")) m_fontSizeLevel = obj["fontSizeLevel"].toInt(1);
    if (obj.contains("reducedMotion")) m_reducedMotion = obj["reducedMotion"].toBool(false);
    if (obj.contains("isBitPerfect")) m_isBitPerfect = obj["isBitPerfect"].toBool(true);
    if (obj.contains("activeDeviceId")) m_activeDeviceId = obj["activeDeviceId"].toString("hw:1,0");
    if (obj.contains("volume")) m_volume = obj["volume"].toDouble(1.0);
    if (obj.contains("activeEqPreset")) m_activeEqPreset = obj["activeEqPreset"].toInt(0);
    if (obj.contains("preamp")) m_preamp = obj["preamp"].toDouble(0.0);
    if (obj.contains("shuffleMode")) m_shuffleMode = obj["shuffleMode"].toInt(0);
    if (obj.contains("repeatMode")) m_repeatMode = obj["repeatMode"].toInt(0);
    if (obj.contains("musicFolder")) m_musicFolder = obj["musicFolder"].toString("/home/smk/Music_LL");
    if (obj.contains("lyricsTranslate")) m_lyricsTranslate = obj["lyricsTranslate"].toBool(false);
    if (obj.contains("lyricsTargetLang")) m_lyricsTargetLang = obj["lyricsTargetLang"].toString("en");
}

void SettingsManager::save() {
    QFile f(settingsFilePath());
    if (!f.open(QIODevice::WriteOnly)) {
        return;
    }
    QJsonObject obj;
    obj["themeFamily"] = m_themeFamily;
    obj["themeVariant"] = m_themeVariant;
    obj["fontFamily"] = m_fontFamily;
    obj["fontSizeScale"] = m_fontSizeScale;
    obj["fontSizeLevel"] = m_fontSizeLevel;
    obj["reducedMotion"] = m_reducedMotion;
    obj["isBitPerfect"] = m_isBitPerfect;
    obj["activeDeviceId"] = m_activeDeviceId;
    obj["volume"] = m_volume;
    obj["activeEqPreset"] = m_activeEqPreset;
    obj["preamp"] = m_preamp;
    obj["shuffleMode"] = m_shuffleMode;
    obj["repeatMode"] = m_repeatMode;
    obj["musicFolder"] = m_musicFolder;
    obj["lyricsTranslate"] = m_lyricsTranslate;
    obj["lyricsTargetLang"] = m_lyricsTargetLang;

    f.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
}

void SettingsManager::resetAllSettings() {
    m_themeFamily = "Gruvbox";
    m_themeVariant = "Gruvbox Material Dark";
    m_fontFamily = "System Default";
    m_fontSizeScale = 1.0;
    m_fontSizeLevel = 1;
    m_reducedMotion = false;
    m_isBitPerfect = true;
    m_activeDeviceId = "hw:1,0";
    m_volume = 1.0;
    m_activeEqPreset = 0;
    m_preamp = 0.0;
    m_shuffleMode = 0;
    m_repeatMode = 0;
    m_musicFolder = "/home/smk/Music_LL";
    m_lyricsTranslate = false;
    m_lyricsTargetLang = "en";

    save();

    emit themeFamilyChanged();
    emit themeVariantChanged();
    emit fontFamilyChanged();
    emit fontSizeScaleChanged();
    emit fontSizeLevelChanged();
    emit reducedMotionChanged();
    emit isBitPerfectChanged();
    emit activeDeviceIdChanged();
    emit volumeChanged();
    emit activeEqPresetChanged();
    emit preampChanged();
    emit shuffleModeChanged();
    emit repeatModeChanged();
    emit musicFolderChanged();
    emit lyricsTranslateChanged();
    emit lyricsTargetLangChanged();
    emit allSettingsReset();
}

