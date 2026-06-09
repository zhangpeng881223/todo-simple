import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15 as QQC
import QtQuick.Layouts 1.15
import org.deepin.dtk 1.0 as D
import "."
import "components"

D.ApplicationWindow {
    id: root
    width: 960
    height: 680
    minimumWidth: 860
    minimumHeight: 600
    visible: false
    title: "小U待办"
    color: "transparent"
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint

    D.DWindow.enabled: true
    D.DWindow.themeType: root.dtkThemeType()
    D.DWindow.alphaBufferSize: 8
    D.DWindow.enableBlurWindow: true

    readonly property bool lightTheme: app.theme === "light"
                                       || (app.theme === "system"
                                           && D.ApplicationHelper.themeType === D.ApplicationHelper.LightType)
    readonly property color windowColor: lightTheme ? "#ffffff" : "#242526"
    readonly property color titlebarColor: lightTheme ? "#ffffff" : "#18191a"
    readonly property color sidebarColor: lightTheme ? Qt.rgba(1, 1, 1, 0.54) : "#222324"
    readonly property color sidebarGlassBlend: lightTheme ? Qt.rgba(1, 1, 1, 0.52) : "#222324"
    readonly property color sidebarGlassTop: lightTheme ? Qt.rgba(1, 1, 1, 0.74) : "#222324"
    readonly property color sidebarGlassBottom: lightTheme ? Qt.rgba(244 / 255, 255 / 255, 238 / 255, 0.24) : "#222324"
    readonly property color sidebarGlassBorder: lightTheme ? Qt.rgba(232 / 255, 238 / 255, 228 / 255, 0.52) : "transparent"
    readonly property color detailColor: lightTheme ? "#ffffff" : windowColor
    readonly property color cardColor: lightTheme ? "#ffffff" : "#2b2c2e"
    readonly property color cardHoverColor: lightTheme ? "#f0f0f0" : "#333538"
    readonly property color lineColor: lightTheme ? Qt.rgba(0, 0, 0, 0.12) : "#3a3c3e"
    readonly property color textColor: lightTheme ? "#252525" : "#f3f4f4"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.56) : "#9aa2a6"
    readonly property color weakColor: lightTheme ? Qt.rgba(0, 0, 0, 0.34) : "#6f777b"
    readonly property color selectedColor: lightTheme ? Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.16) : "#544522"
    readonly property color selectedBorderColor: lightTheme ? Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.42) : "#7a642a"
    readonly property color accentColor: "#ffb520"
    readonly property color redColor: "#ff5f58"
    readonly property color greenColor: "#28d764"
    readonly property color blueColor: "#2ea3ff"
    readonly property string iconTone: lightTheme ? "dark" : "light"

    property string searchTerm: ""
    property string selectedNoteId: ""
    property bool wrapTodos: false
    property bool confirmingNoteDelete: false
    property string draggingTodoId: ""
    property int dragStartIndex: -1
    property int dragTargetIndex: -1
    property real dragPointerY: 0
    property real dragGrabOffsetY: 0
    property int draggingIndex: -1
    property bool applyingAppTheme: false
    readonly property int rowDragStep: 51
    readonly property int sidebarWidth: 300
    readonly property int sidebarInset: lightTheme ? 18 : 0
    readonly property int sidebarRadius: lightTheme ? 12 : 0
    readonly property int titlebarReserve: 52
    readonly property int sidebarShadowLeftPad: 120
    readonly property int sidebarShadowTopPad: 110
    readonly property int sidebarShadowRightPad: 190
    readonly property int sidebarShadowBottomPad: 160

    function notify(message) {
        var text = String(message || "")
        if (text.length === 0) return
        if (D.DTK && D.DTK.sendMessage) {
            D.DTK.sendMessage(root, text)
        } else {
            console.log(text)
        }
    }

    function syncDtkPalette() {
        if (D.ApplicationHelper && D.ApplicationHelper.setPaletteType) {
            applyingAppTheme = true
            D.ApplicationHelper.setPaletteType(root.dtkThemeType())
            Qt.callLater(function() { applyingAppTheme = false })
        }
    }

    function dtkThemeType() {
        if (app.theme === "system") return D.ApplicationHelper.UnknownType
        return root.lightTheme ? D.ApplicationHelper.LightType : D.ApplicationHelper.DarkType
    }

    function syncAppThemeFromDtkPalette(paletteType) {
        if (applyingAppTheme) return
        var nextTheme = ""
        if (paletteType === D.ApplicationHelper.UnknownType) {
            nextTheme = "system"
        } else if (paletteType === D.ApplicationHelper.LightType) {
            nextTheme = "light"
        } else if (paletteType === D.ApplicationHelper.DarkType) {
            nextTheme = "dark"
        }
        if (nextTheme.length > 0 && app.theme !== nextTheme) {
            app.updateSetting("theme", nextTheme)
        }
    }

    function priorityColor(priority) {
        if (priority === "red") return root.redColor
        if (priority === "orange") return root.accentColor
        if (priority === "blue") return root.blueColor
        if (priority === "green") return root.greenColor
        return "#8e8e93"
    }

    function priorityBg(priority) {
        if (app.priorityStyle === "simple" || priority === "gray" || priority === "none" || !priority) {
            return "transparent"
        }
        if (priority === "red") return lightTheme ? Qt.rgba(255 / 255, 95 / 255, 88 / 255, 0.12) : "#3c2929"
        if (priority === "orange") return lightTheme ? Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.12) : "#3b321d"
        if (priority === "blue") return lightTheme ? Qt.rgba(46 / 255, 163 / 255, 255 / 255, 0.12) : "#243341"
        if (priority === "green") return lightTheme ? Qt.rgba(40 / 255, 215 / 255, 100 / 255, 0.12) : "#203629"
        return "transparent"
    }

    function priorityTodoCount() {
        var note = selectedNote()
        if (!note) return 0
        var todos = note.todos || []
        var count = 0
        for (var i = 0; i < todos.length; ++i) {
            var p = todos[i].priority || "gray"
            if (!todos[i].completed && p !== "gray" && p !== "none") ++count
        }
        return count
    }

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

    function firstMatchingNoteId() {
        var notes = app.notesList
        for (var i = 0; i < notes.length; i++) {
            if (noteMatches(notes[i])) return notes[i].id || ""
        }
        return ""
    }

    function selectedNote() {
        var notes = app.notesList
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].id === selectedNoteId) return notes[i]
        }
        return null
    }

    function ensureSelection() {
        var note = selectedNote()
        if (!note || !noteMatches(note)) {
            selectedNoteId = firstMatchingNoteId()
        }
        confirmingNoteDelete = false
    }

    function previewText(note) {
        var todos = note.todos || []
        var lines = []
        for (var i = 0; i < todos.length && lines.length < 2; i++) {
            var text = (todos[i].text || "").trim()
            if (text.length > 0) lines.push(text)
        }
        return lines.length > 0 ? lines.join("，") : "暂无待办内容"
    }

    function unfinishedTodoCount() {
        var note = selectedNote()
        if (!note) return 0
        var todos = note.todos || []
        var count = 0
        for (var i = 0; i < todos.length; ++i) {
            if (!todos[i].completed) ++count
        }
        return count
    }

    function dragDropIndexFromPointer(pointerY) {
        var total = unfinishedTodoCount()
        if (total <= 0) return -1
        var draggedTop = pointerY - dragGrabOffsetY
        var draggedCenter = draggedTop + 22
        var target = Math.floor((draggedCenter + rowDragStep / 2) / rowDragStep)
        return Math.max(0, Math.min(total - 1, target))
    }

    function resetDragState() {
        draggingTodoId = ""
        draggingIndex = -1
        dragStartIndex = -1
        dragTargetIndex = -1
        dragPointerY = 0
        dragGrabOffsetY = 0
    }

    function clampTodoContentY(contentY) {
        if (!todoList) return 0
        return Math.max(0, Math.min(todoList.contentHeight - todoList.height, contentY))
    }

    function restoreTodoContentY(contentY, retries) {
        Qt.callLater(function() {
            todoList.forceLayout()
            todoList.contentY = clampTodoContentY(contentY)
            if (retries > 0) restoreTodoContentY(contentY, retries - 1)
        })
    }

    Component.onCompleted: {
        syncDtkPalette()
        ensureSelection()
    }

    Connections {
        target: app
        function onSettingsChanged() { root.syncDtkPalette() }
        function onNotesChanged() { root.ensureSelection() }
    }

    Connections {
        target: D.ApplicationHelper
        function onPaletteTypeChanged(paletteType) {
            root.syncAppThemeFromDtkPalette(paletteType)
        }
    }

    D.TitleBar {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        z: 100
        title: ""
        separatorVisible: false
        enableInWindowBlendBlur: false

        menu: D.Menu {
            D.MenuItem {
                text: "设置"
                onTriggered: app.showSettingsWindow()
            }
            D.ThemeMenu {}
            D.MenuItem {
                text: "关于"
                onTriggered: app.showAboutDialog()
            }
            D.MenuItem {
                text: "退出"
                onTriggered: Qt.quit()
            }
        }

        D.WindowButtonGroup {
            id: windowButtons
            anchors.top: parent.top
            anchors.right: parent.right
        }
    }

    Rectangle {
        id: windowShell
        anchors.fill: parent
        radius: 0
        color: root.windowColor
        clip: false
        antialiasing: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.preferredWidth: root.sidebarWidth
                Layout.fillHeight: true

                Image {
                    id: sidebarDropShadow
                    x: root.sidebarInset - root.sidebarShadowLeftPad
                    y: root.sidebarInset - root.sidebarShadowTopPad
                    width: root.sidebarWidth - root.sidebarInset * 2
                           + root.sidebarShadowLeftPad + root.sidebarShadowRightPad
                    height: parent.height - root.sidebarInset * 2
                            + root.sidebarShadowTopPad + root.sidebarShadowBottomPad
                    source: "qrc:/assets/sidebar-glass-shadow-tall.png"
                    visible: root.lightTheme
                    opacity: 0.9
                    smooth: true
                }

                Rectangle {
                    id: sidebarPanel
                    anchors.fill: parent
                    anchors.margins: root.sidebarInset
                    radius: root.sidebarRadius
                    color: root.lightTheme ? "transparent" : root.sidebarColor
                    border.width: root.lightTheme ? 1 : 0
                    border.color: root.sidebarGlassBorder
                    antialiasing: true
                    clip: true

                    D.StyledBehindWindowBlur {
                        control: sidebarPanel
                        anchors.fill: parent
                        cornerRadius: sidebarPanel.radius
                        blendColor: valid ? root.sidebarGlassBlend : root.sidebarColor
                        visible: root.lightTheme
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: sidebarPanel.radius
                        antialiasing: true
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: root.sidebarGlassTop }
                            GradientStop { position: 0.56; color: root.sidebarColor }
                            GradientStop { position: 1.0; color: root.sidebarGlassBottom }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 14
                        anchors.bottomMargin: 10
                        spacing: 12

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38

                            Rectangle {
                                id: searchBox
                                anchors.left: parent.left
                                anchors.right: addNoteButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 8
                                height: 36
                                radius: 100
                                color: root.lightTheme ? "#f4f4f4" : "#333538"
                                border.width: 1
                                border.color: root.lightTheme ? "#e2e2e2" : "#45474a"
                                antialiasing: true

                                Image {
                                    id: searchIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    source: "qrc:/assets/search-muted.svg"
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    smooth: true
                                }

                                QQC.TextField {
                                    id: searchInput
                                    anchors.left: searchIcon.right
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 14
                                    height: 28
                                    text: root.searchTerm
                                    placeholderText: "搜索"
                                    placeholderTextColor: root.weakColor
                                    color: root.textColor
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    background: Item {}
                                    onTextChanged: {
                                        if (root.searchTerm === text)
                                            return
                                        root.searchTerm = text
                                        root.ensureSelection()
                                    }
                                }

                                TapHandler {
                                    onTapped: searchInput.forceActiveFocus()
                                }
                            }

                            D.ToolButton {
                                id: addNoteButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                text: "+"
                                font.pixelSize: 20
                                onClicked: app.createNewNote()
                                contentItem: D.Label {
                                    text: "+"
                                    color: root.textColor
                                    font.pixelSize: 17
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                background: Rectangle {
                                    radius: 8
                                    color: addNoteButton.hovered ? root.cardHoverColor : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20

                            D.Label {
                                text: "全部待办（" + root.matchedCount() + "）"
                                color: root.mutedColor
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                        }

                        D.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Column {
                                id: noteListColumn
                                width: sidebarPanel.width - 20
                                topPadding: 0
                                bottomPadding: 10

                                Repeater {
                                    model: app.notesList

                                    delegate: Item {
                                        id: noteRow
                                        width: noteListColumn.width
                                        height: root.noteMatches(modelData) ? 60 : 0
                                        visible: root.noteMatches(modelData)
                                        clip: true

                                        property bool confirmingDelete: false
                                        readonly property bool selected: root.selectedNoteId === modelData.id
                                        readonly property bool hovered: rowHover.hovered

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: parent.height
                                            radius: 8
                                            antialiasing: true
                                            color: noteRow.selected ? root.selectedColor : (noteRow.hovered ? root.cardHoverColor : "transparent")
                                            border.width: noteRow.selected ? 1 : 0
                                            border.color: root.selectedBorderColor
                                        }

                                        HoverHandler { id: rowHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.selectedNoteId = modelData.id
                                        }

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 8
                                            spacing: 4

                                            RowLayout {
                                                id: noteTitleRow
                                                height: 20
                                                width: parent.width
                                                spacing: 8

                                                D.Label {
                                                    Layout.fillWidth: true
                                                    text: modelData.title || "无标题"
                                                    color: root.textColor
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                }

                                                D.Label {
                                                    text: modelData.dateText || ""
                                                    color: root.mutedColor
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                }
                                            }

                                            RowLayout {
                                                width: parent.width
                                                height: 20
                                                spacing: 8

                                                D.Label {
                                                    Layout.fillWidth: true
                                                    text: root.previewText(modelData)
                                                    color: root.mutedColor
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                }

                                                Item {
                                                    Layout.preferredWidth: noteRow.confirmingDelete ? 90 : (noteRow.hovered ? 64 : 42)
                                                    Layout.preferredHeight: 24

                                                    Row {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 5
                                                        visible: noteRow.hovered && !noteRow.confirmingDelete

                                                        Image {
                                                            width: 14
                                                            height: 14
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "qrc:/assets/trash-hover.svg"
                                                            sourceSize.width: 14
                                                            sourceSize.height: 14
                                                            smooth: true
                                                        }

                                                        D.Label {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: noteRow.confirmingDelete ? "确认删除" : "删除"
                                                            color: root.redColor
                                                            font.pixelSize: 12
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 84
                                                        height: 26
                                                        radius: 100
                                                        visible: noteRow.confirmingDelete
                                                        color: root.redColor
                                                        antialiasing: true

                                                        D.Label {
                                                            anchors.centerIn: parent
                                                            text: "确认删除"
                                                            color: "white"
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                        }
                                                    }

                                                    D.Label {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: !noteRow.hovered && !noteRow.confirmingDelete
                                                        text: modelData.completed + "/" + modelData.total
                                                        color: root.mutedColor
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                    }

                                                    MouseArea {
                                                        id: listDeleteMouse
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: noteRow.confirmingDelete ? 84 : 64
                                                        height: 28
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (noteRow.confirmingDelete) {
                                                                app.deleteNote(modelData.id)
                                                            } else {
                                                                noteRow.confirmingDelete = true
                                                                rowDeleteTimer.restart()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: root.lineColor
                                            visible: false
                                        }

                                        Timer {
                                            id: rowDeleteTimer
                                            interval: 1200
                                            onTriggered: noteRow.confirmingDelete = false
                                        }
                                    }
                                }

                                D.Label {
                                    width: parent.width - 36
                                    x: 18
                                    height: root.matchedCount() === 0 ? 120 : 0
                                    visible: root.matchedCount() === 0
                                    text: "暂无匹配的待办窗口"
                                    color: root.mutedColor
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                }
            }

            Item {
                id: detailPane
                Layout.fillWidth: true
                Layout.fillHeight: true

                property var note: root.selectedNote()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    anchors.topMargin: root.titlebarReserve + 26
                    anchors.bottomMargin: 20
                    spacing: 16
                    visible: !!detailPane.note

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        spacing: 18

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            QQC.TextField {
                                id: titleEdit
                                Layout.fillWidth: true
                                text: detailPane.note ? detailPane.note.title : ""
                                color: root.textColor
                                font.pixelSize: 24
                                font.weight: Font.ExtraBold
                                selectByMouse: true
                                leftPadding: 0
                                rightPadding: 0
                                background: Item {}
                                onEditingFinished: if (detailPane.note) app.updateNoteTitle(detailPane.note.id, text)
                            }

                            D.Label {
                                Layout.fillWidth: true
                                text: "更新日期：" + (detailPane.note ? detailPane.note.dateText : "") + " · 默认按未完成优先排序"
                                color: root.mutedColor
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            spacing: 10
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            ActionButton {
                                label: "总结"
                                iconSource: "qrc:/assets/header-ai-" + root.iconTone + ".svg"
                                hoverIconSource: "qrc:/assets/header-ai-accent.svg"
                                onClicked: if (detailPane.note) root.notify(app.summarizeNote(detailPane.note.id))
                            }

                            ActionButton {
                                label: "允许换行"
                                iconSource: "qrc:/assets/toolbar-wrap-" + root.iconTone + ".svg"
                                hoverIconSource: "qrc:/assets/toolbar-wrap-accent.svg"
                                active: root.wrapTodos
                                onClicked: root.wrapTodos = !root.wrapTodos
                            }

                            ActionButton {
                                label: "显示在桌面"
                                iconSource: "qrc:/assets/toolbar-desktop-" + root.iconTone + ".svg"
                                hoverIconSource: "qrc:/assets/toolbar-desktop-accent.svg"
                                onClicked: if (detailPane.note) app.openNote(detailPane.note.id)
                            }

                            ActionButton {
                                label: root.confirmingNoteDelete ? "确认删除" : "删除"
                                danger: true
                                iconSource: "qrc:/assets/trash-hover.svg"
                                hoverIconSource: "qrc:/assets/trash-hover.svg"
                                onClicked: {
                                    if (!detailPane.note) return
                                    if (root.confirmingNoteDelete) {
                                        app.deleteNote(detailPane.note.id)
                                    } else {
                                        root.confirmingNoteDelete = true
                                        confirmDeleteTimer.restart()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        spacing: 12

                        D.Label {
                            text: "已完成 " + (detailPane.note ? detailPane.note.completed : 0) + " / " + (detailPane.note ? detailPane.note.total : 0)
                            color: root.mutedColor
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            radius: 999
                            color: root.lineColor

                            Rectangle {
                                width: parent.width * (detailPane.note && detailPane.note.total > 0 ? detailPane.note.completed / detailPane.note.total : 0)
                                height: parent.height
                                radius: 999
                                color: root.accentColor
                            }
                        }

                        D.Label {
                            text: "优先 " + root.priorityTodoCount() + " 项"
                            color: root.mutedColor
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: todoList
                            anchors.fill: parent
                            clip: true
                            spacing: 7
                            model: detailPane.note ? (detailPane.note.todos || []) : []
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: todoRow
                                width: todoList.width
                                height: root.wrapTodos ? Math.max(44, todoEdit.contentHeight + 14) : 44
                                z: isDraggingThis ? 60 : (priorityMenu.visible ? 20 : 1)

                                property bool confirmingDelete: false
                                property string priority: modelData.priority || "gray"
                                property bool done: !!modelData.completed
                                property bool menuVisible: priorityMouse.containsMouse || priorityMenu.hovered
                                property bool activeRow: rowHover.hovered || menuVisible || confirmingDelete || root.draggingTodoId === modelData.id
                                readonly property bool hasPriorityStripe: app.priorityStyle !== "simple" && priority !== "gray" && priority !== "none"
                                readonly property bool isDraggingThis: root.draggingTodoId === modelData.id
                                property real dragPreviewOffset: {
                                    if (root.draggingTodoId.length === 0 || todoRow.done) {
                                        return 0
                                    }
                                    if (todoRow.isDraggingThis) {
                                        return root.dragPointerY - root.dragGrabOffsetY - todoRow.y
                                    }
                                    if (index > root.dragStartIndex && index <= root.dragTargetIndex) {
                                        return -root.rowDragStep
                                    }
                                    if (index >= root.dragTargetIndex && index < root.dragStartIndex) {
                                        return root.rowDragStep
                                    }
                                    return 0
                                }

                                transform: Translate { y: todoRow.dragPreviewOffset }
                                Behavior on dragPreviewOffset {
                                    enabled: !todoRow.isDraggingThis
                                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                                }

	                                Canvas {
	                                    id: rowSurface
	                                    anchors.fill: parent
	                                    antialiasing: true
	                                    onPaint: {
	                                        var ctx = getContext("2d")
	                                        var w = width
	                                        var h = height
	                                        var r = 6
	                                        ctx.clearRect(0, 0, w, h)
	                                        ctx.beginPath()
	                                        ctx.moveTo(r, 0)
                                        ctx.lineTo(w - r, 0)
                                        ctx.quadraticCurveTo(w, 0, w, r)
                                        ctx.lineTo(w, h - r)
                                        ctx.quadraticCurveTo(w, h, w - r, h)
                                        ctx.lineTo(r, h)
                                        ctx.quadraticCurveTo(0, h, 0, h - r)
	                                        ctx.lineTo(0, r)
	                                        ctx.quadraticCurveTo(0, 0, r, 0)
	                                        ctx.closePath()
	                                        ctx.fillStyle = todoRow.hasPriorityStripe
	                                                ? root.priorityBg(todoRow.priority)
	                                                : (todoRow.activeRow ? root.cardHoverColor : "transparent")
	                                        ctx.fill()

	                                        if (!todoRow.hasPriorityStripe) {
	                                            ctx.strokeStyle = root.lineColor
	                                            ctx.lineWidth = 1
	                                            ctx.stroke()
	                                        }

	                                        if (todoRow.hasPriorityStripe) {
	                                            ctx.fillStyle = root.priorityColor(todoRow.priority)
	                                            var stripe = 4
	                                            var cap = 7
	                                            var outerR = 6
	                                            var innerR = 3
                                            ctx.beginPath()
                                            ctx.moveTo(0, outerR)
                                            ctx.quadraticCurveTo(0, 0, outerR, 0)
                                            ctx.lineTo(stripe + innerR, 0)
                                            ctx.quadraticCurveTo(stripe, innerR, stripe, cap)
                                            ctx.lineTo(stripe, h - cap)
                                            ctx.quadraticCurveTo(stripe, h - innerR, stripe + innerR, h)
                                            ctx.lineTo(outerR, h)
                                            ctx.quadraticCurveTo(0, h, 0, h - outerR)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }
                                }

                                onActiveRowChanged: rowSurface.requestPaint()
                                onPriorityChanged: rowSurface.requestPaint()
                                onHasPriorityStripeChanged: rowSurface.requestPaint()
                                onHeightChanged: rowSurface.requestPaint()

                                HoverHandler { id: rowHover }

	                                RowLayout {
	                                    anchors.fill: parent
	                                    anchors.leftMargin: 12
	                                    anchors.rightMargin: 12
	                                    spacing: 10

	                                    Item {
	                                        Layout.preferredWidth: 16
	                                        Layout.fillHeight: true

                                        Canvas {
                                            id: dragCanvas
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 12
                                            opacity: todoRow.done ? 0.28 : (dragMouse.containsMouse || todoRow.isDraggingThis ? 1 : 0.68)
                                            antialiasing: true
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.fillStyle = dragMouse.containsMouse ? (root.lightTheme ? Qt.rgba(0,0,0,0.6) : Qt.rgba(1,1,1,0.6)) : root.weakColor
                                                for (var rowDot = 0; rowDot < 3; ++rowDot) {
                                                    ctx.beginPath()
                                                    ctx.arc(4, 2.5 + rowDot * 3.5, 1.35, 0, Math.PI * 2)
                                                    ctx.fill()
                                                }
                                            }
                                            onOpacityChanged: requestPaint()
                                        }

                                        MouseArea {
                                            id: dragMouse
                                            anchors.centerIn: parent
                                            width: 24
                                            height: 36
                                            hoverEnabled: true
                                            enabled: !todoRow.done
                                            preventStealing: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            onContainsMouseChanged: dragCanvas.requestPaint()
                                            onPressed: function(mouse) {
                                                mouse.accepted = true
                                                todoList.interactive = false
                                                var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
                                                root.draggingTodoId = modelData.id
                                                root.dragStartIndex = index
                                                root.dragTargetIndex = index
                                                root.draggingIndex = index
                                                root.dragPointerY = p.y
                                                root.dragGrabOffsetY = p.y - todoRow.y
                                            }
                                            onPositionChanged: function(mouse) {
                                                if (!pressed || root.draggingTodoId.length === 0) {
                                                    return
                                                }
                                                mouse.accepted = true
                                                var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
                                                root.dragPointerY = p.y
                                                root.dragTargetIndex = root.dragDropIndexFromPointer(p.y)
                                            }
                                            onReleased: {
                                                var todoId = root.draggingTodoId
                                                var target = root.dragTargetIndex
                                                var start = root.dragStartIndex
                                                var releaseContentY = todoList.contentY
                                                root.resetDragState()
                                                todoList.interactive = true
                                                if (todoId.length > 0 && target >= 0 && target !== start) {
                                                    app.moveNoteTodoById(root.selectedNoteId, todoId, target)
                                                    root.restoreTodoContentY(releaseContentY, 3)
                                                }
                                            }
                                            onCanceled: {
                                                root.resetDragState()
                                                todoList.interactive = true
                                            }
                                        }
                                    }

	                                    Rectangle {
	                                        Layout.preferredWidth: 18
	                                        Layout.preferredHeight: 18
	                                        Layout.alignment: Qt.AlignVCenter
	                                        radius: 5
	                                        color: todoRow.done ? (root.lightTheme ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.30)) : "transparent"
	                                        border.width: 2
	                                        border.color: todoRow.done
	                                                      ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(1, 1, 1, 0.60))
	                                                      : (app.priorityStyle === "simple" || todoRow.priority !== "gray" ? root.priorityColor(todoRow.priority) : root.mutedColor)

                                        D.Label {
                                            anchors.centerIn: parent
                                            text: todoRow.done ? "✓" : ""
                                            color: root.textColor
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: app.toggleNoteTodo(root.selectedNoteId, modelData.id)
                                        }
                                    }

	                                    QQC.TextArea {
	                                        id: todoEdit
	                                        Layout.fillWidth: true
	                                        Layout.minimumWidth: 0
	                                        Layout.preferredHeight: root.wrapTodos ? Math.max(28, contentHeight + 3) : 28
                                        implicitWidth: 0
                                        text: modelData.text || ""
                                        color: todoRow.done ? root.mutedColor : root.textColor
                                        placeholderText: "新待办"
                                        placeholderTextColor: root.mutedColor
                                        selectByMouse: true
                                        wrapMode: root.wrapTodos ? TextEdit.Wrap : TextEdit.NoWrap
	                                        font.pixelSize: 14
	                                        font.weight: Font.DemiBold
	                                        font.strikeout: todoRow.done
	                                        leftPadding: 0
	                                        rightPadding: 0
	                                        topPadding: 3
	                                        bottomPadding: 1
                                        background: Item {}
                                        Keys.onReturnPressed: function(event) {
                                            if (!root.wrapTodos) {
                                                app.commitNoteTodoText(root.selectedNoteId, modelData.id, text)
                                                addTodoInput.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                        Keys.onEscapePressed: function(event) {
                                            focus = false
                                            event.accepted = true
                                        }
                                        onActiveFocusChanged: if (!activeFocus) app.commitNoteTodoText(root.selectedNoteId, modelData.id, text)
                                    }

	                                    Item {
	                                        Layout.preferredWidth: todoRow.confirmingDelete ? 86 : (todoRow.activeRow ? 52 : 16)
	                                        Layout.fillHeight: true

	                                        Rectangle {
	                                            id: priorityDot
                                            width: 12
                                            height: 12
                                            radius: 6
                                            anchors.right: deleteButton.left
                                            anchors.rightMargin: todoRow.confirmingDelete ? 8 : 8
                                            anchors.top: parent.top
                                            anchors.topMargin: 11
                                            color: root.priorityColor(todoRow.priority)
	                                            opacity: todoRow.menuVisible ? 0 : (todoRow.activeRow ? 1 : 0)
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        MouseArea {
                                            id: priorityMouse
                                            anchors.centerIn: priorityDot
                                            width: 28
                                            height: 30
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        Rectangle {
                                            id: deleteButton
                                            anchors.right: parent.right
                                            anchors.rightMargin: 2
                                            anchors.top: parent.top
                                            anchors.topMargin: 5
                                            width: todoRow.confirmingDelete ? 50 : 18
                                            height: 24
                                            radius: todoRow.confirmingDelete ? 12 : 4
	                                            color: todoRow.confirmingDelete ? root.redColor : "transparent"
                                            opacity: todoRow.activeRow ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            Image {
                                                anchors.centerIn: parent
                                                width: 14
                                                height: 14
                                                visible: !todoRow.confirmingDelete
                                                source: deleteMouse.containsMouse ? "qrc:/assets/trash-hover.svg" : "qrc:/assets/trash-muted.svg"
                                                sourceSize.width: 14
                                                sourceSize.height: 14
                                                smooth: true
                                            }

                                            D.Label {
                                                anchors.centerIn: parent
                                                visible: todoRow.confirmingDelete
                                                text: "删除"
                                                color: "white"
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                id: deleteMouse
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (todoRow.confirmingDelete) {
                                                        app.deleteNoteTodo(root.selectedNoteId, modelData.id)
                                                    } else {
                                                        todoRow.confirmingDelete = true
                                                        todoDeleteTimer.restart()
                                                    }
                                                }
                                            }
                                        }

                                        PriorityMenu {
                                            id: priorityMenu
                                            x: parent.width - width - 22
                                            y: 1
                                            z: 40
                                            visible: todoRow.menuVisible
                                            lightTheme: root.lightTheme
                                            currentPriority: todoRow.priority
                                            onPrioritySelected: function(priority) {
                                                app.setNoteTodoPriority(root.selectedNoteId, modelData.id, priority)
                                            }
                                        }

                                        Timer {
                                            id: todoDeleteTimer
                                            interval: 1000
                                            onTriggered: todoRow.confirmingDelete = false
                                        }
                                    }
                                }

	                                Rectangle {
	                                    anchors.left: parent.left
	                                    anchors.right: parent.right
	                                    anchors.bottom: parent.bottom
	                                    height: 1
	                                    color: root.lineColor
	                                    visible: false
	                                }
	                            }

                            QQC.ScrollBar.vertical: QQC.ScrollBar {
                                width: 4
                                policy: QQC.ScrollBar.AsNeeded
                            }
                        }
                    }

	                    Rectangle {
	                        Layout.fillWidth: true
	                        Layout.preferredHeight: 38
	                        radius: 100
	                        color: root.cardHoverColor
	                        border.width: addTodoInput.activeFocus ? 1 : 0
	                        border.color: root.accentColor

	                        QQC.TextField {
	                            id: addTodoInput
	                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
	                            placeholderText: "添加一条待办..."
	                            placeholderTextColor: root.weakColor
	                            color: root.textColor
	                            selectByMouse: true
	                            font.pixelSize: 12
	                            font.weight: Font.Medium
                            background: Item {}
                            onAccepted: {
                                if (detailPane.note && text.trim().length > 0) {
                                    app.addTodoToNote(detailPane.note.id, text)
                                    text = ""
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: !detailPane.note

                    D.Label {
                        text: "暂无待办"
                        color: root.textColor
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    D.Label {
                        width: 260
                        text: "从左侧选择一个待办窗口，或点击左上角 + 新建。"
                        color: root.mutedColor
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    Timer {
        id: confirmDeleteTimer
        interval: 1400
        onTriggered: root.confirmingNoteDelete = false
    }

	    component ActionButton: QQC.ToolButton {
	        id: actionButton
	        property string label: ""
	        property string iconSource: ""
	        property string hoverIconSource: iconSource
	        property bool danger: false
	        property bool active: false
	        property bool emphasized: false
	        signal triggered()

	        width: contentRow.implicitWidth
	        height: 32
        hoverEnabled: true
        padding: 0
        onClicked: triggered()

        contentItem: Row {
            id: contentRow
            anchors.centerIn: parent
	            spacing: 8

            Image {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: actionButton.hovered || actionButton.active || actionButton.emphasized ? actionButton.hoverIconSource : actionButton.iconSource
                sourceSize.width: 16
                sourceSize.height: 16
                opacity: actionButton.hovered || actionButton.active || actionButton.emphasized ? 1 : 0.9
            }

            D.Label {
                anchors.verticalCenter: parent.verticalCenter
	                text: actionButton.label
	                color: actionButton.danger
	                       ? root.redColor
	                       : root.textColor
	                font.pixelSize: 12
	                font.weight: Font.DemiBold
	                Behavior on color { ColorAnimation { duration: 120 } }
	            }
	        }

	        background: Rectangle {
	            radius: 8
	            color: "transparent"
	            border.width: 0
	            border.color: root.lineColor
	        }
	    }
}
