#pragma once

#include <QObject>
#include <QRect>
#include <QJsonArray>
#include <QJsonObject>
#include <QElapsedTimer>
#include <QPointer>
#include <QQuickView>
#include <QQmlEngine>
#include <QStringList>
#include <QSystemTrayIcon>
#include <QUrl>
#include <QVariantList>
#include <DGuiApplicationHelper>

// Calendar/event editor is parked for the current version.
// class EventEditorController;
class NoteController;
class QFileSystemWatcher;
class QMenu;
class QTimer;
class QWindow;
class TelemetryService;

class TodoApp : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList notesList READ notesList NOTIFY notesChanged)
    Q_PROPERTY(QVariantList eventsList READ eventsList NOTIFY eventsChanged)
    Q_PROPERTY(QString theme READ theme NOTIFY settingsChanged)
    Q_PROPERTY(QString noteTheme READ noteTheme NOTIFY settingsChanged)
    Q_PROPERTY(QString priorityStyle READ priorityStyle NOTIFY settingsChanged)
    Q_PROPERTY(bool todosWrapEnabled READ todosWrapEnabled NOTIFY settingsChanged)
    Q_PROPERTY(int opacity READ opacity NOTIFY settingsChanged)
    Q_PROPERTY(QString storagePath READ storagePath CONSTANT)
    Q_PROPERTY(double mainDefaultTodoAlphaLight READ mainDefaultTodoAlphaLight NOTIFY settingsChanged)
    Q_PROPERTY(double mainPriorityTodoAlphaLight READ mainPriorityTodoAlphaLight NOTIFY settingsChanged)
    Q_PROPERTY(double mainDefaultTodoAlphaDark READ mainDefaultTodoAlphaDark NOTIFY settingsChanged)
    Q_PROPERTY(double mainPriorityTodoAlphaDark READ mainPriorityTodoAlphaDark NOTIFY settingsChanged)
    Q_PROPERTY(double mainWindowOpacity READ mainWindowOpacity NOTIFY settingsChanged)
    Q_PROPERTY(double mainRightPanelOpacity READ mainRightPanelOpacity NOTIFY settingsChanged)
    Q_PROPERTY(double mainWallpaperBlur READ mainWallpaperBlur NOTIFY settingsChanged)
    Q_PROPERTY(QString mainWallpaperMode READ mainWallpaperMode NOTIFY settingsChanged)
    Q_PROPERTY(double backdropProtection READ backdropProtection NOTIFY backdropProtectionChanged)
    Q_PROPERTY(QUrl wallpaperSource READ wallpaperSource NOTIFY wallpaperChanged)
    Q_PROPERTY(QRect wallpaperScreenGeometry READ wallpaperScreenGeometry NOTIFY wallpaperChanged)

public:
    explicit TodoApp(QObject *parent = nullptr);
    ~TodoApp() override;

    void initialize();
    void handleExternalLaunch(const QStringList &args);

    QVariantList notesList() const;
    QVariantList eventsList() const;
    QString theme() const;
    QString noteTheme() const;
    QString priorityStyle() const;
    bool todosWrapEnabled() const;
    int opacity() const;
    QString storagePath() const;
    double mainDefaultTodoAlphaLight() const;
    double mainPriorityTodoAlphaLight() const;
    double mainDefaultTodoAlphaDark() const;
    double mainPriorityTodoAlphaDark() const;
    double mainWindowOpacity() const;
    double mainRightPanelOpacity() const;
    double mainWallpaperBlur() const;
    QString mainWallpaperMode() const;
    double backdropProtection() const;
    QUrl wallpaperSource() const;
    QRect wallpaperScreenGeometry() const;
    QString noteSummaryTemplate() const;
    void setNoteSummaryTemplate(const QString &summaryTemplate);
    QString noteWindowLayer(const QString &noteId) const;
    QString cycleNoteWindowLayer(const QString &noteId);

    QJsonObject noteById(const QString &noteId) const;
    void updateNote(const QString &noteId, const QJsonObject &patch);
    void updateNoteTodos(const QString &noteId, const QJsonArray &todos);
    QJsonArray sortedTodosForDisplay(const QJsonArray &todos) const;

    Q_INVOKABLE QString createNewNote();
    Q_INVOKABLE void openNote(const QString &noteId);
    Q_INVOKABLE void showNoteOnDesktop(const QString &noteId);
    Q_INVOKABLE void hideNote(const QString &noteId);
    Q_INVOKABLE void deleteNote(const QString &noteId);
    Q_INVOKABLE void updateNoteTitle(const QString &noteId, const QString &title);
    Q_INVOKABLE QString summarizeNote(const QString &noteId);
    QString summarizeDesktopNote(const QString &noteId);
    Q_INVOKABLE QString syncNoteTodosToSystemCalendar(const QString &noteId);
    Q_INVOKABLE QString syncNoteTodosToSystemCalendarOnDate(const QString &noteId,
                                                            const QString &date);
    Q_INVOKABLE QString addTodoToNote(const QString &noteId, const QString &text);
    Q_INVOKABLE void commitNoteTodoText(const QString &noteId, const QString &todoId, const QString &text);
    Q_INVOKABLE void toggleNoteTodo(const QString &noteId, const QString &todoId);
    Q_INVOKABLE void deleteNoteTodo(const QString &noteId, const QString &todoId);
    Q_INVOKABLE void setNoteTodoPriority(const QString &noteId, const QString &todoId, const QString &priority);
    Q_INVOKABLE void moveNoteTodoById(const QString &noteId, const QString &todoId, int toDisplayIndex);
    Q_INVOKABLE void showListWindow();
    Q_INVOKABLE void showEffectsTestWindow();
    Q_INVOKABLE void triggerFireworksEffect();
    Q_INVOKABLE void triggerMainWindowPowderEffect();
    // Q_INVOKABLE void showCalendarWindow();
    Q_INVOKABLE void showSettingsWindow();
    Q_INVOKABLE void showFeedbackDialog();
    Q_INVOKABLE QString submitFeedback(const QString &content, const QString &contact);
    Q_INVOKABLE void showAboutDialog();
    // Q_INVOKABLE void showEventEditor(const QVariantMap &eventData);
    Q_INVOKABLE void closeWindow(QWindow *window);
    Q_INVOKABLE void updateSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE QString exportData();
    Q_INVOKABLE QString importData();
    Q_INVOKABLE QString openStoragePath();
    Q_INVOKABLE void setMainWallpaperMode(const QString &mode);
    Q_INVOKABLE QString chooseMainWindowWallpaper();
    Q_INVOKABLE QString summarizeAllNotes();
    Q_INVOKABLE QString summarizeNotesRange(const QString &scope);
    Q_INVOKABLE QString summaryTemplate(const QString &scope) const;
    Q_INVOKABLE QString defaultSummaryTemplate(const QString &scope) const;
    Q_INVOKABLE void setSummaryTemplate(const QString &scope, const QString &summaryTemplate);
    Q_INVOKABLE void resetSummaryTemplate(const QString &scope);
    Q_INVOKABLE QVariantMap eventById(const QString &eventId) const;
    Q_INVOKABLE void saveEvent(const QVariantMap &event);
    Q_INVOKABLE void deleteEvent(const QString &eventId);
    Q_INVOKABLE QVariantMap cursorPosition() const;
    Q_INVOKABLE void refreshWallpaper();
    Q_INVOKABLE void resetMainWindowAppearanceDefaults();

signals:
    void notesChanged();
    void eventsChanged();
    void settingsChanged();
    void backdropProtectionChanged();
    void wallpaperChanged();
    void feedbackDialogRequested();

private slots:
    void handleLauncherVisibleChanged(bool visible);

private:
    QQuickView *createView(const QUrl &source, const QSize &size, const QSize &minSize, bool transparent, bool resizable);
    void publishWindowIcon(QWindow *window) const;
    void scheduleWindowIconPublish(QWindow *window) const;
    void createTray();
    void setupLauncherVisibilityTracking();
    void handleTrayTrigger();
    QString createNewNote(bool discardIfEmptyOnHide);
    void openNoteWithLayer(const QString &noteId, const QString &layer);
    QString summarizeNoteForSource(const QString &noteId, const QString &eventName, const QString &source);
    QString latestCreatedNoteId() const;
    void showLatestCreatedNoteOnDesktop();
    void showAutostartNoteWindows();
    void showDefaultLaunchWindows();
    void handleInitialLaunch(const QStringList &args, int probeAttempt = 0);
    QString currentDdeLaunchType(bool *managedLaunch = nullptr, QString *instancePath = nullptr) const;
    bool isLikelyDdeAutostartLaunch(QString *diagnostic = nullptr) const;
    void loadData();
    void saveNotes() const;
    void saveEvents() const;
    void saveSettings() const;
    void ensureSeedData();
    void refreshNoteControllers(const QString &noteId = QString());
    void applyNoteWindowLayer(const QString &noteId, bool activate);
    void scheduleNoteGeometrySave(const QString &noteId, QQuickView *view);
    void saveNoteGeometry(const QString &noteId, const QQuickView *view);
    void syncDtkPalette();
    bool effectiveDarkTheme() const;
    void syncSettingFromDtkPalette(Dtk::Gui::DGuiApplicationHelper::ColorType paletteType);
    QString generateDefaultNoteTitle() const;
    QPoint defaultNotePosition(int xOffset = 20, int y = 20) const;
    void showUosAiAssistant() const;
    QString sendPromptToUosAi(const QString &prompt) const;
    QString defaultNoteSummaryTemplate() const;
    QString defaultWeekSummaryTemplate() const;
    QString defaultMonthSummaryTemplate() const;
    void upgradeDefaultSummaryTemplates();
    QString buildCurrentNoteSummaryPrompt(const QJsonObject &note) const;
    QString buildAllNotesSummaryPrompt() const;
    QString buildNotesRangeSummaryPrompt(const QString &scope) const;
    QVariantList buildPowderParticles(const QPixmap &snapshot, const QRect &windowGeometry) const;
    void showEffectOverlay(const QString &mode, const QVariantList &particles = QVariantList(), bool restoreListWindowOnClose = false);
    QUrl readSystemWallpaperSource() const;
    double analyzeWallpaperBrightness(const QUrl &source) const;
    double recommendedMainWindowOpacityForWallpaper(const QUrl &source) const;
    bool shouldAutoUpdateMainWindowOpacity() const;
    bool applyAutomaticMainWindowOpacity(const QUrl &source);
    QUrl readDdeAppearanceWallpaperSource() const;
    QUrl cachedWallpaperSource(const QUrl &source, const QRect &screenGeometry) const;
    void updateWallpaperWatchPaths(const QUrl &source);
    QRect currentListScreenGeometry() const;
    QString currentListScreenName() const;
    void applyMainWindowAppearanceDefaults();
    void startTelemetry();
    void trackTelemetry(const QString &eventName,
                        const QString &eventType,
                        const QString &module,
                        const QJsonObject &properties = QJsonObject(),
                        double durationSeconds = 0.0);
    QString dataFilePath(const QString &name) const;
    QString m_dataDir;
    QJsonArray m_notes;
    QJsonArray m_events;
    QJsonObject m_settings;
    bool m_syncingDtkPalette = false;
    bool m_launcherVisible = false;
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_trayMenu = nullptr;
    QHash<QString, QPointer<QQuickView>> m_noteViews;
    QHash<QString, QPointer<NoteController>> m_noteControllers;
    QHash<QString, QPointer<QTimer>> m_noteGeometrySaveTimers;
    QPointer<QWindow> m_listWindow;
    QPointer<QQmlEngine> m_listEngine;
    QPointer<QQuickView> m_effectsTestView;
    QPointer<QQuickView> m_effectOverlayView;
    // QPointer<QQuickView> m_calendarView;
    QPointer<QQuickView> m_settingsView;
    // QPointer<QQuickView> m_eventEditorView;
    QFileSystemWatcher *m_wallpaperWatcher = nullptr;
    TelemetryService *m_telemetry = nullptr;
    QTimer *m_telemetryHeartbeatTimer = nullptr;
    QElapsedTimer m_sessionTimer;
    double m_backdropProtection = 0.0;
    QUrl m_wallpaperSource;
    QRect m_wallpaperScreenGeometry;
};
