#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class MoodService : public QObject {
    Q_OBJECT

    Q_PROPERTY(QStringList availableMoods READ availableMoods CONSTANT)

public:
    explicit MoodService(QObject *parent = nullptr);

    QStringList availableMoods() const {
        return { "Sad", "Fun", "Rock", "Traveling", "Chill", "Energetic" };
    }

    Q_INVOKABLE QVariantList scoreTracksForMood(const QString &mood, const QVariantList &allTracks, const QStringList &likedPaths);
};

