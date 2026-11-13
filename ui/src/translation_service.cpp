#include "translation_service.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QNetworkReply>

TranslationService::TranslationService(QObject *parent) : QObject(parent) {
    m_net = new QNetworkAccessManager(this);
    connect(m_net, &QNetworkAccessManager::finished, this, &TranslationService::onReplyFinished);
    loadCache();
}

TranslationService::~TranslationService() {
    saveCache();
}

void TranslationService::loadCache() {
    QString path = QDir::homePath() + "/.config/bitpure/lyrics_cache.json";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            for (auto it = obj.begin(); it != obj.end(); ++it) {
                m_cache[it.key()] = it.value().toString();
            }
        }
    }
}

void TranslationService::saveCache() {
    QString dir = QDir::homePath() + "/.config/bitpure";
    QDir().mkpath(dir);
    QFile f(dir + "/lyrics_cache.json");
    if (f.open(QIODevice::WriteOnly)) {
        QJsonObject obj;
        for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
            obj[it.key()] = it.value();
        }
        f.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
    }
}

QString TranslationService::getCachedTranslation(const QString &original) {
    QString clean = original.trimmed();
    if (clean.isEmpty()) return "";
    return m_cache.value(clean, "");
}

void TranslationService::requestTranslation(const QString &original, const QString &targetLang) {
    QString clean = original.trimmed();
    if (clean.isEmpty()) return;

    if (m_cache.contains(clean)) {
        emit translationReady(clean, m_cache.value(clean));
        return;
    }

    // Built-in offline quick lookup for popular local track lines
    static const QMap<QString, QString> dict = {
        { "Faasle", "Distances" },
        { "Nindiya Re", "My Sweet Sleep" },
        { "Baat Unkahi", "Unspoken Words" },
        { "Tere Pyar Main", "In Your Love" },
        { "Piya Daikho", "Behold My Beloved" },
        { "Sun Zara", "Listen A While" },
        { "Kun Faya Kun", "Be, And It Is" },
        { "Tu Jhoom", "You Sway In Ecstasy" },
        { "Afreen Afreen", "Praise Upon Praise To Your Beauty" },
        { "Saiyyan", "My Beloved" },
        { "Bhalobasha Tarpor", "Love Thereafter" },
        { "Amar Bhitor O Bahire", "Inside And Outside Of Me" },
        { "Jontrona", "The Agony" },
        { "Shudhu Tomakei Bhalobese", "Just Loving You" },
        { "Bhalobashi Jare", "The One I Love" },
        { "Ei Meghla Dine Ekla", "Alone On This Cloudy Day" },
        { "Sei Raate Raat Chhilo Purnima", "That Night Was A Full Moon" },
        { "Benche Thakar Gaan", "The Song Of Staying Alive" },
        { "Jao Pakhi Bolo Tare", "Go O Bird, Tell Them" },
        { "Eka Beche Thakte Shekho Priyo", "Learn To Live Alone, Beloved" }
    };

    if (dict.contains(clean)) {
        QString tr = dict.value(clean);
        m_cache[clean] = tr;
        saveCache();
        emit translationReady(clean, tr);
        return;
    }

    // Fetch from MyMemory free translation API
    QUrl url("https://api.mymemory.translated.net/get");
    QUrlQuery query;
    query.addQueryItem("q", clean);
    query.addQueryItem("langpair", QString("autodetect|%1").arg(targetLang));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "BitPure/1.0");
    QNetworkReply *reply = m_net->get(req);
    m_pendingRequests[reply] = clean;
}

void TranslationService::onReplyFinished(QNetworkReply *reply) {
    if (!reply) return;
    QString orig = m_pendingRequests.take(reply);
    reply->deleteLater();

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray bytes = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(bytes);
        if (doc.isObject()) {
            QJsonObject root = doc.object();
            QJsonObject resData = root["responseData"].toObject();
            QString translated = resData["translatedText"].toString().trimmed();
            if (!translated.isEmpty() && translated != orig && !translated.startsWith("MYMEMORY WARNING")) {
                m_cache[orig] = translated;
                saveCache();
                emit translationReady(orig, translated);
                return;
            }
        }
    }
}
