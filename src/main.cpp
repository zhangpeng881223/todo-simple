#include "TodoApp.h"

#include <QApplication>
#include <QIcon>
#include <QIODevice>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQuickStyle>
#include <QSurfaceFormat>
#include <QTranslator>
#include <DApplication>
#include <DGuiApplicationHelper>
#include <DWindowManagerHelper>

namespace {
QString singleInstanceServerName()
{
    const QString user = qEnvironmentVariable("USER", "default");
    return QStringLiteral("xiaou-todo-single-instance-%1").arg(user);
}

QByteArray encodeArguments(const QStringList &arguments)
{
    QJsonArray array;
    for (const QString &argument : arguments) {
        array.append(argument);
    }
    return QJsonDocument(array).toJson(QJsonDocument::Compact);
}

QStringList decodeArguments(const QByteArray &payload)
{
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &error);
    if (error.error != QJsonParseError::NoError || !document.isArray()) {
        return QCoreApplication::arguments();
    }
    QStringList arguments;
    for (const QJsonValue &value : document.array()) {
        arguments.append(value.toString());
    }
    return arguments.isEmpty() ? QCoreApplication::arguments() : arguments;
}

bool notifyRunningInstance(const QString &serverName, const QStringList &arguments)
{
    QLocalSocket socket;
    socket.connectToServer(serverName, QIODevice::WriteOnly);
    if (!socket.waitForConnected(200)) {
        return false;
    }
    socket.write(encodeArguments(arguments));
    socket.flush();
    socket.waitForBytesWritten(300);
    socket.disconnectFromServer();
    return true;
}

QIcon productIcon()
{
    QIcon icon;
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-16.png"), QSize(16, 16));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-24.png"), QSize(24, 24));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-32.png"), QSize(32, 32));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-48.png"), QSize(48, 48));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-64.png"), QSize(64, 64));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-96.png"), QSize(96, 96));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-128.png"), QSize(128, 128));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-256.png"), QSize(256, 256));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-512.png"), QSize(512, 512));
    icon.addFile(QStringLiteral(":/assets/app-icons/xiaou-todo-1024.png"), QSize(1024, 1024));
    return icon;
}
}

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
    QApplication::setApplicationVersion(QStringLiteral("2.0.0"));
    QApplication::setOrganizationName(QStringLiteral("XiaoU"));
    QGuiApplication::setDesktopFileName(QStringLiteral("xiaou-todo"));

    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    Dtk::Widget::DApplication app(argc, argv);
    Dtk::Gui::DWindowManagerHelper::setWmClassName("xiaou-todo");
    app.setProductName(QStringLiteral("小U待办"));
    app.setWindowIcon(productIcon());
    auto *dtkWidgetTranslator = new QTranslator(&app);
    if (dtkWidgetTranslator->load(QStringLiteral("/usr/share/dtk6/DWidget/translations/dtkwidget_zh_CN.qm"))) {
        app.installTranslator(dtkWidgetTranslator);
    } else {
        delete dtkWidgetTranslator;
    }
    Dtk::Gui::DGuiApplicationHelper::loadTranslator();
    QQuickStyle::setStyle(QStringLiteral("Chameleon"));
    QApplication::setQuitOnLastWindowClosed(false);

    const QString serverName = singleInstanceServerName();
    const QStringList launchArguments = QCoreApplication::arguments();
    if (notifyRunningInstance(serverName, launchArguments)) {
        return 0;
    }

    QLocalServer::removeServer(serverName);
    QLocalServer singleInstanceServer;
    if (!singleInstanceServer.listen(serverName)) {
        qWarning() << "Failed to create single instance server:" << singleInstanceServer.errorString();
    }

    TodoApp todoApp;
    QObject::connect(&singleInstanceServer, &QLocalServer::newConnection, &todoApp, [&singleInstanceServer, &todoApp]() {
        while (QLocalSocket *client = singleInstanceServer.nextPendingConnection()) {
            if (client->bytesAvailable() == 0) {
                client->waitForReadyRead(100);
            }
            const QByteArray payload = client->readAll();
            if (!payload.isEmpty()) {
                todoApp.handleExternalLaunch(decodeArguments(payload));
            }
            client->disconnectFromServer();
            client->deleteLater();
        }
    });
    todoApp.initialize();

    return app.exec();
}
