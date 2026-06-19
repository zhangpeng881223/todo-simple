#include "CalendarSyncService.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QJsonValue>
#include <QRegularExpression>
#include <QUuid>

namespace {
const char CalendarService[] = "com.deepin.dataserver.Calendar";
const char CalendarObjectPath[] = "/com/deepin/dataserver/Calendar/account_local";
const char CalendarInterface[] = "com.deepin.dataserver.Calendar.Account";

QString jsonString(const QJsonObject &object, const QString &key)
{
    return object.value(key).toVariant().toString();
}

QString compactJson(const QJsonObject &object)
{
    return QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

QString isoNowUtc()
{
    return QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd'T'hhmmss'Z'"));
}

QDate dateFromIsoValue(const QJsonValue &value)
{
    const QDateTime dateTime = QDateTime::fromString(value.toString(), Qt::ISODate);
    if (dateTime.isValid()) {
        return dateTime.date();
    }
    const QDate date = QDate::fromString(value.toString().left(10), Qt::ISODate);
    return date;
}

void collectScheduleTypes(const QJsonValue &value, QList<CalendarSyncService::ScheduleType> *types)
{
    if (value.isArray()) {
        const QJsonArray array = value.toArray();
        for (const QJsonValue &child : array) {
            collectScheduleTypes(child, types);
        }
        return;
    }

    if (!value.isObject()) {
        return;
    }

    const QJsonObject object = value.toObject();
    const QString typeId = jsonString(object, QStringLiteral("typeID"));
    if (!typeId.isEmpty()) {
        CalendarSyncService::ScheduleType type;
        type.id = typeId;
        type.displayName = jsonString(object, QStringLiteral("displayName"));
        if (type.displayName.isEmpty()) {
            type.displayName = jsonString(object, QStringLiteral("typeDisplayName"));
        }
        if (type.displayName.isEmpty()) {
            type.displayName = jsonString(object, QStringLiteral("typeName"));
        }
        type.privilege = object.value(QStringLiteral("privilege")).toInt(0);
        type.isDeleted = object.value(QStringLiteral("isDeleted")).toInt(0);
        types->append(type);
    }

    for (auto it = object.begin(); it != object.end(); ++it) {
        collectScheduleTypes(it.value(), types);
    }
}
}

CalendarSyncService::SyncResult CalendarSyncService::syncNoteTodos(const QJsonObject &note) const
{
    SyncResult result;
    result.todos = note.value(QStringLiteral("todos")).toArray();

    QString serviceError;
    if (!hasCalendarService(&serviceError)) {
        result.message = QStringLiteral("系统日历服务不可用");
        if (!serviceError.isEmpty()) {
            result.errors << serviceError;
        }
        return result;
    }

    const QString typeId = preferredScheduleTypeId();
    if (typeId.isEmpty()) {
        result.message = QStringLiteral("系统日历服务不可用");
        result.errors << QStringLiteral("未获取到可用日历分类");
        return result;
    }

    const QString noteId = jsonString(note, QStringLiteral("id"));
    const QString noteTitle = note.value(QStringLiteral("title")).toString(QStringLiteral("无标题"));
    const QDate targetDate = noteDate(note);

    int eligible = 0;
    for (int i = 0; i < result.todos.size(); ++i) {
        QJsonObject todo = result.todos.at(i).toObject();
        const QString text = todo.value(QStringLiteral("text")).toString().trimmed();
        if (text.isEmpty() || todo.value(QStringLiteral("completed")).toBool(false)) {
            continue;
        }
        ++eligible;

        const QString hash = todoSyncHash(noteId, todo, targetDate);
        const QString oldHash = todo.value(QStringLiteral("calendarSyncHash")).toString();
        QString scheduleId = todo.value(QStringLiteral("calendarScheduleId")).toString();
        if (!scheduleId.isEmpty() && oldHash == hash) {
            ++result.unchanged;
            ++result.synced;
            continue;
        }

        const bool creating = scheduleId.isEmpty();
        if (creating) {
            scheduleId = newUid();
        }

        const QString description = QStringLiteral("来自小U待办：%1").arg(noteTitle);
        const QString ics = buildIcs(scheduleId, text, description, targetDate);
        QJsonObject payload{
            {QStringLiteral("schedule"), ics},
            {QStringLiteral("type"), typeId},
            {QStringLiteral("scheduleID"), scheduleId}
        };

        bool ok = false;
        if (creating) {
            const QString createdId = callStringMethod(QStringLiteral("createSchedule"), compactJson(payload), &ok).trimmed();
            if (ok && !createdId.isEmpty()) {
                scheduleId = createdId;
            }
        } else {
            const bool updated = callBoolMethod(QStringLiteral("updateSchedule"), compactJson(payload), &ok);
            ok = ok && updated;
            if (!ok) {
                const QString replacementId = newUid();
                payload.insert(QStringLiteral("schedule"), buildIcs(replacementId, text, description, targetDate));
                payload.insert(QStringLiteral("scheduleID"), replacementId);
                const QString createdId = callStringMethod(QStringLiteral("createSchedule"), compactJson(payload), &ok).trimmed();
                if (ok) {
                    scheduleId = createdId.isEmpty() ? replacementId : createdId;
                }
            }
        }

        if (!ok) {
            ++result.failed;
            result.errors << QStringLiteral("同步失败：%1").arg(text.left(24));
            qWarning() << "Calendar sync failed for todo" << noteId << todo.value(QStringLiteral("id")).toVariant().toString();
            continue;
        }

        todo.insert(QStringLiteral("calendarScheduleId"), scheduleId);
        todo.insert(QStringLiteral("calendarSyncedAt"), QDateTime::currentDateTime().toString(Qt::ISODate));
        todo.insert(QStringLiteral("calendarSyncHash"), hash);
        result.todos.replace(i, todo);
        result.changedTodos = true;
        ++result.synced;
        if (creating) {
            ++result.created;
        } else {
            ++result.updated;
        }
    }

    if (eligible == 0) {
        result.message = QStringLiteral("没有可同步的未完成待办");
    } else if (result.failed > 0) {
        result.message = QStringLiteral("已同步 %1 条，%2 条失败").arg(result.synced).arg(result.failed);
    } else {
        result.message = QStringLiteral("已同步 %1 条到系统日历").arg(result.synced);
    }
    return result;
}

QDate CalendarSyncService::noteDate(const QJsonObject &note)
{
    const QString title = note.value(QStringLiteral("title")).toString();
    const QList<QRegularExpression> patterns = {
        QRegularExpression(QStringLiteral("(\\d{4})[/-](\\d{1,2})[/-](\\d{1,2})")),
        QRegularExpression(QStringLiteral("(\\d{4})年\\s*(\\d{1,2})月\\s*(\\d{1,2})日"))
    };
    for (const QRegularExpression &pattern : patterns) {
        const QRegularExpressionMatch match = pattern.match(title);
        if (!match.hasMatch()) {
            continue;
        }
        const QDate date(match.captured(1).toInt(), match.captured(2).toInt(), match.captured(3).toInt());
        if (date.isValid()) {
            return date;
        }
    }

    const QDate created = dateFromIsoValue(note.value(QStringLiteral("createdDate")));
    if (created.isValid()) {
        return created;
    }
    return QDate::currentDate();
}

QString CalendarSyncService::todoSyncHash(const QString &noteId, const QJsonObject &todo, const QDate &date)
{
    const QString payload = QStringLiteral("%1|%2|%3|%4")
        .arg(noteId,
             todo.value(QStringLiteral("id")).toVariant().toString(),
             todo.value(QStringLiteral("text")).toString().trimmed(),
             date.toString(Qt::ISODate));
    return QString::fromLatin1(QCryptographicHash::hash(payload.toUtf8(), QCryptographicHash::Sha1).toHex());
}

QString CalendarSyncService::buildIcs(const QString &uid, const QString &summary, const QString &description, const QDate &date)
{
    const QString stamp = isoNowUtc();
    const QString start = date.toString(QStringLiteral("yyyyMMdd"));
    const QString end = date.addDays(1).toString(QStringLiteral("yyyyMMdd"));
    const QStringList lines = {
        QStringLiteral("BEGIN:VCALENDAR"),
        QStringLiteral("PRODID:-//XiaoU Todo//todo260606//CN"),
        QStringLiteral("VERSION:2.0"),
        QStringLiteral("BEGIN:VEVENT"),
        QStringLiteral("DTSTAMP:%1").arg(stamp),
        QStringLiteral("CREATED:%1").arg(stamp),
        QStringLiteral("UID:%1").arg(uid),
        QStringLiteral("LAST-MODIFIED:%1").arg(stamp),
        QStringLiteral("SUMMARY:%1").arg(escapeIcsText(summary)),
        QStringLiteral("DESCRIPTION:%1").arg(escapeIcsText(description)),
        QStringLiteral("DTSTART;VALUE=DATE:%1").arg(start),
        QStringLiteral("DTEND;VALUE=DATE:%1").arg(end),
        QStringLiteral("TRANSP:OPAQUE"),
        QStringLiteral("END:VEVENT"),
        QStringLiteral("END:VCALENDAR")
    };

    QStringList folded;
    folded.reserve(lines.size());
    for (const QString &line : lines) {
        folded << foldIcsLine(line);
    }
    return folded.join(QStringLiteral("\r\n")) + QStringLiteral("\r\n");
}

QString CalendarSyncService::escapeIcsText(const QString &text)
{
    QString escaped = text;
    escaped.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
    escaped.replace(QStringLiteral("\n"), QStringLiteral("\\n"));
    escaped.replace(QStringLiteral("\r"), QString());
    escaped.replace(QStringLiteral(","), QStringLiteral("\\,"));
    escaped.replace(QStringLiteral(";"), QStringLiteral("\\;"));
    return escaped;
}

QString CalendarSyncService::foldIcsLine(const QString &line)
{
    constexpr int MaxChars = 70;
    if (line.size() <= MaxChars) {
        return line;
    }

    QString result;
    int index = 0;
    while (index < line.size()) {
        const int count = qMin(MaxChars, line.size() - index);
        if (!result.isEmpty()) {
            result += QStringLiteral("\r\n ");
        }
        result += line.mid(index, count);
        index += count;
    }
    return result;
}

QString CalendarSyncService::newUid()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QList<CalendarSyncService::ScheduleType> CalendarSyncService::scheduleTypes() const
{
    bool ok = false;
    const QString raw = callStringMethod(QStringLiteral("getScheduleTypeList"), QString(), &ok);
    if (!ok || raw.isEmpty()) {
        return {};
    }

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(raw.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError) {
        qWarning() << "Failed to parse deepin calendar schedule types" << error.errorString();
        return {};
    }

    QList<ScheduleType> types;
    collectScheduleTypes(document.isArray() ? QJsonValue(document.array()) : QJsonValue(document.object()), &types);
    return types;
}

QString CalendarSyncService::preferredScheduleTypeId() const
{
    const QList<ScheduleType> types = scheduleTypes();
    auto usable = [](const ScheduleType &type) {
        return !type.id.isEmpty() && type.isDeleted == 0 && type.privilege >= 0;
    };

    for (const QString &preferredName : {QStringLiteral("工作"), QStringLiteral("其他")}) {
        for (const ScheduleType &type : types) {
            if (usable(type) && type.displayName == preferredName) {
                return type.id;
            }
        }
    }
    for (const ScheduleType &type : types) {
        if (usable(type)) {
            return type.id;
        }
    }
    return QString();
}

QString CalendarSyncService::callStringMethod(const QString &method, const QString &payload, bool *ok) const
{
    if (ok) {
        *ok = false;
    }
    QDBusInterface iface(QString::fromLatin1(CalendarService),
                         QString::fromLatin1(CalendarObjectPath),
                         QString::fromLatin1(CalendarInterface),
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "Calendar DBus interface invalid" << QDBusConnection::sessionBus().lastError().message();
        return QString();
    }

    QDBusReply<QString> reply = payload.isNull()
        ? iface.call(method)
        : iface.call(method, payload);
    if (!reply.isValid()) {
        qWarning() << "Calendar DBus string call failed" << method << reply.error().message();
        return QString();
    }
    if (ok) {
        *ok = true;
    }
    return reply.value();
}

bool CalendarSyncService::callBoolMethod(const QString &method, const QString &payload, bool *ok) const
{
    if (ok) {
        *ok = false;
    }
    QDBusInterface iface(QString::fromLatin1(CalendarService),
                         QString::fromLatin1(CalendarObjectPath),
                         QString::fromLatin1(CalendarInterface),
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "Calendar DBus interface invalid" << QDBusConnection::sessionBus().lastError().message();
        return false;
    }

    QDBusReply<bool> reply = iface.call(method, payload);
    if (!reply.isValid()) {
        qWarning() << "Calendar DBus bool call failed" << method << reply.error().message();
        return false;
    }
    if (ok) {
        *ok = true;
    }
    return reply.value();
}

bool CalendarSyncService::hasCalendarService(QString *error) const
{
    if (!QDBusConnection::sessionBus().isConnected()) {
        if (error) {
            *error = QStringLiteral("DBus session bus 未连接");
        }
        return false;
    }

    QDBusInterface iface(QString::fromLatin1(CalendarService),
                         QString::fromLatin1(CalendarObjectPath),
                         QString::fromLatin1(CalendarInterface),
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        if (error) {
            *error = QDBusConnection::sessionBus().lastError().message();
        }
        return false;
    }
    return true;
}
