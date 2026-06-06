import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root
    width: 900
    height: 600

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.noteTheme === "light"
    readonly property real bgOpacity: Math.max(0, Math.min(100, app.opacity)) / 100
    readonly property color windowColor: lightTheme ? Qt.rgba(0.94, 0.94, 0.94, bgOpacity) : Qt.rgba(0.16, 0.16, 0.16, bgOpacity)
    readonly property color textColor: lightTheme ? Qt.rgba(0, 0, 0, 0.86) : "white"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.48) : Qt.rgba(1, 1, 1, 0.48)
    readonly property color lineColor: lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.07)
    property int weekOffset: 0

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function dateStr(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function weekStart() {
        var d = new Date()
        var day = d.getDay()
        if (day === 0) day = 7
        d.setDate(d.getDate() - day + 1 + weekOffset * 7)
        d.setHours(0,0,0,0)
        return d
    }
    function dayData(index) {
        var d = weekStart()
        d.setDate(d.getDate() + index)
        var today = new Date()
        return { date: d, dateText: dateStr(d), dayName: ["一","二","三","四","五","六","日"][index], today: dateStr(d) === dateStr(today) }
    }
    function monthTitle() {
        var d = weekStart()
        return d.getFullYear() + "年" + (d.getMonth() + 1) + "月"
    }
    function priorityColor(priority) {
        if (priority === "red") return "#ff5f57"
        if (priority === "orange") return "#ffbd2e"
        if (priority === "blue") return "#1d8cf8"
        if (priority === "green") return "#28c840"
        return "#8e8e93"
    }
    function eventTop(event) {
        var p = (event.startTime || "09:00").split(":")
        return (parseInt(p[0]) + parseInt(p[1]) / 60) * 45
    }
    function eventHeight(event) {
        var s = (event.startTime || "09:00").split(":")
        var e = (event.endTime || "10:00").split(":")
        var hours = (parseInt(e[0]) + parseInt(e[1]) / 60) - (parseInt(s[0]) + parseInt(s[1]) / 60)
        return Math.max(24, hours * 45)
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
                Layout.preferredHeight: 58
                Layout.leftMargin: 16
                Layout.rightMargin: 10
                spacing: 8

                DragHandler {
                    target: null
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }

                Label {
                    text: root.monthTitle()
                    color: root.textColor
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Button { text: "<"; onClicked: root.weekOffset-- }
                Button { text: ">"; onClicked: root.weekOffset++ }
                Button { text: "今天"; onClicked: { root.weekOffset = 0; toast.show("已回到今天") } }
                Item { Layout.fillWidth: true }
                IconButton {
                    symbol: "+"
                    normalColor: root.mutedColor
                    hoverColor: "#28c840"
                    textSize: 24
                    onClicked: app.showEventEditor({ date: root.dateStr(new Date()), startTime: "09:00", endTime: "10:00" })
                }
                IconButton {
                    symbol: "×"
                    normalColor: root.mutedColor
                    hoverColor: "#ff5f57"
                    textSize: 24
                    onClicked: if (root.hostWindow) root.hostWindow.close()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                columns: 8
                columnSpacing: 0
                rowSpacing: 0

                Item { Layout.preferredWidth: 64; Layout.fillHeight: true }
                Repeater {
                    model: 7
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: root.dayData(index).today ? Qt.rgba(29, 140, 248, 0.20) : "transparent"
                        border.width: 1
                        border.color: root.lineColor
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Label { text: root.dayData(index).dayName; color: root.mutedColor; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                            Label { text: root.dayData(index).date.getDate(); color: root.textColor; font.pixelSize: 16; font.weight: Font.DemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }

            Flickable {
                id: gridFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: 24 * 45

                Row {
                    width: gridFlick.width
                    height: gridFlick.contentHeight

                    Column {
                        width: 64
                        height: parent.height
                        Repeater {
                            model: 24
                            delegate: Rectangle {
                                width: 64
                                height: 45
                                color: root.lightTheme ? Qt.rgba(0,0,0,0.025) : Qt.rgba(0,0,0,0.28)
                                border.width: 1
                                border.color: root.lineColor
                                Label {
                                    anchors.centerIn: parent
                                    text: (index < 10 ? "0" + index : index) + ":00"
                                    color: root.mutedColor
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    Repeater {
                        model: 7
                        delegate: Item {
                            id: dayColumn
                            width: (gridFlick.width - 64) / 7
                            height: gridFlick.contentHeight
                            property var info: root.dayData(index)

                            Rectangle {
                                anchors.fill: parent
                                color: dayColumn.info.today ? Qt.rgba(29,140,248,0.05) : "transparent"
                                border.width: 1
                                border.color: root.lineColor
                            }

                            Repeater {
                                model: 24
                                delegate: Rectangle {
                                    width: dayColumn.width
                                    height: 45
                                    y: index * 45
                                    color: "transparent"
                                    border.width: 1
                                    border.color: root.lineColor
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onDoubleClicked: app.showEventEditor({ date: dayColumn.info.dateText, startTime: "09:00", endTime: "10:00" })
                            }

                            Repeater {
                                model: app.eventsList
                                delegate: Rectangle {
                                    visible: modelData.date === dayColumn.info.dateText
                                    x: 4
                                    y: root.eventTop(modelData)
                                    width: dayColumn.width - 8
                                    height: visible ? root.eventHeight(modelData) : 0
                                    radius: 4
                                    color: app.priorityStyle === "simple" ? "transparent" : root.priorityColor(modelData.priority || "gray")
                                    border.width: app.priorityStyle === "simple" ? 2 : 1
                                    border.color: root.priorityColor(modelData.priority || "gray")
                                    opacity: modelData.done ? 0.5 : 0.92
                                    z: 10

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        spacing: 2
                                        Label {
                                            text: modelData.text || "无标题"
                                            color: app.priorityStyle === "simple" ? root.priorityColor(modelData.priority || "gray") : "white"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Label {
                                            text: (modelData.startTime || "") + "-" + (modelData.endTime || "")
                                            color: app.priorityStyle === "simple" ? root.priorityColor(modelData.priority || "gray") : Qt.rgba(1,1,1,0.9)
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: app.showEventEditor(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }
            }
        }

        Text {
            width: 20
            height: 20
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "⌟"
            color: root.mutedColor
            opacity: 0.7
            font.pixelSize: 18
            DragHandler {
                target: null
                onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
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
