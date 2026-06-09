/*
Calendar/event editor is parked for the current version.

#include "EventEditorController.h"

#include "TodoApp.h"

#include <QDate>
#include <QWindow>

EventEditorController::EventEditorController(TodoApp *app, const QVariantMap &eventData, QObject *parent)
    : QObject(parent)
    , m_app(app)
    , m_event(eventData)
{
    const QString today = QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
    if (!m_event.contains(QStringLiteral("date"))) {
        m_event.insert(QStringLiteral("date"), today);
    }
    if (!m_event.contains(QStringLiteral("endDate"))) {
        m_event.insert(QStringLiteral("endDate"), m_event.value(QStringLiteral("date")).toString());
    }
    if (!m_event.contains(QStringLiteral("startTime"))) {
        m_event.insert(QStringLiteral("startTime"), QStringLiteral("09:00"));
    }
    if (!m_event.contains(QStringLiteral("endTime"))) {
        m_event.insert(QStringLiteral("endTime"), QStringLiteral("10:00"));
    }
    if (!m_event.contains(QStringLiteral("priority"))) {
        m_event.insert(QStringLiteral("priority"), QStringLiteral("gray"));
    }
    if (!m_event.contains(QStringLiteral("repeat"))) {
        m_event.insert(QStringLiteral("repeat"), QStringLiteral("none"));
    }
}
*/

QString EventEditorController::eventId() const { return m_event.value(QStringLiteral("id")).toString(); }
bool EventEditorController::editing() const { return !eventId().isEmpty(); }
QString EventEditorController::text() const { return m_event.value(QStringLiteral("text")).toString(); }
void EventEditorController::setText(const QString &text) { m_event.insert(QStringLiteral("text"), text); emit eventChanged(); }
QString EventEditorController::date() const { return m_event.value(QStringLiteral("date")).toString(); }
void EventEditorController::setDate(const QString &date) { m_event.insert(QStringLiteral("date"), date); emit eventChanged(); }
QString EventEditorController::startTime() const { return m_event.value(QStringLiteral("startTime")).toString(); }
void EventEditorController::setStartTime(const QString &startTime) { m_event.insert(QStringLiteral("startTime"), startTime); emit eventChanged(); }
QString EventEditorController::endDate() const { return m_event.value(QStringLiteral("endDate")).toString(); }
void EventEditorController::setEndDate(const QString &endDate) { m_event.insert(QStringLiteral("endDate"), endDate); emit eventChanged(); }
QString EventEditorController::endTime() const { return m_event.value(QStringLiteral("endTime")).toString(); }
void EventEditorController::setEndTime(const QString &endTime) { m_event.insert(QStringLiteral("endTime"), endTime); emit eventChanged(); }
QString EventEditorController::priority() const
{
    const QString value = m_event.value(QStringLiteral("priority")).toString();
    return value.isEmpty() ? QStringLiteral("gray") : value;
}
void EventEditorController::setPriority(const QString &priority) { m_event.insert(QStringLiteral("priority"), priority); emit eventChanged(); }
QString EventEditorController::repeat() const
{
    const QString value = m_event.value(QStringLiteral("repeat")).toString();
    return value.isEmpty() ? QStringLiteral("none") : value;
}
void EventEditorController::setRepeat(const QString &repeat) { m_event.insert(QStringLiteral("repeat"), repeat); emit eventChanged(); }

QString EventEditorController::save(QWindow *window)
{
    if (date().isEmpty() || startTime().isEmpty() || endDate().isEmpty() || endTime().isEmpty()) {
        return QStringLiteral("请填写完整的时间信息");
    }
    m_app->saveEvent(m_event);
    close(window);
    return QStringLiteral("日程已保存");
}

void EventEditorController::remove(QWindow *window)
{
    if (editing()) {
        m_app->deleteEvent(eventId());
    }
    close(window);
}

void EventEditorController::close(QWindow *window)
{
    if (window) {
        window->close();
    }
}
