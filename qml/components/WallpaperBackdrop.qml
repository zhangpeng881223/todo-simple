import QtQuick 2.15
import Qt5Compat.GraphicalEffects as Fx

Rectangle {
    id: root

    property url source
    property rect screenGeometry
    property real windowX: 0
    property real windowY: 0
    property color fallbackColor: "transparent"
    property bool followScreenPosition: true
    property real blurAmount: 0

    readonly property real screenLeft: screenGeometry.width > 0 ? screenGeometry.x : 0
    readonly property real screenTop: screenGeometry.height > 0 ? screenGeometry.y : 0
    readonly property real screenWidth: Math.max(1, screenGeometry.width > 0 ? screenGeometry.width : width)
    readonly property real screenHeight: Math.max(1, screenGeometry.height > 0 ? screenGeometry.height : height)
    readonly property real blurRadius: Math.max(0, Math.min(1, blurAmount)) * 64

    color: fallbackColor
    antialiasing: true
    clip: true

    Image {
        id: wallpaper
        x: root.followScreenPosition ? root.screenLeft - root.windowX : 0
        y: root.followScreenPosition ? root.screenTop - root.windowY : 0
        width: root.followScreenPosition ? root.screenWidth : root.width
        height: root.followScreenPosition ? root.screenHeight : root.height
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: status === Image.Ready && root.blurRadius <= 0.5
    }

    Fx.FastBlur {
        anchors.fill: wallpaper
        source: wallpaper
        radius: root.blurRadius
        transparentBorder: false
        cached: false
        visible: wallpaper.status === Image.Ready && root.blurRadius > 0.5
    }
}
