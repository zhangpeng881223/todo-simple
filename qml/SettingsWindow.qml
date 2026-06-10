import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15 as QQC
import QtQuick.Layouts 1.15
import org.deepin.dtk 1.0 as D

Item {
    id: root
    width: 480
    height: 430

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.theme === "light"
    readonly property color windowColor: lightTheme ? "#f0f0f0" : "#282828"
    readonly property color textColor: lightTheme ? "#333333" : "#ffffff"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.40) : Qt.rgba(1, 1, 1, 0.40)
    readonly property color labelColor: lightTheme ? Qt.rgba(0, 0, 0, 0.70) : Qt.rgba(1, 1, 1, 0.70)
    readonly property color borderColor: lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color rowLine: lightTheme ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.05)
    readonly property color headerLine: lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlBase: lightTheme ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlBorder: lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.15)
    readonly property color controlText: lightTheme ? "#303030" : "#f4f4f4"
    property string syncedTheme: ""

    function notify(message) {
        var text = String(message || "")
        if (text.length === 0) return
        if (D.DTK && D.DTK.sendMessage) {
            D.DTK.sendMessage(root.hostWindow, text)
        } else {
            console.log(text)
        }
    }

    function syncDtkPalette() {
        if (D.ApplicationHelper && D.ApplicationHelper.setPaletteType) {
            D.ApplicationHelper.setPaletteType(root.lightTheme ? D.ApplicationHelper.LightType : D.ApplicationHelper.DarkType)
        }
    }

    Component.onCompleted: {
        syncedTheme = app.theme
        syncDtkPalette()
    }

    Connections {
        target: app
        function onSettingsChanged() {
            if (root.syncedTheme === app.theme) {
                return
            }
            root.syncedTheme = app.theme
            root.syncDtkPalette()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        antialiasing: true
        color: root.windowColor
        border.width: 1
        border.color: root.borderColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 49

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 8

                    D.Label {
                        Layout.fillWidth: true
                        text: "设置"
                        color: root.textColor
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    HeaderToolButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        text: "×"
                        textSize: 18
                        hoverColor: "#ff5f57"
                        onClicked: if (root.hostWindow) root.hostWindow.close()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: root.headerLine
                }
            }

            Flickable {
                id: settingsFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight + 32

                ColumnLayout {
                    id: contentColumn
                    x: 16
                    y: 16
                    width: Math.max(0, settingsFlick.width - 32)
                    spacing: 0

                    SettingsRow {
                        title: "待办窗口颜色"
                        desc: "选择待办窗口的背景色"
                        control: CompactComboBox {
                            values: ["黑色", "白色"]
                            currentIndex: app.noteTheme === "light" ? 1 : 0
                            onActivated: function(index) {
                                app.updateSetting("noteTheme", index === 1 ? "light" : "dark")
                                root.notify("待办窗口颜色已更新")
                            }
                        }
                    }

                    SettingsRow {
                        title: "待办窗口透明度"
                        desc: "调整待办窗口透明度"
                        control: RowLayout {
                            implicitWidth: 200
                            implicitHeight: 24
                            spacing: 12

                            QQC.Slider {
                                Layout.preferredWidth: 148
                                Layout.preferredHeight: 20
                                from: 0
                                to: 100
                                stepSize: 1
                                value: app.opacity
                                onMoved: app.updateSetting("opacity", Math.round(value))
                            }

                            D.Label {
                                Layout.preferredWidth: 40
                                text: app.opacity + "%"
                                color: root.textColor
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }
                        }
                    }

                    SettingsRow {
                        title: "优先级样式"
                        desc: "选择待办事项优先级显示样式"
                        control: CompactComboBox {
                            values: ["多彩", "简约"]
                            currentIndex: app.priorityStyle === "simple" ? 1 : 0
                            onActivated: function(index) {
                                app.updateSetting("priorityStyle", index === 1 ? "simple" : "colorful")
                                root.notify("设置已保存")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        spacing: 8

                        D.Label {
                            text: "数据存储"
                            color: root.labelColor
                            font.pixelSize: 13
                        }

                        CompactTextField {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            text: app.storagePath
                            readOnly: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 12

                            CompactDataButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                iconName: "data-export"
                                text: "导出数据"
                                onClicked: root.notify(app.exportData())
                            }

                            CompactDataButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                iconName: "data-import"
                                text: "导入数据"
                                onClicked: root.notify(app.importData())
                            }
                        }

                        D.Label {
                            Layout.fillWidth: true
                            text: "导出所有待办事项，可在新电脑上导入恢复"
                            color: root.mutedColor
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 24
                        spacing: 8

                        D.Label {
                            text: "作者：布球人-黑桃老K"
                            color: root.mutedColor
                            font.pixelSize: 13
                        }

                        D.Label {
                            text: "版本号：V1.0.0 / Qt+QML"
                            color: root.mutedColor
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    component SettingsRow: Item {
        id: settingsRowRoot
        Layout.fillWidth: true
        Layout.preferredHeight: 58

        property string title: ""
        property string desc: ""
        property Component control

        Column {
            anchors.left: parent.left
            anchors.right: rowControlLoader.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            D.Label {
                text: settingsRowRoot.title
                color: root.textColor
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            D.Label {
                text: settingsRowRoot.desc
                color: root.mutedColor
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Loader {
            id: rowControlLoader
            width: item ? item.implicitWidth : 0
            height: item ? item.implicitHeight : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: settingsRowRoot.control
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.rowLine
        }
    }

    component HeaderToolButton: QQC.ToolButton {
        id: headerButton
        property color hoverColor: root.textColor
        property int textSize: 16
        hoverEnabled: true
        font.pixelSize: textSize

        contentItem: D.Label {
            text: headerButton.text
            color: headerButton.hovered ? headerButton.hoverColor : root.mutedColor
            font.pixelSize: headerButton.textSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 4
            color: headerButton.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        }
    }

    component CompactComboBox: QQC.Button {
        id: combo
        property var values: []
        property int currentIndex: -1
        signal activated(int index)

        implicitWidth: 90
        implicitHeight: 32
        font.pixelSize: 13
        hoverEnabled: true
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        onClicked: comboPopup.open()

        contentItem: Item {
            implicitWidth: combo.implicitWidth
            implicitHeight: combo.implicitHeight
            clip: false

            Text {
                x: 10
                y: 0
                width: Math.max(0, combo.width - 36)
                height: combo.height
                text: combo.currentIndex >= 0 && combo.currentIndex < combo.values.length ? combo.values[combo.currentIndex] : ""
                color: root.textColor
                font.pixelSize: 13
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                clip: false
                elide: Text.ElideRight
            }

            Image {
                width: 16
                height: 16
                x: combo.width - 23
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/assets/chevron-down-" + (root.lightTheme ? "dark" : "light") + ".svg"
                sourceSize.width: 16
                sourceSize.height: 16
                opacity: 0.78
            }
        }

        background: Rectangle {
            radius: 8
            color: combo.hovered || comboPopup.visible ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12)) : root.controlBase
            border.width: 1
            border.color: combo.hovered || comboPopup.visible ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.20)) : root.controlBorder
        }

        QQC.Popup {
            id: comboPopup
            y: combo.height - 1
            width: combo.width
            implicitHeight: menuColumn.implicitHeight
            padding: 0
            focus: true
            closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent

            contentItem: Column {
                id: menuColumn
                width: combo.width

                Repeater {
                    model: combo.values

                    QQC.ItemDelegate {
                        id: menuItem
                        width: combo.width
                        height: 32
                        hoverEnabled: true
                        onClicked: {
                            combo.currentIndex = index
                            comboPopup.close()
                            combo.activated(index)
                        }

                        contentItem: Text {
                            x: 10
                            width: Math.max(0, parent.width - 20)
                            height: parent.height
                            text: modelData
                            color: root.textColor
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color: menuItem.hovered || combo.currentIndex === index ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.14)) : "transparent"
                        }
                    }
                }
            }

            background: Rectangle {
                radius: 8
                color: root.lightTheme ? Qt.rgba(0.94, 0.94, 0.94, 0.98) : Qt.rgba(0.20, 0.20, 0.20, 0.98)
                border.width: 1
                border.color: root.borderColor
            }
        }
    }

    component CompactTextField: QQC.TextField {
        id: field
        font.pixelSize: 13
        color: root.controlText
        placeholderTextColor: root.mutedColor
        leftPadding: 12
        rightPadding: 30
        verticalAlignment: Text.AlignVCenter
        selectByMouse: true
        horizontalAlignment: Text.AlignLeft
        cursorPosition: 0

        background: Rectangle {
            radius: 6
            color: root.controlBase
            border.width: 1
            border.color: field.activeFocus ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(1, 1, 1, 0.30)) : root.borderColor
        }
    }

    component CompactDataButton: QQC.Button {
        id: dataButton
        property string iconName: ""
        hoverEnabled: true
        font.pixelSize: 13

        contentItem: Row {
            spacing: 8
            anchors.centerIn: parent

            Image {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/assets/" + dataButton.iconName + "-" + (root.lightTheme ? "dark" : "light") + ".svg"
                sourceSize.width: 16
                sourceSize.height: 16
                visible: dataButton.iconName.length > 0
            }

            D.Label {
                text: dataButton.text
                color: root.controlText
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        background: Rectangle {
            radius: 8
            color: dataButton.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.15)) : root.controlBase
            border.width: 1
            border.color: dataButton.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.25)) : root.controlBorder
        }
    }
}
