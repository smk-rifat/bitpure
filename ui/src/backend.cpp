#include "backend.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QLocalSocket>
#include <QTimer>
#include <QFile>
#include <QFileInfo>
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
    char *audioplayer_get_tracks_json(int sort_type);
    char *audioplayer_get_recommendations_json(const char *artist);
    void audioplayer_free_string(char *s);
}

Backend::Backend(QObject *parent) : QObject(parent) {
    audioplayer_init(nullptr);
    initMpv();
    scanFolder(m_musicFolder);
    watchFolder(m_musicFolder);
    refreshDevices();
    setSortCriteria(6); // Default to Dopamine Hits
    fetchRecommendations("Kaavish");
}

Backend::~Backend() {
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
    m_pollTimer->start(200);
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

        int reqId = obj.value("request_id").toInt(-1);
        if (reqId == 1 && obj.contains("data") && obj["data"].isDouble()) {
            qint64 posMs = (qint64)(obj["data"].toDouble() * 1000.0);
            if (qAbs(m_positionMs - posMs) > 100) {
                m_positionMs = posMs;
                emit positionChanged();
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
    float clamped = qBound(0.0f, fraction, 1.0f);
    if (m_durationMs > 0) {
        qint64 targetMs = (qint64)(clamped * (float)m_durationMs);
        seekTo(targetMs);
    }
}

void Backend::watchFolder(const QString &folderPath) {
    audioplayer_watch_directory(folderPath.toUtf8().constData());
}

void Backend::setMusicFolder(const QString &folderPath) {
    if (m_musicFolder != folderPath) {
        m_musicFolder = folderPath;
        scanFolder(folderPath);
        watchFolder(folderPath);
        emit musicFolderChanged();
    }
}

void Backend::setActiveEqPreset(int preset) {
    m_activeEqPreset = preset;
    audioplayer_set_eq_preset(preset);

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
        emit eqChanged();
    }
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
    char *json_c = audioplayer_get_devices_json();
    if (json_c) {
        QJsonDocument doc = QJsonDocument::fromJson(json_c);
        audioplayer_free_string(json_c);

        if (doc.isArray()) {
            m_devices.clear();
            QJsonArray arr = doc.array();
            for (const auto &val : arr) {
                m_devices.append(val.toObject().toVariantMap());
            }
            if (!m_devices.isEmpty() && (m_activeDeviceId.isEmpty() || m_activeDeviceId == "hw:1,0")) {
                m_activeDeviceId = m_devices.first().toMap()["id"].toString();
                audioplayer_set_device(m_activeDeviceId.toUtf8().constData());
            }
            emit devicesChanged();
            emit deviceChanged();
            emit signalPathChanged();
        }
    }
}

void Backend::setBitPerfect(bool enabled) {
    if (m_isBitPerfect != enabled) {
        m_isBitPerfect = enabled;
        audioplayer_set_bit_perfect(enabled ? 1 : 0);
        if (enabled) {
            m_volume = 1.0f;
            QProcess::startDetached("wpctl", QStringList() << "set-volume" << "@DEFAULT_AUDIO_SINK@" << "1.0");
            m_signalPathInfo = QString("[Bit-Perfect Pure Mode: %1 (Direct DAC 0dB)]").arg(m_activeDeviceId);
        } else {
            m_signalPathInfo = QString("[Audited DSP Mode: %1 (Software Volume & EQ Active)]").arg(m_activeDeviceId);
        }
        emit bitPerfectChanged();
        emit signalPathChanged();
        emit volumeChanged();
    }
}

void Backend::setVolume(float v) {
    float clamped = qBound(0.0f, v, 1.0f);
    if (qAbs(m_volume - clamped) > 0.001f) {
        m_volume = clamped;
        if (m_isBitPerfect && clamped < 0.999f) {
            // Automatically switch out of Pure Mode if software volume is adjusted
            m_isBitPerfect = false;
            audioplayer_set_bit_perfect(0);
            m_signalPathInfo = QString("[Audited DSP Mode: %1 (Software Volume & EQ Active)]").arg(m_activeDeviceId);
            emit bitPerfectChanged();
            emit signalPathChanged();
        }
        // Apply volume directly to audio sink via wpctl
        QProcess::startDetached("wpctl", QStringList() << "set-volume" << "@DEFAULT_AUDIO_SINK@" << QString::number(clamped, 'f', 2));
        emit volumeChanged();
    }
}

void Backend::setActiveDeviceId(const QString &id) {
    if (m_activeDeviceId != id) {
        m_activeDeviceId = id;
        audioplayer_set_device(id.toUtf8().constData());
        QProcess::startDetached("wpctl", QStringList() << "set-default" << id);
        m_signalPathInfo = QString("[%1: %2]").arg(m_isBitPerfect ? "Bit-Perfect Pure" : "DSP Mode").arg(id);
        emit deviceChanged();
        emit signalPathChanged();
    }
}

void Backend::playTrack(const QString &filePath, const QString &title, const QString &artist) {
    m_nowPlayingTitle = title;
    m_nowPlayingArtist = artist;
    emit trackChanged();

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
}
