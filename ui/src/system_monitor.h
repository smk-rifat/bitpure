#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class SystemMonitor : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString cpuUsage READ cpuUsage NOTIFY statsChanged)
    Q_PROPERTY(QString ramUsage READ ramUsage NOTIFY statsChanged)
    Q_PROPERTY(QString storageFootprint READ storageFootprint NOTIFY statsChanged)
    Q_PROPERTY(QString formattedStatus READ formattedStatus NOTIFY statsChanged)
    Q_PROPERTY(QString currentTimeStr READ currentTimeStr NOTIFY clockChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    QString cpuUsage() const { return m_cpuUsage; }
    QString ramUsage() const { return m_ramUsage; }
    QString storageFootprint() const { return m_storageFootprint; }
    QString formattedStatus() const;
    QString currentTimeStr() const { return m_currentTimeStr; }

signals:
    void statsChanged();
    void clockChanged();

private slots:
    void updateClock();
    void updateProcessStats();
    void updateStorageSize();

private:
    QString m_cpuUsage = "CPU 0.8%";
    QString m_ramUsage = "RAM 142 MB";
    QString m_storageFootprint = "SSD 12.4 MB";
    QString m_currentTimeStr = "";

    unsigned long long m_lastProcessTicks = 0;
    qint64 m_lastMonotonicMs = 0;

    QTimer m_clockTimer;
    QTimer m_statsTimer;
    QTimer m_storageTimer;
};
