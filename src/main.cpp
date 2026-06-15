#include "TodoApp.h"

#include <QApplication>
#include <QIcon>
#include <QQuickStyle>
#include <QSurfaceFormat>
#include <QTranslator>
#include <DApplication>
#include <DGuiApplicationHelper>
#include <DWindowManagerHelper>

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "dxcb:xcb");
    }
    if (qEnvironmentVariableIsEmpty("QT_IM_MODULE")) {
        qputenv("QT_IM_MODULE", "fcitx");
    }
    if (qEnvironmentVariableIsEmpty("XMODIFIERS")) {
        qputenv("XMODIFIERS", "@im=fcitx");
    }
    if (qEnvironmentVariableIsEmpty("GTK_IM_MODULE")) {
        qputenv("GTK_IM_MODULE", "fcitx");
    }
    if (qEnvironmentVariableIsEmpty("QSG_RENDER_LOOP")) {
        qputenv("QSG_RENDER_LOOP", "basic");
    }

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QApplication::setApplicationName(QStringLiteral("小U待办"));
    QApplication::setOrganizationName(QStringLiteral("Todo260606"));
    QGuiApplication::setDesktopFileName(QStringLiteral("todo260606"));

    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    Dtk::Widget::DApplication app(argc, argv);
    Dtk::Gui::DWindowManagerHelper::setWmClassName("todo260606");
    app.setProductName(QStringLiteral("小U待办"));
    app.setWindowIcon(QIcon(QStringLiteral(":/assets/xiaou-todo-app-icon.png")));
    auto *dtkWidgetTranslator = new QTranslator(&app);
    if (dtkWidgetTranslator->load(QStringLiteral("/usr/share/dtk6/DWidget/translations/dtkwidget_zh_CN.qm"))) {
        app.installTranslator(dtkWidgetTranslator);
    } else {
        delete dtkWidgetTranslator;
    }
    Dtk::Gui::DGuiApplicationHelper::loadTranslator();
    QQuickStyle::setStyle(QStringLiteral("Chameleon"));
    QApplication::setQuitOnLastWindowClosed(false);

    TodoApp todoApp;
    todoApp.initialize();

    return app.exec();
}
