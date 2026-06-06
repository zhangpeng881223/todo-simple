#pragma once

#include <QObject>
#include <QVariantMap>

class TodoApp;
class QWindow;

class EventEditorController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString eventId READ eventId NOTIFY eventChanged)
    Q_PROPERTY(bool editing READ editing NOTIFY eventChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY eventChanged)
    Q_PROPERTY(QString date READ date WRITE setDate NOTIFY eventChanged)
    Q_PROPERTY(QString startTime READ startTime WRITE setStartTime NOTIFY eventChanged)
    Q_PROPERTY(QString endDate READ endDate WRITE setEndDate NOTIFY eventChanged)
    Q_PROPERTY(QString endTime READ endTime WRITE setEndTime NOTIFY eventChanged)
    Q_PROPERTY(QString priority READ priority WRITE setPriority NOTIFY eventChanged)
    Q_PROPERTY(QString repeat READ repeat WRITE setRepeat NOTIFY eventChanged)

public:
    EventEditorController(TodoApp *app, const QVariantMap &eventData, QObject *parent = nullptr);

    QString eventId() const;
    bool editing() const;
    QString text() const;
    void setText(const QString &text);
    QString date() const;
    void setDate(const QString &date);
    QString startTime() const;
    void setStartTime(const QString &startTime);
    QString endDate() const;
    void setEndDate(const QString &endDate);
    QString endTime() const;
    void setEndTime(const QString &endTime);
    QString priority() const;
    void setPriority(const QString &priority);
    QString repeat() const;
    void setRepeat(const QString &repeat);

    Q_INVOKABLE QString save(QWindow *window);
    Q_INVOKABLE void remove(QWindow *window);
    Q_INVOKABLE void close(QWindow *window);

signals:
    void eventChanged();

private:
    TodoApp *m_app = nullptr;
    QVariantMap m_event;
};
