#include "TodoApp.h"

#include "CalendarSyncService.h"
// Calendar/event editor is parked for the current version.
// #include "EventEditorController.h"
#include "NoteController.h"
#include "TelemetryService.h"

#include <QApplication>
#include <QClipboard>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QCursor>
#include <QDate>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDesktopServices>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QBoxLayout>
#include <QLabel>
#include <QLayout>
#include <QMenu>
#include <QPainter>
#include <QPixmap>
#include <QProcess>
#include <QDebug>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QScopedValueRollback>
#include <QSignalBlocker>
#include <QStandardPaths>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <QWindow>
#include <DAboutDialog>
#include <DGuiApplicationHelper>
#include <DLabel>

#include <cmath>
#include <memory>
#include <utility>

#include <X11/Xlib.h>
#include <X11/Xatom.h>

namespace {
constexpr int MaxNotes = 999;
constexpr int MaxPromptLength = 12000;
const char ProductIconPath[] = ":/assets/app-icons/xiaou-todo.svg";
const char ProductIconLargePath[] = ":/assets/app-icons/xiaou-todo.svg";
const char DefaultMainWallpaperPath[] = "qrc:/assets/default-main-wallpaper.jpg";
constexpr double DefaultWallpaperWindowOpacity = 0.405;
constexpr double DefaultWallpaperRightPanelOpacity = 0.70;
constexpr double DefaultWallpaperBlur = 0.75;
constexpr double SystemWallpaperWindowOpacity = 0.30;
constexpr double SystemWallpaperRightPanelOpacity = 0.80;
constexpr double SystemWallpaperBlur = 0.30;
constexpr double DarkDefaultWallpaperWindowOpacity = 0.40;
constexpr double DarkThemeWindowOpacity = 0.70;
constexpr double BrightWallpaperWindowOpacity = 0.70;
constexpr double DarkWallpaperWindowOpacity = 0.40;
constexpr double WallpaperBrightnessThreshold = 0.55;
constexpr double DarkThemeRightPanelOpacity = 0.26;
constexpr double DarkThemeWallpaperBlur = 0.70;
constexpr int DarkThemeMainAppearanceVersion = 4;
constexpr int TelemetryHeartbeatIntervalMs = 10 * 60 * 1000;
const char DiscardIfEmptyOnHideKey[] = "discardIfEmptyOnHide";
const char DiscardIfEmptyOnHideTitleKey[] = "discardIfEmptyOnHideTitle";

bool isCoreTelemetryEvent(const QString &eventName, const QString &eventType)
{
    static const QSet<QString> coreEvents{
        QStringLiteral("app_start"),
        QStringLiteral("app_exit"),
        QStringLiteral("session_heartbeat"),
        QStringLiteral("feedback_submitted"),
        QStringLiteral("note_ai_summary_clicked"),
        QStringLiteral("desktop_ai_summary_clicked"),
        QStringLiteral("calendar_sync"),
        QStringLiteral("ai_summary_week"),
        QStringLiteral("ai_summary_month"),
        QStringLiteral("note_window_layer_changed")
    };
    return coreEvents.contains(eventName) ||
           eventType == QStringLiteral("反馈提交") ||
           eventType == QStringLiteral("错误");
}

QString isoNow()
{
    return QDateTime::currentDateTime().toString(Qt::ISODate);
}

QString valueString(const QJsonObject &object, const QString &key, const QString &fallback = QString())
{
    return object.value(key).toVariant().toString().isEmpty()
        ? fallback
        : object.value(key).toVariant().toString();
}

bool hasNonEmptyTodoText(const QJsonArray &todos)
{
    for (const QJsonValue &value : todos) {
        if (!value.toObject().value(QStringLiteral("text")).toString().trimmed().isEmpty()) {
            return true;
        }
    }
    return false;
}

double numberSetting(const QJsonObject &settings, const QString &key, double fallback)
{
    bool ok = false;
    const double value = settings.value(key).toVariant().toDouble(&ok);
    if (!ok) {
        return fallback;
    }
    return qBound(0.0, value, 1.0);
}

QString summaryTemplateKey(const QString &scope)
{
    if (scope == QStringLiteral("week")) {
        return QStringLiteral("weekSummaryTemplate");
    }
    if (scope == QStringLiteral("month")) {
        return QStringLiteral("monthSummaryTemplate");
    }
    return QStringLiteral("noteSummaryTemplate");
}

QString legacyNoteSummaryTemplate()
{
    return QStringLiteral("请你作为我的工作助理，总结下面这个“今日待办”窗口。\n\n"
                          "请按以下结构输出，语言简洁、具体，不要编造未出现的信息：\n"
                          "1. 今日重点\n"
                          "2. 已完成事项\n"
                          "3. 未完成事项\n"
                          "4. 下一步建议");
}

QString legacyWeekSummaryTemplate()
{
    return QStringLiteral("请你作为我的工作助理，基于下面的小U待办数据总结本周所有待办。\n\n"
                          "请按以下结构输出，语言简洁、具体，不要编造未出现的信息：\n"
                          "1. 本周重点\n"
                          "2. 已完成进展\n"
                          "3. 未完成事项与风险\n"
                          "4. 下周行动建议");
}

QString legacyMonthSummaryTemplate()
{
    return QStringLiteral("请你作为我的工作助理，基于下面的小U待办数据总结本月所有待办。\n\n"
                          "请按以下结构输出，语言简洁、具体，不要编造未出现的信息：\n"
                          "1. 本月重点成果\n"
                          "2. 事项推进情况\n"
                          "3. 长期未完成事项\n"
                          "4. 下月优化建议");
}

QString normalizedWindowLayer(const QString &layer)
{
    if (layer == QStringLiteral("bottom") || layer == QStringLiteral("top")) {
        return layer;
    }
    return QStringLiteral("normal");
}

Qt::WindowFlags baseViewFlags(bool resizable)
{
    Qt::WindowFlags flags = Qt::Window | Qt::FramelessWindowHint | Qt::WindowCloseButtonHint;
    if (resizable) {
        flags |= Qt::WindowMinMaxButtonsHint;
    } else {
        flags |= Qt::MSWindowsFixedSizeDialogHint;
    }
    return flags;
}

Qt::WindowFlags noteViewFlags(const QString &layer, bool topLayerSuspended = false)
{
    const QString normalized = normalizedWindowLayer(layer);
    // Keep desktop notes as independent normal windows. Qt::Tool makes DDE
    // stack them above the application's main window even in the normal layer.
    Qt::WindowFlags flags = baseViewFlags(true);
    if (normalized == QStringLiteral("bottom")) {
        flags |= Qt::WindowStaysOnBottomHint;
    } else if (normalized == QStringLiteral("top") && !topLayerSuspended) {
        flags |= Qt::WindowStaysOnTopHint;
    }
    return flags;
}

void applySkipTaskbarState(QWindow *window)
{
    if (!window) {
        return;
    }

    const WId windowId = window->winId();
    if (!windowId) {
        return;
    }

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
        return;
    }

    const Window xWindow = static_cast<Window>(windowId);
    const Atom wmState = XInternAtom(display, "_NET_WM_STATE", False);
    const Atom desiredStates[] = {
        XInternAtom(display, "_NET_WM_STATE_SKIP_TASKBAR", False),
        XInternAtom(display, "_NET_WM_STATE_SKIP_PAGER", False)
    };

    Atom actualType = None;
    int actualFormat = 0;
    unsigned long itemCount = 0;
    unsigned long bytesAfter = 0;
    unsigned char *data = nullptr;
    QList<Atom> mergedStates;
    if (XGetWindowProperty(display,
                           xWindow,
                           wmState,
                           0,
                           1024,
                           False,
                           XA_ATOM,
                           &actualType,
                           &actualFormat,
                           &itemCount,
                           &bytesAfter,
                           &data) == Success
        && actualType == XA_ATOM
        && actualFormat == 32
        && data) {
        const auto *atoms = reinterpret_cast<const Atom *>(data);
        for (unsigned long i = 0; i < itemCount; ++i) {
            if (!mergedStates.contains(atoms[i])) {
                mergedStates.append(atoms[i]);
            }
        }
    }
    if (data) {
        XFree(data);
    }

    for (const Atom state : desiredStates) {
        if (!mergedStates.contains(state)) {
            mergedStates.append(state);
        }
    }

    XChangeProperty(display,
                    xWindow,
                    wmState,
                    XA_ATOM,
                    32,
                    PropModeReplace,
                    reinterpret_cast<const unsigned char *>(mergedStates.constData()),
                    mergedStates.size());

    const Atom wmWindowType = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
    const Atom windowType = XInternAtom(display, "_NET_WM_WINDOW_TYPE_NORMAL", False);
    XChangeProperty(display,
                    xWindow,
                    wmWindowType,
                    XA_ATOM,
                    32,
                    PropModeReplace,
                    reinterpret_cast<const unsigned char *>(&windowType),
                    1);

    XFlush(display);
    XCloseDisplay(display);
}

bool isWindowViewable(QWindow *window)
{
    if (!window || !window->winId()) {
        return false;
    }

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
        return window->isVisible();
    }

    XWindowAttributes attributes;
    const bool viewable = XGetWindowAttributes(display, static_cast<Window>(window->winId()), &attributes)
        && attributes.map_state == IsViewable;
    XCloseDisplay(display);
    return viewable;
}

void scheduleSkipTaskbarState(QWindow *window)
{
    if (!window) {
        return;
    }
    applySkipTaskbarState(window);
    QPointer<QWindow> guardedWindow(window);
    QTimer::singleShot(0, window, [guardedWindow]() {
        applySkipTaskbarState(guardedWindow.data());
    });
    QTimer::singleShot(160, window, [guardedWindow]() {
        applySkipTaskbarState(guardedWindow.data());
    });
}

QString todoText(const QJsonObject &todo)
{
    return todo.value(QStringLiteral("text")).toString().trimmed();
}

QString formatDateTime(const QJsonValue &value)
{
    const QDateTime dateTime = QDateTime::fromString(value.toString(), Qt::ISODate);
    if (!dateTime.isValid()) {
        return QStringLiteral("未知时间");
    }
    return dateTime.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"));
}

QString completionSummary(const QJsonArray &todos)
{
    int total = 0;
    int completed = 0;
    for (const QJsonValue &value : todos) {
        const QJsonObject todo = value.toObject();
        if (todoText(todo).isEmpty()) {
            continue;
        }
        ++total;
        if (todo.value(QStringLiteral("completed")).toBool(false)) {
            ++completed;
        }
    }
    return QStringLiteral("%1/%2").arg(completed).arg(total);
}

QIcon aboutProductIcon()
{
    QIcon icon(QString::fromLatin1(ProductIconLargePath));
    if (icon.isNull()) {
        icon = QIcon(QString::fromLatin1(ProductIconPath));
    }
    return icon;
}

QIcon productIcon()
{
    QIcon icon;
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo.svg"));
    return icon;
}

void setProductIconOnWindow(QWindow *window)
{
    if (!window) {
        return;
    }
    const QIcon icon = productIcon();
    window->setIcon(icon);
}

QString appDataDir()
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (documentsPath.isEmpty()) {
        documentsPath = QDir::homePath();
    }
    return QDir(documentsPath).filePath(QStringLiteral("小U待办"));
}

QString ddeAppearanceConfigPath()
{
    return QDir::home().filePath(QStringLiteral(".config/dde-appearance/config.json"));
}

QString gsettingsValue(const QString &schema, const QString &key)
{
    QProcess process;
    process.start(QStringLiteral("gsettings"), {QStringLiteral("get"), schema, key});
    if (!process.waitForFinished(800) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return QString();
    }

    QString value = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    if ((value.startsWith(QLatin1Char('\'')) && value.endsWith(QLatin1Char('\'')))
            || (value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"')))) {
        value = value.mid(1, value.size() - 2);
    }
    return value;
}

QUrl wallpaperUrlFromValue(const QString &value)
{
    if (value.isEmpty() || value == QStringLiteral("@ms Nothing")) {
        return QUrl();
    }

    const QUrl url(value);
    if (url.isLocalFile() && QFile::exists(url.toLocalFile())) {
        return url;
    }
    if (url.isValid() && !url.scheme().isEmpty()) {
        return url;
    }
    if (QFile::exists(value)) {
        return QUrl::fromLocalFile(value);
    }
    return QUrl();
}

int currentWorkspaceNumber()
{
    QProcess process;
    process.start(QStringLiteral("xprop"), {QStringLiteral("-root"), QStringLiteral("_NET_CURRENT_DESKTOP")});
    if (!process.waitForFinished(800) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return 1;
    }

    const QString output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    const int equalsIndex = output.lastIndexOf(QLatin1Char('='));
    if (equalsIndex < 0) {
        return 1;
    }

    bool ok = false;
    const int zeroBasedDesktop = output.mid(equalsIndex + 1).trimmed().toInt(&ok);
    return ok ? qMax(1, zeroBasedDesktop + 1) : 1;
}

QStringList todoLines(const QJsonArray &todos)
{
    QStringList lines;
    int index = 1;
    for (const QJsonValue &value : todos) {
        const QJsonObject todo = value.toObject();
        const QString text = todoText(todo);
        if (text.isEmpty()) {
            continue;
        }
        const QString status = todo.value(QStringLiteral("completed")).toBool(false) ? QStringLiteral("已完成") : QStringLiteral("未完成");
        const QString priority = todo.value(QStringLiteral("priority")).toString(QStringLiteral("gray"));
        const QString priorityPart = priority != QStringLiteral("gray") && priority != QStringLiteral("none")
            ? QStringLiteral("，优先级:%1").arg(priority)
            : QString();
        lines << QStringLiteral("%1. [%2%3] %4").arg(index++).arg(status, priorityPart, text);
    }
    if (lines.isEmpty()) {
        lines << QStringLiteral("- 暂无已填写的待办事项");
    }
    return lines;
}
}

TodoApp::TodoApp(QObject *parent)
    : QObject(parent)
    , m_dataDir(appDataDir())
{
    m_wallpaperWatcher = new QFileSystemWatcher(this);
    connect(m_wallpaperWatcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        refreshWallpaper();
    });
    connect(m_wallpaperWatcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        refreshWallpaper();
    });

    m_settings.insert(QStringLiteral("theme"), QStringLiteral("system"));
    m_settings.insert(QStringLiteral("noteTheme"), QStringLiteral("system"));
    m_settings.insert(QStringLiteral("priorityStyle"), QStringLiteral("colorful"));
    m_settings.insert(QStringLiteral("todosWrapEnabled"), true);
    m_settings.insert(QStringLiteral("opacity"), 60);
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    m_settings.insert(QStringLiteral("mainDefaultTodoAlphaLight"), 0.445);
    m_settings.insert(QStringLiteral("mainPriorityTodoAlphaLight"), 0.275);
    m_settings.insert(QStringLiteral("mainDefaultTodoAlphaDark"), 0.13);
    m_settings.insert(QStringLiteral("mainPriorityTodoAlphaDark"), 0.21);
    m_settings.insert(QStringLiteral("mainWindowOpacity"), SystemWallpaperWindowOpacity);
    m_settings.insert(QStringLiteral("mainWindowOpacityUserOverridden"), false);
    m_settings.insert(QStringLiteral("mainRightPanelOpacity"), SystemWallpaperRightPanelOpacity);
    m_settings.insert(QStringLiteral("mainWallpaperBlur"), SystemWallpaperBlur);
    m_settings.insert(QStringLiteral("mainWallpaperMode"), QStringLiteral("default"));
    m_settings.insert(QStringLiteral("mainCustomWallpaperPath"), QString());
    m_settings.insert(QStringLiteral("telemetryEnabled"), true);
    m_settings.insert(QStringLiteral("telemetryEndpoint"), QStringLiteral("http://8.145.43.232/api/telemetry/batch"));
    applyMainWindowAppearanceDefaults();
    m_telemetry = new TelemetryService(m_dataDir, this);
}

TodoApp::~TodoApp()
{
    trackTelemetry(QStringLiteral("app_exit"),
                   QStringLiteral("应用退出"),
                   QStringLiteral("app"),
                   QJsonObject(),
                   m_sessionTimer.isValid() ? m_sessionTimer.elapsed() / 1000.0 : 0.0);
    if (m_telemetry) {
        m_telemetry->flush();
    }
    if (m_tray) {
        m_tray->hide();
        m_tray->setContextMenu(nullptr);
    }
    delete m_trayMenu;
    m_trayMenu = nullptr;
    saveNotes();
    saveEvents();
    saveSettings();
}

void TodoApp::initialize()
{
    QDir().mkpath(m_dataDir);
    loadData();
    startTelemetry();
    connect(Dtk::Gui::DGuiApplicationHelper::instance(),
            &Dtk::Gui::DGuiApplicationHelper::paletteTypeChanged,
            this,
            &TodoApp::syncSettingFromDtkPalette,
            Qt::UniqueConnection);
    syncDtkPalette();
    ensureSeedData();
    createTray();
    setupLauncherVisibilityTracking();

    const QStringList args = QCoreApplication::arguments();
    handleInitialLaunch(args);
}

void TodoApp::handleInitialLaunch(const QStringList &args, int probeAttempt)
{
    if (args.contains(QStringLiteral("--autostart"))) {
        QTimer::singleShot(0, this, [this]() { showAutostartNoteWindows(); });
        return;
    }

    const bool hasExplicitWindowArg = args.contains(QStringLiteral("--show-all")) ||
                                      args.contains(QStringLiteral("--list")) ||
                                      args.contains(QStringLiteral("--effects")) ||
                                      args.contains(QStringLiteral("--settings"));
    if (hasExplicitWindowArg) {
        handleExternalLaunch(args);
        return;
    }

    bool managedLaunch = false;
    const QString launchType = currentDdeLaunchType(&managedLaunch);
    if (launchType == QStringLiteral("dde-application-manager-autostart")) {
        QTimer::singleShot(0, this, [this]() { showAutostartNoteWindows(); });
        return;
    }

    constexpr int MaxLaunchTypeProbeAttempts = 10;
    if (managedLaunch && launchType.isEmpty() && probeAttempt < MaxLaunchTypeProbeAttempts) {
        QTimer::singleShot(100, this, [this, args, probeAttempt]() {
            handleInitialLaunch(args, probeAttempt + 1);
        });
        return;
    }

    handleExternalLaunch(args);
}

void TodoApp::setupLauncherVisibilityTracking()
{
    QDBusConnection::sessionBus().connect(QStringLiteral("org.deepin.dde.Launcher1"),
                                          QStringLiteral("/org/deepin/dde/Launcher1"),
                                          QStringLiteral("org.deepin.dde.Launcher1"),
                                          QStringLiteral("VisibleChanged"),
                                          this,
                                          SLOT(handleLauncherVisibleChanged(bool)));

    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.deepin.dde.Launcher1"),
                                                          QStringLiteral("/org/deepin/dde/Launcher1"),
                                                          QStringLiteral("org.freedesktop.DBus.Properties"),
                                                          QStringLiteral("Get"));
    message << QStringLiteral("org.deepin.dde.Launcher1") << QStringLiteral("Visible");
    const QDBusMessage reply = QDBusConnection::sessionBus().call(message);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        m_launcherVisible = reply.arguments().constFirst().value<QDBusVariant>().variant().toBool();
    }
}

void TodoApp::handleLauncherVisibleChanged(bool visible)
{
    if (m_launcherVisible == visible) {
        return;
    }

    m_launcherVisible = visible;
    for (auto it = m_noteViews.begin(); it != m_noteViews.end(); ++it) {
        if (it.value() && noteWindowLayer(it.key()) == QStringLiteral("top")) {
            applyNoteWindowLayer(it.key(), false);
        }
    }
}

void TodoApp::handleExternalLaunch(const QStringList &args)
{
    QTimer::singleShot(0, this, [this, args]() {
        if (args.contains(QStringLiteral("--autostart"))) {
            showAutostartNoteWindows();
            return;
        }
        if (args.contains(QStringLiteral("--show-all"))) {
            showDefaultLaunchWindows();
            // showCalendarWindow();
            showSettingsWindow();
            return;
        }
        const bool hasExplicitWindowArg = args.contains(QStringLiteral("--list")) ||
                                          args.contains(QStringLiteral("--effects")) ||
                                          args.contains(QStringLiteral("--settings"));
        if (!hasExplicitWindowArg) {
            showDefaultLaunchWindows();
            return;
        }
        if (args.contains(QStringLiteral("--list"))) {
            showListWindow();
        }
        if (args.contains(QStringLiteral("--effects"))) {
            showEffectsTestWindow();
        }
        // if (args.contains(QStringLiteral("--calendar"))) {
        //     showCalendarWindow();
        // }
        if (args.contains(QStringLiteral("--settings"))) {
            showSettingsWindow();
        }
    });
}

void TodoApp::startTelemetry()
{
    if (!m_telemetry) {
        return;
    }
    m_telemetry->setEnabled(m_settings.value(QStringLiteral("telemetryEnabled")).toBool(true));
    m_telemetry->setEndpoint(QUrl(m_settings.value(QStringLiteral("telemetryEndpoint")).toString()));
    m_sessionTimer.start();

    QJsonObject properties;
    properties.insert(QStringLiteral("noteCount"), m_notes.size());
    properties.insert(QStringLiteral("theme"), theme());
    properties.insert(QStringLiteral("wallpaperMode"), mainWallpaperMode());
    trackTelemetry(QStringLiteral("app_start"), QStringLiteral("应用启动"), QStringLiteral("app"), properties);
    m_telemetry->flush();

    if (!m_telemetryHeartbeatTimer) {
        m_telemetryHeartbeatTimer = new QTimer(this);
        m_telemetryHeartbeatTimer->setInterval(TelemetryHeartbeatIntervalMs);
        connect(m_telemetryHeartbeatTimer, &QTimer::timeout, this, [this]() {
            QJsonObject heartbeat;
            heartbeat.insert(QStringLiteral("visibleNoteWindows"), m_noteViews.size());
            heartbeat.insert(QStringLiteral("mainWindowVisible"), static_cast<bool>(m_listWindow && m_listWindow->isVisible()));
            trackTelemetry(QStringLiteral("session_heartbeat"),
                           QStringLiteral("心跳"),
                           QStringLiteral("app"),
                           heartbeat,
                           m_sessionTimer.isValid() ? m_sessionTimer.elapsed() / 1000.0 : 0.0);
            if (m_telemetry) {
                m_telemetry->flush();
            }
        });
    }
    m_telemetryHeartbeatTimer->start();
}

void TodoApp::trackTelemetry(const QString &eventName,
                             const QString &eventType,
                             const QString &module,
                             const QJsonObject &properties,
                             double durationSeconds)
{
    if (!m_telemetry) {
        return;
    }
    if (!isCoreTelemetryEvent(eventName, eventType)) {
        return;
    }
    m_telemetry->track(eventName, eventType, module, properties, durationSeconds);
}

QVariantList TodoApp::notesList() const
{
    QVariantList list;
    QVector<QJsonObject> notes;
    for (const QJsonValue &value : m_notes) {
        notes.append(value.toObject());
    }
    std::sort(notes.begin(), notes.end(), [](const QJsonObject &a, const QJsonObject &b) {
        return valueString(a, QStringLiteral("createdDate"), valueString(a, QStringLiteral("updatedDate"))) >
               valueString(b, QStringLiteral("createdDate"), valueString(b, QStringLiteral("updatedDate")));
    });

    for (const QJsonObject &note : notes) {
        const QString noteId = note.value(QStringLiteral("id")).toVariant().toString();
        const QQuickView *noteView = m_noteViews.value(noteId);
        const QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
        const QJsonArray sortedTodos = sortedTodosForDisplay(todos);
        int completed = 0;
        for (const QJsonValue &todoValue : todos) {
            if (todoValue.toObject().value(QStringLiteral("completed")).toBool(false)) {
                ++completed;
            }
        }
        const QString dateSource = valueString(note, QStringLiteral("updatedDate"), note.value(QStringLiteral("createdDate")).toString());
        const QDateTime listDate = QDateTime::fromString(dateSource, Qt::ISODate);
        QVariantMap item;
        item.insert(QStringLiteral("id"), noteId);
        item.insert(QStringLiteral("title"), note.value(QStringLiteral("title")).toString(QStringLiteral("无标题")));
        item.insert(QStringLiteral("createdDate"), note.value(QStringLiteral("createdDate")).toString());
        item.insert(QStringLiteral("updatedDate"), dateSource);
        item.insert(QStringLiteral("dateText"), listDate.isValid() ? listDate.date().toString(QStringLiteral("yyyy/MM/dd")) : QString());
        item.insert(QStringLiteral("visible"), noteView && noteView->isVisible());
        item.insert(QStringLiteral("completed"), completed);
        item.insert(QStringLiteral("total"), todos.size());
        QVariantList todoList;
        for (const QJsonValue &todoValue : sortedTodos) {
            const QJsonObject todo = todoValue.toObject();
            QVariantMap todoMap;
            todoMap.insert(QStringLiteral("id"), todo.value(QStringLiteral("id")).toVariant().toString());
            todoMap.insert(QStringLiteral("text"), todo.value(QStringLiteral("text")).toString());
            todoMap.insert(QStringLiteral("completed"), todo.value(QStringLiteral("completed")).toBool(false));
            todoMap.insert(QStringLiteral("priority"), todo.value(QStringLiteral("priority")).toString(QStringLiteral("gray")));
            todoList.append(todoMap);
        }
        item.insert(QStringLiteral("todos"), todoList);
        list.append(item);
    }
    return list;
}

QVariantList TodoApp::eventsList() const
{
    QVariantList list;
    for (const QJsonValue &value : m_events) {
        list.append(value.toObject().toVariantMap());
    }
    return list;
}

QString TodoApp::theme() const { return m_settings.value(QStringLiteral("theme")).toString(QStringLiteral("system")); }
QString TodoApp::noteTheme() const { return m_settings.value(QStringLiteral("noteTheme")).toString(QStringLiteral("system")); }
QString TodoApp::priorityStyle() const { return m_settings.value(QStringLiteral("priorityStyle")).toString(QStringLiteral("colorful")); }
bool TodoApp::todosWrapEnabled() const { return m_settings.value(QStringLiteral("todosWrapEnabled")).toBool(true); }
int TodoApp::opacity() const { return m_settings.value(QStringLiteral("opacity")).toInt(60); }
QString TodoApp::storagePath() const { return m_dataDir; }
double TodoApp::mainDefaultTodoAlphaLight() const { return numberSetting(m_settings, QStringLiteral("mainDefaultTodoAlphaLight"), 0.445); }
double TodoApp::mainPriorityTodoAlphaLight() const { return numberSetting(m_settings, QStringLiteral("mainPriorityTodoAlphaLight"), 0.275); }
double TodoApp::mainDefaultTodoAlphaDark() const { return numberSetting(m_settings, QStringLiteral("mainDefaultTodoAlphaDark"), 0.13); }
double TodoApp::mainPriorityTodoAlphaDark() const { return numberSetting(m_settings, QStringLiteral("mainPriorityTodoAlphaDark"), 0.21); }
double TodoApp::mainWindowOpacity() const { return numberSetting(m_settings, QStringLiteral("mainWindowOpacity"), SystemWallpaperWindowOpacity); }
double TodoApp::mainRightPanelOpacity() const { return numberSetting(m_settings, QStringLiteral("mainRightPanelOpacity"), SystemWallpaperRightPanelOpacity); }
double TodoApp::mainWallpaperBlur() const { return numberSetting(m_settings, QStringLiteral("mainWallpaperBlur"), SystemWallpaperBlur); }
QString TodoApp::mainWallpaperMode() const { return m_settings.value(QStringLiteral("mainWallpaperMode")).toString(QStringLiteral("default")); }
double TodoApp::backdropProtection() const { return m_backdropProtection; }
QUrl TodoApp::wallpaperSource() const { return m_wallpaperSource; }
QRect TodoApp::wallpaperScreenGeometry() const { return m_wallpaperScreenGeometry; }

void TodoApp::syncDtkPalette()
{
    auto *helper = Dtk::Gui::DGuiApplicationHelper::instance();
    QSignalBlocker blocker(helper);
    m_syncingDtkPalette = true;
    const QString themeSetting = theme();
    if (themeSetting == QStringLiteral("system")) {
        helper->setPaletteType(Dtk::Gui::DGuiApplicationHelper::UnknownType);
    } else if (themeSetting == QStringLiteral("light")) {
        helper->setPaletteType(Dtk::Gui::DGuiApplicationHelper::LightType);
    } else {
        helper->setPaletteType(Dtk::Gui::DGuiApplicationHelper::DarkType);
    }
    m_syncingDtkPalette = false;
}

bool TodoApp::effectiveDarkTheme() const
{
    const QString themeSetting = theme();
    if (themeSetting == QStringLiteral("dark")) {
        return true;
    }
    if (themeSetting == QStringLiteral("light")) {
        return false;
    }

    auto *helper = Dtk::Gui::DGuiApplicationHelper::instance();
    return helper->themeType() != Dtk::Gui::DGuiApplicationHelper::LightType;
}

void TodoApp::applyMainWindowAppearanceDefaults()
{
    const QString wallpaperMode = mainWallpaperMode();
    const bool userOverridden = m_settings.value(QStringLiteral("mainWindowOpacityUserOverridden")).toBool(false);

    if (effectiveDarkTheme()) {
        if (!userOverridden) {
            const double windowOpacity = wallpaperMode == QStringLiteral("default")
                ? DarkDefaultWallpaperWindowOpacity
                : recommendedMainWindowOpacityForWallpaper(readSystemWallpaperSource());
            m_settings.insert(QStringLiteral("mainWindowOpacity"), windowOpacity);
        }
        m_settings.insert(QStringLiteral("mainRightPanelOpacity"), DarkThemeRightPanelOpacity);
        m_settings.insert(QStringLiteral("mainWallpaperBlur"), DarkThemeWallpaperBlur);
        m_settings.insert(QStringLiteral("darkThemeMainAppearanceVersion"), DarkThemeMainAppearanceVersion);
        return;
    }

    if (!userOverridden) {
        const double windowOpacity = wallpaperMode == QStringLiteral("default")
            ? DefaultWallpaperWindowOpacity
            : recommendedMainWindowOpacityForWallpaper(readSystemWallpaperSource());
        m_settings.insert(QStringLiteral("mainWindowOpacity"), windowOpacity);
    }

    if (wallpaperMode == QStringLiteral("default")) {
        m_settings.insert(QStringLiteral("mainRightPanelOpacity"), DefaultWallpaperRightPanelOpacity);
        m_settings.insert(QStringLiteral("mainWallpaperBlur"), DefaultWallpaperBlur);
        return;
    }

    m_settings.insert(QStringLiteral("mainRightPanelOpacity"), SystemWallpaperRightPanelOpacity);
    m_settings.insert(QStringLiteral("mainWallpaperBlur"), SystemWallpaperBlur);
}

double TodoApp::analyzeWallpaperBrightness(const QUrl &source) const
{
    if (!source.isLocalFile()) {
        return -1.0;
    }

    const QString path = source.toLocalFile();
    if (!QFileInfo::exists(path)) {
        return -1.0;
    }

    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize originalSize = reader.size();
    if (originalSize.isValid()) {
        QSize sampleSize = originalSize;
        sampleSize.scale(QSize(64, 64), Qt::KeepAspectRatio);
        reader.setScaledSize(sampleSize);
    }

    const QImage image = reader.read().convertToFormat(QImage::Format_ARGB32);
    if (image.isNull()) {
        qWarning() << "Failed to analyze wallpaper brightness:" << path << reader.errorString();
        return -1.0;
    }

    double luminanceSum = 0.0;
    int sampleCount = 0;
    for (int y = 0; y < image.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            const QColor color = QColor::fromRgba(line[x]);
            if (color.alpha() < 16) {
                continue;
            }
            luminanceSum += (0.2126 * color.redF()) + (0.7152 * color.greenF()) + (0.0722 * color.blueF());
            ++sampleCount;
        }
    }

    if (sampleCount == 0) {
        return -1.0;
    }
    return luminanceSum / sampleCount;
}

double TodoApp::recommendedMainWindowOpacityForWallpaper(const QUrl &source) const
{
    const double brightness = analyzeWallpaperBrightness(source);
    if (brightness < 0.0) {
        return effectiveDarkTheme() ? DarkThemeWindowOpacity : SystemWallpaperWindowOpacity;
    }
    return brightness >= WallpaperBrightnessThreshold ? BrightWallpaperWindowOpacity : DarkWallpaperWindowOpacity;
}

bool TodoApp::shouldAutoUpdateMainWindowOpacity() const
{
    const QString mode = mainWallpaperMode();
    return (mode == QStringLiteral("system") || mode == QStringLiteral("custom"))
        && !m_settings.value(QStringLiteral("mainWindowOpacityUserOverridden")).toBool(false);
}

bool TodoApp::applyAutomaticMainWindowOpacity(const QUrl &source)
{
    if (!shouldAutoUpdateMainWindowOpacity()) {
        return false;
    }

    const double recommendedOpacity = recommendedMainWindowOpacityForWallpaper(source);
    if (std::abs(mainWindowOpacity() - recommendedOpacity) < 0.0005) {
        return false;
    }

    m_settings.insert(QStringLiteral("mainWindowOpacity"), recommendedOpacity);
    return true;
}

void TodoApp::syncSettingFromDtkPalette(Dtk::Gui::DGuiApplicationHelper::ColorType paletteType)
{
    Q_UNUSED(paletteType)
    if (m_syncingDtkPalette) {
        return;
    }

    // Palette changes can come from the system while the user setting remains
    // "follow system". Do not persist DTK's effective Light/Dark value back
    // into settings; otherwise windows can disagree and theme switching loops.
    if (theme() == QStringLiteral("system")) {
        applyMainWindowAppearanceDefaults();
        saveSettings();
        emit settingsChanged();
    }
}

QString TodoApp::noteSummaryTemplate() const
{
    return m_settings.value(QStringLiteral("noteSummaryTemplate")).toString(defaultNoteSummaryTemplate());
}

void TodoApp::setNoteSummaryTemplate(const QString &summaryTemplate)
{
    const QString trimmed = summaryTemplate.trimmed();
    m_settings.insert(QStringLiteral("noteSummaryTemplate"), trimmed.isEmpty() ? defaultNoteSummaryTemplate() : summaryTemplate);
    saveSettings();
    emit settingsChanged();
}

QString TodoApp::summaryTemplate(const QString &scope) const
{
    return m_settings.value(summaryTemplateKey(scope)).toString(defaultSummaryTemplate(scope));
}

QString TodoApp::defaultSummaryTemplate(const QString &scope) const
{
    if (scope == QStringLiteral("week")) {
        return defaultWeekSummaryTemplate();
    }
    if (scope == QStringLiteral("month")) {
        return defaultMonthSummaryTemplate();
    }
    return defaultNoteSummaryTemplate();
}

void TodoApp::setSummaryTemplate(const QString &scope, const QString &summaryTemplate)
{
    const QString trimmed = summaryTemplate.trimmed();
    m_settings.insert(summaryTemplateKey(scope), trimmed.isEmpty() ? defaultSummaryTemplate(scope) : summaryTemplate);
    saveSettings();
    emit settingsChanged();
}

void TodoApp::resetSummaryTemplate(const QString &scope)
{
    m_settings.insert(summaryTemplateKey(scope), defaultSummaryTemplate(scope));
    saveSettings();
    emit settingsChanged();
}

void TodoApp::upgradeDefaultSummaryTemplates()
{
    bool changed = false;
    auto upgradeIfLegacyDefault = [this, &changed](const QString &key, const QString &legacyValue, const QString &nextValue) {
        if (!m_settings.contains(key)) {
            return;
        }
        const QString currentValue = m_settings.value(key).toString();
        if (currentValue.trimmed() == legacyValue.trimmed()) {
            m_settings.insert(key, nextValue);
            changed = true;
        }
    };

    upgradeIfLegacyDefault(QStringLiteral("noteSummaryTemplate"), legacyNoteSummaryTemplate(), defaultNoteSummaryTemplate());
    upgradeIfLegacyDefault(summaryTemplateKey(QStringLiteral("week")), legacyWeekSummaryTemplate(), defaultWeekSummaryTemplate());
    upgradeIfLegacyDefault(summaryTemplateKey(QStringLiteral("month")), legacyMonthSummaryTemplate(), defaultMonthSummaryTemplate());

    if (changed) {
        saveSettings();
        emit settingsChanged();
    }
}

QString TodoApp::noteWindowLayer(const QString &noteId) const
{
    return normalizedWindowLayer(noteById(noteId).value(QStringLiteral("windowLayer")).toString());
}

QString TodoApp::cycleNoteWindowLayer(const QString &noteId)
{
    if (noteId.isEmpty()) {
        return QStringLiteral("normal");
    }

    const QString current = noteWindowLayer(noteId);
    const QString next = current == QStringLiteral("normal")
        ? QStringLiteral("bottom")
        : current == QStringLiteral("bottom")
            ? QStringLiteral("top")
            : QStringLiteral("normal");

    for (int i = 0; i < m_notes.size(); ++i) {
        QJsonObject note = m_notes.at(i).toObject();
        if (note.value(QStringLiteral("id")).toVariant().toString() != noteId) {
            continue;
        }
        note.insert(QStringLiteral("windowLayer"), next);
        m_notes.replace(i, note);
        saveNotes();
        emit notesChanged();
        refreshNoteControllers(noteId);
        applyNoteWindowLayer(noteId, true);
        trackTelemetry(QStringLiteral("note_window_layer_changed"),
                       QStringLiteral("功能点击"),
                       QStringLiteral("desktop_note"),
                       QJsonObject{{QStringLiteral("nextLayer"), next},
                                   {QStringLiteral("previousLayer"), current}});
        return next;
    }

    return QStringLiteral("normal");
}

QJsonObject TodoApp::noteById(const QString &noteId) const
{
    for (const QJsonValue &value : m_notes) {
        const QJsonObject note = value.toObject();
        if (note.value(QStringLiteral("id")).toVariant().toString() == noteId) {
            return note;
        }
    }
    return {};
}

void TodoApp::updateNote(const QString &noteId, const QJsonObject &patch)
{
    for (int i = 0; i < m_notes.size(); ++i) {
        QJsonObject note = m_notes.at(i).toObject();
        if (note.value(QStringLiteral("id")).toVariant().toString() != noteId) {
            continue;
        }
        for (auto it = patch.begin(); it != patch.end(); ++it) {
            note.insert(it.key(), it.value());
        }
        const bool hasUserTodoText = patch.contains(QStringLiteral("todos")) &&
            hasNonEmptyTodoText(patch.value(QStringLiteral("todos")).toArray());
        const bool hasUserTitle = patch.contains(QStringLiteral("title")) &&
            note.value(QStringLiteral("title")).toString() != note.value(QString::fromLatin1(DiscardIfEmptyOnHideTitleKey)).toString();
        if (hasUserTodoText || hasUserTitle) {
            note.remove(QString::fromLatin1(DiscardIfEmptyOnHideKey));
            note.remove(QString::fromLatin1(DiscardIfEmptyOnHideTitleKey));
        }
        note.insert(QStringLiteral("updatedDate"), isoNow());
        m_notes.replace(i, note);
        saveNotes();
        emit notesChanged();
        refreshNoteControllers(noteId);
        return;
    }
}

void TodoApp::updateNoteTodos(const QString &noteId, const QJsonArray &todos)
{
    QJsonObject patch;
    patch.insert(QStringLiteral("todos"), todos);
    updateNote(noteId, patch);
}

void TodoApp::updateNoteTitle(const QString &noteId, const QString &title)
{
    QJsonObject patch;
    patch.insert(QStringLiteral("title"), title.trimmed().isEmpty() ? QStringLiteral("未命名待办") : title.trimmed());
    updateNote(noteId, patch);
}

QString TodoApp::summarizeNote(const QString &noteId)
{
    return summarizeNoteForSource(noteId, QStringLiteral("note_ai_summary_clicked"), QStringLiteral("main_window"));
}

QString TodoApp::summarizeDesktopNote(const QString &noteId)
{
    return summarizeNoteForSource(noteId, QStringLiteral("desktop_ai_summary_clicked"), QStringLiteral("desktop_note"));
}

QString TodoApp::summarizeNoteForSource(const QString &noteId, const QString &eventName, const QString &source)
{
    const QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return QStringLiteral("未找到待办窗口");
    }
    trackTelemetry(eventName,
                   QStringLiteral("功能点击"),
                   QStringLiteral("summary"),
                   QJsonObject{{QStringLiteral("source"), source},
                               {QStringLiteral("todoCount"), note.value(QStringLiteral("todos")).toArray().size()}});
    return sendPromptToUosAi(buildCurrentNoteSummaryPrompt(note));
}

QString TodoApp::syncNoteTodosToSystemCalendar(const QString &noteId)
{
    if (noteId.isEmpty()) {
        return QStringLiteral("未找到待办窗口");
    }

    const QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return QStringLiteral("未找到待办窗口");
    }

    CalendarSyncService service;
    const CalendarSyncService::SyncResult result = service.syncNoteTodos(note);
    for (const QString &error : result.errors) {
        qWarning() << "Calendar sync:" << error;
    }

    if (result.changedTodos) {
        for (int i = 0; i < m_notes.size(); ++i) {
            QJsonObject current = m_notes.at(i).toObject();
            if (current.value(QStringLiteral("id")).toVariant().toString() != noteId) {
                continue;
            }
            current.insert(QStringLiteral("todos"), result.todos);
            m_notes.replace(i, current);
            saveNotes();
            emit notesChanged();
            refreshNoteControllers(noteId);
            break;
        }
    }

    QJsonObject properties;
    properties.insert(QStringLiteral("changedTodos"), result.changedTodos);
    properties.insert(QStringLiteral("errorCount"), result.errors.size());
    properties.insert(QStringLiteral("todoCount"), note.value(QStringLiteral("todos")).toArray().size());
    trackTelemetry(QStringLiteral("calendar_sync"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("calendar"),
                   properties);

    return result.message.isEmpty() ? QStringLiteral("系统日历服务不可用") : result.message;
}

QString TodoApp::addTodoToNote(const QString &noteId, const QString &text)
{
    if (noteId.isEmpty()) {
        return QString();
    }
    QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return QString();
    }
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty()) {
        return QString();
    }
    QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    const QString id = QString::number(QDateTime::currentMSecsSinceEpoch());
    todos.append(QJsonObject{
        {QStringLiteral("id"), id},
        {QStringLiteral("text"), trimmed},
        {QStringLiteral("completed"), false},
        {QStringLiteral("priority"), QStringLiteral("gray")}
    });
    updateNoteTodos(noteId, todos);
    int totalTodos = 0;
    for (const QJsonValue &noteValue : std::as_const(m_notes)) {
        const QJsonArray noteTodos = noteValue.toObject().value(QStringLiteral("todos")).toArray();
        for (const QJsonValue &todoValue : noteTodos) {
            if (!todoValue.toObject().value(QStringLiteral("text")).toString().trimmed().isEmpty()) {
                ++totalTodos;
            }
        }
    }
    if (totalTodos > 0 && totalTodos % 50 == 0) {
        QTimer::singleShot(220, this, &TodoApp::triggerMainWindowPowderEffect);
    }
    trackTelemetry(QStringLiteral("todo_created"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("todo"),
                   QJsonObject{{QStringLiteral("totalTodos"), totalTodos},
                               {QStringLiteral("noteTodoCount"), todos.size()}});
    return id;
}

void TodoApp::commitNoteTodoText(const QString &noteId, const QString &todoId, const QString &text)
{
    QJsonObject note = noteById(noteId);
    if (note.isEmpty() || todoId.isEmpty()) {
        return;
    }
    QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    for (int i = 0; i < todos.size(); ++i) {
        QJsonObject todo = todos.at(i).toObject();
        if (todo.value(QStringLiteral("id")).toVariant().toString() != todoId) {
            continue;
        }
        const QString trimmed = text.trimmed();
        if (trimmed.isEmpty()) {
            todos.removeAt(i);
            trackTelemetry(QStringLiteral("todo_empty_removed"),
                           QStringLiteral("功能点击"),
                           QStringLiteral("todo"));
        } else {
            todo.insert(QStringLiteral("text"), trimmed);
            todos.replace(i, todo);
            trackTelemetry(QStringLiteral("todo_text_committed"),
                           QStringLiteral("功能点击"),
                           QStringLiteral("todo"));
        }
        updateNoteTodos(noteId, todos);
        return;
    }
}

void TodoApp::toggleNoteTodo(const QString &noteId, const QString &todoId)
{
    QJsonObject note = noteById(noteId);
    if (note.isEmpty() || todoId.isEmpty()) {
        return;
    }
    QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    for (int i = 0; i < todos.size(); ++i) {
        QJsonObject todo = todos.at(i).toObject();
        if (todo.value(QStringLiteral("id")).toVariant().toString() != todoId) {
            continue;
        }
        const bool nextCompleted = !todo.value(QStringLiteral("completed")).toBool(false);
        todo.insert(QStringLiteral("completed"), nextCompleted);
        todos.replace(i, todo);
        updateNoteTodos(noteId, todos);
        trackTelemetry(nextCompleted ? QStringLiteral("todo_completed") : QStringLiteral("todo_uncompleted"),
                       QStringLiteral("功能点击"),
                       QStringLiteral("todo"),
                       QJsonObject{{QStringLiteral("priority"), todo.value(QStringLiteral("priority")).toString(QStringLiteral("gray"))}});
        return;
    }
}

void TodoApp::deleteNoteTodo(const QString &noteId, const QString &todoId)
{
    QJsonObject note = noteById(noteId);
    if (note.isEmpty() || todoId.isEmpty()) {
        return;
    }
    QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    for (int i = 0; i < todos.size(); ++i) {
        if (todos.at(i).toObject().value(QStringLiteral("id")).toVariant().toString() == todoId) {
            todos.removeAt(i);
            updateNoteTodos(noteId, todos);
            trackTelemetry(QStringLiteral("todo_deleted"),
                           QStringLiteral("功能点击"),
                           QStringLiteral("todo"),
                           QJsonObject{{QStringLiteral("noteTodoCount"), todos.size()}});
            return;
        }
    }
}

void TodoApp::setNoteTodoPriority(const QString &noteId, const QString &todoId, const QString &priority)
{
    QJsonObject note = noteById(noteId);
    if (note.isEmpty() || todoId.isEmpty()) {
        return;
    }
    QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    for (int i = 0; i < todos.size(); ++i) {
        QJsonObject todo = todos.at(i).toObject();
        if (todo.value(QStringLiteral("id")).toVariant().toString() != todoId) {
            continue;
        }
        todo.insert(QStringLiteral("priority"), priority);
        todos.replace(i, todo);
        updateNoteTodos(noteId, todos);
        trackTelemetry(QStringLiteral("todo_priority_changed"),
                       QStringLiteral("功能点击"),
                       QStringLiteral("todo"),
                       QJsonObject{{QStringLiteral("priority"), priority}});
        return;
    }
}

void TodoApp::moveNoteTodoById(const QString &noteId, const QString &todoId, int toDisplayIndex)
{
    QJsonObject note = noteById(noteId);
    if (note.isEmpty() || todoId.isEmpty()) {
        return;
    }

    const QJsonArray displayTodos = sortedTodosForDisplay(note.value(QStringLiteral("todos")).toArray());
    if (displayTodos.isEmpty()) {
        return;
    }

    int from = -1;
    int firstCompleted = displayTodos.size();
    for (int i = 0; i < displayTodos.size(); ++i) {
        const QJsonObject object = displayTodos.at(i).toObject();
        if (object.value(QStringLiteral("completed")).toBool(false) && firstCompleted == displayTodos.size()) {
            firstCompleted = i;
        }
        if (object.value(QStringLiteral("id")).toVariant().toString() == todoId) {
            from = i;
        }
    }

    if (from < 0 || displayTodos.at(from).toObject().value(QStringLiteral("completed")).toBool(false)) {
        return;
    }

    const int maxUnfinishedIndex = qMax(0, firstCompleted - 1);
    const int to = qBound(0, toDisplayIndex, maxUnfinishedIndex);
    if (from == to) {
        return;
    }

    QVector<QJsonObject> objects;
    for (const QJsonValue &value : displayTodos) {
        objects.append(value.toObject());
    }
    objects.move(from, to);

    QJsonArray next;
    for (const QJsonObject &object : objects) {
        next.append(object);
    }
    updateNoteTodos(noteId, next);
    trackTelemetry(QStringLiteral("todo_reordered"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("todo"),
                   QJsonObject{{QStringLiteral("fromIndex"), from},
                               {QStringLiteral("toIndex"), to}});
}

QString TodoApp::createNewNote()
{
    return createNewNote(true);
}

QString TodoApp::createNewNote(bool discardIfEmptyOnHide)
{
    if (m_notes.size() >= MaxNotes) {
        return {};
    }

    const QString id = QString::number(QDateTime::currentMSecsSinceEpoch());
    const QPoint pos = defaultNotePosition(120, 100);
    const QString title = generateDefaultNoteTitle();
    QJsonObject note;
    note.insert(QStringLiteral("id"), id);
    note.insert(QStringLiteral("title"), title);
    note.insert(QStringLiteral("todos"), QJsonArray());
    note.insert(QStringLiteral("position"), QJsonObject{{QStringLiteral("x"), pos.x()}, {QStringLiteral("y"), pos.y()}});
    note.insert(QStringLiteral("size"), QJsonObject{{QStringLiteral("width"), 280}, {QStringLiteral("height"), 400}});
    note.insert(QStringLiteral("visible"), true);
    note.insert(QStringLiteral("windowLayer"), QStringLiteral("normal"));
    note.insert(QStringLiteral("createdDate"), isoNow());
    note.insert(QStringLiteral("updatedDate"), isoNow());
    if (discardIfEmptyOnHide) {
        note.insert(QString::fromLatin1(DiscardIfEmptyOnHideKey), true);
        note.insert(QString::fromLatin1(DiscardIfEmptyOnHideTitleKey), title);
    }
    m_notes.append(note);
    saveNotes();
    emit notesChanged();
    openNote(id);
    trackTelemetry(QStringLiteral("note_created"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("note"),
                   QJsonObject{{QStringLiteral("noteCount"), m_notes.size()}});
    return id;
}

QString TodoApp::latestCreatedNoteId() const
{
    QString latestId;
    QString latestCreated;
    for (const QJsonValue &value : m_notes) {
        const QJsonObject note = value.toObject();
        const QString noteId = note.value(QStringLiteral("id")).toVariant().toString();
        if (noteId.isEmpty()) {
            continue;
        }
        const QString created = valueString(note,
                                            QStringLiteral("createdDate"),
                                            valueString(note, QStringLiteral("updatedDate")));
        if (latestId.isEmpty() || created > latestCreated) {
            latestId = noteId;
            latestCreated = created;
        }
    }
    return latestId;
}

void TodoApp::showLatestCreatedNoteOnDesktop()
{
    const QString noteId = latestCreatedNoteId();
    if (noteId.isEmpty()) {
        createNewNote();
        return;
    }
    openNoteWithLayer(noteId, QString());
}

void TodoApp::showAutostartNoteWindows()
{
    QStringList visibleNoteIds;
    for (const QJsonValue &value : std::as_const(m_notes)) {
        const QJsonObject note = value.toObject();
        const QString noteId = note.value(QStringLiteral("id")).toVariant().toString();
        if (!noteId.isEmpty() && note.value(QStringLiteral("visible")).toBool(false)) {
            visibleNoteIds.append(noteId);
        }
    }

    if (visibleNoteIds.isEmpty()) {
        showLatestCreatedNoteOnDesktop();
        return;
    }

    for (const QString &noteId : std::as_const(visibleNoteIds)) {
        openNoteWithLayer(noteId, QString());
    }
}

QString TodoApp::currentDdeLaunchType(bool *managedLaunch) const
{
    if (managedLaunch) {
        *managedLaunch = false;
    }

    QFile cgroupFile(QStringLiteral("/proc/self/cgroup"));
    if (!cgroupFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }

    const QString cgroup = QString::fromUtf8(cgroupFile.readAll());
    const QRegularExpressionMatch runIdMatch =
        QRegularExpression(QStringLiteral("@([0-9a-fA-F]{32})\\.service(?:$|\\n)"))
            .match(cgroup);
    if (!runIdMatch.hasMatch()) {
        return QString();
    }
    if (managedLaunch) {
        *managedLaunch = true;
    }

    const QString instancePath = QStringLiteral("/org/desktopspec/ApplicationManager1/xiaou_2dtodo/%1")
                                     .arg(runIdMatch.captured(1).toLower());
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.desktopspec.ApplicationManager1"),
        instancePath,
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("Get"));
    message << QStringLiteral("org.desktopspec.ApplicationManager1.Instance")
            << QStringLiteral("LaunchType");

    const QDBusMessage reply = QDBusConnection::sessionBus().call(message);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return QString();
    }

    return reply.arguments().constFirst().value<QDBusVariant>().variant().toString();
}

void TodoApp::showDefaultLaunchWindows()
{
    showLatestCreatedNoteOnDesktop();
    showListWindow();
}

void TodoApp::openNote(const QString &noteId)
{
    openNoteWithLayer(noteId, QString());
}

void TodoApp::showNoteOnDesktop(const QString &noteId)
{
    openNoteWithLayer(noteId, QStringLiteral("normal"));
    trackTelemetry(QStringLiteral("note_show_on_desktop"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("note"));
}

void TodoApp::openNoteWithLayer(const QString &noteId, const QString &layer)
{
    if (noteId.isEmpty()) {
        return;
    }
    const QString normalizedLayer = layer.isEmpty() ? QString() : normalizedWindowLayer(layer);

    auto setRequestedLayer = [this, &normalizedLayer](const QString &targetNoteId) {
        if (normalizedLayer.isEmpty()) {
            return;
        }
        for (int i = 0; i < m_notes.size(); ++i) {
            QJsonObject note = m_notes.at(i).toObject();
            if (note.value(QStringLiteral("id")).toVariant().toString() != targetNoteId) {
                continue;
            }
            if (note.value(QStringLiteral("windowLayer")).toString() != normalizedLayer) {
                note.insert(QStringLiteral("windowLayer"), normalizedLayer);
                m_notes.replace(i, note);
                saveNotes();
            }
            return;
        }
    };

    setRequestedLayer(noteId);
    if (m_noteViews.value(noteId)) {
        m_noteViews.value(noteId)->show();
        scheduleWindowIconPublish(m_noteViews.value(noteId));
        scheduleSkipTaskbarState(m_noteViews.value(noteId));
        applyNoteWindowLayer(noteId, true);
        emit notesChanged();
        return;
    }

    QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return;
    }
    QJsonObject patch;
    patch.insert(QStringLiteral("visible"), true);
    if (!normalizedLayer.isEmpty()) {
        patch.insert(QStringLiteral("windowLayer"), normalizedLayer);
    }
    updateNote(noteId, patch);
    note = noteById(noteId);

    const QJsonObject size = note.value(QStringLiteral("size")).toObject();
    const QJsonObject position = note.value(QStringLiteral("position")).toObject();
    QQuickView *view = createView(QUrl(QStringLiteral("qrc:/NoteWindow.qml")),
                                  QSize(size.value(QStringLiteral("width")).toInt(280), size.value(QStringLiteral("height")).toInt(400)),
                                  QSize(240, 200), true, true);
    auto *controller = new NoteController(this, noteId, view);
    view->rootContext()->setContextProperty(QStringLiteral("noteController"), controller);
    view->rootContext()->setContextProperty(QStringLiteral("app"), this);
    view->setSource(QUrl(QStringLiteral("qrc:/NoteWindow.qml")));
    view->setPosition(position.value(QStringLiteral("x")).toInt(defaultNotePosition().x()),
                      position.value(QStringLiteral("y")).toInt(defaultNotePosition().y()));

    connect(view, &QQuickView::widthChanged, this, [this, noteId, view]() { scheduleNoteGeometrySave(noteId, view); });
    connect(view, &QQuickView::heightChanged, this, [this, noteId, view]() { scheduleNoteGeometrySave(noteId, view); });
    connect(view, &QQuickView::xChanged, this, [this, noteId, view]() { scheduleNoteGeometrySave(noteId, view); });
    connect(view, &QQuickView::yChanged, this, [this, noteId, view]() { scheduleNoteGeometrySave(noteId, view); });
    connect(view, &QWindow::visibleChanged, this, [this, noteId, view](bool visible) {
        if (!visible) {
            saveNoteGeometry(noteId, view);
        }
    });
    connect(view, &QObject::destroyed, this, [this, noteId]() {
        if (QTimer *timer = m_noteGeometrySaveTimers.take(noteId)) {
            timer->deleteLater();
        }
        m_noteViews.remove(noteId);
        m_noteControllers.remove(noteId);
        emit notesChanged();
    });

    m_noteViews.insert(noteId, view);
    m_noteControllers.insert(noteId, controller);
    applyNoteWindowLayer(noteId, false);
    // Publish skip-taskbar state before the first map so DDE never creates a
    // dock entry for this otherwise-normal desktop note window.
    scheduleSkipTaskbarState(view);
    view->show();
    scheduleWindowIconPublish(view);
    scheduleSkipTaskbarState(view);
    applyNoteWindowLayer(noteId, true);
    emit notesChanged();
}

void TodoApp::hideNote(const QString &noteId)
{
    for (int i = m_notes.size() - 1; i >= 0; --i) {
        const QJsonObject note = m_notes.at(i).toObject();
        if (note.value(QStringLiteral("id")).toVariant().toString() != noteId) {
            continue;
        }

        const bool discardIfEmptyOnHide = note.value(QString::fromLatin1(DiscardIfEmptyOnHideKey)).toBool(false);
        const QString originalTitle = note.value(QString::fromLatin1(DiscardIfEmptyOnHideTitleKey)).toString();
        const bool titleUnchanged = originalTitle.isEmpty() || note.value(QStringLiteral("title")).toString() == originalTitle;
        if (discardIfEmptyOnHide && titleUnchanged && !hasNonEmptyTodoText(note.value(QStringLiteral("todos")).toArray())) {
            m_notes.removeAt(i);
            saveNotes();
            emit notesChanged();
            if (QQuickView *view = m_noteViews.value(noteId)) {
                view->close();
                view->deleteLater();
            }
            return;
        }
        break;
    }

    QJsonObject patch;
    patch.insert(QStringLiteral("visible"), false);
    updateNote(noteId, patch);
    if (QQuickView *view = m_noteViews.value(noteId)) {
        view->close();
        view->deleteLater();
    }
}

void TodoApp::deleteNote(const QString &noteId)
{
    for (int i = m_notes.size() - 1; i >= 0; --i) {
        if (m_notes.at(i).toObject().value(QStringLiteral("id")).toVariant().toString() == noteId) {
            m_notes.removeAt(i);
        }
    }
    saveNotes();
    emit notesChanged();
    if (QQuickView *view = m_noteViews.value(noteId)) {
        view->close();
        view->deleteLater();
    }
    trackTelemetry(QStringLiteral("note_deleted"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("note"),
                   QJsonObject{{QStringLiteral("noteCount"), m_notes.size()}});
}

void TodoApp::showListWindow()
{
    if (m_listWindow && isWindowViewable(m_listWindow)) {
        refreshWallpaper();
        m_listWindow->showNormal();
        m_listWindow->show();
        m_listWindow->setVisible(true);
        m_listWindow->raise();
        m_listWindow->requestActivate();
        trackTelemetry(QStringLiteral("main_window_opened"),
                       QStringLiteral("页面访问"),
                       QStringLiteral("main_window"));
        return;
    }

    if (m_listWindow) {
        QWindow *oldWindow = m_listWindow.data();
        m_listWindow = nullptr;
        m_listEngine = nullptr;
        oldWindow->deleteLater();
    }

    refreshWallpaper();
    auto *engine = new QQmlEngine(this);
    m_listEngine = engine;
    engine->rootContext()->setContextProperty(QStringLiteral("app"), this);
    QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/ListWindow.qml")));
    QObject *object = component.create();
    if (!object) {
        qWarning() << component.errors();
        if (m_listEngine == engine) {
            m_listEngine = nullptr;
        }
        engine->deleteLater();
        return;
    }
    auto *window = qobject_cast<QWindow *>(object);
    if (!window) {
        qWarning() << "ListWindow root is not a QWindow";
        object->deleteLater();
        if (m_listEngine == engine) {
            m_listEngine = nullptr;
        }
        engine->deleteLater();
        return;
    }
    window->setIcon(productIcon());
    if (auto *quickWindow = qobject_cast<QQuickWindow *>(window)) {
        quickWindow->setColor(Qt::transparent);
    }
    m_listWindow = window;
    connect(window, &QWindow::visibleChanged, this, [this](bool visible) {
        if (visible) {
            refreshWallpaper();
        }
    });
    connect(window, &QWindow::screenChanged, this, [this]() {
        refreshWallpaper();
    });
    connect(window, &QObject::destroyed, this, [this, window, engine]() {
        if (m_listWindow == window) {
            m_listWindow = nullptr;
        }
        if (m_listEngine == engine) {
            m_listEngine = nullptr;
        }
        engine->deleteLater();
    });
    window->show();
    scheduleWindowIconPublish(window);
    window->raise();
    window->requestActivate();
    refreshWallpaper();
    trackTelemetry(QStringLiteral("main_window_opened"),
                   QStringLiteral("页面访问"),
                   QStringLiteral("main_window"));
}

void TodoApp::refreshWallpaper()
{
    const QUrl rawSource = readSystemWallpaperSource();
    const QRect nextGeometry = currentListScreenGeometry();
    updateWallpaperWatchPaths(rawSource);

    const QUrl nextSource = cachedWallpaperSource(rawSource, nextGeometry);
    const bool opacityChanged = applyAutomaticMainWindowOpacity(nextSource);
    if (opacityChanged) {
        m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
        saveSettings();
    }

    if (nextSource == m_wallpaperSource && nextGeometry == m_wallpaperScreenGeometry) {
        if (opacityChanged) {
            emit settingsChanged();
        }
        return;
    }

    m_wallpaperSource = nextSource;
    m_wallpaperScreenGeometry = nextGeometry;
    emit wallpaperChanged();
    if (opacityChanged) {
        emit settingsChanged();
    }
}

void TodoApp::resetMainWindowAppearanceDefaults()
{
    m_settings.insert(QStringLiteral("mainWindowOpacityUserOverridden"), false);
    applyMainWindowAppearanceDefaults();
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    saveSettings();
    emit settingsChanged();
    refreshWallpaper();
}

QUrl TodoApp::readSystemWallpaperSource() const
{
    if (mainWallpaperMode() == QStringLiteral("default")) {
        return QUrl(QString::fromLatin1(DefaultMainWallpaperPath));
    }

    if (mainWallpaperMode() == QStringLiteral("custom")) {
        const QString customPath = m_settings.value(QStringLiteral("mainCustomWallpaperPath")).toString();
        if (!customPath.isEmpty() && QFile::exists(customPath)) {
            return QUrl::fromLocalFile(customPath);
        }
    }

    const QUrl ddeAppearanceUrl = readDdeAppearanceWallpaperSource();
    if (ddeAppearanceUrl.isValid() && !ddeAppearanceUrl.isEmpty()) {
        return ddeAppearanceUrl;
    }

    const QUrl deepinUrl = wallpaperUrlFromValue(gsettingsValue(QStringLiteral("com.deepin.wrap.gnome.desktop.background"),
                                                               QStringLiteral("picture-uri")));
    if (deepinUrl.isValid() && !deepinUrl.isEmpty()) {
        return deepinUrl;
    }

    return wallpaperUrlFromValue(gsettingsValue(QStringLiteral("org.gnome.desktop.background"),
                                                QStringLiteral("picture-uri")));
}

QUrl TodoApp::readDdeAppearanceWallpaperSource() const
{
    QFile file(ddeAppearanceConfigPath());
    if (!file.open(QIODevice::ReadOnly)) {
        return QUrl();
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        return QUrl();
    }

    const QString screenName = currentListScreenName();
    const int workspace = currentWorkspaceNumber();
    const QString exactKey = QStringLiteral("%1+%2").arg(workspace).arg(screenName);
    const QString workspacePrefix = QStringLiteral("%1+").arg(workspace);
    const QString screenSuffix = QStringLiteral("+%1").arg(screenName);

    QUrl firstWorkspaceUrl;
    QUrl firstScreenUrl;
    QUrl firstUrl;

    const QJsonArray roots = document.array();
    for (const QJsonValue &rootValue : roots) {
        const QJsonArray wallpaperInfo = rootValue.toObject().value(QStringLiteral("wallpaperInfo")).toArray();
        for (const QJsonValue &infoValue : wallpaperInfo) {
            const QJsonObject info = infoValue.toObject();
            const QString wpIndex = info.value(QStringLiteral("wpIndex")).toString();
            const QUrl url = wallpaperUrlFromValue(info.value(QStringLiteral("uri")).toString());
            if (!url.isValid() || url.isEmpty()) {
                continue;
            }

            if (firstUrl.isEmpty()) {
                firstUrl = url;
            }
            if (firstWorkspaceUrl.isEmpty() && wpIndex.startsWith(workspacePrefix)) {
                firstWorkspaceUrl = url;
            }
            if (!screenName.isEmpty() && firstScreenUrl.isEmpty() && wpIndex.endsWith(screenSuffix)) {
                firstScreenUrl = url;
            }
            if (!screenName.isEmpty() && wpIndex == exactKey) {
                return url;
            }
        }
    }

    if (!firstWorkspaceUrl.isEmpty()) {
        return firstWorkspaceUrl;
    }
    if (!firstScreenUrl.isEmpty()) {
        return firstScreenUrl;
    }
    return firstUrl;
}

QUrl TodoApp::cachedWallpaperSource(const QUrl &source, const QRect &screenGeometry) const
{
    if (!source.isLocalFile()) {
        return source;
    }

    const QString sourcePath = source.toLocalFile();
    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        return source;
    }

    QSize targetSize = screenGeometry.size();
    if (!targetSize.isValid() || targetSize.width() <= 0 || targetSize.height() <= 0) {
        if (QScreen *screen = QGuiApplication::primaryScreen()) {
            targetSize = screen->geometry().size();
        }
    }
    if (!targetSize.isValid() || targetSize.width() <= 0 || targetSize.height() <= 0) {
        return source;
    }

    QString cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (cacheRoot.isEmpty()) {
        cacheRoot = QDir(m_dataDir).filePath(QStringLiteral("cache"));
    }
    const QString cacheDir = QDir(cacheRoot).filePath(QStringLiteral("wallpapers"));
    QDir().mkpath(cacheDir);

    QByteArray key;
    key += sourcePath.toUtf8();
    key += '|';
    key += QByteArray::number(sourceInfo.lastModified().toMSecsSinceEpoch());
    key += '|';
    key += QByteArray::number(sourceInfo.size());
    key += '|';
    key += QByteArray::number(targetSize.width());
    key += 'x';
    key += QByteArray::number(targetSize.height());
    const QString cachePath = QDir(cacheDir).filePath(QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex()) + QStringLiteral(".jpg"));
    if (QFile::exists(cachePath)) {
        return QUrl::fromLocalFile(cachePath);
    }

    QImageReader reader(sourcePath);
    reader.setAutoTransform(true);
    const QSize originalSize = reader.size();
    if (originalSize.isValid()) {
        QSize decodeSize = originalSize;
        decodeSize.scale(targetSize, Qt::KeepAspectRatioByExpanding);
        reader.setScaledSize(decodeSize);
    }

    QImage image = reader.read();
    if (image.isNull()) {
        qWarning() << "Failed to read wallpaper for cache:" << sourcePath << reader.errorString();
        return source;
    }

    if (image.size() != targetSize) {
        QSize scaledSize = image.size();
        scaledSize.scale(targetSize, Qt::KeepAspectRatioByExpanding);
        image = image.scaled(scaledSize, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    }

    const QRect cropRect((image.width() - targetSize.width()) / 2,
                         (image.height() - targetSize.height()) / 2,
                         targetSize.width(),
                         targetSize.height());
    const QImage cropped = image.copy(cropRect).convertToFormat(QImage::Format_RGB888);
    if (!cropped.save(cachePath, "JPG", 88)) {
        qWarning() << "Failed to write wallpaper cache:" << cachePath;
        return source;
    }

    return QUrl::fromLocalFile(cachePath);
}

void TodoApp::updateWallpaperWatchPaths(const QUrl &source)
{
    if (!m_wallpaperWatcher) {
        return;
    }

    const QStringList watchedFiles = m_wallpaperWatcher->files();
    if (!watchedFiles.isEmpty()) {
        m_wallpaperWatcher->removePaths(watchedFiles);
    }
    const QStringList watchedDirectories = m_wallpaperWatcher->directories();
    if (!watchedDirectories.isEmpty()) {
        m_wallpaperWatcher->removePaths(watchedDirectories);
    }

    const QString configPath = ddeAppearanceConfigPath();
    const QFileInfo configInfo(configPath);
    if (configInfo.exists()) {
        m_wallpaperWatcher->addPath(configPath);
    }
    const QString configDir = configInfo.absolutePath();
    if (QDir(configDir).exists()) {
        m_wallpaperWatcher->addPath(configDir);
    }

    if (source.isLocalFile()) {
        const QString sourcePath = source.toLocalFile();
        if (QFile::exists(sourcePath)) {
            m_wallpaperWatcher->addPath(sourcePath);
        }
    }
}

QRect TodoApp::currentListScreenGeometry() const
{
    QScreen *screen = nullptr;
    if (m_listWindow) {
        screen = m_listWindow->screen();
    }
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }
    return screen ? screen->geometry() : QRect();
}

QString TodoApp::currentListScreenName() const
{
    QScreen *screen = nullptr;
    if (m_listWindow) {
        screen = m_listWindow->screen();
    }
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }
    return screen ? screen->name() : QString();
}

void TodoApp::showEffectsTestWindow()
{
    if (m_effectsTestView) {
        m_effectsTestView->show();
        m_effectsTestView->raise();
        m_effectsTestView->requestActivate();
        return;
    }

    m_effectsTestView = createView(QUrl(QStringLiteral("qrc:/EffectsTestWindow.qml")),
                                   QSize(280, 156),
                                   QSize(260, 140),
                                   true,
                                   false);
    m_effectsTestView->rootContext()->setContextProperty(QStringLiteral("app"), this);
    m_effectsTestView->setSource(QUrl(QStringLiteral("qrc:/EffectsTestWindow.qml")));
    m_effectsTestView->setFlags(Qt::Tool | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    connect(m_effectsTestView, &QObject::destroyed, this, [this]() { m_effectsTestView = nullptr; });
    m_effectsTestView->show();
    m_effectsTestView->raise();
    m_effectsTestView->requestActivate();
}

void TodoApp::triggerFireworksEffect()
{
    qDebug() << "effects: trigger fireworks";
    showEffectOverlay(QStringLiteral("fireworks"));
}

void TodoApp::triggerMainWindowPowderEffect()
{
    qDebug() << "effects: trigger powder";
    if (m_effectOverlayView) {
        qDebug() << "effects: overlay already active";
        m_effectOverlayView->raise();
        return;
    }

    if (!m_listWindow) {
        qDebug() << "effects: list window missing, showing first";
        showListWindow();
        QTimer::singleShot(180, this, &TodoApp::triggerMainWindowPowderEffect);
        return;
    }

    if (!m_listWindow->isVisible()) {
        qDebug() << "effects: list window hidden, showing first";
        m_listWindow->show();
        m_listWindow->raise();
        QTimer::singleShot(120, this, &TodoApp::triggerMainWindowPowderEffect);
        return;
    }

    QScreen *screen = m_listWindow->screen() ? m_listWindow->screen() : QGuiApplication::primaryScreen();
    if (!screen) {
        qDebug() << "effects: no screen for powder";
        return;
    }

    const QRect geometry = m_listWindow->geometry();
    const QPixmap snapshot = screen->grabWindow(m_listWindow->winId(), 0, 0, geometry.width(), geometry.height());
    if (snapshot.isNull()) {
        qDebug() << "effects: list snapshot failed" << geometry;
        return;
    }

    const QVariantList particles = buildPowderParticles(snapshot, geometry);
    if (particles.isEmpty()) {
        qDebug() << "effects: no powder particles" << snapshot.size() << geometry;
        return;
    }

    qDebug() << "effects: powder particles" << particles.size() << "geometry" << geometry << "snapshot" << snapshot.size();
    m_listWindow->hide();
    showEffectOverlay(QStringLiteral("powder"), particles, true);
}

// void TodoApp::showCalendarWindow()
// {
//     if (m_calendarView) {
//         m_calendarView->show();
//         m_calendarView->raise();
//         m_calendarView->requestActivate();
//         return;
//     }
//     m_calendarView = createView(QUrl(QStringLiteral("qrc:/CalendarWindow.qml")), QSize(900, 600), QSize(700, 500), true, true);
//     m_calendarView->rootContext()->setContextProperty(QStringLiteral("app"), this);
//     m_calendarView->setSource(QUrl(QStringLiteral("qrc:/CalendarWindow.qml")));
//     connect(m_calendarView, &QObject::destroyed, this, [this]() { m_calendarView = nullptr; });
//     m_calendarView->show();
// }

void TodoApp::showSettingsWindow()
{
    if (m_settingsView) {
        m_settingsView->show();
        m_settingsView->raise();
        m_settingsView->requestActivate();
        trackTelemetry(QStringLiteral("settings_opened"),
                       QStringLiteral("页面访问"),
                       QStringLiteral("settings"));
        return;
    }
    m_settingsView = createView(QUrl(QStringLiteral("qrc:/SettingsWindow.qml")), QSize(760, 560), QSize(680, 500), true, false);
    m_settingsView->rootContext()->setContextProperty(QStringLiteral("app"), this);
    m_settingsView->setSource(QUrl(QStringLiteral("qrc:/SettingsWindow.qml")));
    connect(m_settingsView, &QObject::destroyed, this, [this]() { m_settingsView = nullptr; });
    m_settingsView->show();
    m_settingsView->raise();
    m_settingsView->requestActivate();
    trackTelemetry(QStringLiteral("settings_opened"),
                   QStringLiteral("页面访问"),
                   QStringLiteral("settings"));
}

void TodoApp::showFeedbackDialog()
{
    showListWindow();
    QTimer::singleShot(0, this, [this]() {
        emit feedbackDialogRequested();
    });
}

QString TodoApp::submitFeedback(const QString &content, const QString &contact)
{
    const QString trimmedContent = content.trimmed();
    if (trimmedContent.isEmpty()) {
        return QStringLiteral("请先输入反馈内容");
    }

    QJsonObject properties;
    properties.insert(QStringLiteral("content"), trimmedContent.left(2000));
    properties.insert(QStringLiteral("contact"), contact.trimmed().left(300));
    properties.insert(QStringLiteral("contentLength"), trimmedContent.size());
    properties.insert(QStringLiteral("hasContact"), !contact.trimmed().isEmpty());

    trackTelemetry(QStringLiteral("feedback_submitted"),
                   QStringLiteral("反馈提交"),
                   QStringLiteral("feedback"),
                   properties);
    if (m_telemetry) {
        m_telemetry->flush();
    }
    return QStringLiteral("反馈已提交，感谢帮助小U变得更好");
}

QVariantList TodoApp::buildPowderParticles(const QPixmap &snapshot, const QRect &windowGeometry) const
{
    const QImage image = snapshot.toImage().convertToFormat(QImage::Format_RGBA8888);
    if (image.isNull() || windowGeometry.isEmpty()) {
        return {};
    }

    constexpr int TargetParticles = 7600;
    const int totalPixels = qMax(1, image.width() * image.height());
    const int step = qBound(5, static_cast<int>(std::sqrt(totalPixels / static_cast<double>(TargetParticles))), 12);
    const double scaleX = windowGeometry.width() / static_cast<double>(image.width());
    const double scaleY = windowGeometry.height() / static_cast<double>(image.height());

    QVariantList particles;
    particles.reserve(TargetParticles + 400);
    QRandomGenerator *rng = QRandomGenerator::global();

    for (int y = step / 2; y < image.height(); y += step) {
        for (int x = step / 2; x < image.width(); x += step) {
            const QColor color = image.pixelColor(x, y);
            if (color.alpha() < 24) {
                continue;
            }

            QVariantMap particle;
            particle.insert(QStringLiteral("x"), windowGeometry.x() + x * scaleX);
            particle.insert(QStringLiteral("y"), windowGeometry.y() + y * scaleY);
            particle.insert(QStringLiteral("size"), qBound(2.0, step * qMin(scaleX, scaleY) * 0.82, 6.0));
            particle.insert(QStringLiteral("color"), color.name(QColor::HexArgb));
            particle.insert(QStringLiteral("delay"), static_cast<int>(rng->bounded(620)));
            particle.insert(QStringLiteral("duration"), 1450 + static_cast<int>(rng->bounded(1000)));
            particle.insert(QStringLiteral("dx"), 230 + static_cast<int>(rng->bounded(560)));
            particle.insert(QStringLiteral("dy"), -260 + static_cast<int>(rng->bounded(280)));
            particle.insert(QStringLiteral("spin"), -220 + static_cast<int>(rng->bounded(440)));
            particles.append(particle);

            if (particles.size() >= 9000) {
                return particles;
            }
        }
    }

    return particles;
}

void TodoApp::showEffectOverlay(const QString &mode, const QVariantList &particles, bool restoreListWindowOnClose)
{
    if (m_effectOverlayView) {
        qDebug() << "effects: show overlay skipped, already active" << mode;
        m_effectOverlayView->raise();
        return;
    }

    QScreen *screen = nullptr;
    if (m_listWindow) {
        screen = m_listWindow->screen();
    }
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }
    if (!screen) {
        qDebug() << "effects: no screen for overlay" << mode;
        return;
    }

    qDebug() << "effects: show overlay" << mode << "particles" << particles.size() << "screen" << screen->geometry();
    auto *view = new QQuickView;
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->setColor(Qt::transparent);
    view->setGeometry(screen->geometry());
    view->setFlags(Qt::Tool | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    view->rootContext()->setContextProperty(QStringLiteral("app"), this);
    view->setSource(QUrl(QStringLiteral("qrc:/EffectOverlayWindow.qml")));
    m_effectOverlayView = view;

    auto cleanedUp = std::make_shared<bool>(false);
    auto cleanupOverlay = [this, view, restoreListWindowOnClose, cleanedUp]() {
        if (*cleanedUp) {
            return;
        }
        *cleanedUp = true;
        if (m_effectOverlayView == view) {
            m_effectOverlayView = nullptr;
        }
        if (restoreListWindowOnClose && m_listWindow) {
            m_listWindow->show();
            m_listWindow->raise();
            m_listWindow->requestActivate();
        }
        view->deleteLater();
    };

    connect(view, &QWindow::visibleChanged, this, [cleanupOverlay](bool visible) {
        if (!visible) {
            cleanupOverlay();
        }
    });
    connect(view, &QObject::destroyed, this, [this, view]() {
        if (m_effectOverlayView == view) {
            m_effectOverlayView = nullptr;
        }
    });

    view->show();
    view->raise();

    if (QObject *rootObject = view->rootObject()) {
        const QVariant modeArg(mode);
        const QVariant particlesArg = QVariant::fromValue(particles);
        QMetaObject::invokeMethod(rootObject,
                                  "start",
                                  Qt::QueuedConnection,
                                  Q_ARG(QVariant, modeArg),
                                  Q_ARG(QVariant, particlesArg));
    }
}

void TodoApp::showAboutDialog()
{
    auto *dialog = new Dtk::Widget::DAboutDialog();
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    const QIcon icon = productIcon();
    dialog->setWindowIcon(icon);
    dialog->setProductIcon(aboutProductIcon());
    dialog->setProductName(QStringLiteral("小U待办"));
    dialog->setVersion(QStringLiteral("2.0.0"));
    dialog->setDescription(QStringLiteral("一个面向 deepin/UOS 桌面的轻量待办工具。"));
    dialog->setAcknowledgementVisible(false);
    dialog->setLicenseEnabled(false);
    dialog->show();
    QTimer::singleShot(0, dialog, [dialog]() {
        const QString descriptionText = QStringLiteral("一个面向 deepin/UOS 桌面的轻量待办工具。");
        QObject *versionObject = dialog->findChild<QObject *>(QStringLiteral("VersionLabel"));
        QWidget *versionLabel = qobject_cast<QWidget *>(versionObject);
        QWidget *contentWidget = versionLabel ? versionLabel->parentWidget() : nullptr;
        auto *contentLayout = contentWidget ? dynamic_cast<QBoxLayout *>(contentWidget->layout()) : nullptr;
        if (!versionLabel || !contentWidget || !contentLayout) {
            qWarning() << "Unable to add author field to about dialog";
            return;
        }

        auto directLayoutWidget = [contentWidget, contentLayout](QWidget *widget) -> QWidget * {
            for (QWidget *candidate = widget; candidate; candidate = candidate->parentWidget()) {
                if (candidate->parentWidget() == contentWidget && contentLayout->indexOf(candidate) >= 0) {
                    return candidate;
                }
            }
            return nullptr;
        };

        QLabel *descriptionLabel = qobject_cast<QLabel *>(dialog->findChild<QObject *>(QStringLiteral("DescriptionLabel")));
        if (!descriptionLabel) {
            const auto labels = contentWidget->findChildren<QLabel *>();
            for (QLabel *label : labels) {
                if (label->text() == descriptionText) {
                    descriptionLabel = label;
                    break;
                }
            }
        }

        QWidget *descriptionLayoutWidget = descriptionLabel ? directLayoutWidget(descriptionLabel) : nullptr;
        int insertIndex = descriptionLayoutWidget ? contentLayout->indexOf(descriptionLayoutWidget) + 1 : -1;
        if (insertIndex <= 0) {
            const int versionIndex = contentLayout->indexOf(versionLabel);
            if (versionIndex < 0) {
                qWarning() << "Unable to locate description or version field in about dialog";
                return;
            }
            insertIndex = versionIndex + 1;
        }

        QWidget *titleReference = insertIndex > 1 ? contentLayout->itemAt(insertIndex - 2)->widget() : nullptr;
        QWidget *valueReference = descriptionLabel ? static_cast<QWidget *>(descriptionLabel) : versionLabel;
        auto cloneAboutLabel = [contentWidget](const QString &text, QWidget *reference, const QString &objectName) {
            auto *label = new Dtk::Widget::DLabel(text, contentWidget);
            label->setObjectName(objectName);
            if (reference) {
                label->setFont(reference->font());
                label->setPalette(reference->palette());
                label->setSizePolicy(reference->sizePolicy());
                label->setContentsMargins(reference->contentsMargins());
                if (auto *referenceLabel = qobject_cast<QLabel *>(reference)) {
                    label->setAlignment(referenceLabel->alignment());
                    label->setWordWrap(referenceLabel->wordWrap());
                }
            }
            return label;
        };

        auto *authorTitle = cloneAboutLabel(QStringLiteral("作者"),
                                            titleReference,
                                            QStringLiteral("AuthorTitleLabel"));
        auto *authorLabel = cloneAboutLabel(QStringLiteral("黑桃老K"),
                                            valueReference,
                                            QStringLiteral("AuthorLabel"));

        contentLayout->insertSpacing(insertIndex, 10);
        ++insertIndex;
        contentLayout->insertWidget(insertIndex, authorTitle);
        contentLayout->insertWidget(insertIndex + 1, authorLabel);
    });
    dialog->raise();
    dialog->activateWindow();
}

QVariantMap TodoApp::cursorPosition() const
{
    const QPoint position = QCursor::pos();
    return QVariantMap{
        {QStringLiteral("x"), position.x()},
        {QStringLiteral("y"), position.y()}
    };
}

void TodoApp::scheduleNoteGeometrySave(const QString &noteId, QQuickView *view)
{
    if (noteId.isEmpty() || !view) {
        return;
    }

    QTimer *timer = m_noteGeometrySaveTimers.value(noteId);
    if (!timer) {
        QPointer<QQuickView> guardedView(view);
        timer = new QTimer(this);
        timer->setSingleShot(true);
        timer->setInterval(350);
        connect(timer, &QTimer::timeout, this, [this, noteId, guardedView]() {
            saveNoteGeometry(noteId, guardedView);
        });
        m_noteGeometrySaveTimers.insert(noteId, timer);
    }
    timer->start();
}

void TodoApp::saveNoteGeometry(const QString &noteId, const QQuickView *view)
{
    if (noteId.isEmpty() || !view) {
        return;
    }

    const QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return;
    }

    const QJsonObject currentSize = note.value(QStringLiteral("size")).toObject();
    const QJsonObject currentPosition = note.value(QStringLiteral("position")).toObject();
    if (currentSize.value(QStringLiteral("width")).toInt() == view->width()
        && currentSize.value(QStringLiteral("height")).toInt() == view->height()
        && currentPosition.value(QStringLiteral("x")).toInt() == view->x()
        && currentPosition.value(QStringLiteral("y")).toInt() == view->y()) {
        return;
    }

    QJsonObject patch;
    patch.insert(QStringLiteral("size"), QJsonObject{
        {QStringLiteral("width"), view->width()},
        {QStringLiteral("height"), view->height()}
    });
    patch.insert(QStringLiteral("position"), QJsonObject{
        {QStringLiteral("x"), view->x()},
        {QStringLiteral("y"), view->y()}
    });
    updateNote(noteId, patch);
}

// void TodoApp::showEventEditor(const QVariantMap &eventData)
// {
//     if (m_eventEditorView) {
//         m_eventEditorView->close();
//         m_eventEditorView->deleteLater();
//     }
//     m_eventEditorView = createView(QUrl(QStringLiteral("qrc:/EventEditorWindow.qml")), QSize(420, 500), QSize(380, 440), true, false);
//     auto *controller = new EventEditorController(this, eventData, m_eventEditorView);
//     m_eventEditorView->rootContext()->setContextProperty(QStringLiteral("eventEditor"), controller);
//     m_eventEditorView->rootContext()->setContextProperty(QStringLiteral("app"), this);
//     m_eventEditorView->setSource(QUrl(QStringLiteral("qrc:/EventEditorWindow.qml")));
//     connect(m_eventEditorView, &QObject::destroyed, this, [this]() { m_eventEditorView = nullptr; });
//     m_eventEditorView->show();
// }

void TodoApp::closeWindow(QWindow *window)
{
    if (window) {
        window->close();
    }
}

void TodoApp::updateSetting(const QString &key, const QVariant &value)
{
    if (key == QStringLiteral("mainWindowOpacity")) {
        m_settings.insert(QStringLiteral("mainWindowOpacityUserOverridden"), true);
    }
    m_settings.insert(key, QJsonValue::fromVariant(value));
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    if (key == QStringLiteral("theme")) {
        syncDtkPalette();
        applyMainWindowAppearanceDefaults();
    }
    saveSettings();
    emit settingsChanged();
    if (key == QStringLiteral("telemetryEnabled") && m_telemetry) {
        m_telemetry->setEnabled(value.toBool());
    }
    if (key == QStringLiteral("telemetryEndpoint") && m_telemetry) {
        m_telemetry->setEndpoint(QUrl(value.toString()));
    }
    if (key == QStringLiteral("mainWallpaperMode")
            || key == QStringLiteral("mainCustomWallpaperPath")
            || key == QStringLiteral("mainWindowOpacity")
            || key == QStringLiteral("mainRightPanelOpacity")) {
        refreshWallpaper();
    }
    trackTelemetry(QStringLiteral("setting_changed"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("settings"),
                   QJsonObject{{QStringLiteral("key"), key}});
}

QString TodoApp::exportData()
{
    const QString fileName = QFileDialog::getSaveFileName(nullptr, QStringLiteral("导出数据"),
        QDir::homePath() + QStringLiteral("/小U待办-") + QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")) + QStringLiteral(".json"),
        QStringLiteral("JSON 数据包 (*.json)"));
    if (fileName.isEmpty()) {
        return QStringLiteral("已取消导出");
    }

    QJsonObject bundle;
    bundle.insert(QStringLiteral("notes"), m_notes);
    QFile file(fileName);
    if (!file.open(QIODevice::WriteOnly)) {
        return QStringLiteral("导出失败");
    }
    file.write(QJsonDocument(bundle).toJson(QJsonDocument::Indented));
    trackTelemetry(QStringLiteral("data_exported"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("data"));
    return QStringLiteral("数据导出成功");
}

QString TodoApp::importData()
{
    const QString fileName = QFileDialog::getOpenFileName(nullptr, QStringLiteral("导入数据"), QDir::homePath(), QStringLiteral("JSON 数据包 (*.json)"));
    if (fileName.isEmpty()) {
        return QStringLiteral("已取消导入");
    }

    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        return QStringLiteral("导入失败");
    }
    const QJsonObject bundle = QJsonDocument::fromJson(file.readAll()).object();
    if (!bundle.contains(QStringLiteral("notes"))) {
        return QStringLiteral("数据包格式不正确");
    }
    m_notes = bundle.value(QStringLiteral("notes")).toArray();
    saveNotes();
    emit notesChanged();
    refreshNoteControllers();
    trackTelemetry(QStringLiteral("data_imported"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("data"),
                   QJsonObject{{QStringLiteral("noteCount"), m_notes.size()}});
    return QStringLiteral("数据导入成功");
}

QString TodoApp::openStoragePath()
{
    QDir().mkpath(m_dataDir);
    if (QDesktopServices::openUrl(QUrl::fromLocalFile(m_dataDir))) {
        return QStringLiteral("已打开存储路径");
    }
    return QStringLiteral("无法打开存储路径");
}

void TodoApp::setMainWallpaperMode(const QString &mode)
{
    const QString nextMode = mode == QStringLiteral("default") ? QStringLiteral("default") : QStringLiteral("system");
    m_settings.insert(QStringLiteral("mainWallpaperMode"), nextMode);
    m_settings.insert(QStringLiteral("mainWindowOpacityUserOverridden"), false);
    applyMainWindowAppearanceDefaults();
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    saveSettings();
    emit settingsChanged();
    refreshWallpaper();
    trackTelemetry(QStringLiteral("main_wallpaper_mode_changed"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("settings"),
                   QJsonObject{{QStringLiteral("mode"), nextMode}});
}

QString TodoApp::chooseMainWindowWallpaper()
{
    const QString fileName = QFileDialog::getOpenFileName(nullptr,
        QStringLiteral("选择主窗口背景壁纸"),
        QStandardPaths::writableLocation(QStandardPaths::PicturesLocation).isEmpty()
            ? QDir::homePath()
            : QStandardPaths::writableLocation(QStandardPaths::PicturesLocation),
        QStringLiteral("图片文件 (*.png *.jpg *.jpeg *.webp *.bmp)"));
    if (fileName.isEmpty()) {
        return QStringLiteral("已取消选择壁纸");
    }

    const QFileInfo sourceInfo(fileName);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        return QStringLiteral("壁纸文件不存在");
    }

    const QString wallpaperDir = QDir(m_dataDir).filePath(QStringLiteral("wallpapers"));
    QDir().mkpath(wallpaperDir);
    QString suffix = sourceInfo.suffix().toLower();
    if (suffix.isEmpty()) {
        suffix = QStringLiteral("jpg");
    }
    const QString targetPath = QDir(wallpaperDir).filePath(QStringLiteral("main-window-wallpaper.") + suffix);
    if (QFile::exists(targetPath) && !QFile::remove(targetPath)) {
        return QStringLiteral("无法替换已有壁纸");
    }
    if (!QFile::copy(fileName, targetPath)) {
        return QStringLiteral("壁纸复制失败");
    }

    m_settings.insert(QStringLiteral("mainWallpaperMode"), QStringLiteral("custom"));
    m_settings.insert(QStringLiteral("mainCustomWallpaperPath"), targetPath);
    m_settings.insert(QStringLiteral("mainWindowOpacityUserOverridden"), false);
    applyMainWindowAppearanceDefaults();
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    saveSettings();
    emit settingsChanged();
    refreshWallpaper();
    trackTelemetry(QStringLiteral("custom_wallpaper_changed"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("settings"));
    return QStringLiteral("主窗口背景已更新");
}

QString TodoApp::summarizeAllNotes()
{
    trackTelemetry(QStringLiteral("ai_summary_all"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("summary"),
                   QJsonObject{{QStringLiteral("noteCount"), m_notes.size()}});
    return sendPromptToUosAi(buildAllNotesSummaryPrompt());
}

QString TodoApp::summarizeNotesRange(const QString &scope)
{
    trackTelemetry(scope == QStringLiteral("month") ? QStringLiteral("ai_summary_month") : QStringLiteral("ai_summary_week"),
                   QStringLiteral("功能点击"),
                   QStringLiteral("summary"),
                   QJsonObject{{QStringLiteral("scope"), scope},
                               {QStringLiteral("noteCount"), m_notes.size()}});
    return sendPromptToUosAi(buildNotesRangeSummaryPrompt(scope));
}

QVariantMap TodoApp::eventById(const QString &eventId) const
{
    for (const QJsonValue &value : m_events) {
        const QJsonObject event = value.toObject();
        if (event.value(QStringLiteral("id")).toVariant().toString() == eventId) {
            return event.toVariantMap();
        }
    }
    return {};
}

void TodoApp::saveEvent(const QVariantMap &event)
{
    QJsonObject object = QJsonObject::fromVariantMap(event);
    if (object.value(QStringLiteral("id")).toVariant().toString().isEmpty()) {
        object.insert(QStringLiteral("id"), QString::number(QDateTime::currentMSecsSinceEpoch()));
        object.insert(QStringLiteral("createdDate"), isoNow());
    }
    object.insert(QStringLiteral("updatedDate"), isoNow());

    const QString id = object.value(QStringLiteral("id")).toVariant().toString();
    bool replaced = false;
    for (int i = 0; i < m_events.size(); ++i) {
        if (m_events.at(i).toObject().value(QStringLiteral("id")).toVariant().toString() == id) {
            m_events.replace(i, object);
            replaced = true;
            break;
        }
    }
    if (!replaced) {
        m_events.append(object);
    }
    saveEvents();
    emit eventsChanged();
}

void TodoApp::deleteEvent(const QString &eventId)
{
    for (int i = m_events.size() - 1; i >= 0; --i) {
        if (m_events.at(i).toObject().value(QStringLiteral("id")).toVariant().toString() == eventId) {
            m_events.removeAt(i);
        }
    }
    saveEvents();
    emit eventsChanged();
}

QQuickView *TodoApp::createView(const QUrl &, const QSize &size, const QSize &minSize, bool transparent, bool resizable)
{
    auto *view = new QQuickView;
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->resize(size);
    view->setMinimumSize(minSize);
    view->setIcon(productIcon());
    view->setColor(transparent ? Qt::transparent : QColor(40, 40, 40));
    view->setFlags(baseViewFlags(resizable));
    return view;
}

void TodoApp::publishWindowIcon(QWindow *window) const
{
    setProductIconOnWindow(window);
}

void TodoApp::scheduleWindowIconPublish(QWindow *window) const
{
    if (!window) {
        return;
    }
    publishWindowIcon(window);
    QPointer<QWindow> guardedWindow(window);
    QTimer::singleShot(0, window, [guardedWindow]() {
        setProductIconOnWindow(guardedWindow.data());
    });
    QTimer::singleShot(160, window, [guardedWindow]() {
        setProductIconOnWindow(guardedWindow.data());
    });
}

void TodoApp::createTray()
{
    m_tray = new QSystemTrayIcon(productIcon(), this);
    m_trayMenu = new QMenu;
    m_trayMenu->addAction(QStringLiteral("打开主窗口"), this, &TodoApp::showListWindow);
    m_trayMenu->addAction(QStringLiteral("新建桌面待办页"), this, [this]() {
        createNewNote();
    });
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(QStringLiteral("AI总结本周"), this, [this]() {
        const QString result = summarizeNotesRange(QStringLiteral("week"));
        if (m_tray) {
            m_tray->showMessage(QStringLiteral("小U待办"), result);
        }
    });
    m_trayMenu->addAction(QStringLiteral("AI总结本月"), this, [this]() {
        const QString result = summarizeNotesRange(QStringLiteral("month"));
        if (m_tray) {
            m_tray->showMessage(QStringLiteral("小U待办"), result);
        }
    });
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(QStringLiteral("反馈建议"), this, &TodoApp::showFeedbackDialog);
    m_trayMenu->addAction(QStringLiteral("设置"), this, &TodoApp::showSettingsWindow);
    m_trayMenu->addAction(QStringLiteral("退出"), qApp, &QApplication::quit);
    m_tray->setContextMenu(m_trayMenu);
    m_tray->setToolTip(QStringLiteral("小U待办"));
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger) {
            handleTrayTrigger();
        }
    });
    m_tray->show();
}

void TodoApp::handleTrayTrigger()
{
    QString latestVisibleNoteId;
    QString latestCreatedDate;
    for (const QJsonValue &value : m_notes) {
        const QJsonObject note = value.toObject();
        const QString noteId = note.value(QStringLiteral("id")).toVariant().toString();
        QQuickView *view = m_noteViews.value(noteId);
        if (!view || !view->isVisible()) {
            continue;
        }
        const QString createdDate = valueString(note, QStringLiteral("createdDate"));
        if (latestVisibleNoteId.isEmpty() || createdDate > latestCreatedDate) {
            latestVisibleNoteId = noteId;
            latestCreatedDate = createdDate;
        }
    }

    if (latestVisibleNoteId.isEmpty()) {
        createNewNote(true);
        return;
    }

    for (int i = 0; i < m_notes.size(); ++i) {
        QJsonObject note = m_notes.at(i).toObject();
        if (note.value(QStringLiteral("id")).toVariant().toString() != latestVisibleNoteId) {
            continue;
        }
        if (note.value(QStringLiteral("windowLayer")).toString() != QStringLiteral("normal")) {
            note.insert(QStringLiteral("windowLayer"), QStringLiteral("normal"));
            m_notes.replace(i, note);
            saveNotes();
            emit notesChanged();
            refreshNoteControllers(latestVisibleNoteId);
        }
        break;
    }

    applyNoteWindowLayer(latestVisibleNoteId, true);
}

void TodoApp::loadData()
{
    auto readArray = [](const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            return QJsonArray();
        }
        return QJsonDocument::fromJson(file.readAll()).array();
    };
    auto readObject = [](const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            return QJsonObject();
        }
        return QJsonDocument::fromJson(file.readAll()).object();
    };
    m_notes = readArray(dataFilePath(QStringLiteral("notes.json")));
    m_events = readArray(dataFilePath(QStringLiteral("events.json")));
    const QJsonObject savedSettings = readObject(dataFilePath(QStringLiteral("settings.json")));
    for (auto it = savedSettings.begin(); it != savedSettings.end(); ++it) {
        m_settings.insert(it.key(), it.value());
    }
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    upgradeDefaultSummaryTemplates();

    auto settingEquals = [this](const QString &key, double expected) {
        return std::abs(numberSetting(m_settings, key, -1.0) - expected) < 0.0005;
    };
    const QString wallpaperMode = mainWallpaperMode();
    if (wallpaperMode == QStringLiteral("default")) {
        const bool hasOldDefaultWallpaperValues =
            settingEquals(QStringLiteral("mainWindowOpacity"), 0.0)
            && settingEquals(QStringLiteral("mainRightPanelOpacity"), 0.0)
            && settingEquals(QStringLiteral("mainWallpaperBlur"), 0.75);
        if (hasOldDefaultWallpaperValues) {
            m_settings.insert(QStringLiteral("mainWindowOpacity"), DefaultWallpaperWindowOpacity);
            m_settings.insert(QStringLiteral("mainRightPanelOpacity"), DefaultWallpaperRightPanelOpacity);
            m_settings.insert(QStringLiteral("mainWallpaperBlur"), DefaultWallpaperBlur);
        }
    } else {
        const bool hasOldSystemWallpaperValues =
            settingEquals(QStringLiteral("mainWindowOpacity"), 0.30)
            && settingEquals(QStringLiteral("mainRightPanelOpacity"), 0.48)
            && settingEquals(QStringLiteral("mainWallpaperBlur"), 0.0);
        if (hasOldSystemWallpaperValues) {
            m_settings.insert(QStringLiteral("mainWindowOpacity"), SystemWallpaperWindowOpacity);
            m_settings.insert(QStringLiteral("mainRightPanelOpacity"), SystemWallpaperRightPanelOpacity);
            m_settings.insert(QStringLiteral("mainWallpaperBlur"), SystemWallpaperBlur);
        }
    }

    const int darkAppearanceVersion = m_settings.value(QStringLiteral("darkThemeMainAppearanceVersion")).toInt(0);
    if (effectiveDarkTheme() && darkAppearanceVersion < DarkThemeMainAppearanceVersion) {
        applyMainWindowAppearanceDefaults();
    }
}

void TodoApp::saveNotes() const
{
    QFile file(dataFilePath(QStringLiteral("notes.json")));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_notes).toJson(QJsonDocument::Indented));
    }
}

void TodoApp::saveEvents() const
{
    QFile file(dataFilePath(QStringLiteral("events.json")));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_events).toJson(QJsonDocument::Indented));
    }
}

void TodoApp::saveSettings() const
{
    QFile file(dataFilePath(QStringLiteral("settings.json")));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_settings).toJson(QJsonDocument::Indented));
    }
}

void TodoApp::ensureSeedData()
{
    if (!m_notes.isEmpty()) {
        return;
    }
    const QPoint pos = defaultNotePosition();
    QJsonArray todos;
    const QList<QPair<QString, QString>> tips = {
        {QStringLiteral("善用回车快速创建多个待办"), QStringLiteral("orange")},
        {QStringLiteral("鼠标悬浮待办可调整优先级"), QStringLiteral("blue")},
        {QStringLiteral("支持拖拽待办排序"), QStringLiteral("green")},
        {QStringLiteral("设置中支持多彩、简约模式"), QStringLiteral("gray")},
        {QStringLiteral("设置中支持黑色/白色卡片"), QStringLiteral("blue")},
        {QStringLiteral("设置中支持调节透明度"), QStringLiteral("gray")},
        {QStringLiteral("支持导入/导出，换机无忧"), QStringLiteral("green")},
        {QStringLiteral("! 待办支持钉在壁纸或强制置顶"), QStringLiteral("red")},
        {QStringLiteral("!  支持AI总结日报/周报/月报"), QStringLiteral("red")},
        {QStringLiteral("！设置中支持切换壁纸"), QStringLiteral("red")},
        {QStringLiteral("！支持一键同步到日历日程"), QStringLiteral("red")}
    };
    int i = 0;
    for (const auto &tip : tips) {
        todos.append(QJsonObject{
            {QStringLiteral("id"), QString::number(QDateTime::currentMSecsSinceEpoch() + i++)},
            {QStringLiteral("text"), tip.first},
            {QStringLiteral("completed"), false},
            {QStringLiteral("priority"), tip.second}
        });
    }
    m_notes.append(QJsonObject{
        {QStringLiteral("id"), QString::number(QDateTime::currentMSecsSinceEpoch())},
        {QStringLiteral("title"), QStringLiteral("待办使用技巧")},
        {QStringLiteral("todos"), todos},
        {QStringLiteral("position"), QJsonObject{{QStringLiteral("x"), pos.x()}, {QStringLiteral("y"), pos.y()}}},
        {QStringLiteral("size"), QJsonObject{{QStringLiteral("width"), 280}, {QStringLiteral("height"), 400}}},
        {QStringLiteral("visible"), true},
        {QStringLiteral("windowLayer"), QStringLiteral("normal")},
        {QStringLiteral("createdDate"), isoNow()},
        {QStringLiteral("updatedDate"), isoNow()}
    });
    saveNotes();
}

void TodoApp::refreshNoteControllers(const QString &noteId)
{
    for (auto it = m_noteControllers.begin(); it != m_noteControllers.end(); ++it) {
        if (!it.value()) {
            continue;
        }
        if (noteId.isEmpty() || it.key() == noteId) {
            it.value()->refresh();
        }
    }
}

void TodoApp::applyNoteWindowLayer(const QString &noteId, bool activate)
{
    QQuickView *view = m_noteViews.value(noteId);
    if (!view) {
        return;
    }

    const QString layer = noteWindowLayer(noteId);
    const QRect geometry(view->x(), view->y(), view->width(), view->height());
    const bool wasVisible = view->isVisible();
    const Qt::WindowFlags flags = noteViewFlags(layer, layer == QStringLiteral("top") && m_launcherVisible);
    if (view->flags() != flags) {
        view->setFlags(flags);
        view->setGeometry(geometry);
        if (wasVisible) {
            view->show();
            scheduleSkipTaskbarState(view);
        }
    } else if (wasVisible) {
        scheduleSkipTaskbarState(view);
    }

    if (!wasVisible) {
        return;
    }

    if (layer == QStringLiteral("bottom")) {
        view->lower();
        QTimer::singleShot(0, view, [view]() {
            if (view) {
                view->lower();
            }
        });
        QTimer::singleShot(120, view, [view]() {
            if (view) {
                view->lower();
            }
        });
        return;
    }

    if (activate) {
        view->raise();
        view->requestActivate();
    }
}

QString TodoApp::generateDefaultNoteTitle() const
{
    const QDate today = QDate::currentDate();
    const QString base = today.toString(QStringLiteral("yyyy/MM/dd")) + QStringLiteral("(周") + QStringLiteral("一二三四五六日").mid(today.dayOfWeek() - 1, 1) + QStringLiteral(")");
    auto exists = [this](const QString &title) {
        for (const QJsonValue &value : m_notes) {
            if (value.toObject().value(QStringLiteral("title")).toString() == title) {
                return true;
            }
        }
        return false;
    };
    if (!exists(base)) {
        return base;
    }
    for (int i = 1; i < 1000; ++i) {
        const QString title = QStringLiteral("%1 %2").arg(base).arg(i);
        if (!exists(title)) {
            return title;
        }
    }
    return base;
}

QPoint TodoApp::defaultNotePosition(int xOffset, int y) const
{
    if (QScreen *screen = QGuiApplication::primaryScreen()) {
        const QRect available = screen->availableGeometry();
        return QPoint(available.right() - 280 - xOffset, available.top() + y);
    }
    return QPoint(100, 100);
}

void TodoApp::showUosAiAssistant() const
{
    QDBusMessage launchMessage = QDBusMessage::createMethodCall(
        QStringLiteral("com.deepin.copilot"),
        QStringLiteral("/com/deepin/copilot"),
        QStringLiteral("com.deepin.copilot"),
        QStringLiteral("launchChatPage"));
    const QDBusMessage launchReply = QDBusConnection::sessionBus().call(
        launchMessage, QDBus::Block, 1500);

    if (launchReply.type() != QDBusMessage::ReplyMessage) {
        if (!QProcess::startDetached(QStringLiteral("/usr/bin/uos-ai-assistant"), {QStringLiteral("--chat")})) {
            QProcess::startDetached(QStringLiteral("gtk-launch"), {QStringLiteral("uos-ai-assistant")});
        }
    }

    const QString activateScript = QStringLiteral(
        "sleep 0.8; "
        "for i in 1 2 3 4 5 6 7 8 9 10; do "
        "for id in $(/usr/bin/xdotool search --class uos-ai-assistant 2>/dev/null); do "
        "eval $(/usr/bin/xdotool getwindowgeometry --shell \"$id\" 2>/dev/null); "
        "if [ ${WIDTH:-0} -gt 100 ] && [ ${HEIGHT:-0} -gt 100 ]; then "
        "/usr/bin/xdotool windowraise \"$id\" 2>/dev/null; "
        "/usr/bin/xdotool windowactivate \"$id\" 2>/dev/null; "
        "/usr/bin/xdotool windowfocus \"$id\" 2>/dev/null; "
        "exit 0; "
        "fi; "
        "done; "
        "sleep 0.2; "
        "done");
    QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), activateScript});
}

QString TodoApp::sendPromptToUosAi(const QString &prompt) const
{
    static bool promptDeliveryInProgress = false;
    if (promptDeliveryInProgress) {
        return QStringLiteral("正在发送到小U同学，请稍候");
    }
    QScopedValueRollback<bool> deliveryGuard(promptDeliveryInProgress, true);

    const QString truncated = prompt.size() > MaxPromptLength
        ? prompt.left(MaxPromptLength) + QStringLiteral("\n\n（内容较多，已自动截断，请基于以上内容总结。）")
        : prompt;

    bool assistantWasRunning = false;
    if (QDBusConnectionInterface *busInterface = QDBusConnection::sessionBus().interface()) {
        const QDBusReply<bool> registered = busInterface->isServiceRegistered(
            QStringLiteral("com.deepin.copilot"));
        assistantWasRunning = registered.isValid() && registered.value();
    }

    const auto sendThroughNativeInterface = [&truncated]() {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("com.deepin.copilot"),
            QStringLiteral("/org/deepin/copilot/chat"),
            QStringLiteral("org.deepin.copilot.chat"),
            QStringLiteral("dockInputPrompt"));
        message << truncated;

        const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, 3000);
        if (reply.type() == QDBusMessage::ReplyMessage) {
            return true;
        }

        qWarning() << "UOS AI native prompt interface unavailable:"
                   << reply.errorName() << reply.errorMessage();
        return false;
    };

    if (sendThroughNativeInterface()) {
        showUosAiAssistant();
        return QStringLiteral("已发送到 UOS AI 助手");
    }

    // UOS AI 3.0.1 advertises inputPrompt on D-Bus, but that method is a no-op.
    // Use the visible chat input as a compatibility path on the current X11 release.
    showUosAiAssistant();

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        return QStringLiteral("发送到小U同学失败，请稍后重试");
    }

    const QString previousClipboard = clipboard->text(QClipboard::Clipboard);
    clipboard->setText(truncated, QClipboard::Clipboard);

    const QString automationScript = QStringLiteral(
        "cold_start=%1; "
        "command -v xdotool >/dev/null 2>&1 || exit 2; "
        "for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do "
        "best_id=; best_area=0; best_x=0; best_y=0; best_w=0; best_h=0; "
        "for id in $(xdotool search --onlyvisible --class uos-ai-assistant 2>/dev/null); do "
        "eval $(xdotool getwindowgeometry --shell \"$id\" 2>/dev/null) || continue; "
        "area=$((WIDTH * HEIGHT)); "
        "if [ \"$WIDTH\" -ge 600 ] && [ \"$HEIGHT\" -ge 450 ] && [ \"$area\" -gt \"$best_area\" ]; then "
        "best_id=$id; best_area=$area; best_x=$X; best_y=$Y; best_w=$WIDTH; best_h=$HEIGHT; "
        "fi; "
        "done; "
        "if [ -n \"$best_id\" ]; then "
        "if [ \"$cold_start\" -eq 1 ]; then sleep 3.2; fi; "
        "eval $(xdotool getwindowgeometry --shell \"$best_id\" 2>/dev/null) || exit 4; "
        "best_x=$X; best_y=$Y; best_w=$WIDTH; best_h=$HEIGHT; "
        "xdotool windowraise \"$best_id\" windowactivate --sync \"$best_id\" 2>/dev/null || true; "
        "sleep 0.2; "
        "input_x=$((best_x + best_w / 2)); input_y=$((best_y + best_h - 105)); "
        "xdotool mousemove --sync \"$input_x\" \"$input_y\" click 1; "
        "sleep 0.15; "
        "xdotool key --clearmodifiers ctrl+a; "
        "xdotool key --clearmodifiers ctrl+v; "
        "sleep 0.2; "
        "xdotool key --clearmodifiers Return; "
        "sleep 0.4; "
        "exit 0; "
        "fi; "
        "sleep 0.25; "
        "done; "
        "exit 3").arg(assistantWasRunning ? 0 : 1);

    QProcess automation;
    QEventLoop waitLoop;
    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    QObject::connect(&automation,
                     qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
                     &waitLoop,
                     &QEventLoop::quit);
    QObject::connect(&timeoutTimer, &QTimer::timeout, &waitLoop, &QEventLoop::quit);
    automation.start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), automationScript});
    timeoutTimer.start(12000);
    waitLoop.exec();
    const bool finished = automation.state() == QProcess::NotRunning;
    const bool sent = finished
        && automation.exitStatus() == QProcess::NormalExit
        && automation.exitCode() == 0;

    if (clipboard->text(QClipboard::Clipboard) == truncated) {
        clipboard->setText(previousClipboard, QClipboard::Clipboard);
    }

    if (!sent) {
        if (!finished) {
            automation.kill();
            automation.waitForFinished(500);
        }
        qWarning() << "UOS AI compatibility prompt delivery failed:"
                   << automation.exitCode() << automation.errorString()
                   << automation.readAllStandardError();
        return QStringLiteral("发送到小U同学失败，请稍后重试");
    }

    qInfo() << "UOS AI compatibility prompt delivered through visible chat input";
    return QStringLiteral("已发送到 UOS AI 助手");
}

QString TodoApp::defaultNoteSummaryTemplate() const
{
    return QStringLiteral("请你作为我的工作助理，基于下面这个“今日待办”窗口生成一份概括型日报。\n\n"
                          "目标：输出结论和归纳，不要把待办逐条改写成流水账。请根据待办数据自行统计数量。\n\n"
                          "请按以下结构输出：\n"
                          "今日共执行 X 项任务，已完成 Y 项，未完成 Z 项。\n\n"
                          "已完成工作：\n"
                          "- 合并相近事项，用 2-5 条概括今天实际完成的工作。\n\n"
                          "未完成工作：\n"
                          "- 按优先级和影响归纳未完成事项；没有则写“暂无”。\n\n"
                          "明日建议：\n"
                          "- 优先推进高优先级、反复出现或临近截止的事项。\n"
                          "- 给出 1-3 条具体建议。\n\n"
                          "要求：只基于待办数据，不编造；合并同类项；语言简洁，避免空话。");
}

QString TodoApp::defaultWeekSummaryTemplate() const
{
    return QStringLiteral("请你作为我的工作助理，基于下面的小U待办数据生成一份概括型周报。\n\n"
                          "目标：按工作主题归纳，不要按日期逐条复述。请根据待办数据自行统计数量，并合并连续多天出现的同一件事。\n\n"
                          "请按以下结构输出：\n"
                          "本周共执行 X 项任务，已完成 Y 项，未完成 Z 项。\n\n"
                          "已完成工作：\n"
                          "- 合并同类事项，提炼 3-6 条本周完成的关键工作。\n\n"
                          "未完成工作：\n"
                          "- 按高优先级、阻塞延期、需要继续跟进分类概括；没有则写“暂无”。\n\n"
                          "本周观察：\n"
                          "- 概括本周工作重心、重复出现的问题或推进节奏。\n\n"
                          "建议下周：\n"
                          "- 优先完成高优先级和反复出现的未完成工作。\n"
                          "- 给出 2-4 条可执行建议。\n\n"
                          "要求：只基于待办数据，不编造；少写过程，多写结论；表达简洁清晰。");
}

QString TodoApp::defaultMonthSummaryTemplate() const
{
    return QStringLiteral("请你作为我的工作助理，基于下面的小U待办数据生成一份概括型月报。\n\n"
                          "目标：提炼本月工作成果、长期未完成事项和下月重点，不要输出流水账。请根据待办数据自行统计数量。\n\n"
                          "请按以下结构输出：\n"
                          "本月共执行 X 项任务，已完成 Y 项，未完成 Z 项。\n\n"
                          "本月完成：\n"
                          "- 按主题归并，提炼 4-8 条本月主要成果。\n\n"
                          "未完成/延期：\n"
                          "- 标出高优先级、长期停留或反复出现的事项；没有则写“暂无”。\n\n"
                          "本月重点观察：\n"
                          "- 概括本月工作重心、效率变化、风险和重复问题。\n\n"
                          "下月建议：\n"
                          "- 优先处理高优先级未完成事项，并给出 3-5 条具体推进建议。\n\n"
                          "要求：只基于待办数据，不编造；合并同类项；语言简洁，突出结论和行动。");
}

QString TodoApp::buildCurrentNoteSummaryPrompt(const QJsonObject &note) const
{
    QStringList lines;
    const QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
    lines << noteSummaryTemplate()
          << QString()
          << QStringLiteral("待办窗口标题：%1").arg(note.value(QStringLiteral("title")).toString(QStringLiteral("未命名待办")))
          << QStringLiteral("创建时间：%1").arg(formatDateTime(note.value(QStringLiteral("createdDate"))))
          << QStringLiteral("更新时间：%1").arg(formatDateTime(note.value(QStringLiteral("updatedDate"))))
          << QStringLiteral("完成进度：%1").arg(completionSummary(todos))
          << QString()
          << QStringLiteral("待办列表：");
    lines << todoLines(todos);
    return lines.join(QLatin1Char('\n'));
}

QString TodoApp::buildAllNotesSummaryPrompt() const
{
    const QDateTime now = QDateTime::currentDateTime();
    const int day = now.date().dayOfWeek();
    const QDateTime weekStart(QDate(now.date().year(), now.date().month(), now.date().day()).addDays(1 - day), QTime(0, 0));
    const QDateTime monthStart(QDate(now.date().year(), now.date().month(), 1), QTime(0, 0));

    auto inRange = [](const QJsonObject &note, const QDateTime &start) {
        const QDateTime dateTime = QDateTime::fromString(valueString(note, QStringLiteral("updatedDate"), valueString(note, QStringLiteral("createdDate"))), Qt::ISODate);
        return dateTime.isValid() && dateTime >= start;
    };
    auto appendNotes = [&inRange](QStringList &lines, const QJsonArray &notes, const QDateTime &start, const QString &emptyText) {
        int index = 1;
        for (const QJsonValue &value : notes) {
            const QJsonObject note = value.toObject();
            if (!inRange(note, start)) {
                continue;
            }
            const QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
            lines << QStringLiteral("%1. %2（更新：%3，完成：%4）")
                .arg(index++)
                .arg(note.value(QStringLiteral("title")).toString(QStringLiteral("未命名待办")))
                .arg(formatDateTime(note.value(QStringLiteral("updatedDate"))))
                .arg(completionSummary(todos));
            for (const QString &line : todoLines(todos)) {
                lines << QStringLiteral("   %1").arg(line);
            }
        }
        if (index == 1) {
            lines << emptyText;
        }
    };

    QStringList lines;
    lines << summaryTemplate(QStringLiteral("week"))
          << QString()
          << QStringLiteral("当前时间：%1").arg(now.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")))
          << QString()
          << QStringLiteral("【本周待办】");
    appendNotes(lines, m_notes, weekStart, QStringLiteral("本周暂无待办数据。"));
    lines << QString()
          << summaryTemplate(QStringLiteral("month"))
          << QString()
          << QStringLiteral("【本月待办】");
    appendNotes(lines, m_notes, monthStart, QStringLiteral("本月暂无待办数据。"));
    return lines.join(QLatin1Char('\n'));
}

QString TodoApp::buildNotesRangeSummaryPrompt(const QString &scope) const
{
    const QString normalizedScope = scope == QStringLiteral("month") ? QStringLiteral("month") : QStringLiteral("week");
    const QDate today = QDate::currentDate();
    const bool monthScope = normalizedScope == QStringLiteral("month");
    const QDate startDate = monthScope
        ? QDate(today.year(), today.month(), 1)
        : today.addDays(1 - today.dayOfWeek());
    const QDate exclusiveEndDate = monthScope ? startDate.addMonths(1) : startDate.addDays(7);
    const QDate endDate = exclusiveEndDate.addDays(-1);
    const QDateTime start(startDate, QTime(0, 0));
    const QDateTime exclusiveEnd(exclusiveEndDate, QTime(0, 0));
    const QString rangeName = monthScope ? QStringLiteral("本月") : QStringLiteral("本周");

    QStringList lines;
    lines << summaryTemplate(normalizedScope)
          << QString()
          << QStringLiteral("统计范围：%1（%2 至 %3，%4）")
                .arg(rangeName,
                     startDate.toString(QStringLiteral("yyyy-MM-dd")),
                     endDate.toString(QStringLiteral("yyyy-MM-dd")),
                     monthScope ? QStringLiteral("当月1日至当月最后一日") : QStringLiteral("周一到周日"))
          << QStringLiteral("当前时间：%1").arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")))
          << QString()
          << QStringLiteral("分析要求：")
          << QStringLiteral("- 总结%1做了什么，以及还有哪些没做完。").arg(rangeName)
          << QStringLiteral("- 如果同一件事连续几天出现，或标题/内容明显相近，请合并为同一事项分析，不要按日期重复罗列。")
          << QStringLiteral("- 只基于下面的数据分析，不要编造未出现的信息。")
          << QString()
          << QStringLiteral("待办窗口数据：");

    int index = 1;
    for (const QJsonValue &value : m_notes) {
        const QJsonObject note = value.toObject();
        const QString dateSource = valueString(note, QStringLiteral("updatedDate"), valueString(note, QStringLiteral("createdDate")));
        const QDateTime dateTime = QDateTime::fromString(dateSource, Qt::ISODate);
        if (!dateTime.isValid() || dateTime < start || dateTime >= exclusiveEnd) {
            continue;
        }

        const QJsonArray todos = note.value(QStringLiteral("todos")).toArray();
        lines << QStringLiteral("%1. %2（创建：%3，更新：%4，完成：%5）")
            .arg(index++)
            .arg(note.value(QStringLiteral("title")).toString(QStringLiteral("未命名待办")))
            .arg(formatDateTime(note.value(QStringLiteral("createdDate"))))
            .arg(formatDateTime(note.value(QStringLiteral("updatedDate"))))
            .arg(completionSummary(todos));
        for (const QString &line : todoLines(todos)) {
            lines << QStringLiteral("   %1").arg(line);
        }
    }

    if (index == 1) {
        lines << QStringLiteral("%1暂无待办数据。").arg(rangeName);
    }

    return lines.join(QLatin1Char('\n'));
}

QString TodoApp::dataFilePath(const QString &name) const
{
    return m_dataDir + QLatin1Char('/') + name;
}

QJsonArray TodoApp::sortedTodosForDisplay(const QJsonArray &todos) const
{
    QVector<QJsonObject> incomplete;
    QVector<QJsonObject> completed;
    for (const QJsonValue &value : todos) {
        const QJsonObject object = value.toObject();
        if (object.value(QStringLiteral("completed")).toBool(false)) {
            completed.append(object);
        } else {
            incomplete.append(object);
        }
    }
    QJsonArray result;
    for (const QJsonObject &object : incomplete) {
        result.append(object);
    }
    for (const QJsonObject &object : completed) {
        result.append(object);
    }
    return result;
}
