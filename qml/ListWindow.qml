import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root
    width: 400
    height: 500

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.theme === "light"
    readonly property color windowColor: lightTheme ? Qt.rgba(1, 1, 1, 0.96) : Qt.rgba(0.16, 0.16, 0.16, 1)
    readonly property color textColor: lightTheme ? Qt.rgba(0, 0, 0, 0.86) : "white"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.48) : Qt.rgba(1, 1, 1, 0.48)
    property string searchTerm: ""

    function noteMatches(note) {
        if (searchTerm.length === 0) return true
        var term = searchTerm.toLowerCase()
        if ((note.title || "").toLowerCase().indexOf(term) >= 0) return true
        var todos = note.todos || []
        for (var i = 0; i < todos.length; i++) {
            if ((todos[i].text || "").toLowerCase().indexOf(term) >= 0) return true
        }
        return false
    }

    function matchedCount() {
        var count = 0
        var notes = app.notesList
        for (var i = 0; i < notes.length; i++) {
            if (noteMatches(notes[i])) count++
        }
        return count
    }

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
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                spacing: 2

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }

                Label {
                    text: "所有待办（" + matchedCount() + "）"
                    color: root.textColor
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                IconButton {
                    symbol: "✦"
                    tooltip: "总结本周/本月所有待办"
                    normalColor: root.mutedColor
                    hoverColor: "#9c27b0"
                    textSize: 18
                    onClicked: toast.show(app.summarizeAllNotes())
                }

                IconButton {
                    symbol: "+"
                    tooltip: "新建待办窗口"
                    normalColor: root.mutedColor
                    hoverColor: "#28c840"
                    textSize: 24
                    onClicked: app.createNewNote()
                }

                IconButton {
                    symbol: "×"
                    tooltip: "关闭"
                    normalColor: root.mutedColor
                    hoverColor: "#ff5f57"
                    textSize: 24
                    onClicked: if (root.hostWindow) root.hostWindow.close()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: lightTheme ? Qt.rgba(0,0,0,0.08) : Qt.rgba(1,1,1,0.08) }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 14
                spacing: 10

                TextField {
                    id: searchBox
                    Layout.fillWidth: true
                    height: 34
                    placeholderText: "搜索待办..."
                    text: root.searchTerm
                    onTextChanged: root.searchTerm = text
                    color: root.textColor
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 6
                        color: root.lightTheme ? Qt.rgba(0,0,0,0.05) : Qt.rgba(1,1,1,0.10)
                        border.width: 1
                        border.color: searchBox.activeFocus ? Qt.rgba(29,140,248,0.6) : (root.lightTheme ? Qt.rgba(0,0,0,0.10) : Qt.rgba(1,1,1,0.10))
                    }
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: notesColumn.implicitHeight

                    Column {
                        id: notesColumn
                        width: flick.width
                        spacing: 0

                        Repeater {
                            model: app.notesList
                            delegate: Item {
                                id: noteRow
                                width: notesColumn.width
                                height: root.noteMatches(modelData) ? Math.max(74, 62 + matchedTodos.height) : 0
                                visible: root.noteMatches(modelData)
                                clip: true

                                property bool confirmingDelete: false

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: openMouse.containsMouse ? (root.lightTheme ? Qt.rgba(0,0,0,0.035) : Qt.rgba(1,1,1,0.035)) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 38
                                    spacing: 4

                                    Label {
                                        width: parent.width
                                        text: modelData.title || "无标题"
                                        color: root.textColor
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                    }

                                    Column {
                                        id: matchedTodos
                                        width: parent.width
                                        spacing: 2
                                        visible: root.searchTerm.length > 0
                                        Repeater {
                                            model: modelData.todos || []
                                            delegate: Label {
                                                width: matchedTodos.width
                                                visible: (modelData.text || "").toLowerCase().indexOf(root.searchTerm.toLowerCase()) >= 0
                                                height: visible ? implicitHeight : 0
                                                text: (modelData.completed ? "✓ " : "□ ") + modelData.text
                                                color: modelData.completed ? root.mutedColor : root.textColor
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Row {
                                        spacing: 14
                                        Label {
                                            text: modelData.completed + "/" + modelData.total + " 完成"
                                            color: root.mutedColor
                                            font.pixelSize: 11
                                        }
                                        Label {
                                            text: modelData.dateText || ""
                                            color: root.mutedColor
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: noteRow.confirmingDelete ? "删除" : "×"
                                    color: noteRow.confirmingDelete ? "#ff5f57" : root.mutedColor
                                    font.pixelSize: noteRow.confirmingDelete ? 12 : 18
                                    opacity: openMouse.containsMouse || noteRow.confirmingDelete ? 1 : 0
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        onClicked: {
                                            if (noteRow.confirmingDelete) {
                                                app.deleteNote(modelData.id)
                                            } else {
                                                noteRow.confirmingDelete = true
                                                deleteTimer.restart()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: root.lightTheme ? Qt.rgba(0,0,0,0.08) : Qt.rgba(1,1,1,0.08)
                                }

                                MouseArea {
                                    id: openMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: app.openNote(modelData.id)
                                }

                                Timer {
                                    id: deleteTimer
                                    interval: 3000
                                    onTriggered: noteRow.confirmingDelete = false
                                }
                            }
                        }

                        Label {
                            width: notesColumn.width
                            height: matchedCount() === 0 ? 90 : 0
                            visible: matchedCount() === 0
                            text: "暂无待办窗口，点击上方 + 按钮或右键托盘新建待办窗口"
                            color: root.mutedColor
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }
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
