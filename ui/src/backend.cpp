#include "backend.h"
#include "settings_manager.h"
#include "system_monitor.h"
#include "mood_service.h"
#include "translation_service.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QLocalSocket>
#include <QTimer>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QSet>
#include <QVector>
#include <QDebug>

extern "C" {
    int audioplayer_init(const char *db_path);
    char *audioplayer_get_devices_json();
    void audioplayer_set_device(const char *dev_id);
    void audioplayer_set_bit_perfect(int enabled);
    void audioplayer_set_eq_preset(int preset_idx);
    void audioplayer_set_eq_band(int band, float gain_db);
    char *audioplayer_play_file(const char *path);
    void audioplayer_stop();
    int audioplayer_scan_directory(const char *dir_path);
    int audioplayer_watch_directory(const char *dir_path);
    char *audioplayer_get_albums_json(int sort_type);
    char *audioplayer_get_album_tracks_json(const char *album_id_str);
    char *audioplayer_get_tracks_json(int sort_type);
    char *audioplayer_get_recommendations_json(const char *artist);
    void audioplayer_free_string(char *s);
}

Backend::Backend(QObject *parent) : QObject(parent) {
    m_settings = new SettingsManager(this);
    m_systemMonitor = new SystemMonitor(this);
    m_moodService = new MoodService(this);
    m_translationService = new TranslationService(this);

    // Apply loaded persistent settings
    m_volume = m_settings->volume();
    m_isBitPerfect = m_settings->isBitPerfect();
    m_shuffleMode = m_settings->shuffleMode();
    m_repeatMode = m_settings->repeatMode();
    m_musicFolder = m_settings->musicFolder();
    m_lyricsTranslationEnabled = m_settings->lyricsTranslate();

    connect(m_translationService, &TranslationService::translationReady, this, [this](const QString &orig, const QString &trans) {
        if (orig == m_currentLyricLine) {
            m_translatedLyricLine = trans;
            emit translatedLyricLineChanged();
        }
    });

    connect(m_settings, &SettingsManager::allSettingsReset, this, [this]() {
        setBitPerfect(m_settings->isBitPerfect());
        setVolume(m_settings->volume());
        setShuffleMode(m_settings->shuffleMode());
        setRepeatMode(m_settings->repeatMode());
        setActiveEqPreset(m_settings->activeEqPreset());
        setPreamp(m_settings->preamp());
        setMusicFolder(m_settings->musicFolder());
        setLyricsTranslationEnabled(m_settings->lyricsTranslate());
    });

    m_netManager = new QNetworkAccessManager(this);
    audioplayer_init(nullptr);
    initMpv();
    loadCustomPresets();
    loadLikedTracks();
    loadHistory();
    loadPlaylists();
    scanFolder(m_musicFolder);
    watchFolder(m_musicFolder);
    refreshDevices();
    setSortCriteria(6); // Default to Dopamine Hits
    fetchRecommendations("Kaavish");
}

Backend::~Backend() {
    persistCustomPresets();
    persistLikedTracks();
    persistHistory();
    persistPlaylists();
    if (m_mpvSocket) {
        sendMpvCommand("{\"command\": [\"quit\"]}\n");
        m_mpvSocket->disconnectFromServer();
    }
    if (m_mpvProcess) {
        m_mpvProcess->kill();
        m_mpvProcess->waitForFinished(500);
    }
    QFile::remove("/tmp/audioplayer-mpv.sock");
    audioplayer_stop();
}

void Backend::initMpv() {
    QFile::remove("/tmp/audioplayer-mpv.sock");

    m_mpvProcess = new QProcess(this);
    QStringList args;
    args << "--idle" << "--no-video" << "--keep-open=yes"
         << "--input-ipc-server=/tmp/audioplayer-mpv.sock";

    m_mpvProcess->start("mpv", args);

    m_mpvSocket = new QLocalSocket(this);
    connect(m_mpvSocket, &QLocalSocket::readyRead, this, &Backend::onMpvSocketReadyRead);

    QTimer::singleShot(250, this, [this]() {
        if (m_mpvSocket) {
            m_mpvSocket->connectToServer("/tmp/audioplayer-mpv.sock");
        }
    });

    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &Backend::pollPlayback);
    m_pollTimer->start(50);
}

void Backend::sendMpvCommand(const QString &cmd) {
    if (m_mpvSocket) {
        if (m_mpvSocket->state() != QLocalSocket::ConnectedState) {
            m_mpvSocket->connectToServer("/tmp/audioplayer-mpv.sock");
            m_mpvSocket->waitForConnected(100);
        }
        if (m_mpvSocket->state() == QLocalSocket::ConnectedState) {
            m_mpvSocket->write(cmd.toUtf8());
            m_mpvSocket->flush();
        }
    }
}

void Backend::onMpvSocketReadyRead() {
    while (m_mpvSocket && m_mpvSocket->canReadLine()) {
        QByteArray line = m_mpvSocket->readLine().trimmed();
        if (line.isEmpty()) continue;
        QJsonDocument doc = QJsonDocument::fromJson(line);
        if (!doc.isObject()) continue;
        QJsonObject obj = doc.object();

        // Detect track ending naturally -> auto-advance
        if (obj.contains("event")) {
            QString eventName = obj["event"].toString();
            if (eventName == "end-file") {
                QString reason = obj.value("reason").toString();
                if (reason == "eof") {
                    QTimer::singleShot(50, this, &Backend::nextTrack);
                }
            }
        }

        int reqId = obj.value("request_id").toInt(-1);
        if (reqId == 1 && obj.contains("data") && obj["data"].isDouble()) {
            qint64 posMs = (qint64)(obj["data"].toDouble() * 1000.0);
            if (qAbs(m_positionMs - posMs) > 40) {
                m_positionMs = posMs;
                emit positionChanged();
                updateCurrentLyric(posMs);
            }
        } else if (reqId == 2 && obj.contains("data") && obj["data"].isDouble()) {
            qint64 durMs = (qint64)(obj["data"].toDouble() * 1000.0);
            if (durMs > 0 && m_durationMs != durMs) {
                m_durationMs = durMs;
                emit durationChanged();
            }
        } else if (reqId == 3 && obj.contains("data") && obj["data"].isBool()) {
            bool paused = obj["data"].toBool();
            if (m_isPlaying == paused) {
                m_isPlaying = !paused;
                emit playStateChanged();
            }
        }
    }
}

void Backend::pollPlayback() {
    if (m_isPlaying) {
        sendMpvCommand("{\"command\": [\"get_property\", \"time-pos\"], \"request_id\": 1}\n");
        sendMpvCommand("{\"command\": [\"get_property\", \"duration\"], \"request_id\": 2}\n");
        sendMpvCommand("{\"command\": [\"get_property\", \"pause\"], \"request_id\": 3}\n");
    }
}

QString Backend::positionStr() const {
    qint64 totalSec = m_positionMs / 1000;
    qint64 min = totalSec / 60;
    qint64 sec = totalSec % 60;
    return QString("%1:%2").arg(min).arg(sec, 2, 10, QChar('0'));
}

QString Backend::durationStr() const {
    if (m_durationMs <= 0) return "0:00";
    qint64 totalSec = m_durationMs / 1000;
    qint64 min = totalSec / 60;
    qint64 sec = totalSec % 60;
    return QString("%1:%2").arg(min).arg(sec, 2, 10, QChar('0'));
}

void Backend::seekTo(qint64 ms) {
    double sec = ms / 1000.0;
    sendMpvCommand(QString("{\"command\": [\"seek\", %1, \"absolute\"]}\n").arg(QString::number(sec, 'f', 2)));
    m_positionMs = ms;
    emit positionChanged();
}

void Backend::seekFraction(float fraction) {
    if (m_durationMs > 0) {
        seekTo((qint64)(m_durationMs * fraction));
    }
}

void Backend::watchFolder(const QString &folderPath) {
    audioplayer_watch_directory(folderPath.toUtf8().constData());
}

void Backend::setMusicFolder(const QString &folderPath) {
    m_musicFolder = folderPath;
    if (m_settings) m_settings->setMusicFolder(folderPath);
    emit musicFolderChanged();
    scanFolder(folderPath);
    watchFolder(folderPath);
}

void Backend::setActiveEqPreset(int preset) {
    m_activeEqPreset = preset;
    audioplayer_set_eq_preset(preset);
    if (m_settings) m_settings->setActiveEqPreset(preset);

    // Synchronize local gains cache
    static const float presetGains[5][10] = {
        { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f }, // Flat
        { 1.5f, 1.0f, 0.5f, 0.0f, 0.0f, 0.5f, 1.0f, 1.5f, 2.0f, 1.5f }, // Balanced
        { 5.0f, 4.0f, 3.0f, 1.5f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f }, // Bass Boost
        { 2.0f, 1.8f, 1.2f, 0.5f, 0.0f, -0.5f, -0.8f, -1.0f, -1.5f, -2.0f }, // Warm Vocal
        { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, -1.0f, -2.0f, -3.0f, -4.0f, -5.0f }  // Treble Clean
    };

    if (preset >= 0 && preset < 5) {
        for (int i = 0; i < 10; ++i) {
            m_eqGains[i] = presetGains[preset][i];
        }
    }
    emit eqChanged();
}

void Backend::setEqBand(int band, float gainDb) {
    if (band >= 0 && band < 10) {
        m_eqGains[band] = gainDb;
        audioplayer_set_eq_band(band, gainDb);
        m_activeEqPreset = -1; // Custom user setting
        if (m_settings) m_settings->setActiveEqPreset(-1);
        emit eqChanged();
    }
}

void Backend::setPreamp(float db) {
    m_preamp = db;
    if (m_settings) m_settings->setPreamp(db);
    emit eqChanged();
}

void Backend::resetEq() {
    for (int i = 0; i < 10; ++i) {
        m_eqGains[i] = 0.0f;
        audioplayer_set_eq_band(i, 0.0f);
    }
    m_preamp = 0.0f;
    m_activeEqPreset = 0; // Flat
    emit eqChanged();
}

QVariantList Backend::eqGains() const {
    QVariantList list;
    for (int i = 0; i < 10; ++i) {
        list.append(m_eqGains[i]);
    }
    return list;
}

void Backend::fetchRecommendations(const QString &artist) {
    char *recs_c = audioplayer_get_recommendations_json(artist.toUtf8().constData());
    if (recs_c) {
        QJsonDocument doc = QJsonDocument::fromJson(recs_c);
        audioplayer_free_string(recs_c);
        if (doc.isArray()) {
            m_recommendations.clear();
            for (const auto &val : doc.array()) {
                m_recommendations.append(val.toObject().toVariantMap());
            }
            emit recommendationsChanged();
        }
    }
}

void Backend::refreshDevices() {
    char *devs_c = audioplayer_get_devices_json();
    if (devs_c) {
        QJsonDocument doc = QJsonDocument::fromJson(devs_c);
        audioplayer_free_string(devs_c);
        if (doc.isArray()) {
            m_devices.clear();
            for (const auto &val : doc.array()) {
                m_devices.append(val.toObject().toVariantMap());
            }
            emit devicesChanged();

            // Auto-select USB DAC if found
            for (const auto &d : m_devices) {
                QVariantMap m = d.toMap();
                if (m.value("is_usb_dac").toBool()) {
                    setActiveDeviceId(m.value("id").toString());
                    break;
                }
            }
        }
    }
}

void Backend::setBitPerfect(bool enabled) {
    m_isBitPerfect = enabled;
    audioplayer_set_bit_perfect(enabled ? 1 : 0);
    if (m_settings) m_settings->setIsBitPerfect(enabled);

    if (enabled) {
        m_signalPathInfo = QString("[Bit-Perfect Pure Mode: %1 (Direct Line-Out 0dB)]").arg(m_activeDeviceId);
        setVolume(1.0f);
    } else {
        m_signalPathInfo = QString("[Audited DSP Mode: %1 (10-Band EQ Active)]").arg(m_activeDeviceId);
    }

    emit bitPerfectChanged();
    emit signalPathChanged();
}

void Backend::setVolume(float v) {
    m_volume = qBound(0.0f, v, 1.0f);
    int mpvVol = (int)(m_volume * 100.0f);
    sendMpvCommand(QString("{\"command\": [\"set_property\", \"volume\", %1]}\n").arg(mpvVol));
    if (m_settings) m_settings->setVolume(m_volume);
    emit volumeChanged();
}

void Backend::setActiveDeviceId(const QString &id) {
    m_activeDeviceId = id;
    audioplayer_set_device(id.toUtf8().constData());
    if (m_settings) m_settings->setActiveDeviceId(id);
    setBitPerfect(m_isBitPerfect);
    emit deviceChanged();
}

void Backend::playTrack(const QString &filePath, const QString &title, const QString &artist) {
    m_nowPlayingTitle = title;
    m_nowPlayingArtist = artist;
    m_nowPlayingFilePath = filePath;
    emit trackChanged();

    // Track play history
    m_playHistory.removeAll(filePath);
    m_playHistory.append(filePath);
    if (m_playHistory.size() > 50) m_playHistory.removeFirst();
    persistHistory();
    emit historyChanged();

    // Synchronize currentTrackIndex
    QVariantList pool = m_playQueue.isEmpty() ? m_tracks : m_playQueue;
    for (int i = 0; i < pool.size(); ++i) {
        if (pool[i].toMap()["file_path"].toString() == filePath) {
            m_currentTrackIndex = i;
            emit currentTrackIndexChanged();
            break;
        }
    }

    fetchLyrics(artist, title, filePath);

    sendMpvCommand(QString("{\"command\": [\"loadfile\", \"%1\"]}\n").arg(filePath));
    sendMpvCommand("{\"command\": [\"set_property\", \"pause\", false]}\n");
    m_isPlaying = true;
    m_positionMs = 0;
    emit playStateChanged();
    emit positionChanged();

    char *sig_json = audioplayer_play_file(filePath.toUtf8().constData());
    if (sig_json) {
        QJsonDocument doc = QJsonDocument::fromJson(sig_json);
        audioplayer_free_string(sig_json);

        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            if (!obj.contains("error")) {
                QJsonObject src = obj["source_format"].toObject();

                QString depthStr = src["bit_depth"].toString();
                if (depthStr == "Bits24") depthStr = "24";
                else if (depthStr == "Bits16") depthStr = "16";
                else if (depthStr == "Bits32") depthStr = "32";
                else if (depthStr == "Float32") depthStr = "32";

                QString codecStr = src["codec"].toString().toUpper();
                if (codecStr.isEmpty() || codecStr == "NULL") codecStr = "LOSSLESS";

                int rate = src["sample_rate"].toInt();
                int ch = src["channels"].toInt();
                QString chStr = (ch == 2) ? "Stereo" : (ch == 1 ? "Mono" : QString("%1ch").arg(ch));

                m_formatBadge = QString("%1 | %2-bit | %3 kHz | %4")
                    .arg(codecStr)
                    .arg(depthStr)
                    .arg(rate / 1000)
                    .arg(chStr);

                emit formatChanged();
            }
        }
    }
}

void Backend::pause() {
    sendMpvCommand("{\"command\": [\"cycle\", \"pause\"]}\n");
    m_isPlaying = !m_isPlaying;
    emit playStateChanged();
}

void Backend::stop() {
    sendMpvCommand("{\"command\": [\"stop\"]}\n");
    m_isPlaying = false;
    m_positionMs = 0;
    emit playStateChanged();
    emit positionChanged();
}

void Backend::cycleShuffleMode() {
    setShuffleMode((m_shuffleMode + 1) % 3);
}

void Backend::setShuffleMode(int mode) {
    if (m_shuffleMode != mode) {
        m_shuffleMode = mode;
        if (m_settings) m_settings->setShuffleMode(mode);
        emit shuffleModeChanged();
    }
}

void Backend::cycleRepeatMode() {
    setRepeatMode((m_repeatMode + 1) % 3);
}

void Backend::setRepeatMode(int mode) {
    if (m_repeatMode != mode) {
        m_repeatMode = mode;
        if (m_settings) m_settings->setRepeatMode(mode);
        emit repeatModeChanged();
    }
}

void Backend::nextTrack() {
    QVariantList pool = m_playQueue.isEmpty() ? m_tracks : m_playQueue;
    if (pool.isEmpty()) return;

    if (m_repeatMode == 2 && m_currentTrackIndex >= 0 && m_currentTrackIndex < pool.size()) {
        // Repeat One
        QVariantMap trk = pool[m_currentTrackIndex].toMap();
        playTrack(trk["file_path"].toString(), trk["title"].toString(), trk["track_artist"].toString());
        return;
    }

    int nextIdx = -1;

    if (m_shuffleMode == 1) {
        // Normal Shuffle
        if (pool.size() == 1) {
            nextIdx = 0;
        } else {
            int tries = 0;
            do {
                nextIdx = QRandomGenerator::global()->bounded(pool.size());
                tries++;
            } while (nextIdx == m_currentTrackIndex && tries < 10);
        }
    } else if (m_shuffleMode == 2) {
        // Smart Shuffle: Biased towards liked songs and artists
        QSet<QString> likedArtists;
        for (const QString &lp : m_likedTrackPaths) {
            for (const auto &v : m_tracks) {
                QVariantMap m = v.toMap();
                if (m["file_path"].toString() == lp) {
                    likedArtists.insert(m["track_artist"].toString().trimmed().toLower());
                    break;
                }
            }
        }

        QVector<double> weights(pool.size(), 1.0);
        for (int i = 0; i < pool.size(); ++i) {
            QVariantMap m = pool[i].toMap();
            QString path = m["file_path"].toString();
            QString artist = m["track_artist"].toString().trimmed().toLower();

            if (m_likedTrackPaths.contains(path)) {
                weights[i] *= 6.0; // Liked songs get 6x weight
            }
            if (likedArtists.contains(artist)) {
                weights[i] *= 2.5; // Same artist as liked songs get 2.5x
            }
            if (m_playHistory.contains(path)) {
                weights[i] *= 0.1; // Avoid immediate repeat
            }
            if (i == m_currentTrackIndex && pool.size() > 1) {
                weights[i] = 0.0;
            }
        }

        double totalWeight = 0.0;
        for (double w : weights) totalWeight += w;

        if (totalWeight <= 0.0) {
            nextIdx = QRandomGenerator::global()->bounded(pool.size());
        } else {
            double r = QRandomGenerator::global()->generateDouble() * totalWeight;
            double running = 0.0;
            for (int i = 0; i < pool.size(); ++i) {
                running += weights[i];
                if (r <= running) {
                    nextIdx = i;
                    break;
                }
            }
            if (nextIdx < 0 || nextIdx >= pool.size()) nextIdx = 0;
        }
    } else {
        // Sequential
        nextIdx = m_currentTrackIndex + 1;
        if (nextIdx >= pool.size()) {
            if (m_repeatMode == 1) {
                nextIdx = 0; // Repeat All
            } else {
                stop();
                return;
            }
        }
    }

    if (nextIdx >= 0 && nextIdx < pool.size()) {
        m_currentTrackIndex = nextIdx;
        emit currentTrackIndexChanged();
        QVariantMap trk = pool[nextIdx].toMap();
        playTrack(trk["file_path"].toString(), trk["title"].toString(), trk["track_artist"].toString());
    }
}

void Backend::previousTrack() {
    if (m_positionMs > 3000) {
        seekTo(0);
        return;
    }

    QVariantList pool = m_playQueue.isEmpty() ? m_tracks : m_playQueue;
    if (pool.isEmpty()) return;

    if (m_playHistory.size() > 1) {
        m_playHistory.takeLast(); // current
        QString prevPath = m_playHistory.takeLast();
        for (int i = 0; i < pool.size(); ++i) {
            QVariantMap trk = pool[i].toMap();
            if (trk["file_path"].toString() == prevPath) {
                m_currentTrackIndex = i;
                emit currentTrackIndexChanged();
                playTrack(trk["file_path"].toString(), trk["title"].toString(), trk["track_artist"].toString());
                return;
            }
        }
    }

    int prevIdx = m_currentTrackIndex - 1;
    if (prevIdx < 0) {
        prevIdx = (m_repeatMode == 1) ? (pool.size() - 1) : 0;
    }
    m_currentTrackIndex = prevIdx;
    emit currentTrackIndexChanged();
    QVariantMap trk = pool[prevIdx].toMap();
    playTrack(trk["file_path"].toString(), trk["title"].toString(), trk["track_artist"].toString());
}

void Backend::scanFolder(const QString &folderPath) {
    audioplayer_scan_directory(folderPath.toUtf8().constData());
    setSortCriteria(0);
}

void Backend::setSortCriteria(int sortIndex) {
    char *alb_c = audioplayer_get_albums_json(sortIndex);
    if (alb_c) {
        QJsonDocument doc = QJsonDocument::fromJson(alb_c);
        audioplayer_free_string(alb_c);
        if (doc.isArray()) {
            m_albums.clear();
            for (const auto &val : doc.array()) {
                m_albums.append(val.toObject().toVariantMap());
            }
        }
    }

    char *trk_c = audioplayer_get_tracks_json(sortIndex);
    if (trk_c) {
        QJsonDocument doc = QJsonDocument::fromJson(trk_c);
        audioplayer_free_string(trk_c);
        if (doc.isArray()) {
            m_tracks.clear();
            for (const auto &val : doc.array()) {
                m_tracks.append(val.toObject().toVariantMap());
            }
        }
    }
    emit libraryChanged();
    emit likedTracksChanged();
    emit activePlaylistTracksChanged();
}

void Backend::loadCustomPresets() {
    m_customEqPresets.clear();
    QString path = QDir::homePath() + "/.config/bitpure/custom_eq.json";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isArray()) {
            for (const auto &v : doc.array()) {
                m_customEqPresets.append(v.toObject().toVariantMap());
            }
        }
    }
    emit customEqPresetsChanged();
}

void Backend::persistCustomPresets() {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    QFile f(dir + "/custom_eq.json");
    if (f.open(QIODevice::WriteOnly)) {
        QJsonArray arr;
        for (const auto &v : m_customEqPresets) {
            arr.append(QJsonObject::fromVariantMap(v.toMap()));
        }
        f.write(QJsonDocument(arr).toJson());
    }
}

void Backend::saveCustomPreset(const QString &name) {
    QString cleanName = name.trimmed();
    if (cleanName.isEmpty()) cleanName = "Custom Preset";

    QVariantList gains;
    for (int i = 0; i < 10; ++i) {
        gains.append(m_eqGains[i]);
    }

    QVariantMap map;
    map["name"] = cleanName;
    map["gains"] = gains;

    bool found = false;
    for (int i = 0; i < m_customEqPresets.size(); ++i) {
        if (m_customEqPresets[i].toMap()["name"].toString() == cleanName) {
            m_customEqPresets[i] = map;
            found = true;
            break;
        }
    }
    if (!found) {
        m_customEqPresets.append(map);
    }

    persistCustomPresets();
    emit customEqPresetsChanged();
}

void Backend::deleteCustomPreset(int index) {
    if (index >= 0 && index < m_customEqPresets.size()) {
        m_customEqPresets.removeAt(index);
        persistCustomPresets();
        emit customEqPresetsChanged();
    }
}

void Backend::applyCustomPreset(int index) {
    if (index >= 0 && index < m_customEqPresets.size()) {
        QVariantMap map = m_customEqPresets[index].toMap();
        QVariantList gains = map["gains"].toList();
        for (int i = 0; i < 10 && i < gains.size(); ++i) {
            float g = gains[i].toFloat();
            m_eqGains[i] = g;
            audioplayer_set_eq_band(i, g);
        }
        m_activeEqPreset = -1; // custom
        emit eqChanged();
    }
}

void Backend::loadLikedTracks() {
    m_likedTrackPaths.clear();
    QString path = QDir::homePath() + "/.config/bitpure/liked_songs.json";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isArray()) {
            for (const auto &v : doc.array()) {
                m_likedTrackPaths.append(v.toString());
            }
        }
        f.close();
    }
    emit likedTracksChanged();
}

void Backend::persistLikedTracks() {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    QFile f(dir + "/liked_songs.json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QJsonArray arr;
        for (const QString &p : m_likedTrackPaths) {
            arr.append(p);
        }
        f.write(QJsonDocument(arr).toJson());
        f.close();
    }
}

void Backend::loadHistory() {
    m_playHistory.clear();
    QString path = QDir::homePath() + "/.config/bitpure/history.json";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isArray()) {
            for (const auto &v : doc.array()) {
                m_playHistory.append(v.toString());
            }
        }
        f.close();
    }
    emit historyChanged();
}

void Backend::persistHistory() {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    QFile f(dir + "/history.json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QJsonArray arr;
        for (const QString &p : m_playHistory) {
            arr.append(p);
        }
        f.write(QJsonDocument(arr).toJson());
        f.close();
    }
}

void Backend::saveHistory() {
    persistHistory();
}

QVariantList Backend::historyTracks() const {
    QVariantList list;
    for (int i = m_playHistory.size() - 1; i >= 0; --i) {
        const QString &path = m_playHistory[i];
        for (const auto &trkVal : m_tracks) {
            QVariantMap map = trkVal.toMap();
            if (map["file_path"].toString() == path) {
                list.append(map);
                break;
            }
        }
    }
    return list;
}

bool Backend::isTrackLiked(const QString &filePath) const {
    return m_likedTrackPaths.contains(filePath);
}

void Backend::toggleLikeTrack(const QString &filePath) {
    if (m_likedTrackPaths.contains(filePath)) {
        m_likedTrackPaths.removeAll(filePath);
    } else {
        m_likedTrackPaths.append(filePath);
    }
    persistLikedTracks();
    emit likedTracksChanged();
}

void Backend::likeTrack(const QString &filePath) {
    if (!m_likedTrackPaths.contains(filePath)) {
        m_likedTrackPaths.append(filePath);
        persistLikedTracks();
        emit likedTracksChanged();
    }
}

void Backend::unlikeTrack(const QString &filePath) {
    if (m_likedTrackPaths.contains(filePath)) {
        m_likedTrackPaths.removeAll(filePath);
        persistLikedTracks();
        emit likedTracksChanged();
    }
}

QVariantList Backend::likedTracks() const {
    QVariantList list;
    for (const auto &v : m_tracks) {
        QVariantMap trk = v.toMap();
        if (m_likedTrackPaths.contains(trk["file_path"].toString())) {
            list.append(trk);
        }
    }
    return list;
}

void Backend::loadPlaylists() {
    m_playlists.clear();
    QString path = QDir::homePath() + "/.config/bitpure/playlists.json";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            for (auto it = obj.begin(); it != obj.end(); ++it) {
                QStringList tracks;
                if (it.value().isArray()) {
                    for (const auto &v : it.value().toArray()) {
                        tracks.append(v.toString());
                    }
                }
                m_playlists[it.key()] = tracks;
            }
        }
        f.close();
    }
    if (m_playlists.isEmpty()) {
        m_playlists["Favorites"] = QStringList();
    }
    if (m_activePlaylistName.isEmpty() || !m_playlists.contains(m_activePlaylistName)) {
        m_activePlaylistName = m_playlists.firstKey();
    }
    emit playlistsChanged();
    emit activePlaylistTracksChanged();
}

void Backend::persistPlaylists() {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    QFile f(dir + "/playlists.json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QJsonObject obj;
        for (auto it = m_playlists.begin(); it != m_playlists.end(); ++it) {
            QJsonArray arr;
            for (const QString &p : it.value()) {
                arr.append(p);
            }
            obj[it.key()] = arr;
        }
        f.write(QJsonDocument(obj).toJson());
        f.close();
    }
}

void Backend::createPlaylist(const QString &name) {
    QString clean = name.trimmed();
    if (clean.isEmpty()) return;
    if (!m_playlists.contains(clean)) {
        m_playlists[clean] = QStringList();
        m_activePlaylistName = clean;
        persistPlaylists();
        emit playlistsChanged();
        emit activePlaylistNameChanged();
        emit activePlaylistTracksChanged();
    }
}

void Backend::deletePlaylist(const QString &name) {
    if (m_playlists.contains(name)) {
        m_playlists.remove(name);
        if (m_activePlaylistName == name) {
            m_activePlaylistName = m_playlists.isEmpty() ? "" : m_playlists.firstKey();
            emit activePlaylistNameChanged();
        }
        persistPlaylists();
        emit playlistsChanged();
        emit activePlaylistTracksChanged();
    }
}

void Backend::addToPlaylist(const QString &playlistName, const QString &filePath) {
    if (m_playlists.contains(playlistName)) {
        if (!m_playlists[playlistName].contains(filePath)) {
            m_playlists[playlistName].append(filePath);
            persistPlaylists();
            emit playlistsChanged();
            if (m_activePlaylistName == playlistName) {
                emit activePlaylistTracksChanged();
            }
        }
    }
}

void Backend::removeFromPlaylist(const QString &playlistName, const QString &filePath) {
    if (m_playlists.contains(playlistName)) {
        if (m_playlists[playlistName].removeAll(filePath) > 0) {
            persistPlaylists();
            emit playlistsChanged();
            if (m_activePlaylistName == playlistName) {
                emit activePlaylistTracksChanged();
            }
        }
    }
}

void Backend::setActivePlaylistName(const QString &name) {
    if (m_activePlaylistName != name && m_playlists.contains(name)) {
        m_activePlaylistName = name;
        emit activePlaylistNameChanged();
        emit activePlaylistTracksChanged();
    }
}

QVariantList Backend::activePlaylistTracks() const {
    QVariantList list;
    if (!m_playlists.contains(m_activePlaylistName)) return list;
    const QStringList &paths = m_playlists[m_activePlaylistName];
    for (const QString &p : paths) {
        for (const auto &v : m_tracks) {
            QVariantMap trk = v.toMap();
            if (trk["file_path"].toString() == p) {
                list.append(trk);
                break;
            }
        }
    }
    return list;
}

void Backend::addToQueue(const QString &filePath) {
    for (const auto &v : m_tracks) {
        QVariantMap trk = v.toMap();
        if (trk["file_path"].toString() == filePath) {
            m_playQueue.append(trk);
            emit playQueueChanged();
            break;
        }
    }
}

void Backend::removeFromQueue(int index) {
    if (index >= 0 && index < m_playQueue.size()) {
        m_playQueue.removeAt(index);
        emit playQueueChanged();
    }
}

void Backend::clearQueue() {
    m_playQueue.clear();
    emit playQueueChanged();
}

bool Backend::deleteTrackFromStorage(const QString &filePath) {
    if (!QFile::exists(filePath)) return false;

    if (m_isPlaying && m_nowPlayingFilePath == filePath) {
        stop();
    }

    bool removed = QFile::remove(filePath);
    if (!removed) return false;

    // Remove from in-memory tracks
    for (int i = m_tracks.size() - 1; i >= 0; --i) {
        if (m_tracks[i].toMap()["file_path"].toString() == filePath) {
            m_tracks.removeAt(i);
        }
    }
    // Remove from queue
    for (int i = m_playQueue.size() - 1; i >= 0; --i) {
        if (m_playQueue[i].toMap()["file_path"].toString() == filePath) {
            m_playQueue.removeAt(i);
        }
    }
    // Remove from liked
    if (m_likedTrackPaths.contains(filePath)) {
        m_likedTrackPaths.removeAll(filePath);
        persistLikedTracks();
        emit likedTracksChanged();
    }
    // Remove from playlists
    bool pChanged = false;
    for (auto it = m_playlists.begin(); it != m_playlists.end(); ++it) {
        if (it.value().removeAll(filePath) > 0) {
            pChanged = true;
        }
    }
    if (pChanged) {
        persistPlaylists();
        emit playlistsChanged();
        emit activePlaylistTracksChanged();
    }

    emit libraryChanged();
    emit playQueueChanged();
    return true;
}

void Backend::fetchLyrics(const QString &artist, const QString &title, const QString &filePath) {
    m_syncedLyrics.clear();
    m_syncedLyricsLines.clear();
    m_currentLyricIndex = -1;
    m_currentLyricLine = "";
    m_translatedLyricLine = "";
    emit syncedLyricsChanged();
    emit currentLyricIndexChanged();
    emit currentLyricLineChanged();
    emit translatedLyricLineChanged();

    auto parseLrc = [this](const QString &lrcContent) -> bool {
        m_syncedLyrics.clear();
        m_syncedLyricsLines.clear();
        m_currentLyricIndex = -1;
        QStringList lines = lrcContent.split('\n');
        static QRegularExpression re("\\[(\\d+):(\\d+(?:\\.\\d+)?)\\](.*)");
        for (const QString &line : lines) {
            QRegularExpressionMatch match = re.match(line.trimmed());
            if (match.hasMatch()) {
                qint64 min = match.captured(1).toLongLong();
                double sec = match.captured(2).toDouble();
                qint64 totalMs = (min * 60 * 1000) + (qint64)(sec * 1000.0);
                QString text = match.captured(3).trimmed();
                if (!text.isEmpty()) {
                    m_syncedLyrics.append(qMakePair(totalMs, text));
                    QVariantMap m;
                    m["timeMs"] = totalMs;
                    m["text"] = text;
                    qint64 totalSec = totalMs / 1000;
                    m["timeStr"] = QString("%1:%2").arg(totalSec / 60).arg(totalSec % 60, 2, 10, QChar('0'));
                    m_syncedLyricsLines.append(m);
                }
            }
        }
        if (!m_syncedLyrics.isEmpty()) {
            m_lyrics = lrcContent;
            emit lyricsChanged();
            emit syncedLyricsChanged();
            updateCurrentLyric(m_positionMs);
            return true;
        }
        return false;
    };

    // 1. Check local .lrc file right next to audio file
    if (!filePath.isEmpty()) {
        QFileInfo fi(filePath);
        QString lrcPath = fi.dir().filePath(fi.completeBaseName() + ".lrc");
        if (QFile::exists(lrcPath)) {
            QFile lf(lrcPath);
            if (lf.open(QIODevice::ReadOnly | QIODevice::Text)) {
                if (parseLrc(QString::fromUtf8(lf.readAll()))) return;
            }
        }
        // 2. Check cached lyrics extracted from embedded tag
        QString cachedLrc = QDir::homePath() + "/.cache/bitpure/lyrics/" + fi.completeBaseName() + ".lrc";
        if (QFile::exists(cachedLrc)) {
            QFile lf(cachedLrc);
            if (lf.open(QIODevice::ReadOnly | QIODevice::Text)) {
                if (parseLrc(QString::fromUtf8(lf.readAll()))) return;
            }
        }
    }

    // 3. Query LRCLIB for synced lyrics
    QString cleanArtist = artist.split(',').first().split('&').first().split('/').first().trimmed();
    QString cleanTitle = title;
    int paren = cleanTitle.indexOf('(');
    if (paren > 0) cleanTitle = cleanTitle.left(paren).trimmed();
    int dash = cleanTitle.indexOf('-');
    if (dash > 0) cleanTitle = cleanTitle.left(dash).trimmed();

    m_lyrics = QString("Searching lyrics for %1 — %2...").arg(cleanArtist, cleanTitle);
    emit lyricsChanged();

    QUrl url("https://lrclib.net/api/get");
    QUrlQuery query;
    query.addQueryItem("artist_name", cleanArtist);
    query.addQueryItem("track_name", cleanTitle);
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "BitPure/1.0 (https://github.com/smk-rifat/bitpure)");

    QNetworkReply *reply = m_netManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cleanTitle, parseLrc]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject()) {
                QJsonObject obj = doc.object();
                QString synced = obj.value("syncedLyrics").toString();
                QString plain = obj.value("plainLyrics").toString();

                if (!synced.isEmpty() && parseLrc(synced)) {
                    return;
                } else if (!plain.isEmpty()) {
                    m_lyrics = plain;
                    m_currentLyricLine = plain.split('\n').first();
                    emit lyricsChanged();
                    emit currentLyricLineChanged();
                    return;
                }
            }
        }
        m_lyrics = QString("No synced lyrics found for \"%1\".").arg(cleanTitle);
        m_currentLyricLine = "";
        m_syncedLyricsLines.clear();
        m_currentLyricIndex = -1;
        emit lyricsChanged();
        emit syncedLyricsChanged();
        emit currentLyricIndexChanged();
        emit currentLyricLineChanged();
    });
}

void Backend::updateCurrentLyric(qint64 posMs) {
    if (m_syncedLyrics.isEmpty()) return;

    QString found = "";
    int activeIdx = -1;
    for (int i = 0; i < m_syncedLyrics.size(); ++i) {
        if (m_syncedLyrics[i].first <= posMs) {
            found = m_syncedLyrics[i].second;
            activeIdx = i;
        } else {
            break;
        }
    }

    if (activeIdx != m_currentLyricIndex) {
        m_currentLyricIndex = activeIdx;
        emit currentLyricIndexChanged();
    }

    if (found != m_currentLyricLine) {
        m_currentLyricLine = found;
        emit currentLyricLineChanged();

        if (m_lyricsTranslationEnabled && !found.isEmpty()) {
            QString cached = m_translationService->getCachedTranslation(found);
            if (!cached.isEmpty()) {
                m_translatedLyricLine = cached;
                emit translatedLyricLineChanged();
            } else {
                m_translationService->requestTranslation(found, m_settings ? m_settings->lyricsTargetLang() : "en");
            }
        } else {
            m_translatedLyricLine = "";
            emit translatedLyricLineChanged();
        }
    }
}

void Backend::setLyricsTranslationEnabled(bool e) {
    if (m_lyricsTranslationEnabled != e) {
        m_lyricsTranslationEnabled = e;
        if (m_settings) m_settings->setLyricsTranslate(e);
        emit lyricsTranslationEnabledChanged();
        if (e && !m_currentLyricLine.isEmpty()) {
            m_translationService->requestTranslation(m_currentLyricLine, m_settings ? m_settings->lyricsTargetLang() : "en");
        } else {
            m_translatedLyricLine = "";
            emit translatedLyricLineChanged();
        }
    }
}

QVariantList Backend::getAlbumTracks(const QString &albumId) {
    QVariantList list;
    char *c_res = audioplayer_get_album_tracks_json(albumId.toUtf8().constData());
    if (c_res) {
        QJsonDocument doc = QJsonDocument::fromJson(c_res);
        audioplayer_free_string(c_res);
        if (doc.isArray()) {
            for (const auto &v : doc.array()) {
                list.append(v.toObject().toVariantMap());
            }
        }
    }
    return list;
}

void Backend::playAlbum(const QString &albumId) {
    QVariantList trks = getAlbumTracks(albumId);
    if (!trks.isEmpty()) {
        m_playQueue = trks;
        emit playQueueChanged();
        QVariantMap first = trks.first().toMap();
        playTrack(first["file_path"].toString(), first["title"].toString(), first["track_artist"].toString());
    }
}

void Backend::playMood(const QString &mood) {
    QVariantList scored = m_moodService->scoreTracksForMood(mood, m_tracks, m_likedTrackPaths);
    if (!scored.isEmpty()) {
        m_playQueue = scored;
        emit playQueueChanged();
        QVariantMap first = scored.first().toMap();
        playTrack(first["file_path"].toString(), first["title"].toString(), first["track_artist"].toString());
    }
}

void Backend::rescanLibrary() {
    scanFolder(m_musicFolder);
}
