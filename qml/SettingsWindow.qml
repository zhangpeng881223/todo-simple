import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15 as QQC
import QtQuick.Layouts 1.15
import org.deepin.dtk 1.0 as D

Item {
    id: root
    width: 760
    height: 560

    readonly property var hostWindow: Window.window
    readonly property bool lightTheme: app.theme === "light"
    readonly property color windowColor: lightTheme ? "#f7f8fa" : "#202124"
    readonly property color panelColor: lightTheme ? "#ffffff" : "#2b2c2f"
    readonly property color navColor: lightTheme ? "#f1f2f4" : "#26272a"
    readonly property color textColor: lightTheme ? "#242628" : "#f5f5f5"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.48) : Qt.rgba(1, 1, 1, 0.46)
    readonly property color borderColor: lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color rowLine: lightTheme ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.065)
    readonly property color controlBase: lightTheme ? "#f2f3f5" : "#35363a"
    readonly property color accentColor: "#2d8cff"
    property int activeIndex: 0
    property string aiScope: "note"
    property string aiTemplateDraft: ""
    property bool aiDirty: false
    property string syncedTheme: ""
    property string toastMessage: ""

    function notify(message) {
        var text = String(message || "")
        if (text.length === 0) return
        toastMessage = text
        toastTimer.restart()
        console.log(text)
    }

    function syncDtkPalette() {
        if (D.ApplicationHelper && D.ApplicationHelper.setPaletteType) {
            D.ApplicationHelper.setPaletteType(root.lightTheme ? D.ApplicationHelper.LightType : D.ApplicationHelper.DarkType)
        }
    }

    function formatAlpha(value) {
        return Number(value).toFixed(3)
    }

    function setAlpha(key, value) {
        app.updateSetting(key, Number(value.toFixed(3)))
    }

    function resetMainWindowAlpha() {
        app.updateSetting("mainDefaultTodoAlphaLight", 0.445)
        app.updateSetting("mainPriorityTodoAlphaLight", 0.275)
        app.updateSetting("mainDefaultTodoAlphaDark", 0.13)
        app.updateSetting("mainPriorityTodoAlphaDark", 0.21)
        notify("主窗口样式已恢复默认")
    }

    function aiScopeName(scope) {
        if (scope === "week") return "本周"
        if (scope === "month") return "本月"
        return "本条"
    }

    function loadAiTemplate(scope) {
        aiScope = scope
        aiTemplateDraft = app.summaryTemplate(scope)
        aiDirty = false
    }

    Component.onCompleted: {
        syncedTheme = app.theme
        syncDtkPalette()
        loadAiTemplate("note")
    }

    Connections {
        target: app
        function onSettingsChanged() {
            if (root.syncedTheme !== app.theme) {
                root.syncedTheme = app.theme
                root.syncDtkPalette()
            }
            if (!root.aiDirty) {
                root.loadAiTemplate(root.aiScope)
            }
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
                Layout.preferredHeight: 52

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 14
                    spacing: 8

                    D.Label {
                        Layout.fillWidth: true
                        text: "设置"
                        color: root.textColor
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    HeaderToolButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        text: "×"
                        textSize: 19
                        hoverColor: "#ff5f57"
                        onClicked: if (root.hostWindow) root.hostWindow.close()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 166
                    Layout.fillHeight: true
                    radius: 10
                    color: root.navColor
                    border.width: 1
                    border.color: root.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        NavButton { text: "主窗口样式"; index: 0 }
                        NavButton { text: "桌面待办样式"; index: 1 }
                        NavButton { text: "AI总结"; index: 2 }
                        NavButton { text: "数据存储"; index: 3 }
                        NavButton { text: "彩蛋"; index: 4 }
                        Item { Layout.fillHeight: true }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.activeIndex

                    MainWindowStylePage {}
                    DesktopTodoStylePage {}
                    AiSummaryPage {}
                    DataStoragePage {}
                    EasterEggPage {}
                }
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 1600
        onTriggered: root.toastMessage = ""
    }

    Rectangle {
        z: 20
        width: Math.min(360, toastText.implicitWidth + 36)
        height: 38
        radius: 19
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        visible: root.toastMessage.length > 0
        opacity: visible ? 1 : 0
        color: root.lightTheme ? Qt.rgba(0.08, 0.09, 0.10, 0.88) : Qt.rgba(0.96, 0.96, 0.96, 0.92)

        D.Label {
            id: toastText
            anchors.centerIn: parent
            text: root.toastMessage
            color: root.lightTheme ? "#ffffff" : "#222222"
            font.pixelSize: 13
            elide: Text.ElideRight
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
        }

        Behavior on opacity { NumberAnimation { duration: 140 } }
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
            radius: 6
            color: headerButton.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        }
    }

    component NavButton: QQC.Button {
        id: navButton
        property int index: 0
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        hoverEnabled: true
        onClicked: root.activeIndex = index

        contentItem: D.Label {
            text: navButton.text
            color: root.activeIndex === navButton.index ? "#ffffff" : root.textColor
            font.pixelSize: 13
            font.weight: root.activeIndex === navButton.index ? Font.DemiBold : Font.Normal
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 8
            color: root.activeIndex === navButton.index
                ? root.accentColor
                : navButton.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.07)) : "transparent"
        }
    }

    component PageShell: Flickable {
        id: page
        clip: true
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 4

        default property alias content: pageColumn.data

        ColumnLayout {
            id: pageColumn
            width: Math.max(0, page.width)
            spacing: 12
        }
    }

    component PageTitle: ColumnLayout {
        id: titleRoot
        property string title: ""
        property string desc: ""
        Layout.fillWidth: true
        spacing: 4

        D.Label {
            Layout.fillWidth: true
            text: titleRoot.title
            color: root.textColor
            font.pixelSize: 20
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        D.Label {
            Layout.fillWidth: true
            text: titleRoot.desc
            color: root.mutedColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    component SectionCard: Rectangle {
        id: card
        default property alias content: cardColumn.data
        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 24
        radius: 10
        color: root.panelColor
        border.width: 1
        border.color: root.borderColor

        ColumnLayout {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 0
        }
    }

    component SettingRow: Item {
        id: row
        property string title: ""
        property string desc: ""
        property Component control
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(64, controlLoader.item ? controlLoader.item.implicitHeight + 18 : 64)

        Column {
            anchors.left: parent.left
            anchors.right: controlLoader.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            D.Label {
                width: parent.width
                text: row.title
                color: root.textColor
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            D.Label {
                width: parent.width
                text: row.desc
                color: root.mutedColor
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Loader {
            id: controlLoader
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: item ? item.implicitWidth : 0
            height: item ? item.implicitHeight : 0
            sourceComponent: row.control
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.rowLine
        }
    }

    component AlphaRow: RowLayout {
        id: alphaRow
        property string label: ""
        property string keyName: ""
        property real settingValue: 0
        Layout.fillWidth: true
        implicitWidth: 430
        implicitHeight: 32
        spacing: 10

        D.Label {
            Layout.preferredWidth: 92
            text: alphaRow.label
            color: root.textColor
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        QQC.Slider {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            from: 0
            to: 0.6
            stepSize: 0.005
            value: alphaRow.settingValue
            live: true
            onMoved: root.setAlpha(alphaRow.keyName, value)
        }

        D.Label {
            Layout.preferredWidth: 48
            text: root.formatAlpha(alphaRow.settingValue)
            color: root.mutedColor
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
        }
    }

    component AlphaGroup: ColumnLayout {
        id: alphaGroup
        property string title: ""
        default property alias content: alphaGroupRows.data
        Layout.fillWidth: true
        spacing: 8

        D.Label {
            Layout.fillWidth: true
            text: alphaGroup.title
            color: root.textColor
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        ColumnLayout {
            id: alphaGroupRows
            Layout.fillWidth: true
            spacing: 4
        }
    }

    component CompactComboBox: QQC.ComboBox {
        id: combo
        implicitWidth: 136
        implicitHeight: 34
        font.pixelSize: 13
        hoverEnabled: true

        function optionText(optionIndex) {
            if (combo.model && combo.model[optionIndex] !== undefined) {
                return String(combo.model[optionIndex])
            }
            return combo.textAt(optionIndex)
        }

        contentItem: D.Label {
            leftPadding: 12
            rightPadding: 28
            text: combo.displayText
            color: root.textColor
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Image {
            width: 16
            height: 16
            x: combo.width - 24
            y: Math.round((combo.height - height) / 2)
            source: "qrc:/assets/chevron-down-" + (root.lightTheme ? "dark" : "light") + ".svg"
            sourceSize.width: 16
            sourceSize.height: 16
            opacity: 0.70
        }

        background: Rectangle {
            radius: 8
            color: combo.hovered || combo.popup.visible ? (root.lightTheme ? "#e9eaec" : "#3b3c40") : root.controlBase
            border.width: 1
            border.color: combo.activeFocus ? root.accentColor : root.borderColor
        }

        popup: QQC.Popup {
            y: combo.height + 4
            width: combo.width
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 160)
            padding: 4

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.model
                currentIndex: combo.currentIndex

                delegate: QQC.ItemDelegate {
                    id: popupDelegate
                    width: combo.popup.width - combo.popup.leftPadding - combo.popup.rightPadding
                    height: 36
                    hoverEnabled: true
                    onClicked: {
                        combo.currentIndex = index
                        combo.popup.close()
                        combo.activated(index)
                    }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        D.Label {
                            Layout.preferredWidth: 16
                            text: combo.currentIndex === index ? "✓" : ""
                            color: root.textColor
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        D.Label {
                            Layout.fillWidth: true
                            text: combo.optionText(index)
                            color: root.textColor
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    background: Rectangle {
                        radius: 6
                        color: popupDelegate.hovered || combo.currentIndex === index
                            ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            : "transparent"
                    }
                }
            }

            background: Rectangle {
                radius: 8
                color: root.panelColor
                border.width: 1
                border.color: root.borderColor
            }
        }
    }

    component ReadOnlyField: QQC.TextField {
        id: field
        implicitHeight: 34
        readOnly: true
        selectByMouse: true
        color: root.textColor
        font.pixelSize: 12
        leftPadding: 12
        rightPadding: 12
        background: Rectangle {
            radius: 8
            color: root.controlBase
            border.width: 1
            border.color: root.borderColor
        }
    }

    component DataButton: D.Button {
        id: dataButton
        property string assetName: ""
        implicitHeight: 36
        icon.name: ""

        contentItem: Row {
            spacing: 7
            anchors.centerIn: parent

            Image {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/assets/" + dataButton.assetName + "-" + (root.lightTheme ? "dark" : "light") + ".svg"
                sourceSize.width: 16
                sourceSize.height: 16
                visible: dataButton.assetName.length > 0
                opacity: 0.82
            }

            D.Label {
                text: dataButton.text
                color: root.textColor
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component LinkButton: QQC.Button {
        id: linkButton
        implicitWidth: 42
        implicitHeight: 34
        hoverEnabled: true
        background: Item {}

        contentItem: D.Label {
            text: linkButton.text
            color: linkButton.hovered ? Qt.darker(root.accentColor, 1.12) : root.accentColor
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component ScopeTab: QQC.Button {
        id: tab
        property string scope: "note"
        implicitWidth: 74
        implicitHeight: 32
        hoverEnabled: true
        onClicked: root.loadAiTemplate(scope)

        contentItem: D.Label {
            text: tab.text
            color: root.aiScope === tab.scope ? "#ffffff" : root.textColor
            font.pixelSize: 13
            font.weight: root.aiScope === tab.scope ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 8
            color: root.aiScope === tab.scope
                ? root.accentColor
                : tab.hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        }
    }

    component MainWindowStylePage: PageShell {
        PageTitle {
            title: "主窗口样式"
            desc: "调整主窗口右侧待办条目的底色透明度。"
        }

        SectionCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                D.Label {
                    Layout.fillWidth: true
                    text: "待办底色透明度"
                    color: root.textColor
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                D.Button {
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 32
                    text: "恢复默认"
                    onClicked: root.resetMainWindowAlpha()
                }
            }

            D.Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "分别控制浅色/深色模式下默认和优先级待办底色。"
                color: root.mutedColor
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 14

                AlphaGroup {
                    title: "浅色主题透明度调节"
                    AlphaRow { label: "默认优先级"; keyName: "mainDefaultTodoAlphaLight"; settingValue: app.mainDefaultTodoAlphaLight }
                    AlphaRow { label: "其它优先级"; keyName: "mainPriorityTodoAlphaLight"; settingValue: app.mainPriorityTodoAlphaLight }
                }

                AlphaGroup {
                    title: "深色主题透明度调节"
                    AlphaRow { label: "默认优先级"; keyName: "mainDefaultTodoAlphaDark"; settingValue: app.mainDefaultTodoAlphaDark }
                    AlphaRow { label: "其它优先级"; keyName: "mainPriorityTodoAlphaDark"; settingValue: app.mainPriorityTodoAlphaDark }
                }
            }
        }
    }

    component DesktopTodoStylePage: PageShell {
        PageTitle {
            title: "桌面待办样式"
            desc: "控制桌面便签窗口的颜色、透明度和优先级显示方式。"
        }

        SectionCard {
            SettingRow {
                title: "待办窗口颜色"
                desc: "选择桌面待办窗口外观，或跟随主窗口主题"
                control: CompactComboBox {
                    model: ["跟随系统", "黑色", "白色"]
                    currentIndex: app.noteTheme === "system" ? 0 : app.noteTheme === "light" ? 2 : 1
                    onActivated: function(index) {
                        app.updateSetting("noteTheme", index === 0 ? "system" : index === 2 ? "light" : "dark")
                        root.notify("待办窗口颜色已更新")
                    }
                }
            }

            SettingRow {
                title: "待办窗口透明度"
                desc: "调整桌面便签窗口整体透明度"
                control: RowLayout {
                    implicitWidth: 230
                    implicitHeight: 34
                    spacing: 10

                    QQC.Slider {
                        Layout.preferredWidth: 168
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        from: 0
                        to: 100
                        stepSize: 1
                        value: app.opacity
                        live: true
                        onMoved: app.updateSetting("opacity", Math.round(value))
                    }

                    D.Label {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        text: app.opacity + "%"
                        color: root.textColor
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            SettingRow {
                title: "优先级样式"
                desc: "多彩模式显示彩色底色，简约模式只保留线性提示"
                control: CompactComboBox {
                    model: ["多彩", "简约"]
                    currentIndex: app.priorityStyle === "simple" ? 1 : 0
                    onActivated: function(index) {
                        app.updateSetting("priorityStyle", index === 1 ? "simple" : "colorful")
                        root.notify("设置已保存")
                    }
                }
            }
        }
    }

    component AiSummaryPage: PageShell {
        PageTitle {
            title: "AI总结"
            desc: "分别维护本条、本周、本月总结提示词。保存后总结入口会使用对应模板。"
        }

        SectionCard {
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 12
                spacing: 6

                ScopeTab { scope: "note"; text: "本条" }
                ScopeTab { scope: "week"; text: "本周" }
                ScopeTab { scope: "month"; text: "本月" }
                Item { Layout.fillWidth: true }
            }

            QQC.TextArea {
                id: promptEdit
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                text: root.aiTemplateDraft
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: root.textColor
                selectedTextColor: "#ffffff"
                selectionColor: root.accentColor
                font.pixelSize: 13
                leftPadding: 12
                rightPadding: 12
                topPadding: 10
                bottomPadding: 10
                onTextChanged: {
                    if (text !== root.aiTemplateDraft) {
                        root.aiTemplateDraft = text
                        root.aiDirty = true
                    }
                }

                background: Rectangle {
                    radius: 8
                    color: root.controlBase
                    border.width: 1
                    border.color: promptEdit.activeFocus ? root.accentColor : root.borderColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 10

                Item { Layout.fillWidth: true }

                D.Button {
                    text: "恢复默认"
                    onClicked: {
                        app.resetSummaryTemplate(root.aiScope)
                        root.loadAiTemplate(root.aiScope)
                        root.notify(root.aiScopeName(root.aiScope) + "提示词已恢复默认")
                    }
                }

                D.Button {
                    text: "取消"
                    onClicked: root.loadAiTemplate(root.aiScope)
                }

                D.Button {
                    text: "保存"
                    highlighted: true
                    onClicked: {
                        app.setSummaryTemplate(root.aiScope, root.aiTemplateDraft)
                        root.aiDirty = false
                        root.notify(root.aiScopeName(root.aiScope) + "提示词已保存")
                    }
                }
            }
        }
    }

    component DataStoragePage: PageShell {
        PageTitle {
            title: "数据存储"
            desc: "查看本机永久存储路径，并导入或导出全部待办数据。"
        }

        SectionCard {
            SettingRow {
                title: "存储路径"
                desc: "当前数据文件所在位置"
                control: RowLayout {
                    implicitWidth: 386
                    implicitHeight: 34
                    spacing: 10

                    ReadOnlyField {
                        Layout.preferredWidth: 330
                        text: app.storagePath
                    }

                    LinkButton {
                        text: "打开"
                        onClicked: root.notify(app.openStoragePath())
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 12

                DataButton {
                    Layout.preferredWidth: 128
                    text: "导出数据"
                    assetName: "data-export"
                    onClicked: root.notify(app.exportData())
                }

                DataButton {
                    Layout.preferredWidth: 128
                    text: "导入数据"
                    assetName: "data-import"
                    onClicked: root.notify(app.importData())
                }

                Item { Layout.fillWidth: true }
            }

            D.Label {
                Layout.fillWidth: true
                Layout.topMargin: 12
                text: "导出文件包含 notes.json、events.json 和 settings.json；导入后会刷新当前窗口。"
                color: root.mutedColor
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }

    component EasterEggPage: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 420)
            spacing: 14

            D.Label {
                Layout.fillWidth: true
                text: "阿弥陀佛，算法自然"
                color: root.textColor
                font.pixelSize: 28
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            D.Label {
                Layout.fillWidth: true
                text: "愿今日待办有序。"
                color: root.mutedColor
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
