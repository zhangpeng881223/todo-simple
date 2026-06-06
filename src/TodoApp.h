#pragma once

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QPointer>
#include <QQuickView>
#include <QSystemTrayIcon>
#include <QVariantList>

class EventEditorController;
class NoteController;
class QMenu;
class QWindow;

class TodoApp : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList notesList READ notesList NOTIFY notesChanged)
    Q_PROPERTY(QVariantList eventsList READ eventsList NOTIFY eventsChanged)
    Q_PROPERTY(QString theme READ theme NOTIFY settingsChanged)
    Q_PROPERTY(QString noteTheme READ noteTheme NOTIFY settingsChanged)
    Q_PROPERTY(QString priorityStyle READ priorityStyle NOTIFY settingsChanged)
    Q_PROPERTY(int opacity READ opacity NOTIFY settingsChanged)
    Q_PROPERTY(QString storagePath READ storagePath CONSTANT)

public:
    explicit TodoApp(QObject *parent = nullptr);
    ~TodoApp() override;

    void initialize();

    QVariantList notesList() const;
    QVariantList eventsList() const;
    QString theme() const;
    QString noteTheme() const;
    QString priorityStyle() const;
    int opacity() const;
    QString storagePath() const;

    QJsonObject noteById(const QString &noteId) const;
    void updateNote(const QString &noteId, const QJsonObject &patch);
    void updateNoteTodos(const QString &noteId, const QJsonArray &todos);
    QString summarizeNote(const QString &noteId);
    QJsonArray sortedTodosForDisplay(const QJsonArray &todos) const;

    Q_INVOKABLE void createNewNote();
    Q_INVOKABLE void openNote(const QString &noteId);
    Q_INVOKABLE void hideNote(const QString &noteId);
    Q_INVOKABLE void deleteNote(const QString &noteId);
    Q_INVOKABLE void showListWindow();
    Q_INVOKABLE void showCalendarWindow();
    Q_INVOKABLE void showSettingsWindow();
    Q_INVOKABLE void showEventEditor(const QVariantMap &eventData);
    Q_INVOKABLE void closeWindow(QWindow *window);
    Q_INVOKABLE void updateSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE QString exportData();
    Q_INVOKABLE QString importData();
    Q_INVOKABLE QString summarizeAllNotes();
    Q_INVOKABLE QVariantMap eventById(const QString &eventId) const;
    Q_INVOKABLE void saveEvent(const QVariantMap &event);
    Q_INVOKABLE void deleteEvent(const QString &eventId);

signals:
    void notesChanged();
    void eventsChanged();
    void settingsChanged();

private:
    QQuickView *createView(const QUrl &source, const QSize &size, const QSize &minSize, bool transparent, bool resizable);
    void createTray();
    void loadData();
    void saveNotes() const;
    void saveEvents() const;
    void saveSettings() const;
    void ensureSeedData();
    void refreshNoteControllers(const QString &noteId = QString());
    QString generateDefaultNoteTitle() const;
    QPoint defaultNotePosition(int xOffset = 20, int y = 20) const;
    QString sendPromptToUosAi(const QString &prompt) const;
    QString buildCurrentNoteSummaryPrompt(const QJsonObject &note) const;
    QString buildAllNotesSummaryPrompt() const;
    QString dataFilePath(const QString &name) const;
    QString m_dataDir;
    QJsonArray m_notes;
    QJsonArray m_events;
    QJsonObject m_settings;
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_trayMenu = nullptr;
    QHash<QString, QPointer<QQuickView>> m_noteViews;
    QHash<QString, QPointer<NoteController>> m_noteControllers;
    QPointer<QQuickView> m_listView;
    QPointer<QQuickView> m_calendarView;
    QPointer<QQuickView> m_settingsView;
    QPointer<QQuickView> m_eventEditorView;
};
