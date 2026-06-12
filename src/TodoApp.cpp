#include "TodoApp.h"

// Calendar/event editor is parked for the current version.
// #include "EventEditorController.h"
#include "NoteController.h"

#include <QApplication>
#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QPainter>
#include <QPixmap>
#include <QProcess>
#include <QDebug>
#include <QQmlComponent>
#include <QQmlContext>
#include <QScreen>
#include <QSignalBlocker>
#include <QStandardPaths>
#include <QTimer>
#include <QWindow>
#include <DAboutDialog>
#include <DGuiApplicationHelper>

namespace {
constexpr int MaxNotes = 999;
constexpr int MaxPromptLength = 12000;

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

Qt::WindowFlags noteViewFlags(const QString &layer)
{
    Qt::WindowFlags flags = baseViewFlags(true);
    const QString normalized = normalizedWindowLayer(layer);
    if (normalized == QStringLiteral("bottom")) {
        flags |= Qt::WindowStaysOnBottomHint;
    } else if (normalized == QStringLiteral("top")) {
        flags |= Qt::WindowStaysOnTopHint;
    }
    return flags;
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
    const QPixmap source(QStringLiteral(":/assets/xiaou-todo-app-icon.png"));
    if (source.isNull()) {
        return QIcon(QStringLiteral(":/assets/xiaou-todo-app-icon.png"));
    }

    constexpr int canvasSize = 128;
    constexpr int visualSize = 112;
    QPixmap canvas(canvasSize, canvasSize);
    canvas.fill(Qt::transparent);

    QPainter painter(&canvas);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    const QRect target((canvasSize - visualSize) / 2,
                       (canvasSize - visualSize) / 2,
                       visualSize,
                       visualSize);
    painter.drawPixmap(target, source);

    return QIcon(canvas);
}

QString appDataDir()
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (documentsPath.isEmpty()) {
        documentsPath = QDir::homePath();
    }
    return QDir(documentsPath).filePath(QStringLiteral("小U待办"));
}

void migrateLegacyDataDir(const QString &targetDir)
{
    const QString legacyDir = QDir::homePath() + QStringLiteral("/.todo260606");
    if (!QDir(legacyDir).exists()) {
        return;
    }

    QDir().mkpath(targetDir);
    const QStringList dataFiles = {
        QStringLiteral("notes.json"),
        QStringLiteral("events.json"),
        QStringLiteral("settings.json")
    };
    for (const QString &fileName : dataFiles) {
        const QString source = QDir(legacyDir).filePath(fileName);
        const QString target = QDir(targetDir).filePath(fileName);
        if (QFile::exists(source) && !QFile::exists(target)) {
            QFile::copy(source, target);
        }
    }
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
    m_settings.insert(QStringLiteral("theme"), QStringLiteral("dark"));
    m_settings.insert(QStringLiteral("noteTheme"), QStringLiteral("dark"));
    m_settings.insert(QStringLiteral("priorityStyle"), QStringLiteral("colorful"));
    m_settings.insert(QStringLiteral("opacity"), 60);
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
}

TodoApp::~TodoApp()
{
    saveNotes();
    saveEvents();
    saveSettings();
}

void TodoApp::initialize()
{
    migrateLegacyDataDir(m_dataDir);
    QDir().mkpath(m_dataDir);
    loadData();
    connect(Dtk::Gui::DGuiApplicationHelper::instance(),
            &Dtk::Gui::DGuiApplicationHelper::paletteTypeChanged,
            this,
            &TodoApp::syncSettingFromDtkPalette,
            Qt::UniqueConnection);
    syncDtkPalette();
    ensureSeedData();
    createTray();

    if (!m_notes.isEmpty()) {
        QVector<QJsonObject> sorted;
        for (const QJsonValue &value : m_notes) {
            sorted.append(value.toObject());
        }
        std::sort(sorted.begin(), sorted.end(), [](const QJsonObject &a, const QJsonObject &b) {
            return valueString(a, QStringLiteral("updatedDate"), valueString(a, QStringLiteral("createdDate"))) >
                   valueString(b, QStringLiteral("updatedDate"), valueString(b, QStringLiteral("createdDate")));
        });
        openNote(sorted.first().value(QStringLiteral("id")).toVariant().toString());
    } else {
        createNewNote();
    }

    const QStringList args = QCoreApplication::arguments();
    QTimer::singleShot(0, this, [this, args]() {
        if (args.contains(QStringLiteral("--show-all"))) {
            showListWindow();
            // showCalendarWindow();
            showSettingsWindow();
            return;
        }
        if (args.contains(QStringLiteral("--list"))) {
            showListWindow();
        }
        // if (args.contains(QStringLiteral("--calendar"))) {
        //     showCalendarWindow();
        // }
        if (args.contains(QStringLiteral("--settings"))) {
            showSettingsWindow();
        }
    });
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

QString TodoApp::theme() const { return m_settings.value(QStringLiteral("theme")).toString(QStringLiteral("dark")); }
QString TodoApp::noteTheme() const { return m_settings.value(QStringLiteral("noteTheme")).toString(QStringLiteral("dark")); }
QString TodoApp::priorityStyle() const { return m_settings.value(QStringLiteral("priorityStyle")).toString(QStringLiteral("colorful")); }
int TodoApp::opacity() const { return m_settings.value(QStringLiteral("opacity")).toInt(60); }
QString TodoApp::storagePath() const { return m_dataDir; }

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

void TodoApp::syncSettingFromDtkPalette(Dtk::Gui::DGuiApplicationHelper::ColorType paletteType)
{
    if (m_syncingDtkPalette) {
        return;
    }

    QString nextTheme;
    switch (paletteType) {
    case Dtk::Gui::DGuiApplicationHelper::UnknownType:
        nextTheme = QStringLiteral("system");
        break;
    case Dtk::Gui::DGuiApplicationHelper::LightType:
        nextTheme = QStringLiteral("light");
        break;
    case Dtk::Gui::DGuiApplicationHelper::DarkType:
        nextTheme = QStringLiteral("dark");
        break;
    }

    if (nextTheme.isEmpty() || nextTheme == theme()) {
        return;
    }

    m_settings.insert(QStringLiteral("theme"), nextTheme);
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    saveSettings();
    emit settingsChanged();
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
    const QJsonObject note = noteById(noteId);
    if (note.isEmpty()) {
        return QStringLiteral("未找到待办窗口");
    }
    return sendPromptToUosAi(buildCurrentNoteSummaryPrompt(note));
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
        } else {
            todo.insert(QStringLiteral("text"), trimmed);
            todos.replace(i, todo);
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
        todo.insert(QStringLiteral("completed"), !todo.value(QStringLiteral("completed")).toBool(false));
        todos.replace(i, todo);
        updateNoteTodos(noteId, todos);
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
}

QString TodoApp::createNewNote()
{
    if (m_notes.size() >= MaxNotes) {
        return {};
    }

    const QString id = QString::number(QDateTime::currentMSecsSinceEpoch());
    const QPoint pos = defaultNotePosition(120, 100);
    QJsonObject note;
    note.insert(QStringLiteral("id"), id);
    note.insert(QStringLiteral("title"), generateDefaultNoteTitle());
    note.insert(QStringLiteral("todos"), QJsonArray());
    note.insert(QStringLiteral("position"), QJsonObject{{QStringLiteral("x"), pos.x()}, {QStringLiteral("y"), pos.y()}});
    note.insert(QStringLiteral("size"), QJsonObject{{QStringLiteral("width"), 280}, {QStringLiteral("height"), 400}});
    note.insert(QStringLiteral("visible"), true);
    note.insert(QStringLiteral("windowLayer"), QStringLiteral("normal"));
    note.insert(QStringLiteral("createdDate"), isoNow());
    note.insert(QStringLiteral("updatedDate"), isoNow());
    m_notes.append(note);
    saveNotes();
    emit notesChanged();
    openNote(id);
    return id;
}

void TodoApp::openNote(const QString &noteId)
{
    if (noteId.isEmpty()) {
        return;
    }
    if (m_noteViews.value(noteId)) {
        m_noteViews.value(noteId)->show();
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

    connect(view, &QQuickView::widthChanged, this, [this, noteId, view]() {
        QJsonObject patch;
        patch.insert(QStringLiteral("size"), QJsonObject{{QStringLiteral("width"), view->width()}, {QStringLiteral("height"), view->height()}});
        updateNote(noteId, patch);
    });
    connect(view, &QQuickView::heightChanged, this, [this, noteId, view]() {
        QJsonObject patch;
        patch.insert(QStringLiteral("size"), QJsonObject{{QStringLiteral("width"), view->width()}, {QStringLiteral("height"), view->height()}});
        updateNote(noteId, patch);
    });
    connect(view, &QQuickView::xChanged, this, [this, noteId, view]() {
        QJsonObject patch;
        patch.insert(QStringLiteral("position"), QJsonObject{{QStringLiteral("x"), view->x()}, {QStringLiteral("y"), view->y()}});
        updateNote(noteId, patch);
    });
    connect(view, &QQuickView::yChanged, this, [this, noteId, view]() {
        QJsonObject patch;
        patch.insert(QStringLiteral("position"), QJsonObject{{QStringLiteral("x"), view->x()}, {QStringLiteral("y"), view->y()}});
        updateNote(noteId, patch);
    });
    connect(view, &QObject::destroyed, this, [this, noteId]() {
        m_noteViews.remove(noteId);
        m_noteControllers.remove(noteId);
        emit notesChanged();
    });

    m_noteViews.insert(noteId, view);
    m_noteControllers.insert(noteId, controller);
    applyNoteWindowLayer(noteId, false);
    view->show();
    applyNoteWindowLayer(noteId, true);
    emit notesChanged();
}

void TodoApp::hideNote(const QString &noteId)
{
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
}

void TodoApp::showListWindow()
{
    if (m_listWindow) {
        m_listWindow->show();
        m_listWindow->raise();
        m_listWindow->requestActivate();
        return;
    }

    m_listEngine = new QQmlEngine(this);
    m_listEngine->rootContext()->setContextProperty(QStringLiteral("app"), this);
    QQmlComponent component(m_listEngine, QUrl(QStringLiteral("qrc:/ListWindow.qml")));
    QObject *object = component.create();
    if (!object) {
        qWarning() << component.errors();
        m_listEngine->deleteLater();
        m_listEngine = nullptr;
        return;
    }
    auto *window = qobject_cast<QWindow *>(object);
    if (!window) {
        qWarning() << "ListWindow root is not a QWindow";
        object->deleteLater();
        m_listEngine->deleteLater();
        m_listEngine = nullptr;
        return;
    }
    m_listWindow = window;
    connect(window, &QObject::destroyed, this, [this]() {
        m_listWindow = nullptr;
        if (m_listEngine) {
            m_listEngine->deleteLater();
            m_listEngine = nullptr;
        }
    });
    window->show();
    window->raise();
    window->requestActivate();
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
        return;
    }
    m_settingsView = createView(QUrl(QStringLiteral("qrc:/SettingsWindow.qml")), QSize(480, 430), QSize(420, 360), true, false);
    m_settingsView->rootContext()->setContextProperty(QStringLiteral("app"), this);
    m_settingsView->setSource(QUrl(QStringLiteral("qrc:/SettingsWindow.qml")));
    connect(m_settingsView, &QObject::destroyed, this, [this]() { m_settingsView = nullptr; });
    m_settingsView->show();
}

void TodoApp::showAboutDialog()
{
    auto *dialog = new Dtk::Widget::DAboutDialog();
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    const QIcon productIcon(QStringLiteral(":/assets/xiaou-todo-app-icon.png"));
    dialog->setWindowIcon(productIcon);
    dialog->setProductIcon(aboutProductIcon());
    dialog->setProductName(QStringLiteral("小U待办"));
    dialog->setVersion(QStringLiteral("1.0.0"));
    dialog->setDescription(QStringLiteral("一个面向 deepin/UOS 桌面的轻量待办工具。"));
    dialog->setLicenseEnabled(false);
    dialog->show();
    dialog->raise();
    dialog->activateWindow();
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
    m_settings.insert(key, QJsonValue::fromVariant(value));
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    if (key == QStringLiteral("theme")) {
        syncDtkPalette();
    }
    saveSettings();
    emit settingsChanged();
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
    bundle.insert(QStringLiteral("events"), m_events);
    bundle.insert(QStringLiteral("settings"), m_settings);
    QFile file(fileName);
    if (!file.open(QIODevice::WriteOnly)) {
        return QStringLiteral("导出失败");
    }
    file.write(QJsonDocument(bundle).toJson(QJsonDocument::Indented));
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
    m_events = bundle.value(QStringLiteral("events")).toArray();
    m_settings = bundle.value(QStringLiteral("settings")).toObject(m_settings);
    m_settings.insert(QStringLiteral("storagePath"), m_dataDir);
    syncDtkPalette();
    saveNotes();
    saveEvents();
    saveSettings();
    emit notesChanged();
    emit eventsChanged();
    emit settingsChanged();
    refreshNoteControllers();
    return QStringLiteral("数据导入成功");
}

QString TodoApp::summarizeAllNotes()
{
    return sendPromptToUosAi(buildAllNotesSummaryPrompt());
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
    view->setColor(transparent ? Qt::transparent : QColor(40, 40, 40));
    view->setFlags(baseViewFlags(resizable));
    return view;
}

void TodoApp::createTray()
{
    QPixmap pixmap(22, 22);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    QLinearGradient gradient(0, 0, 0, 22);
    gradient.setColorAt(0, QColor(255, 220, 100));
    gradient.setColorAt(1, QColor(255, 193, 77));
    painter.setBrush(gradient);
    painter.setPen(QPen(QColor(220, 170, 60), 1));
    painter.drawRoundedRect(QRectF(1, 1, 20, 20), 4, 4);
    painter.setPen(QPen(QColor(80, 60, 40), 2));
    painter.drawLine(6, 7, 16, 7);
    painter.drawLine(6, 11, 14, 11);
    painter.drawLine(6, 15, 17, 15);
    painter.end();

    m_tray = new QSystemTrayIcon(QIcon(pixmap), this);
    m_trayMenu = new QMenu;
    m_trayMenu->addAction(QStringLiteral("新建待办窗口"), this, &TodoApp::createNewNote);
    m_trayMenu->addAction(QStringLiteral("所有待办"), this, &TodoApp::showListWindow);
    // m_trayMenu->addAction(QStringLiteral("日历日程"), this, &TodoApp::showCalendarWindow);
    m_trayMenu->addAction(QStringLiteral("设置"), this, &TodoApp::showSettingsWindow);
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(QStringLiteral("退出"), qApp, &QApplication::quit);
    m_tray->setContextMenu(m_trayMenu);
    m_tray->setToolTip(QStringLiteral("小U待办"));
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger) {
            createNewNote();
        }
    });
    m_tray->show();
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
    const QStringList tips = {
        QStringLiteral("单击托盘图标新增待办窗口"),
        QStringLiteral("善用回车可快速创建多个待办"),
        QStringLiteral("鼠标悬浮待办可调整优先级"),
        QStringLiteral("支持拖拽待办排序"),
        QStringLiteral("设置中支持多彩、简约模式"),
        QStringLiteral("设置中支持黑色/白色卡片"),
        QStringLiteral("设置中支持调节透明度"),
        QStringLiteral("支持导入/导出，换机无忧")
    };
    int i = 0;
    for (const QString &tip : tips) {
        todos.append(QJsonObject{
            {QStringLiteral("id"), QString::number(QDateTime::currentMSecsSinceEpoch() + i++)},
            {QStringLiteral("text"), tip},
            {QStringLiteral("completed"), false},
            {QStringLiteral("priority"), i % 4 == 0 ? QStringLiteral("green") : i % 3 == 0 ? QStringLiteral("blue") : QStringLiteral("gray")}
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
    const Qt::WindowFlags flags = noteViewFlags(layer);
    if (view->flags() != flags) {
        view->setFlags(flags);
        view->setGeometry(geometry);
        if (wasVisible) {
            view->show();
        }
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

QString TodoApp::sendPromptToUosAi(const QString &prompt) const
{
    const QString truncated = prompt.size() > MaxPromptLength
        ? prompt.left(MaxPromptLength) + QStringLiteral("\n\n（内容较多，已自动截断，请基于以上内容总结。）")
        : prompt;

    QProcess process;
    process.start(QStringLiteral("dbus-send"), {
        QStringLiteral("--session"),
        QStringLiteral("--dest=com.deepin.copilot"),
        QStringLiteral("--print-reply"),
        QStringLiteral("/org/deepin/copilot/chat"),
        QStringLiteral("org.deepin.copilot.chat.dockInputPrompt"),
        QStringLiteral("string:%1").arg(truncated)
    });
    if (!process.waitForFinished(10000) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return QStringLiteral("发送到 UOS AI 助手失败，请确认 UOS AI 已启动");
    }
    return QStringLiteral("已发送到 UOS AI 助手");
}

QString TodoApp::defaultNoteSummaryTemplate() const
{
    return QStringLiteral("请你作为我的工作助理，总结下面这个“今日待办”窗口。\n\n"
                          "请按以下结构输出，语言简洁、具体，不要编造未出现的信息：\n"
                          "1. 今日重点\n"
                          "2. 已完成事项\n"
                          "3. 未完成事项\n"
                          "4. 下一步建议");
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
    lines << QStringLiteral("请你作为我的工作助理，基于下面的小U待办数据，总结本周和本月所有待办。")
          << QString()
          << QStringLiteral("请按以下结构输出，语言简洁、具体，不要编造未出现的信息：")
          << QStringLiteral("1. 本周总结")
          << QStringLiteral("2. 本月总结")
          << QStringLiteral("3. 未完成事项归纳")
          << QStringLiteral("4. 下周/后续行动建议")
          << QString()
          << QStringLiteral("当前时间：%1").arg(now.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")))
          << QString()
          << QStringLiteral("【本周待办】");
    appendNotes(lines, m_notes, weekStart, QStringLiteral("本周暂无待办数据。"));
    lines << QString() << QStringLiteral("【本月待办】");
    appendNotes(lines, m_notes, monthStart, QStringLiteral("本月暂无待办数据。"));
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
