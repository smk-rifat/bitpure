#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QNetworkAccessManager>

class TranslationService : public QObject {
    Q_OBJECT

public:
    explicit TranslationService(QObject *parent = nullptr);
    ~TranslationService() override;

    Q_INVOKABLE QString getCachedTranslation(const QString &original);
    Q_INVOKABLE void requestTranslation(const QString &original, const QString &targetLang = "en");

signals:
    void translationReady(const QString &original, const QString &translated);

private slots:
    void onReplyFinished(class QNetworkReply *reply);

private:
    void loadCache();
    void saveCache();

    QMap<QString, QString> m_cache;
    QNetworkAccessManager *m_net = nullptr;
    QMap<class QNetworkReply*, QString> m_pendingRequests;
};
