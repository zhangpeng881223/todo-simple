pragma Singleton
import QtQuick 2.15
import org.deepin.dtk 1.0 as D

QtObject {
    readonly property bool dark: D.ApplicationHelper.themeType !== D.ApplicationHelper.LightType
    readonly property color systemAccent: D.DTK.palette.highlight
    readonly property color fgNormal: dark ? "#F4F4F4" : "#202124"
    readonly property color fgStrong: dark ? "#FFFFFF" : "#101010"
    readonly property color textPrimary: fgNormal
    readonly property color textStrong: fgStrong
    readonly property color iconNormal: fgNormal
    readonly property color iconStrong: fgStrong
    readonly property color bg: dark ? "#181818" : "#F8F8F8"
    readonly property color bgToolbar: bg
    readonly property color titlebarBg: bg
    readonly property color sidebarBlurBlend: dark ? "#CC101010" : "#CCFFFFFF"
    readonly property color sidebarBlurFallback: dark ? "#101010" : "#FFFFFF"

    function priorityColor(priority) {
        if (priority === "red") return "#ff5f57"
        if (priority === "orange") return "#ffbd2e"
        if (priority === "blue") return "#1d8cf8"
        if (priority === "green") return "#28c840"
        return "#8e8e93"
    }
}
