import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15 as QQC
import QtQuick.Layouts 1.15
import org.deepin.dtk 1.0 as D

Item {
    id: root
    width: 280
    height: 156

    readonly property var hostWindow: Window.window
    readonly property color panelColor: Qt.rgba(250 / 255, 252 / 255, 1, 0.96)
    readonly property color borderColor: Qt.rgba(0, 0, 0, 0.12)
    readonly property color textColor: "#242628"

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.panelColor
        border.width: 1
        border.color: root.borderColor
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 8

                D.Label {
                    Layout.fillWidth: true
                    text: "特效样张"
                    color: root.textColor
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }

                QQC.ToolButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    text: "×"
                    onClicked: if (root.hostWindow) root.hostWindow.close()
                    contentItem: D.Label {
                        text: "×"
                        color: "#697078"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                    }
                }
            }

            D.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                text: "全屏烟花"
                highlighted: true
                onClicked: app.triggerFireworksEffect()
            }

            D.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                text: "粉末消散"
                onClicked: app.triggerMainWindowPowderEffect()
            }
        }

        DragHandler {
            target: null
            acceptedButtons: Qt.LeftButton
            onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
        }
    }
}
