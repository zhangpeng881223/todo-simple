import QtQuick 2.15

Item {
    id: root
    signal prioritySelected(string priority)

    property string currentPriority: "gray"
    property bool lightTheme: false
    readonly property bool hovered: hoverHandler.hovered

    width: 132
    height: 30

    HoverHandler { id: hoverHandler }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: lightTheme ? Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.95) : Qt.rgba(0, 0, 0, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.20)
    }

    Row {
        anchors.centerIn: parent
        spacing: 8
        Repeater {
            model: [
                { name: "red", color: "#ff5f57" },
                { name: "orange", color: "#ffbd2e" },
                { name: "blue", color: "#1d8cf8" },
                { name: "green", color: "#28c840" },
                { name: "gray", color: "#8e8e93" }
            ]

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: modelData.color
                opacity: root.currentPriority === modelData.name ? 1 : 0.55
                border.width: root.currentPriority === modelData.name ? 2 : 0
                border.color: "white"
                scale: dotMouse.containsMouse ? 1.2 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }

                MouseArea {
                    id: dotMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.prioritySelected(modelData.name)
                }
            }
        }
    }
}
