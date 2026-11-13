#include "system_monitor.h"
#include <QDateTime>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDirIterator>
#include <unistd.h>

SystemMonitor::SystemMonitor(QObject *parent) : QObject(parent) {
    connect(&m_clockTimer, &QTimer::timeout, this, &SystemMonitor::updateClock);
    m_clockTimer.start(1000);

    connect(&m_statsTimer, &QTimer::timeout, this, &SystemMonitor::updateProcessStats);
    m_statsTimer.start(2000);

    connect(&m_storageTimer, &QTimer::timeout, this, &SystemMonitor::updateStorageSize);
    m_storageTimer.start(60000);

    updateClock();
    updateProcessStats();
    updateStorageSize();
}

void SystemMonitor::updateClock() {
    QDateTime now = QDateTime::currentDateTime();
    // 12-hour AM/PM format: e.g. 03:24 PM · Thu, Nov 13
    m_currentTimeStr = now.toString("hh:mm AP · ddd, MMM d");
    emit clockChanged();
}

void SystemMonitor::updateProcessStats() {
    // 1. Process RAM from /proc/self/statm
    QFile statmFile("/proc/self/statm");
    if (statmFile.open(QIODevice::ReadOnly)) {
        QTextStream in(&statmFile);
        long long totalPages = 0, residentPages = 0;
        in >> totalPages >> residentPages;
        long pageSize = sysconf(_SC_PAGESIZE);
        long long residentBytes = residentPages * pageSize;
        double mb = residentBytes / (1024.0 * 1024.0);
        m_ramUsage = QString("RAM %1 MB").arg(QString::number(mb, 'f', 0));
    }

    // 2. Process CPU % from /proc/self/stat
    QFile statFile("/proc/self/stat");
    if (statFile.open(QIODevice::ReadOnly)) {
        QString content = statFile.readAll();
        QStringList parts = content.split(' ', Qt::SkipEmptyParts);
        // utime is field 14 (idx 13), stime is field 15 (idx 14)
        if (parts.size() >= 15) {
            unsigned long long utime = parts[13].toULongLong();
            unsigned long long stime = parts[14].toULongLong();
            unsigned long long totalTicks = utime + stime;

            qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
            if (m_lastMonotonicMs > 0 && nowMs > m_lastMonotonicMs) {
                unsigned long long tickDelta = totalTicks - m_lastProcessTicks;
                double msDelta = (double)(nowMs - m_lastMonotonicMs);
                long ticksPerSec = sysconf(_SC_CLK_TCK);
                if (ticksPerSec > 0 && msDelta > 0) {
                    double cpuSec = (double)tickDelta / (double)ticksPerSec;
                    double wallSec = msDelta / 1000.0;
                    double cpuPercent = (cpuSec / wallSec) * 100.0;
                    if (cpuPercent > 100.0) cpuPercent = 100.0;
                    m_cpuUsage = QString("CPU %1%").arg(QString::number(cpuPercent, 'f', 1));
                }
            }
            m_lastProcessTicks = totalTicks;
            m_lastMonotonicMs = nowMs;
        }
    }

    emit statsChanged();
}

void SystemMonitor::updateStorageSize() {
    qint64 totalBytes = 0;

    QStringList scanDirs = {
        QDir::homePath() + "/.local/share/audioplayer",
        QDir::homePath() + "/.config/bitpure"
    };

    for (const QString &dPath : scanDirs) {
        if (!QDir(dPath).exists()) continue;
        QDirIterator it(dPath, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            totalBytes += it.fileInfo().size();
        }
    }

    if (totalBytes < 1024 * 1024) {
        m_storageFootprint = QString("SSD %1 KB").arg(totalBytes / 1024);
    } else if (totalBytes < 1024LL * 1024 * 1024) {
        double mb = totalBytes / (1024.0 * 1024.0);
        m_storageFootprint = QString("SSD %1 MB").arg(QString::number(mb, 'f', 1));
    } else {
        double gb = totalBytes / (1024.0 * 1024.0 * 1024.0);
        m_storageFootprint = QString("SSD %1 GB").arg(QString::number(gb, 'f', 2));
    }
    emit statsChanged();
}

QString SystemMonitor::formattedStatus() const {
    return QString("%1 · %2 · %3").arg(m_cpuUsage, m_ramUsage, m_storageFootprint);
}
