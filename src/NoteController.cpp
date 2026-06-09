#include "NoteController.h"

#include "TodoApp.h"

#include <QDateTime>
#include <QJsonObject>

NoteController::NoteController(TodoApp *app, const QString &noteId, QObject *parent)
    : QObject(parent)
    , m_app(app)
    , m_noteId(noteId)
{
}

QString NoteController::noteId() const
{
    return m_noteId;
}

QString NoteController::title() const
{
    return note().value(QStringLiteral("title")).toString();
}

void NoteController::setTitle(const QString &title)
{
    QJsonObject patch;
    patch.insert(QStringLiteral("title"), title.trimmed().isEmpty() ? QStringLiteral("未命名待办") : title.trimmed());
    m_app->updateNote(m_noteId, patch);
    emit noteChanged();
}

QString NoteController::createdDateText() const
{
    const QDateTime created = QDateTime::fromString(note().value(QStringLiteral("createdDate")).toString(), Qt::ISODate);
    return created.isValid() ? created.date().toString(QStringLiteral("yyyy/M/d")) : QString();
}

QVariantList NoteController::todos() const
{
    QVariantList list;
    const QJsonArray sorted = m_app->sortedTodosForDisplay(note().value(QStringLiteral("todos")).toArray());
    for (const QJsonValue &value : sorted) {
        const QJsonObject object = value.toObject();
        QVariantMap item;
        item.insert(QStringLiteral("id"), object.value(QStringLiteral("id")).toVariant().toString());
        item.insert(QStringLiteral("text"), object.value(QStringLiteral("text")).toString());
        item.insert(QStringLiteral("completed"), object.value(QStringLiteral("completed")).toBool(false));
        item.insert(QStringLiteral("priority"), object.value(QStringLiteral("priority")).toString(QStringLiteral("gray")));
        list.append(item);
    }
    return list;
}

int NoteController::completedCount() const
{
    int count = 0;
    for (const QJsonValue &value : todosArray()) {
        if (value.toObject().value(QStringLiteral("completed")).toBool(false)) {
            ++count;
        }
    }
    return count;
}

int NoteController::totalCount() const
{
    return todosArray().size();
}

QString NoteController::summaryTemplate() const
{
    return m_app->noteSummaryTemplate();
}

void NoteController::setSummaryTemplate(const QString &summaryTemplate)
{
    m_app->setNoteSummaryTemplate(summaryTemplate);
    emit summaryTemplateChanged();
}

void NoteController::refresh()
{
    emit noteChanged();
    emit summaryTemplateChanged();
}

QString NoteController::addTodo(int afterIndex)
{
    QJsonArray todos = todosArray();
    const QString id = newTodoId();
    QJsonObject item;
    item.insert(QStringLiteral("id"), id);
    item.insert(QStringLiteral("text"), QString());
    item.insert(QStringLiteral("completed"), false);
    item.insert(QStringLiteral("priority"), QStringLiteral("gray"));

    const int insertAt = afterIndex >= 0 ? qMin(actualIndexFromDisplayIndex(todos, afterIndex) + 1, todos.size()) : todos.size();
    todos.insert(insertAt, item);
    saveTodos(todos);
    return id;
}

void NoteController::updateTodoText(int index, const QString &text)
{
    QJsonArray todos = todosArray();
    const int actualIndex = actualIndexFromDisplayIndex(todos, index);
    if (actualIndex < 0) {
        return;
    }

    QJsonObject item = todos.at(actualIndex).toObject();
    item.insert(QStringLiteral("text"), text);
    todos.replace(actualIndex, item);
    saveTodos(todos);
}

void NoteController::commitTodoText(int index, const QString &text)
{
    QJsonArray todos = todosArray();
    const int actualIndex = actualIndexFromDisplayIndex(todos, index);
    if (actualIndex < 0) {
        return;
    }

    if (text.trimmed().isEmpty()) {
        todos.removeAt(actualIndex);
    } else {
        QJsonObject item = todos.at(actualIndex).toObject();
        item.insert(QStringLiteral("text"), text.trimmed());
        todos.replace(actualIndex, item);
    }
    saveTodos(todos);
}

void NoteController::toggleTodo(int index)
{
    QJsonArray todos = todosArray();
    const int actualIndex = actualIndexFromDisplayIndex(todos, index);
    if (actualIndex < 0) {
        return;
    }

    QJsonObject item = todos.at(actualIndex).toObject();
    item.insert(QStringLiteral("completed"), !item.value(QStringLiteral("completed")).toBool(false));
    todos.replace(actualIndex, item);
    saveTodos(todos);
}

void NoteController::deleteTodo(int index)
{
    QJsonArray todos = todosArray();
    const int actualIndex = actualIndexFromDisplayIndex(todos, index);
    if (actualIndex < 0) {
        return;
    }
    todos.removeAt(actualIndex);
    saveTodos(todos);
}

void NoteController::setPriority(int index, const QString &priority)
{
    QJsonArray todos = todosArray();
    const int actualIndex = actualIndexFromDisplayIndex(todos, index);
    if (actualIndex < 0) {
        return;
    }
    QJsonObject item = todos.at(actualIndex).toObject();
    item.insert(QStringLiteral("priority"), priority);
    todos.replace(actualIndex, item);
    saveTodos(todos);
}

void NoteController::moveTodo(int from, int to)
{
    QJsonArray displayTodos = m_app->sortedTodosForDisplay(todosArray());
    if (from < 0 || from >= displayTodos.size() || to < 0 || to >= displayTodos.size() || from == to) {
        return;
    }
    QJsonArray next;
    QVector<QJsonObject> objects;
    for (const QJsonValue &value : displayTodos) {
        objects.append(value.toObject());
    }
    objects.move(from, to);
    for (const QJsonObject &object : objects) {
        next.append(object);
    }
    saveTodos(next);
}

void NoteController::moveTodoById(const QString &todoId, int toDisplayIndex)
{
    QJsonArray displayTodos = m_app->sortedTodosForDisplay(todosArray());
    if (todoId.isEmpty() || displayTodos.isEmpty()) {
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
    saveTodos(next);
}

void NoteController::hide()
{
    m_app->hideNote(m_noteId);
}

QString NoteController::summarizeToday()
{
    return m_app->summarizeNote(m_noteId);
}

void NoteController::resetSummaryTemplate()
{
    m_app->setNoteSummaryTemplate(QString());
    emit summaryTemplateChanged();
}

QJsonObject NoteController::note() const
{
    return m_app->noteById(m_noteId);
}

QJsonArray NoteController::todosArray() const
{
    return note().value(QStringLiteral("todos")).toArray();
}

void NoteController::saveTodos(const QJsonArray &todos)
{
    m_app->updateNoteTodos(m_noteId, todos);
    emit noteChanged();
}

int NoteController::actualIndexFromDisplayIndex(const QJsonArray &todos, int displayIndex) const
{
    const QJsonArray sorted = m_app->sortedTodosForDisplay(todos);
    if (displayIndex < 0 || displayIndex >= sorted.size()) {
        return -1;
    }

    const QString targetId = sorted.at(displayIndex).toObject().value(QStringLiteral("id")).toVariant().toString();
    for (int i = 0; i < todos.size(); ++i) {
        if (todos.at(i).toObject().value(QStringLiteral("id")).toVariant().toString() == targetId) {
            return i;
        }
    }
    return -1;
}

QString NoteController::newTodoId() const
{
    return QString::number(QDateTime::currentMSecsSinceEpoch());
}
