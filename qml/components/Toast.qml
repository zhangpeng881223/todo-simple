import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property string message: ""
    property bool lightTheme: false

    function show(text) {
        message = text
        timer.restart()
    }

    width: Math.min(parent ? parent.width - 28 : 260, label.implicitWidth + 28)
    height: 34
    radius: 8
    color: lightTheme ? Qt.rgba(1, 1, 1, 0.96) : Qt.rgba(0, 0, 0, 0.82)
    border.width: 1
    border.color: lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    opacity: message.length > 0 ? 1 : 0
    z: 999

    Behavior on opacity { NumberAnimation { duration: 180 } }

    Label {
        id: label
        anchors.centerIn: parent
        width: parent.width - 18
        text: root.message
        color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.78) : "white"
        font.pixelSize: 12
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    Timer {
        id: timer
        interval: 2600
        repeat: false
        onTriggered: root.message = ""
    }
}
