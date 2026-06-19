#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QUrl>

class QNetworkAccessManager;
class QNetworkReply;

class TelemetryService : public QObject
{
    Q_OBJECT

public:
    explicit TelemetryService(const QString &dataDir, QObject *parent = nullptr);

    QString anonymousDeviceId() const;
    QString sessionId() const;

    void setEndpoint(const QUrl &endpoint);
    void setEnabled(bool enabled);
    bool isEnabled() const;

    void track(const QString &eventName,
               const QString &eventType,
               const QString &module,
               const QJsonObject &properties = QJsonObject(),
               double durationSeconds = 0.0);
    void flush();

private:
    QString stateFilePath() const;
    QString queueFilePath() const;
    void loadOrCreateState();
    QJsonArray readQueue() const;
    void writeQueue(const QJsonArray &events) const;
    void appendEvent(const QJsonObject &event);
    void sendNextBatch();
    void handleBatchFinished(QNetworkReply *reply, int sentCount);

    QString m_dataDir;
    QString m_anonymousDeviceId;
    QString m_sessionId;
    QUrl m_endpoint;
    bool m_enabled = true;
    bool m_sending = false;
    QNetworkAccessManager *m_network = nullptr;
};
