#include "TelemetryService.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSysInfo>
#include <QTimer>
#include <QUuid>
#include <QDebug>

namespace {
constexpr int MaxQueuedEvents = 500;
constexpr int MaxBatchEvents = 20;

QString isoUtcNow()
{
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
}
}

TelemetryService::TelemetryService(const QString &dataDir, QObject *parent)
    : QObject(parent)
    , m_dataDir(dataDir)
    , m_sessionId(QUuid::createUuid().toString(QUuid::WithoutBraces))
    , m_endpoint(QStringLiteral("http://8.145.43.232/api/telemetry/batch"))
    , m_network(new QNetworkAccessManager(this))
{
    QDir().mkpath(m_dataDir);
    loadOrCreateState();
}

QString TelemetryService::anonymousDeviceId() const
{
    return m_anonymousDeviceId;
}

QString TelemetryService::sessionId() const
{
    return m_sessionId;
}

void TelemetryService::setEndpoint(const QUrl &endpoint)
{
    if (endpoint.isValid() && !endpoint.isEmpty()) {
        m_endpoint = endpoint;
    }
}

void TelemetryService::setEnabled(bool enabled)
{
    m_enabled = enabled;
}

bool TelemetryService::isEnabled() const
{
    return m_enabled;
}

void TelemetryService::track(const QString &eventName,
                             const QString &eventType,
                             const QString &module,
                             const QJsonObject &properties,
                             double durationSeconds)
{
    if (!m_enabled || eventName.isEmpty()) {
        return;
    }

    QJsonObject event;
    event.insert(QStringLiteral("eventName"), eventName);
    event.insert(QStringLiteral("eventType"), eventType.isEmpty() ? eventName : eventType);
    event.insert(QStringLiteral("eventTime"), isoUtcNow());
    event.insert(QStringLiteral("anonymousDeviceId"), m_anonymousDeviceId);
    event.insert(QStringLiteral("sessionId"), m_sessionId);
    event.insert(QStringLiteral("appVersion"), QCoreApplication::applicationVersion());
    event.insert(QStringLiteral("systemVersion"), QSysInfo::prettyProductName());
    event.insert(QStringLiteral("module"), module);
    event.insert(QStringLiteral("durationSeconds"), durationSeconds);
    event.insert(QStringLiteral("source"), QStringLiteral("小U待办"));
    event.insert(QStringLiteral("properties"), properties);

    appendEvent(event);
    QTimer::singleShot(1200, this, &TelemetryService::flush);
}

void TelemetryService::flush()
{
    if (!m_enabled || m_sending || !m_endpoint.isValid() || m_endpoint.isEmpty()) {
        return;
    }
    sendNextBatch();
}

QString TelemetryService::stateFilePath() const
{
    return QDir(m_dataDir).filePath(QStringLiteral("telemetry-state.json"));
}

QString TelemetryService::queueFilePath() const
{
    return QDir(m_dataDir).filePath(QStringLiteral("telemetry-queue.json"));
}

void TelemetryService::loadOrCreateState()
{
    QFile file(stateFilePath());
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonObject state = QJsonDocument::fromJson(file.readAll()).object();
        m_anonymousDeviceId = state.value(QStringLiteral("anonymousDeviceId")).toString();
    }
    if (m_anonymousDeviceId.isEmpty()) {
        m_anonymousDeviceId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QJsonObject state;
        state.insert(QStringLiteral("anonymousDeviceId"), m_anonymousDeviceId);
        QFile out(stateFilePath());
        if (out.open(QIODevice::WriteOnly)) {
            out.write(QJsonDocument(state).toJson(QJsonDocument::Indented));
        }
    }
}

QJsonArray TelemetryService::readQueue() const
{
    QFile file(queueFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return QJsonArray();
    }
    return QJsonDocument::fromJson(file.readAll()).array();
}

void TelemetryService::writeQueue(const QJsonArray &events) const
{
    QFile file(queueFilePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(events).toJson(QJsonDocument::Compact));
    }
}

void TelemetryService::appendEvent(const QJsonObject &event)
{
    QJsonArray events = readQueue();
    events.append(event);
    while (events.size() > MaxQueuedEvents) {
        events.removeAt(0);
    }
    writeQueue(events);
}

void TelemetryService::sendNextBatch()
{
    const QJsonArray queue = readQueue();
    if (queue.isEmpty()) {
        return;
    }

    QJsonArray batch;
    const int count = qMin(MaxBatchEvents, queue.size());
    for (int i = 0; i < count; ++i) {
        batch.append(queue.at(i));
    }

    QJsonObject body;
    body.insert(QStringLiteral("events"), batch);

    QNetworkRequest request(m_endpoint);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    m_sending = true;
    QNetworkReply *reply = m_network->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, count]() {
        handleBatchFinished(reply, count);
    });
}

void TelemetryService::handleBatchFinished(QNetworkReply *reply, int sentCount)
{
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool ok = reply->error() == QNetworkReply::NoError && httpStatus >= 200 && httpStatus < 300;
    if (!ok) {
        qWarning() << "Telemetry upload failed" << httpStatus << reply->errorString();
    } else {
        QJsonArray queue = readQueue();
        for (int i = 0; i < sentCount && !queue.isEmpty(); ++i) {
            queue.removeAt(0);
        }
        writeQueue(queue);
    }
    reply->deleteLater();
    m_sending = false;
    if (ok && !readQueue().isEmpty()) {
        QTimer::singleShot(250, this, &TelemetryService::sendNextBatch);
    }
}
