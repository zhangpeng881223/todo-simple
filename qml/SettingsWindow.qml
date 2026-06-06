import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root
    width: 480
    height: 460

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.theme === "light"
    readonly property color windowColor: lightTheme ? Qt.rgba(1, 1, 1, 0.96) : Qt.rgba(0.16, 0.16, 0.16, 1)
    readonly property color textColor: lightTheme ? Qt.rgba(0, 0, 0, 0.86) : "white"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.48) : Qt.rgba(1, 1, 1, 0.48)
    readonly property color rowLine: lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.windowColor
        border.width: 1
        border.color: lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Layout.leftMargin: 16
                Layout.rightMargin: 10
                DragHandler {
                    target: null
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }
                Label {
                    text: "设置"
                    color: root.textColor
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                IconButton {
                    symbol: "×"
                    normalColor: root.mutedColor
                    hoverColor: "#ff5f57"
                    textSize: 24
                    onClicked: if (root.hostWindow) root.hostWindow.close()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.rowLine }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: content.implicitHeight + 32
                clip: true

                ColumnLayout {
                    id: content
                    width: parent.width
                    spacing: 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    y: 10

                    SettingRow {
                        title: "待办窗口颜色"
                        desc: "选择待办窗口的背景色"
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        lineColor: root.rowLine
                        control: ComboBox {
                            model: ["黑色", "白色"]
                            currentIndex: app.noteTheme === "light" ? 1 : 0
                            onActivated: {
                                app.updateSetting("noteTheme", index === 1 ? "light" : "dark")
                                toast.show("待办窗口颜色已更新")
                            }
                            width: 96
                        }
                    }

                    SettingRow {
                        title: "待办窗口透明度"
                        desc: "调整待办窗口透明度"
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        lineColor: root.rowLine
                        control: Row {
                            spacing: 10
                            Slider {
                                width: 150
                                from: 0
                                to: 100
                                value: app.opacity
                                onMoved: app.updateSetting("opacity", Math.round(value))
                            }
                            Label {
                                width: 42
                                text: app.opacity + "%"
                                color: root.textColor
                                font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    SettingRow {
                        title: "优先级样式"
                        desc: "选择待办事项优先级显示样式"
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        lineColor: root.rowLine
                        control: ComboBox {
                            model: ["多彩", "简约"]
                            currentIndex: app.priorityStyle === "simple" ? 1 : 0
                            onActivated: {
                                app.updateSetting("priorityStyle", index === 1 ? "simple" : "colorful")
                                toast.show("设置已保存")
                            }
                            width: 96
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 8
                        Label {
                            text: "数据存储"
                            color: root.mutedColor
                            font.pixelSize: 13
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: app.storagePath
                            readOnly: true
                            color: root.textColor
                            background: Rectangle {
                                radius: 6
                                color: root.lightTheme ? Qt.rgba(0,0,0,0.05) : Qt.rgba(1,1,1,0.10)
                                border.width: 1
                                border.color: root.lightTheme ? Qt.rgba(0,0,0,0.10) : Qt.rgba(1,1,1,0.10)
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Button {
                                Layout.fillWidth: true
                                text: "导出数据"
                                onClicked: toast.show(app.exportData())
                            }
                            Button {
                                Layout.fillWidth: true
                                text: "导入数据"
                                onClicked: toast.show(app.importData())
                            }
                        }
                        Label {
                            text: "导出所有待办事项，可在新电脑上导入恢复"
                            color: root.mutedColor
                            font.pixelSize: 11
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 24
                        spacing: 8
                        Label { text: "作者：布球人-黑桃老K"; color: root.mutedColor; font.pixelSize: 13 }
                        Label { text: "版本号：V1.0.0 / Qt+QML"; color: root.mutedColor; font.pixelSize: 13 }
                    }
                }
            }
        }
    }

    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: message.length > 0 ? 18 : -60
        lightTheme: root.lightTheme
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    component SettingRow: Item {
        property string title
        property string desc
        property color textColor
        property color mutedColor
        property color lineColor
        property Component control

        Layout.fillWidth: true
        Layout.preferredHeight: 66

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Label { text: title; color: textColor; font.pixelSize: 13 }
            Label { text: desc; color: mutedColor; font.pixelSize: 11 }
        }

        Loader {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: control
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: lineColor
        }
    }
}
