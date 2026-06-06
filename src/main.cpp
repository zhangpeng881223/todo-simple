#include "TodoApp.h"

#include <QApplication>
#include <QQuickStyle>
#include <QSurfaceFormat>

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QApplication::setApplicationName(QStringLiteral("小U待办"));
    QApplication::setOrganizationName(QStringLiteral("Todo260606"));

    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    QApplication app(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QApplication::setQuitOnLastWindowClosed(false);

    TodoApp todoApp;
    todoApp.initialize();

    return app.exec();
}
