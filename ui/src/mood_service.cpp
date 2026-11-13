#include "mood_service.h"
#include <QStringList>
#include <QSet>
#include <algorithm>
#include <QRandomGenerator>

MoodService::MoodService(QObject *parent) : QObject(parent) {
}

QVariantList MoodService::scoreTracksForMood(const QString &mood, const QVariantList &allTracks, const QStringList &likedPaths) {
    if (allTracks.isEmpty()) return {};

    QString m = mood.trimmed().toLower();

    // Keywords and artist associations for each mood
    QStringList sadKeywords = {
        "sad", "goodbye", "another love", "faasle", "jontrona", "beparwah", "hanju", "hum",
        "lovely", "die", "cry", "lonely", "tear", "eka", "dooriyan", "pain", "hurt",
        "kaavish", "dean lewis", "tom odell", "billie eilish", "mohon sharif", "nindiya", "intezaar"
    };

    QStringList funKeywords = {
        "fun", "jhol", "closer", "sweet", "dance", "happy", "party", "something just like this",
        "until i found you", "maanu", "chainsmokers", "stephen sanchez", "vance joy", "pop"
    };

    QStringList rockKeywords = {
        "rock", "sweet home alabama", "laaree chootee", "nadaan parinde", "benche thakar gaan",
        "shokal dupur raatri", "lynyrd skynyrd", "call", "rupam islam", "hasan", "encore",
        "rockstar", "vikings", "guitar"
    };

    QStringList travelKeywords = {
        "travel", "road", "turri jandi", "riptide", "kun faya kun", "somewhere only we know",
        "aas paas khuda", "tu jhoom", "afreen", "saiyyan", "maula mere maula", "shazia manzoor",
        "vance joy", "keane", "rahat fateh ali khan", "kailash kher", "journey", "ei meghla"
    };

    QStringList chillKeywords = {
        "chill", "relax", "lounge", "ambient", "co2", "bindya", "jonaaki raati", "shudhu tomakei",
        "baat unkahi", "nindiya re", "piya daikho", "sun zara", "tere pyar main", "prateek kuhad",
        "sulk station", "papon", "nilanjan ghosal", "arnob", "kishore", "bappa mazumder", "somlata"
    };

    QStringList energeticKeywords = {
        "energetic", "beat", "power", "laaree chootee", "something just like this",
        "turri jandi", "closer", "rockstar", "sweet home alabama", "fast", "dance"
    };

    const QStringList *activeKeywords = &chillKeywords;
    if (m == "sad") activeKeywords = &sadKeywords;
    else if (m == "fun") activeKeywords = &funKeywords;
    else if (m == "rock") activeKeywords = &rockKeywords;
    else if (m == "traveling" || m == "travel") activeKeywords = &travelKeywords;
    else if (m == "chill") activeKeywords = &chillKeywords;
    else if (m == "energetic") activeKeywords = &energeticKeywords;

    struct ScoredTrack {
        QVariantMap track;
        double score;
    };

    QList<ScoredTrack> scoredList;

    for (const auto &item : allTracks) {
        QVariantMap t = item.toMap();
        QString title = t.value("title").toString().toLower();
        QString artist = t.value("track_artist").toString().toLower();
        QString path = t.value("file_path").toString();
        QString fullStr = title + " " + artist;

        double score = 0.0;

        for (const QString &kw : *activeKeywords) {
            if (fullStr.contains(kw)) {
                score += 10.0;
            }
        }

        // Liked songs bonus
        if (likedPaths.contains(path)) {
            score += 4.0;
        }

        // Subtle jitter for non-zero items to provide variety
        score += QRandomGenerator::global()->generateDouble() * 1.5;

        scoredList.append({ t, score });
    }

    // Sort descending by score
    std::sort(scoredList.begin(), scoredList.end(), [](const ScoredTrack &a, const ScoredTrack &b) {
        return a.score > b.score;
    });

    QVariantList result;
    // Pick top matching tracks, or if few matched, fill up to 15
    int count = qMin(scoredList.size(), 20);
    for (int i = 0; i < count; ++i) {
        result.append(scoredList[i].track);
    }

    return result;
}

