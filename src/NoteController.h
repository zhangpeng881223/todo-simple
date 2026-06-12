#pragma once

#include <QObject>
#include <QJsonArray>
#include <QVariantList>

class TodoApp;

class NoteController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString noteId READ noteId CONSTANT)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY noteChanged)
    Q_PROPERTY(QString createdDateText READ createdDateText NOTIFY noteChanged)
    Q_PROPERTY(QVariantList todos READ todos NOTIFY noteChanged)
    Q_PROPERTY(int completedCount READ completedCount NOTIFY noteChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY noteChanged)
    Q_PROPERTY(QString summaryTemplate READ summaryTemplate WRITE setSummaryTemplate NOTIFY summaryTemplateChanged)
    Q_PROPERTY(QString windowLayer READ windowLayer NOTIFY noteChanged)

public:
    NoteController(TodoApp *app, const QString &noteId, QObject *parent = nullptr);

    QString noteId() const;
    QString title() const;
    void setTitle(const QString &title);
    QString createdDateText() const;
    QVariantList todos() const;
    int completedCount() const;
    int totalCount() const;
    QString summaryTemplate() const;
    void setSummaryTemplate(const QString &summaryTemplate);
    QString windowLayer() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString addTodo(int afterIndex = -1);
    Q_INVOKABLE void updateTodoText(int index, const QString &text);
    Q_INVOKABLE void commitTodoText(int index, const QString &text);
    Q_INVOKABLE void toggleTodo(int index);
    Q_INVOKABLE void deleteTodo(int index);
    Q_INVOKABLE void setPriority(int index, const QString &priority);
    Q_INVOKABLE void moveTodo(int from, int to);
    Q_INVOKABLE void moveTodoById(const QString &todoId, int toDisplayIndex);
    Q_INVOKABLE void hide();
    Q_INVOKABLE QString summarizeToday();
    Q_INVOKABLE void resetSummaryTemplate();
    Q_INVOKABLE void cycleWindowLayer();

signals:
    void noteChanged();
    void summaryTemplateChanged();

private:
    QJsonObject note() const;
    QJsonArray todosArray() const;
    void saveTodos(const QJsonArray &todos);
    int actualIndexFromDisplayIndex(const QJsonArray &todos, int displayIndex) const;
    QString newTodoId() const;

    TodoApp *m_app = nullptr;
    QString m_noteId;
};
