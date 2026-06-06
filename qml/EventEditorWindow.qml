import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root
    width: 420
    height: 500

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.noteTheme === "light"
    readonly property color windowColor: lightTheme ? Qt.rgba(0.94, 0.94, 0.94, 0.98) : Qt.rgba(0.16, 0.16, 0.16, 0.98)
    readonly property color textColor: lightTheme ? Qt.rgba(0, 0, 0, 0.86) : "white"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.48) : Qt.rgba(1, 1, 1, 0.48)

    function priorityColor(priority) {
        if (priority === "red") return "#ff5f57"
        if (priority === "orange") return "#ffbd2e"
        if (priority === "blue") return "#1d8cf8"
        if (priority === "green") return "#28c840"
        return "#8e8e93"
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.windowColor
        border.width: 1
        border.color: lightTheme ? Qt.rgba(0,0,0,0.10) : Qt.rgba(1,1,1,0.10)
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
                    text: eventEditor.editing ? "编辑日程" : "新建日程"
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
                    onClicked: eventEditor.close(root.hostWindow)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 14

                Label { text: "内容"; color: root.mutedColor; font.pixelSize: 13 }
                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: eventText
                        Layout.fillWidth: true
                        text: eventEditor.text
                        placeholderText: "请输入日程内容"
                        color: root.textColor
                        onTextChanged: eventEditor.text = text
                    }
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: root.priorityColor(eventEditor.priority)
                        MouseArea {
                            anchors.fill: parent
                            onClicked: priorityPopup.visible = !priorityPopup.visible
                        }
                    }
                }

                PriorityMenu {
                    id: priorityPopup
                    visible: false
                    currentPriority: eventEditor.priority
                    lightTheme: root.lightTheme
                    onPrioritySelected: {
                        eventEditor.priority = priority
                        visible = false
                    }
                }

                Label { text: "开始时间"; color: root.mutedColor; font.pixelSize: 13 }
                RowLayout {
                    Layout.fillWidth: true
                    TextField { Layout.fillWidth: true; text: eventEditor.date; placeholderText: "YYYY-MM-DD"; color: root.textColor; onEditingFinished: eventEditor.date = text }
                    TextField { Layout.preferredWidth: 92; text: eventEditor.startTime; placeholderText: "09:00"; color: root.textColor; onEditingFinished: eventEditor.startTime = text }
                }

                Label { text: "结束时间"; color: root.mutedColor; font.pixelSize: 13 }
                RowLayout {
                    Layout.fillWidth: true
                    TextField { Layout.fillWidth: true; text: eventEditor.endDate; placeholderText: "YYYY-MM-DD"; color: root.textColor; onEditingFinished: eventEditor.endDate = text }
                    TextField { Layout.preferredWidth: 92; text: eventEditor.endTime; placeholderText: "10:00"; color: root.textColor; onEditingFinished: eventEditor.endTime = text }
                }

                Label { text: "重复"; color: root.mutedColor; font.pixelSize: 13 }
                ComboBox {
                    id: repeatBox
                    Layout.fillWidth: true
                    model: ["不重复", "每天", "每周", "每月", "每年"]
                    currentIndex: ["none", "daily", "weekly", "monthly", "yearly"].indexOf(eventEditor.repeat)
                    onActivated: eventEditor.repeat = ["none", "daily", "weekly", "monthly", "yearly"][index]
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Button { Layout.fillWidth: true; text: "取消"; onClicked: eventEditor.close(root.hostWindow) }
                    Button { Layout.fillWidth: true; text: "删除"; visible: eventEditor.editing; onClicked: eventEditor.remove(root.hostWindow) }
                    Button { Layout.fillWidth: true; text: "保存"; onClicked: toast.show(eventEditor.save(root.hostWindow)) }
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
}
