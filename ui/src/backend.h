#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QMap>

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
    Q_PROPERTY(QString nowPlayingFilePath READ nowPlayingFilePath NOTIFY trackChanged)
    Q_PROPERTY(QString formatBadge READ formatBadge NOTIFY formatChanged)
    Q_PROPERTY(QString signalPathInfo READ signalPathInfo NOTIFY signalPathChanged)
    Q_PROPERTY(QString activeDeviceId READ activeDeviceId WRITE setActiveDeviceId NOTIFY deviceChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList albums READ albums NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList tracks READ tracks NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList recommendations READ recommendations NOTIFY recommendationsChanged)
    Q_PROPERTY(int activeEqPreset READ activeEqPreset WRITE setActiveEqPreset NOTIFY eqChanged)
    Q_PROPERTY(QVariantList eqGains READ eqGains NOTIFY eqChanged)
    Q_PROPERTY(float preamp READ preamp WRITE setPreamp NOTIFY eqChanged)
    Q_PROPERTY(QString lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QString currentLyricLine READ currentLyricLine NOTIFY currentLyricLineChanged)
    Q_PROPERTY(QVariantList customEqPresets READ customEqPresets NOTIFY customEqPresetsChanged)
    Q_PROPERTY(QString musicFolder READ musicFolder NOTIFY musicFolderChanged)
    Q_PROPERTY(QString developerName READ developerName CONSTANT)

    // Playback modes & Queue
    Q_PROPERTY(int shuffleMode READ shuffleMode WRITE setShuffleMode NOTIFY shuffleModeChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(int currentTrackIndex READ currentTrackIndex NOTIFY currentTrackIndexChanged)
    Q_PROPERTY(QVariantList playQueue READ playQueue NOTIFY playQueueChanged)

    // Liked tracks
    Q_PROPERTY(QStringList likedTrackPaths READ likedTrackPaths NOTIFY likedTracksChanged)
    Q_PROPERTY(QVariantList likedTracks READ likedTracks NOTIFY likedTracksChanged)

    // Playlists
    Q_PROPERTY(QStringList playlistNames READ playlistNames NOTIFY playlistsChanged)
    Q_PROPERTY(QString activePlaylistName READ activePlaylistName WRITE setActivePlaylistName NOTIFY activePlaylistNameChanged)
    Q_PROPERTY(QVariantList activePlaylistTracks READ activePlaylistTracks NOTIFY activePlaylistTracksChanged)

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
    QString nowPlayingFilePath() const { return m_nowPlayingFilePath; }
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
    float preamp() const { return m_preamp; }
    void setPreamp(float db);

    int shuffleMode() const { return m_shuffleMode; }
    void setShuffleMode(int mode);
    int repeatMode() const { return m_repeatMode; }
    void setRepeatMode(int mode);
    int currentTrackIndex() const { return m_currentTrackIndex; }
    QVariantList playQueue() const { return m_playQueue; }

    QStringList likedTrackPaths() const { return m_likedTrackPaths; }
    QVariantList likedTracks() const;

    QStringList playlistNames() const { return m_playlists.keys(); }
    QString activePlaylistName() const { return m_activePlaylistName; }
    void setActivePlaylistName(const QString &name);
    QVariantList activePlaylistTracks() const;

    QVariantList devices() const { return m_devices; }
    QVariantList albums() const { return m_albums; }
    QVariantList tracks() const { return m_tracks; }
    QVariantList recommendations() const { return m_recommendations; }

public slots:
    void playTrack(const QString &filePath, const QString &title, const QString &artist);
    void pause();
    void stop();
    void nextTrack();
    void previousTrack();
    void cycleShuffleMode();
    void cycleRepeatMode();

    void seekTo(qint64 ms);
    void seekFraction(float fraction);
    void scanFolder(const QString &folderPath);
    void watchFolder(const QString &folderPath);
    void setMusicFolder(const QString &folderPath);
    void setSortCriteria(int sortIndex);
    void refreshDevices();
    void fetchRecommendations(const QString &artist);

    // EQ
    void setEqBand(int band, float gainDb);
    void resetEq();
    void saveCustomPreset(const QString &name);
    void deleteCustomPreset(int index);
    void applyCustomPreset(int index);

    // Lyrics
    void fetchLyrics(const QString &artist, const QString &title);

    // Liked songs
    bool isTrackLiked(const QString &filePath) const;
    void toggleLikeTrack(const QString &filePath);
    void likeTrack(const QString &filePath);
    void unlikeTrack(const QString &filePath);

    // Playlists & Queue
    void createPlaylist(const QString &name);
    void deletePlaylist(const QString &name);
    void addToPlaylist(const QString &playlistName, const QString &filePath);
    void removeFromPlaylist(const QString &playlistName, const QString &filePath);

    void addToQueue(const QString &filePath);
    void removeFromQueue(int index);
    void clearQueue();

    // Storage deletion
    bool deleteTrackFromStorage(const QString &filePath);

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
    void shuffleModeChanged();
    void repeatModeChanged();
    void currentTrackIndexChanged();
    void playQueueChanged();
    void likedTracksChanged();
    void playlistsChanged();
    void activePlaylistNameChanged();
    void activePlaylistTracksChanged();

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
    float m_preamp = 0.0f;
    QVariantList m_customEqPresets;
    QString m_lyrics = "No lyrics loaded.";
    QString m_currentLyricLine = "";
    QList<QPair<qint64, QString>> m_syncedLyrics;
    class QNetworkAccessManager *m_netManager = nullptr;

    void loadCustomPresets();
    void persistCustomPresets();
    void updateCurrentLyric(qint64 posMs);

    void loadLikedTracks();
    void persistLikedTracks();

    void loadPlaylists();
    void persistPlaylists();

    int m_shuffleMode = 0; // 0=Off, 1=Normal, 2=Smart
    int m_repeatMode = 0;  // 0=Off, 1=All, 2=One
    int m_currentTrackIndex = -1;
    QVariantList m_playQueue;
    QStringList m_playHistory;
    QStringList m_likedTrackPaths;
    QMap<QString, QStringList> m_playlists;
    QString m_activePlaylistName = "Favorites";

    QString m_musicFolder = "/home/smk/Music_LL";
    QString m_nowPlayingTitle = "Ready";
    QString m_nowPlayingArtist = "Select an album or track";
    QString m_nowPlayingFilePath = "";
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
