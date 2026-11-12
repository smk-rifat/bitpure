#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playStateChanged)
    Q_PROPERTY(bool isBitPerfect READ isBitPerfect WRITE setBitPerfect NOTIFY bitPerfectChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qint64 positionMs READ positionMs NOTIFY positionChanged)
    Q_PROPERTY(qint64 durationMs READ durationMs NOTIFY durationChanged)
    Q_PROPERTY(QString positionStr READ positionStr NOTIFY positionChanged)
    Q_PROPERTY(QString durationStr READ durationStr NOTIFY durationChanged)
    Q_PROPERTY(float progress READ progress NOTIFY positionChanged)
    Q_PROPERTY(QString nowPlayingTitle READ nowPlayingTitle NOTIFY trackChanged)
    Q_PROPERTY(QString nowPlayingArtist READ nowPlayingArtist NOTIFY trackChanged)
    Q_PROPERTY(QString formatBadge READ formatBadge NOTIFY formatChanged)
    Q_PROPERTY(QString signalPathInfo READ signalPathInfo NOTIFY signalPathChanged)
    Q_PROPERTY(QString activeDeviceId READ activeDeviceId WRITE setActiveDeviceId NOTIFY deviceChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList albums READ albums NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList tracks READ tracks NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList recommendations READ recommendations NOTIFY recommendationsChanged)
    Q_PROPERTY(int activeEqPreset READ activeEqPreset WRITE setActiveEqPreset NOTIFY eqChanged)
    Q_PROPERTY(QVariantList eqGains READ eqGains NOTIFY eqChanged)
    Q_PROPERTY(QString lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QString currentLyricLine READ currentLyricLine NOTIFY currentLyricLineChanged)
    Q_PROPERTY(QVariantList customEqPresets READ customEqPresets NOTIFY customEqPresetsChanged)
    Q_PROPERTY(QString musicFolder READ musicFolder NOTIFY musicFolderChanged)
    Q_PROPERTY(QString developerName READ developerName CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    bool isPlaying() const { return m_isPlaying; }
    bool isBitPerfect() const { return m_isBitPerfect; }
    void setBitPerfect(bool enabled);

    float volume() const { return m_volume; }
    void setVolume(float v);

    qint64 positionMs() const { return m_positionMs; }
    qint64 durationMs() const { return m_durationMs; }
    float progress() const { return m_durationMs > 0 ? (float)m_positionMs / (float)m_durationMs : 0.0f; }
    QString positionStr() const;
    QString durationStr() const;

    QString nowPlayingTitle() const { return m_nowPlayingTitle; }
    QString nowPlayingArtist() const { return m_nowPlayingArtist; }
    QString formatBadge() const { return m_formatBadge; }
    QString signalPathInfo() const { return m_signalPathInfo; }
    QString activeDeviceId() const { return m_activeDeviceId; }
    void setActiveDeviceId(const QString &id);

    QString lyrics() const { return m_lyrics; }
    QString currentLyricLine() const { return m_currentLyricLine; }
    QVariantList customEqPresets() const { return m_customEqPresets; }

    QString musicFolder() const { return m_musicFolder; }
    QString developerName() const { return "smk"; }

    int activeEqPreset() const { return m_activeEqPreset; }
    void setActiveEqPreset(int preset);
    QVariantList eqGains() const;

    QVariantList devices() const { return m_devices; }
    QVariantList albums() const { return m_albums; }
    QVariantList tracks() const { return m_tracks; }
    QVariantList recommendations() const { return m_recommendations; }

public slots:
    void playTrack(const QString &filePath, const QString &title, const QString &artist);
    void pause();
    void stop();
    void seekTo(qint64 ms);
    void seekFraction(float fraction);
    void scanFolder(const QString &folderPath);
    void watchFolder(const QString &folderPath);
    void setMusicFolder(const QString &folderPath);
    void setSortCriteria(int sortIndex);
    void refreshDevices();
    void fetchRecommendations(const QString &artist);
    void setEqBand(int band, float gainDb);
    void saveCustomPreset(const QString &name);
    void deleteCustomPreset(int index);
    void applyCustomPreset(int index);
    void fetchLyrics(const QString &artist, const QString &title);

signals:
    void playStateChanged();
    void bitPerfectChanged();
    void positionChanged();
    void durationChanged();
    void trackChanged();
    void formatChanged();
    void signalPathChanged();
    void deviceChanged();
    void devicesChanged();
    void libraryChanged();
    void recommendationsChanged();
    void eqChanged();
    void customEqPresetsChanged();
    void lyricsChanged();
    void currentLyricLineChanged();
    void musicFolderChanged();
    void volumeChanged();

private slots:
    void onMpvSocketReadyRead();
    void pollPlayback();

private:
    void initMpv();
    void sendMpvCommand(const QString &cmd);

    bool m_isPlaying = false;
    bool m_isBitPerfect = true;
    float m_volume = 1.0f;
    qint64 m_positionMs = 0;
    qint64 m_durationMs = 0;
    int m_activeEqPreset = 0;
    float m_eqGains[10] = {0.0f};
    QVariantList m_customEqPresets;
    QString m_lyrics = "No lyrics loaded.";
    QString m_currentLyricLine = "";
    QList<QPair<qint64, QString>> m_syncedLyrics;
    class QNetworkAccessManager *m_netManager = nullptr;
    void loadCustomPresets();
    void persistCustomPresets();
    void updateCurrentLyric(qint64 posMs);
    QString m_musicFolder = "/home/smk/Music_LL";
    QString m_nowPlayingTitle = "Ready";
    QString m_nowPlayingArtist = "Select an album or track";
    QString m_formatBadge = "FLAC | 24-bit | 96 kHz | Stereo";
    QString m_signalPathInfo = "[Bit-Perfect Pure Mode: hw:1,0 (NICEHCK NK1 MAX)]";
    QString m_activeDeviceId = "hw:1,0";

    QVariantList m_devices;
    QVariantList m_albums;
    QVariantList m_tracks;
    QVariantList m_recommendations;

    class QProcess *m_mpvProcess = nullptr;
    class QLocalSocket *m_mpvSocket = nullptr;
    class QTimer *m_pollTimer = nullptr;
};

