#pragma once

#include <QDate>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QStringList>

class CalendarSyncService
{
public:
    struct SyncResult {
        int synced = 0;
        int created = 0;
        int updated = 0;
        int unchanged = 0;
        int failed = 0;
        bool changedTodos = false;
        QString message;
        QStringList errors;
        QJsonArray todos;
    };

    struct ScheduleType {
        QString id;
        QString displayName;
        int privilege = 0;
        int isDeleted = 0;
    };

    SyncResult syncNoteTodos(const QJsonObject &note, const QDate &selectedDate = QDate()) const;

private:
    static QDate noteDate(const QJsonObject &note);
    static QString todoSyncHash(const QString &noteId, const QJsonObject &todo, const QDate &date);
    static QString buildIcs(const QString &uid, const QString &summary, const QString &description, const QDate &date);
    static QString escapeIcsText(const QString &text);
    static QString foldIcsLine(const QString &line);
    static QString newUid();

    QList<ScheduleType> scheduleTypes() const;
    QString preferredScheduleTypeId() const;
    QString callStringMethod(const QString &method, const QString &payload, bool *ok) const;
    bool callBoolMethod(const QString &method, const QString &payload, bool *ok) const;
    bool hasCalendarService(QString *error = nullptr) const;
};
