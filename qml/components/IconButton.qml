import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    signal clicked()

    property string symbol: ""
    property string tooltip: ""
    property color normalColor: "#b8ffffff"
    property color hoverColor: "#ffffff"
    property color hoverBackground: "transparent"
    property int textSize: 18

    width: 32
    height: 32

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: mouse.containsMouse ? root.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.symbol
        color: mouse.containsMouse ? root.hoverColor : root.normalColor
        font.pixelSize: root.textSize
        font.family: "Noto Sans CJK SC"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    ToolTip.visible: mouse.containsMouse && root.tooltip.length > 0
    ToolTip.text: root.tooltip
    ToolTip.delay: 500
}
