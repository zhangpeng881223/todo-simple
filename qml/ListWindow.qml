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
    flags: Qt.Window | Qt.WindowTitleHint | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint
    background: Item {}

    D.DWindow.enabled: true
    D.DWindow.themeType: root.dtkThemeType()
    D.DWindow.alphaBufferSize: 8
    D.DWindow.enableBlurWindow: true

    readonly property bool lightTheme: app.theme === "light"
                                       || (app.theme === "system"
                                           && D.ApplicationHelper.themeType === D.ApplicationHelper.LightType)
    readonly property real mainWindowOpacity: Math.max(0, Math.min(1, app.mainWindowOpacity))
    readonly property real mainWallpaperBlur: Math.max(0, Math.min(1, app.mainWallpaperBlur))
    readonly property real mainWindowLightTintOpacity: mainWindowOpacity
    readonly property real mainWindowDarkTintOpacity: mainWindowOpacity
    readonly property real rightPanelOpacity: Math.max(0, Math.min(0.8, app.mainRightPanelOpacity))
    readonly property real rightPanelLightTintOpacity: Math.max(0, Math.min(0.8, rightPanelOpacity - 0.16))
    readonly property real rightPanelDarkTintOpacity: rightPanelOpacity
    readonly property color windowColor: lightTheme ? Qt.rgba(235 / 255, 244 / 255, 1, Math.min(1, mainWindowLightTintOpacity + 0.02)) : Qt.rgba(16 / 255, 19 / 255, 22 / 255, Math.min(1, mainWindowDarkTintOpacity + 0.08))
    readonly property color titlebarColor: windowColor
    readonly property color sidebarColor: lightTheme ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(34 / 255, 35 / 255, 36 / 255, 0.26)
    readonly property color sidebarGlassBlend: lightTheme ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(34 / 255, 35 / 255, 36 / 255, 0.22)
    readonly property color sidebarGlassTop: lightTheme ? Qt.rgba(1, 1, 1, 0.52) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color sidebarGlassBottom: lightTheme ? Qt.rgba(244 / 255, 255 / 255, 238 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.03)
    readonly property color sidebarGlassBorder: lightTheme ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color detailColor: windowColor
    readonly property color cardColor: lightTheme ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.055)
    readonly property color cardHoverColor: lightTheme ? Qt.rgba(1, 1, 1, 0.56) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color todoRowHoverColor: cardHoverColor
    readonly property color lineColor: lightTheme ? Qt.rgba(0, 0, 0, 0.085) : Qt.rgba(1, 1, 1, 0.105)
    readonly property color textColor: lightTheme ? "#252525" : "#f3f4f4"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.56) : "#9aa2a6"
    readonly property color weakColor: lightTheme ? Qt.rgba(0, 0, 0, 0.34) : "#6f777b"
    readonly property color selectedColor: lightTheme ? Qt.rgba(255 / 255, 196 / 255, 48 / 255, 0.36) : Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.26)
    readonly property color selectedBorderColor: lightTheme ? Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.28) : Qt.rgba(255 / 255, 181 / 255, 32 / 255, 0.24)
    readonly property color glassControlColor: lightTheme ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 0.055)
    readonly property color glassControlHoverColor: lightTheme ? Qt.rgba(1, 1, 1, 0.46) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color glassControlFocusColor: lightTheme ? Qt.rgba(1, 1, 1, 0.58) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassControlBorderColor: lightTheme ? Qt.rgba(0, 0, 0, 0.075) : Qt.rgba(1, 1, 1, 0.105)
    readonly property color glassControlHoverBorderColor: lightTheme ? Qt.rgba(0, 0, 0, 0.105) : Qt.rgba(1, 1, 1, 0.145)
    readonly property color glassControlFocusBorderColor: lightTheme ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.18)
    readonly property color accentColor: "#ffb520"
    readonly property color redColor: "#ff5f58"
    readonly property color greenColor: "#28d764"
    readonly property color blueColor: "#2ea3ff"
    readonly property color toolbarAccentHoverColor: lightTheme ? "#168fe8" : "#59bcff"
    readonly property color toolbarAccentActiveColor: lightTheme ? "#006dff" : "#6ac7ff"
    readonly property color toolbarDangerHoverColor: lightTheme ? "#e9433c" : "#ff746e"
    readonly property string iconTone: lightTheme ? "dark" : "light"

    property string searchTerm: ""
    property string selectedNoteId: ""
    readonly property bool wrapTodos: app.todosWrapEnabled
    property bool confirmingNoteDelete: false
    property bool sidebarSummaryMenuOpen: false
    property string contextDeleteNoteId: ""
    property string contextDeleteNoteTitle: ""
    property string feedbackDraftContent: ""
    property string feedbackDraftContact: ""
    property string draggingTodoId: ""
    property int dragStartIndex: -1
    property int dragTargetIndex: -1
    property real dragGrabOffsetY: 0
    property int draggingIndex: -1
    property bool dragSettling: false
    property string pendingDragTodoId: ""
    property string pendingDragNoteId: ""
    property int pendingDragStartIndex: -1
    property int pendingDragTargetIndex: -1
    property real pendingDragContentY: 0
    property bool committingTodoMove: false
    property bool applyingAppTheme: false
    property real defaultTodoAlphaLight: app.mainDefaultTodoAlphaLight
    property real defaultTodoAlphaDark: app.mainDefaultTodoAlphaDark
    property real priorityTodoAlphaLight: app.mainPriorityTodoAlphaLight
    property real priorityTodoAlphaDark: app.mainPriorityTodoAlphaDark
    readonly property real noteListElasticSpan: 20
    readonly property real todoRowHeight: 35.2
    readonly property real todoRowSpacing: 4.4
    readonly property real rowDragStep: todoRowHeight + todoRowSpacing
    readonly property real todoCheckboxTopMargin: Math.max(0, Math.round((todoRowHeight - 16) / 2))
    readonly property int sidebarWidth: 300
    readonly property int sidebarInset: 6
    readonly property int sidebarRadius: 16
    readonly property int sidebarLogoSize: 32
    readonly property int sidebarTopButtonSize: 28
    readonly property int sidebarSearchTop: sidebarInset + (sidebarLogoSize > 0 ? sidebarLogoSize + 12 : 14) + 1
    readonly property int titlebarReserve: 52
    readonly property int windowRadius: 12
    readonly property int sidebarShadowLeftPad: 120
    readonly property int sidebarShadowTopPad: 110
    readonly property int sidebarShadowRightPad: 190
    readonly property int sidebarShadowBottomPad: 160
    readonly property real backdropProtection: 0

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
        if (priority === "red") return "#ff5f57"
        if (priority === "orange") return "#ffbd2e"
        if (priority === "blue") return "#1d8cf8"
        if (priority === "green") return "#28c840"
        return "#8e8e93"
    }

    function checkboxPriorityColor(priority) {
        return priorityColor(priority)
    }

    function mixColor(colorA, colorB, amount) {
        var t = Math.max(0, Math.min(1, amount))
        return Qt.rgba(
            colorA.r + (colorB.r - colorA.r) * t,
            colorA.g + (colorB.g - colorA.g) * t,
            colorA.b + (colorB.b - colorA.b) * t,
            colorA.a + (colorB.a - colorA.a) * t
        )
    }

    function readabilityColor(lightBaseAlpha, lightProtectedAlpha, darkBaseAlpha, darkProtectedAlpha) {
        var lightBase = Qt.rgba(235 / 255, 244 / 255, 1, lightBaseAlpha)
        var lightProtected = Qt.rgba(238 / 255, 238 / 255, 238 / 255, lightProtectedAlpha)
        var darkBase = Qt.rgba(0.08, 0.09, 0.10, darkBaseAlpha)
        var darkProtected = Qt.rgba(24 / 255, 24 / 255, 24 / 255, darkProtectedAlpha)
        return root.lightTheme
               ? mixColor(lightBase, lightProtected, root.backdropProtection)
               : mixColor(darkBase, darkProtected, root.backdropProtection)
    }

    function readabilityAlpha(lightBaseAlpha, lightProtectedAlpha, darkBaseAlpha, darkProtectedAlpha) {
        return root.lightTheme
               ? lightBaseAlpha + (lightProtectedAlpha - lightBaseAlpha) * root.backdropProtection
               : darkBaseAlpha + (darkProtectedAlpha - darkBaseAlpha) * root.backdropProtection
    }

    function defaultTodoBg() {
        return lightTheme ? Qt.rgba(1, 1, 1, defaultTodoAlphaLight) : Qt.rgba(1, 1, 1, defaultTodoAlphaDark)
    }

    function priorityBg(priority) {
        if (app.priorityStyle === "simple" || priority === "gray" || priority === "none" || !priority) {
            return "transparent"
        }
        if (priority === "red") return Qt.rgba(255 / 255, 95 / 255, 87 / 255, 0.08)
        if (priority === "orange") return Qt.rgba(255 / 255, 189 / 255, 46 / 255, 0.08)
        if (priority === "blue") return Qt.rgba(29 / 255, 140 / 255, 248 / 255, 0.08)
        if (priority === "green") return Qt.rgba(40 / 255, 200 / 255, 64 / 255, 0.08)
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

    function summarizeSidebarNotes() {
        root.sidebarSummaryMenuOpen = !root.sidebarSummaryMenuOpen
    }

    function summarizeSidebarRange(scope) {
        root.sidebarSummaryMenuOpen = false
        root.notify(app.summarizeNotesRange(scope))
    }

    function createSidebarNote() {
        root.sidebarSummaryMenuOpen = false
        var noteId = app.createNewNote()
        if (noteId && noteId.length > 0) {
            root.searchTerm = ""
            root.selectedNoteId = noteId
            Qt.callLater(function() {
                root.selectedNoteId = noteId
                if (noteListScroll) {
                    noteListScroll.contentY = 0
                    noteListScroll.resetShortElastic(false)
                }
            })
            root.notify("已新建待办窗口")
        } else {
            root.notify("无法新建待办窗口")
        }
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
        var count = 0
        for (var i = 0; i < detailTodosModel.count; ++i) {
            if (!detailTodosModel.get(i).completed) ++count
        }
        return count
    }

    function dragDropIndexFromPointer(pointerY) {
        var total = unfinishedTodoCount()
        if (total <= 0) return -1
        var draggedTop = pointerY - dragGrabOffsetY
        var draggedCenter = draggedTop + todoRowHeight / 2
        var target = Math.floor((draggedCenter + rowDragStep / 2) / rowDragStep)
        return Math.max(0, Math.min(total - 1, target))
    }

    function resetDragState() {
        draggingTodoId = ""
        draggingIndex = -1
        dragStartIndex = -1
        dragTargetIndex = -1
        dragGrabOffsetY = 0
        dragSettling = false
    }

    function clearPendingDragCommit() {
        pendingDragTodoId = ""
        pendingDragNoteId = ""
        pendingDragStartIndex = -1
        pendingDragTargetIndex = -1
        pendingDragContentY = 0
    }

    function queueTodoDragCommit(noteId, todoId, start, target, contentY) {
        pendingDragNoteId = noteId
        pendingDragTodoId = todoId
        pendingDragStartIndex = start
        pendingDragTargetIndex = target
        pendingDragContentY = contentY
        dragCommitTimer.restart()
    }

    function todoField(todo, fieldName, fallbackValue) {
        if (!todo || todo[fieldName] === undefined || todo[fieldName] === null)
            return fallbackValue
        return todo[fieldName]
    }

    function syncDetailTodos(force) {
        var note = selectedNote()
        var todos = note ? (note.todos || []) : []
        var sameShape = detailTodosModel.count === todos.length
        if (sameShape) {
            for (var i = 0; i < todos.length; ++i) {
                if (detailTodosModel.get(i).id !== todoField(todos[i], "id", "")) {
                    sameShape = false
                    break
                }
            }
        }
        if (force || !sameShape) {
            detailTodosModel.clear()
            for (var appendIndex = 0; appendIndex < todos.length; ++appendIndex) {
                detailTodosModel.append({
                    "id": todoField(todos[appendIndex], "id", ""),
                    "text": todoField(todos[appendIndex], "text", ""),
                    "completed": !!todoField(todos[appendIndex], "completed", false),
                    "priority": todoField(todos[appendIndex], "priority", "gray")
                })
            }
            return
        }
        for (var updateIndex = 0; updateIndex < todos.length; ++updateIndex) {
            var todo = todos[updateIndex]
            detailTodosModel.setProperty(updateIndex, "text", todoField(todo, "text", ""))
            detailTodosModel.setProperty(updateIndex, "completed", !!todoField(todo, "completed", false))
            detailTodosModel.setProperty(updateIndex, "priority", todoField(todo, "priority", "gray"))
        }
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

    function pointInItem(item, x, y) {
        if (!item || !item.visible)
            return false
        var point = item.mapFromItem(windowShell, x, y)
        return point.x >= 0 && point.x <= item.width && point.y >= 0 && point.y <= item.height
    }

    function clearInputFocusAt(x, y) {
        if (pointInItem(searchBox, x, y) || pointInItem(addTodoBox, x, y) || pointInItem(titleEdit, x, y))
            return
        searchInput.focus = false
        addTodoInput.focus = false
        titleEdit.focus = false
        windowShell.forceActiveFocus(Qt.MouseFocusReason)
    }

    Component.onCompleted: {
        syncDtkPalette()
        ensureSelection()
        syncDetailTodos(true)
    }

    Connections {
        target: app
        function onSettingsChanged() { root.syncDtkPalette() }
        function onNotesChanged() {
            root.ensureSelection()
            root.syncDetailTodos(false)
        }
    }

    onSelectedNoteIdChanged: syncDetailTodos(true)

    ListModel {
        id: detailTodosModel
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
            D.Menu {
                title: "主题"

                D.MenuItem {
                    text: ""
                    height: 0
                    implicitHeight: 0
                    onTriggered: {}
                }

                D.MenuItem {
                    text: "浅色"
                    checkable: true
                    checked: app.theme === "light"
                    onTriggered: app.updateSetting("theme", "light")
                }

                D.MenuItem {
                    text: "深色"
                    checkable: true
                    checked: app.theme === "dark"
                    onTriggered: app.updateSetting("theme", "dark")
                }

                D.MenuItem {
                    text: "跟随系统"
                    checkable: true
                    checked: app.theme === "system"
                    onTriggered: app.updateSetting("theme", "system")
                }
            }
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

    Item {
        id: titleMoveArea
        x: root.sidebarWidth + 20
        y: 0
        width: Math.max(0, root.width - x - 300)
        height: root.titlebarReserve
        z: 101
        property real pressedCursorX: 0
        property real pressedCursorY: 0
        property real pressedWindowX: 0
        property real pressedWindowY: 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: {
                var cursor = app.cursorPosition()
                titleMoveArea.pressedCursorX = cursor.x
                titleMoveArea.pressedCursorY = cursor.y
                titleMoveArea.pressedWindowX = root.x
                titleMoveArea.pressedWindowY = root.y
            }
            onPositionChanged: {
                if (!pressed) return
                var cursor = app.cursorPosition()
                root.x = titleMoveArea.pressedWindowX + cursor.x - titleMoveArea.pressedCursorX
                root.y = titleMoveArea.pressedWindowY + cursor.y - titleMoveArea.pressedCursorY
            }
        }
    }

    Rectangle {
        id: windowShell
        anchors.fill: parent
        radius: root.windowRadius
        color: "transparent"
        clip: false
        focus: true
        antialiasing: true

        WallpaperBackdrop {
            id: wallpaperBackdrop
            anchors.fill: parent
            radius: root.windowRadius
            source: app.mainWallpaperMode === "default"
                    ? (root.lightTheme ? "qrc:/assets/default-main-wallpaper-source-light.jpg"
                                       : "qrc:/assets/default-main-wallpaper-source-dark.jpg")
                    : app.wallpaperSource
            screenGeometry: app.wallpaperScreenGeometry
            windowX: root.x
            windowY: root.y
            followScreenPosition: app.mainWallpaperMode === "system"
            blurAmount: root.mainWallpaperBlur
            fallbackColor: root.windowColor
        }

        LiquidGlassSurface {
            id: windowGlass
            anchors.fill: parent
            radius: root.windowRadius
            variant: "window"
            lightTheme: root.lightTheme
            blurEnabled: false
            density: root.lightTheme ? 0.18 : 0.20
            tintOpacity: root.lightTheme ? root.mainWindowLightTintOpacity : root.mainWindowDarkTintOpacity
            edgeOpacity: root.lightTheme ? 0.24 : 0.10
            highlightOpacity: 0
            lensOpacity: 0
            chromaOpacity: 0
            blendColor: root.lightTheme ? Qt.rgba(235 / 255, 244 / 255, 1, root.mainWindowLightTintOpacity) : Qt.rgba(0.08, 0.09, 0.10, Math.max(0, root.mainWindowDarkTintOpacity - 0.02))
            tintColor: root.lightTheme ? Qt.rgba(235 / 255, 244 / 255, 1, root.mainWindowLightTintOpacity) : Qt.rgba(0.08, 0.09, 0.10, root.mainWindowDarkTintOpacity)
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.preferredWidth: root.sidebarWidth
                Layout.fillHeight: true

                Item {
                    id: sidebarPanel
                    anchors.fill: parent
                    anchors.margins: root.sidebarInset

	                    Rectangle {
	                        id: productLogo
                        x: 5
                        y: 5
		                        width: root.sidebarLogoSize
		                        height: root.sidebarLogoSize
		                        radius: root.windowRadius
	                        visible: root.sidebarLogoSize > 0
	                        color: "transparent"
	                        clip: true
	                        antialiasing: true
	                        z: 2

                        Image {
                            anchors.fill: parent
                            source: "qrc:/assets/xiaou-todo-app-icon.png"
                            sourceSize.width: parent.width
                            sourceSize.height: parent.height
                            fillMode: Image.PreserveAspectCrop
	                            smooth: true
	                        }
	                    }

	                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: root.sidebarLogoSize > 0 ? root.sidebarLogoSize + 12 : 14
                        anchors.bottomMargin: 10
                        spacing: 12

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38

	                            Rectangle {
	                                id: searchBox
	                                anchors.left: parent.left
	                                anchors.right: parent.right
	                                anchors.verticalCenter: parent.verticalCenter
	                                height: 36
                                radius: 100
                                color: searchInput.activeFocus
                                       ? root.glassControlFocusColor
                                       : (searchHover.hovered ? root.glassControlHoverColor : root.glassControlColor)
                                border.width: 1
                                border.color: searchInput.activeFocus
                                              ? root.glassControlFocusBorderColor
                                              : (searchHover.hovered ? root.glassControlHoverBorderColor : root.glassControlBorderColor)
                                antialiasing: true

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                HoverHandler {
                                    id: searchHover
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: searchInput.forceActiveFocus()
                                }

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
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    background: Item {}
                                    onTextChanged: {
                                        if (root.searchTerm === text)
                                            return
                                        root.searchTerm = text
                                        root.ensureSelection()
	                                    }
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

	                        Flickable {
	                            id: noteListScroll
	                            Layout.fillWidth: true
	                            Layout.fillHeight: true
	                            clip: true
	                            contentWidth: width
		                            contentHeight: shortContent ? height : noteListColumn.implicitHeight
		                            boundsBehavior: Flickable.DragAndOvershootBounds
		                            boundsMovement: Flickable.FollowBoundsBehavior
		                            flickableDirection: Flickable.VerticalFlick
		                            readonly property bool shortContent: noteListColumn.implicitHeight <= height + 1
		                            property real shortElasticOffset: 0

		                            function resetShortElastic(animated) {
		                                if (animated) {
		                                    noteListReturnAnimation.restart()
		                                } else {
		                                    noteListReturnAnimation.stop()
		                                    shortElasticOffset = 0
		                                }
		                            }

		                            function applyShortElasticWheel(wheel) {
		                                if (!shortContent) {
		                                    return
		                                }

		                                var delta = 0
		                                if (wheel.pixelDelta && wheel.pixelDelta.y !== 0) {
		                                    delta = wheel.pixelDelta.y
		                                } else if (wheel.angleDelta && wheel.angleDelta.y !== 0) {
		                                    delta = wheel.angleDelta.y / 8
		                                }

		                                if (Math.abs(delta) < 0.1) {
		                                    return
		                                }

		                                noteListElasticReturn.stop()
		                                noteListReturnAnimation.stop()

		                                var nextOffset = shortElasticOffset + delta * 0.16
		                                if (Math.abs(shortElasticOffset) > root.noteListElasticSpan * 0.55
		                                        && Math.sign(nextOffset) === Math.sign(shortElasticOffset)) {
		                                    nextOffset = shortElasticOffset + delta * 0.07
		                                }
		                                shortElasticOffset = Math.max(-root.noteListElasticSpan,
		                                                              Math.min(root.noteListElasticSpan, nextOffset))
		                                wheel.accepted = true
		                                noteListElasticReturn.restart()
		                            }

		                            Timer {
		                                id: noteListElasticReturn
		                                interval: 80
		                                repeat: false
		                                onTriggered: noteListScroll.resetShortElastic(true)
		                            }

		                            NumberAnimation {
		                                id: noteListReturnAnimation
		                                target: noteListScroll
		                                property: "shortElasticOffset"
		                                to: 0
		                                duration: 220
		                                easing.type: Easing.OutQuart
		                            }

		                            rebound: Transition {
		                                NumberAnimation {
		                                    properties: "x,y"
		                                    duration: 240
		                                    easing.type: Easing.OutCubic
		                                }
		                            }

		                            WheelHandler {
		                                target: null
		                                enabled: noteListScroll.shortContent
		                                onWheel: function(wheel) {
		                                    noteListScroll.applyShortElasticWheel(wheel)
		                                }
		                            }

		                            Component.onCompleted: Qt.callLater(function() { noteListScroll.resetShortElastic(false) })
		                            onHeightChanged: Qt.callLater(function() { noteListScroll.resetShortElastic(false) })
		                            onContentHeightChanged: Qt.callLater(function() { noteListScroll.resetShortElastic(false) })
		                            onShortContentChanged: Qt.callLater(function() { noteListScroll.resetShortElastic(false) })
		                            onMovementStarted: {
		                                noteListElasticReturn.stop()
		                                noteListReturnAnimation.stop()
		                            }
		                            onFlickStarted: {
		                                noteListElasticReturn.stop()
		                                noteListReturnAnimation.stop()
		                            }

		                            Column {
		                                id: noteListColumn
		                                y: noteListScroll.shortContent ? noteListScroll.shortElasticOffset : 0
	                                width: noteListScroll.width
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
                                            border.width: 0
                                            border.color: root.selectedBorderColor
                                        }

                                        HoverHandler { id: rowHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: function(mouse) {
                                                root.selectedNoteId = modelData.id
                                                if (mouse.button === Qt.RightButton) {
                                                    noteContextMenu.popup()
                                                }
                                            }
                                        }

                                        QQC.Menu {
                                            id: noteContextMenu
                                            width: 158
                                            topPadding: 5
                                            bottomPadding: 5
                                            leftPadding: 6
                                            rightPadding: 6

                                            background: Rectangle {
                                                implicitWidth: 158
                                                implicitHeight: 140
                                                radius: 8
                                                antialiasing: true
                                                color: root.lightTheme ? Qt.rgba(245 / 255, 245 / 255, 245 / 255, 0.96)
                                                                       : Qt.rgba(42 / 255, 42 / 255, 42 / 255, 0.96)
                                                border.width: 1
                                                border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.08)
                                                                             : Qt.rgba(1, 1, 1, 0.10)
                                            }

                                            SidebarContextMenuItem {
                                                text: "AI总结"
                                                iconSource: "qrc:/assets/header-ai-" + root.iconTone + ".svg"
                                                onTriggered: root.notify(app.summarizeNote(modelData.id))
                                            }

                                            SidebarContextMenuItem {
                                                text: "在桌面显示"
                                                iconSource: "qrc:/assets/toolbar-desktop-" + root.iconTone + ".svg"
                                                onTriggered: app.showNoteOnDesktop(modelData.id)
                                            }

                                            SidebarContextMenuItem {
                                                text: "同步到系统日历"
                                                iconSource: "qrc:/assets/toolbar-calendar-" + root.iconTone + ".svg"
                                                onTriggered: root.notify(app.syncNoteTodosToSystemCalendar(modelData.id))
                                            }

                                            SidebarContextMenuItem {
                                                text: "删除"
                                                iconSource: "qrc:/assets/toolbar-trash-" + root.iconTone + ".svg"
                                                onTriggered: {
                                                    root.contextDeleteNoteId = modelData.id
                                                    root.contextDeleteNoteTitle = modelData.title || "无标题"
                                                    deleteNoteDialog.open()
                                                }
                                            }
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
                                                    font.weight: Font.Normal
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
                                                            source: "qrc:/assets/trash-muted.svg"
                                                            sourceSize.width: 14
                                                            sourceSize.height: 14
                                                            smooth: true
                                                        }

                                                        D.Label {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: noteRow.confirmingDelete ? "确认删除" : "删除"
                                                            color: root.mutedColor
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
                onNoteChanged: root.syncDetailTodos(false)

                LiquidGlassSurface {
                    id: detailWorkSurface
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 5
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    radius: root.windowRadius
                    variant: "readability"
                    lightTheme: root.lightTheme
                    visible: root.rightPanelOpacity > 0.001
                    enabled: visible
                    // The main window already paints the selected wallpaper as its base.
                    // Keep this layer local to that base instead of blurring whatever
                    // real window happens to be behind the app.
                    blurEnabled: false
                    protection: root.backdropProtection
                    density: 0.14
                    tintOpacity: root.readabilityAlpha(root.rightPanelLightTintOpacity, Math.min(0.8, root.rightPanelLightTintOpacity + 0.20), root.rightPanelDarkTintOpacity, Math.min(0.8, root.rightPanelDarkTintOpacity + 0.14))
                    edgeOpacity: root.lightTheme ? 0.10 + 0.04 * root.backdropProtection : 0.07 + 0.03 * root.backdropProtection
                    highlightOpacity: 0
                    lensOpacity: 0
                    chromaOpacity: 0
                    thicknessOpacity: 0
                    blendColor: root.readabilityColor(root.rightPanelLightTintOpacity, Math.min(0.8, root.rightPanelLightTintOpacity + 0.20), root.rightPanelDarkTintOpacity, Math.min(0.8, root.rightPanelDarkTintOpacity + 0.14))
                    tintColor: root.readabilityColor(root.rightPanelLightTintOpacity, Math.min(0.8, root.rightPanelLightTintOpacity + 0.20), root.rightPanelDarkTintOpacity, Math.min(0.8, root.rightPanelDarkTintOpacity + 0.14))
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    anchors.topMargin: root.sidebarSearchTop - 16
                    anchors.bottomMargin: root.sidebarInset
                    spacing: 12
                    visible: !!detailPane.note

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68
                        spacing: 3

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

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            spacing: 10

                            D.Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "更新日期：" + (detailPane.note ? detailPane.note.dateText : "")
                                color: root.mutedColor
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                spacing: 10

	                                ActionButton {
	                                    label: "总结"
	                                    iconSource: "qrc:/assets/header-ai-" + root.iconTone + ".svg"
	                                    hoverIconSource: "qrc:/assets/header-ai-accent.svg"
	                                    activeIconSource: "qrc:/assets/header-ai-active-" + root.iconTone + ".svg"
	                                    onClicked: if (detailPane.note) root.notify(app.summarizeNote(detailPane.note.id))
	                                }

	                                ActionButton {
		                                    label: "在桌面显示"
		                                    iconSource: "qrc:/assets/toolbar-desktop-" + root.iconTone + ".svg"
		                                    hoverIconSource: "qrc:/assets/toolbar-desktop-accent.svg"
		                                    activeIconSource: "qrc:/assets/toolbar-desktop-active-" + root.iconTone + ".svg"
		                                    active: detailPane.note && detailPane.note.visible
	                                    onClicked: {
	                                        if (!detailPane.note) return
	                                        if (detailPane.note.visible) {
	                                            app.hideNote(detailPane.note.id)
	                                        } else {
	                                            app.showNoteOnDesktop(detailPane.note.id)
	                                        }
	                                    }
	                                }

                                ActionButton {
                                    label: "同步到日历"
                                    iconSource: "qrc:/assets/toolbar-calendar-" + root.iconTone + ".svg"
                                    hoverIconSource: "qrc:/assets/toolbar-calendar-accent.svg"
                                    activeIconSource: "qrc:/assets/toolbar-calendar-accent.svg"
                                    onClicked: if (detailPane.note) root.notify(app.syncNoteTodosToSystemCalendar(detailPane.note.id))
                                }

                                ActionButton {
                                    label: "删除"
	                                    danger: true
	                                    iconSource: "qrc:/assets/toolbar-trash-" + root.iconTone + ".svg"
	                                    hoverIconSource: "qrc:/assets/toolbar-trash-danger.svg"
	                                    activeIconSource: "qrc:/assets/toolbar-trash-danger.svg"
	                                    onClicked: {
                                        if (!detailPane.note) return
                                        root.contextDeleteNoteId = detailPane.note.id
                                        root.contextDeleteNoteTitle = detailPane.note.title || "无标题"
                                        deleteNoteDialog.open()
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
	                        clip: false

		                        ListView {
	                            id: todoList
	                            anchors.fill: parent
	                            clip: false
	                            spacing: root.todoRowSpacing
                            model: detailTodosModel
                            boundsBehavior: Flickable.StopAtBounds
                            displaced: Transition {
                                enabled: !root.committingTodoMove
                                NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                            }
                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                                NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: 140; easing.type: Easing.OutCubic }
                            }
                            remove: Transition {
                                NumberAnimation { property: "opacity"; to: 0; duration: 110 }
                                NumberAnimation { property: "scale"; to: 0.98; duration: 110; easing.type: Easing.InCubic }
                            }

                            delegate: Item {
                                id: todoRow
                                width: todoList.width
                                height: root.wrapTodos ? Math.max(root.todoRowHeight, todoEdit.contentHeight + 8) : root.todoRowHeight
                                z: isDraggingThis ? 60 : (priorityMenu.visible ? 20 : 1)
                                opacity: 1
                                scale: 1

                                property bool confirmingDelete: false
                                property string priority: model.priority || "gray"
                                property bool done: !!model.completed
                                property real dragLiftOffset: 0
                                property bool menuVisible: priorityMouse.containsMouse || priorityMenu.hovered
                                property bool activeRow: rowHover.hovered || menuVisible || confirmingDelete || root.draggingTodoId === model.id
                                readonly property bool hasPriorityStripe: app.priorityStyle !== "simple" && priority !== "gray" && priority !== "none"
                                readonly property bool isDraggingThis: root.draggingTodoId === model.id
                                property real dragPreviewOffset: {
                                    if (root.draggingTodoId.length === 0 || todoRow.done) {
                                        return 0
                                    }
                                    if (todoRow.isDraggingThis) {
                                        return todoRow.dragLiftOffset
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
                                    enabled: !root.committingTodoMove && (!todoRow.isDraggingThis || root.dragSettling)
                                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                                }

		                                Canvas {
		                                    id: rowSurface
		                                    anchors.left: parent.left
		                                    anchors.leftMargin: 7
		                                    anchors.right: parent.right
		                                    anchors.top: parent.top
		                                    anchors.bottom: parent.bottom
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
		                                        ctx.fillStyle = todoRow.activeRow && !todoRow.isDraggingThis
		                                                ? root.todoRowHoverColor
		                                                : root.priorityBg(todoRow.priority)
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
                                Connections {
                                    target: root
                                    function onLightThemeChanged() { rowSurface.requestPaint() }
                                    function onDefaultTodoAlphaLightChanged() { rowSurface.requestPaint() }
                                    function onDefaultTodoAlphaDarkChanged() { rowSurface.requestPaint() }
                                    function onPriorityTodoAlphaLightChanged() { rowSurface.requestPaint() }
                                    function onPriorityTodoAlphaDarkChanged() { rowSurface.requestPaint() }
                                }

		                                HoverHandler { id: rowHover }

		                                Item {
		                                    id: dragHandleSlot
		                                    anchors.left: parent.left
		                                    anchors.leftMargin: -7
		                                    anchors.top: parent.top
		                                    anchors.bottom: parent.bottom
		                                    width: 10

	                                    Canvas {
	                                        id: dragCanvas
		                                        anchors.centerIn: parent
		                                        width: 6
		                                        height: 12
		                                        opacity: !todoRow.done && (todoRow.activeRow || dragMouse.containsMouse || todoRow.isDraggingThis) ? 1 : 0
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
		                                        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
		                                    }

	                                    MouseArea {
	                                        id: dragMouse
	                                        anchors.fill: parent
	                                        hoverEnabled: true
	                                        enabled: !todoRow.done
	                                        preventStealing: true
	                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
	                                        onContainsMouseChanged: dragCanvas.requestPaint()
	                                        onPressed: function(mouse) {
	                                            mouse.accepted = true
	                                            todoList.interactive = false
	                                            var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
	                                            root.draggingTodoId = model.id
	                                            root.dragStartIndex = index
	                                            root.dragTargetIndex = index
	                                            root.draggingIndex = index
	                                            root.dragGrabOffsetY = p.y - todoRow.y
	                                            todoRow.dragLiftOffset = 0
	                                        }
	                                        onPositionChanged: function(mouse) {
	                                            if (!pressed || root.draggingTodoId.length === 0) {
	                                                return
	                                            }
	                                            mouse.accepted = true
	                                            var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
	                                            todoRow.dragLiftOffset = p.y - root.dragGrabOffsetY - todoRow.y
	                                            var nextTarget = root.dragDropIndexFromPointer(p.y)
	                                            if (nextTarget !== root.dragTargetIndex) {
	                                                root.dragTargetIndex = nextTarget
	                                            }
	                                        }
	                                        onReleased: {
	                                            var appRoot = root
	                                            var todoId = appRoot.draggingTodoId
	                                            var target = appRoot.dragTargetIndex
	                                            var start = appRoot.dragStartIndex
	                                            var noteId = appRoot.selectedNoteId
	                                            var releaseContentY = todoList.contentY
	                                            if (todoId.length > 0 && target >= 0 && target !== start) {
	                                                appRoot.dragSettling = true
	                                                todoRow.dragLiftOffset = (target - start) * appRoot.rowDragStep
	                                                appRoot.queueTodoDragCommit(noteId, todoId, start, target, releaseContentY)
	                                            } else {
	                                                todoRow.dragLiftOffset = 0
	                                                appRoot.resetDragState()
	                                                todoList.interactive = true
	                                            }
	                                        }
	                                        onCanceled: {
	                                            dragCommitTimer.stop()
	                                            root.clearPendingDragCommit()
	                                            todoRow.dragLiftOffset = 0
	                                            root.resetDragState()
	                                            todoList.interactive = true
	                                        }
	                                    }
	                                }

		                                RowLayout {
		                                    anchors.left: rowSurface.left
		                                    anchors.right: rowSurface.right
		                                    anchors.top: rowSurface.top
		                                    anchors.bottom: rowSurface.bottom
			                                    anchors.leftMargin: 11
		                                    anchors.rightMargin: 12
		                                    spacing: 5

			                                    Rectangle {
		                                        Layout.preferredWidth: 16
		                                        Layout.preferredHeight: 16
		                                        Layout.alignment: root.wrapTodos ? Qt.AlignTop : Qt.AlignVCenter
		                                        Layout.topMargin: root.wrapTodos ? root.todoCheckboxTopMargin : 0
		                                        radius: 4
		                                        color: todoRow.done
		                                               ? (root.lightTheme ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.30))
		                                               : "transparent"
		                                        border.width: 1.2
		                                        border.color: todoRow.done
		                                                      ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(1, 1, 1, 0.60))
		                                                      : (app.priorityStyle === "simple" || todoRow.priority !== "gray"
		                                                         ? root.checkboxPriorityColor(todoRow.priority)
		                                                         : root.mutedColor)

	                                        Text {
	                                            anchors.centerIn: parent
	                                            y: -1
	                                            text: todoRow.done ? "✓" : ""
	                                            color: root.lightTheme ? "#333333" : "white"
	                                            font.pixelSize: 11
	                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: app.toggleNoteTodo(root.selectedNoteId, model.id)
                                        }
                                    }

	                                    QQC.TextArea {
	                                        id: todoEdit
	                                        Layout.fillWidth: true
	                                        Layout.minimumWidth: 0
	                                        Layout.preferredHeight: root.wrapTodos ? Math.max(24, contentHeight + 2) : 24
                                        implicitWidth: 0
                                        text: model.text || ""
                                        color: todoRow.done ? root.mutedColor : root.textColor
                                        placeholderText: "新待办"
                                        placeholderTextColor: root.mutedColor
                                        selectByMouse: true
                                        wrapMode: root.wrapTodos ? TextEdit.Wrap : TextEdit.NoWrap
	                                        font.pixelSize: 13
	                                        font.weight: Font.Normal
	                                        font.strikeout: todoRow.done
	                                        leftPadding: 6
	                                        rightPadding: 0
	                                        topPadding: 0
	                                        bottomPadding: 1
                                        background: Item {}
                                        Keys.onReturnPressed: function(event) {
                                            if (!root.wrapTodos) {
                                                app.commitNoteTodoText(root.selectedNoteId, model.id, text)
                                                addTodoInput.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                        Keys.onEscapePressed: function(event) {
                                            focus = false
                                            event.accepted = true
                                        }
                                        onActiveFocusChanged: if (!activeFocus) app.commitNoteTodoText(root.selectedNoteId, model.id, text)
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
                                            anchors.topMargin: 10
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
                                            anchors.topMargin: 4
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
                                                        app.deleteNoteTodo(root.selectedNoteId, model.id)
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
                                                app.setNoteTodoPriority(root.selectedNoteId, model.id, priority)
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

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 38
                        Layout.preferredHeight: 38
                        Layout.maximumHeight: 38
                        spacing: 10

	                    Rectangle {
                            id: addTodoBox
	                        Layout.fillWidth: true
                            Layout.minimumHeight: 38
	                        Layout.preferredHeight: 38
                            Layout.maximumHeight: 38
	                        radius: 100
	                        color: addTodoInput.activeFocus
	                               ? root.glassControlFocusColor
	                               : (addTodoHover.hovered ? root.glassControlHoverColor : root.glassControlColor)
	                        border.width: 1
	                        border.color: addTodoInput.activeFocus
	                                      ? root.glassControlFocusBorderColor
	                                      : (addTodoHover.hovered ? root.glassControlHoverBorderColor : root.glassControlBorderColor)
	                        antialiasing: true

	                        Behavior on color { ColorAnimation { duration: 120 } }
	                        Behavior on border.color { ColorAnimation { duration: 120 } }

	                        HoverHandler {
	                            id: addTodoHover
	                        }

	                        MouseArea {
	                            anchors.fill: parent
	                            hoverEnabled: true
	                            cursorShape: Qt.IBeamCursor
	                            onClicked: addTodoInput.forceActiveFocus()
	                        }

	                        QQC.TextField {
	                            id: addTodoInput
	                            anchors.fill: parent
	                            anchors.leftMargin: 12
	                            anchors.rightMargin: 12
	                            placeholderText: "添加一条待办..."
	                            placeholderTextColor: root.weakColor
	                            color: root.textColor
	                            selectByMouse: true
	                            font.pixelSize: 13
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

                        Rectangle {
                            id: feedbackButton
                            Layout.preferredWidth: 58
                            Layout.minimumHeight: 38
                            Layout.preferredHeight: 38
                            Layout.maximumHeight: 38
                            radius: 100
                            color: feedbackMouse.pressed
                                   ? root.glassControlFocusColor
                                   : (feedbackMouse.containsMouse ? root.glassControlHoverColor : root.glassControlColor)
                            border.width: 1
                            border.color: feedbackMouse.containsMouse ? root.glassControlHoverBorderColor : root.glassControlBorderColor
                            antialiasing: true

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            D.Label {
                                anchors.centerIn: parent
                                text: "反馈"
                                color: feedbackMouse.containsMouse ? root.textColor : root.mutedColor
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: feedbackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: feedbackDialog.open()
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

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: function(eventPoint, button) {
                root.clearInputFocusAt(eventPoint.position.x, eventPoint.position.y)
            }
        }
    }

    Row {
        id: sidebarTopActions
        x: root.sidebarInset + (root.sidebarWidth - root.sidebarInset * 2) - width - 7
        y: root.sidebarInset + 7
        spacing: 4
        z: 130

        SidebarIconButton {
            kind: "ai"
            tooltipText: "AI总结"
            onClicked: root.summarizeSidebarNotes()
        }

        SidebarIconButton {
            kind: "plus"
            tooltipText: "新建待办"
            onClicked: root.createSidebarNote()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 128
        visible: root.sidebarSummaryMenuOpen
        acceptedButtons: Qt.LeftButton
        onClicked: root.sidebarSummaryMenuOpen = false
    }

    Rectangle {
        id: sidebarSummaryMenu
        x: Math.max(root.sidebarInset + 10, sidebarTopActions.x + sidebarTopActions.width - width)
        y: sidebarTopActions.y + root.sidebarTopButtonSize + 7
        width: 124
        height: 82
        radius: 9
        z: 135
        visible: root.sidebarSummaryMenuOpen
        color: root.lightTheme ? Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.98)
                               : Qt.rgba(38 / 255, 39 / 255, 40 / 255, 0.98)
        border.width: 1
        border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12)
        antialiasing: true

        Column {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 4

            SummaryMenuItem {
                label: "AI总结本周"
                onTriggered: root.summarizeSidebarRange("week")
            }

            SummaryMenuItem {
                label: "AI总结本月"
                onTriggered: root.summarizeSidebarRange("month")
            }
        }
    }

    Timer {
        id: confirmDeleteTimer
        interval: 1400
        onTriggered: root.confirmingNoteDelete = false
    }

    Timer {
        id: dragCommitTimer
        interval: 120
        repeat: false
        onTriggered: {
            var noteId = root.pendingDragNoteId
            var todoId = root.pendingDragTodoId
            var start = root.pendingDragStartIndex
            var target = root.pendingDragTargetIndex
            var contentY = root.pendingDragContentY
            var shouldMove = noteId.length > 0 && todoId.length > 0 && target >= 0
            if (shouldMove) {
                root.committingTodoMove = true
                if (start >= 0 && start < detailTodosModel.count && target >= 0 && target < detailTodosModel.count && start !== target) {
                    detailTodosModel.move(start, target, 1)
                }
                app.moveNoteTodoById(noteId, todoId, target)
            }
            root.resetDragState()
            root.clearPendingDragCommit()
            todoList.interactive = true
            if (shouldMove) {
                root.restoreTodoContentY(contentY, 3)
            }
            Qt.callLater(function() {
                root.committingTodoMove = false
                root.syncDetailTodos(false)
            })
        }
    }

    QQC.Popup {
        id: deleteNoteDialog
        modal: true
        focus: true
        width: 300
        height: 156
        anchors.centerIn: parent
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: root.lightTheme ? "#ffffff" : "#2b2c2e"
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
            antialiasing: true
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            D.Label {
                Layout.fillWidth: true
                text: "删除待办窗口"
                color: root.textColor
                font.pixelSize: 16
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            D.Label {
                Layout.fillWidth: true
                text: "确认删除「" + root.contextDeleteNoteTitle + "」？"
                color: root.mutedColor
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                D.Button {
                    Layout.fillWidth: true
                    text: "取消"
                    onClicked: deleteNoteDialog.close()
                }

                D.Button {
                    Layout.fillWidth: true
                    text: "删除"
                    highlighted: true
                    onClicked: {
                        if (root.contextDeleteNoteId.length > 0) {
                            app.deleteNote(root.contextDeleteNoteId)
                        }
                        root.contextDeleteNoteId = ""
                        root.contextDeleteNoteTitle = ""
                        deleteNoteDialog.close()
                    }
                }
            }
        }
    }

    QQC.Popup {
        id: feedbackDialog
        modal: true
        focus: true
        width: 420
        height: 450
        anchors.centerIn: parent
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

        onOpened: Qt.callLater(function() {
            feedbackContentInput.forceActiveFocus()
        })

        background: Rectangle {
            radius: 14
            color: root.lightTheme ? "#ffffff" : "#2b2c2e"
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
            antialiasing: true
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 8

            D.Label {
                Layout.fillWidth: true
                text: "反馈"
                color: root.textColor
                font.pixelSize: 17
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            D.Label {
                Layout.fillWidth: true
                text: "感谢您使用小U待办，如果遇到问题或希望小U增加什么功能，请填写反馈，帮助小U待办变得更好。但作者希望我们一起秉承少即是多的理念，尽可能保证小U同学的简约性。"
                color: root.mutedColor
                font.pixelSize: 12
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            D.Label {
                Layout.fillWidth: true
                text: "反馈内容"
                color: root.mutedColor
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                radius: 8
                color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: feedbackContentInput.activeFocus
                              ? root.glassControlFocusBorderColor
                              : root.glassControlBorderColor
                antialiasing: true

                QQC.TextArea {
                    id: feedbackContentInput
                    anchors.fill: parent
                    anchors.margins: 10
                    placeholderText: "请输入你的问题、建议或想要的功能..."
                    placeholderTextColor: root.weakColor
                    color: root.textColor
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 13
                    background: Item {}
                }
            }

            D.Label {
                Layout.fillWidth: true
                text: "联系方式（选填）"
                color: root.mutedColor
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 38
                Layout.preferredHeight: 38
                Layout.maximumHeight: 38
                radius: 8
                color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: feedbackContactInput.activeFocus
                              ? root.glassControlFocusBorderColor
                              : root.glassControlBorderColor
                antialiasing: true

                QQC.TextField {
                    id: feedbackContactInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    placeholderText: "微信、邮箱或手机号"
                    placeholderTextColor: root.weakColor
                    color: root.textColor
                    selectByMouse: true
                    font.pixelSize: 13
                    background: Item {}
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                spacing: 10

                D.Button {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "取消"
                    onClicked: feedbackDialog.close()
                }

                D.Button {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "提交"
                    highlighted: true
                    onClicked: {
                        var content = feedbackContentInput.text.trim()
                        if (content.length === 0) {
                            feedbackContentInput.forceActiveFocus()
                            root.notify("请先输入反馈内容")
                            return
                        }
                        root.feedbackDraftContent = content
                        root.feedbackDraftContact = feedbackContactInput.text.trim()
                        feedbackDialog.close()
                        root.notify("反馈入口已准备，待接入存储")
                    }
                }
            }
        }
    }

	    component SidebarIconButton: Item {
	        id: sidebarButton
	        width: root.sidebarTopButtonSize
	        height: root.sidebarTopButtonSize

	        signal clicked()
	        property string kind: "plus"
	        property string tooltipText: ""
	        readonly property bool hovered: sidebarMouse.containsMouse
	        readonly property color hoverBackground: root.lightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.12)
	        readonly property color pressedBackground: root.lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.16)
	        readonly property string iconTone: root.lightTheme ? "dark" : "light"

	        Rectangle {
	            anchors.centerIn: parent
	            width: 24
	            height: 24
	            radius: 5
	            color: sidebarMouse.pressed ? sidebarButton.pressedBackground
	                                        : (sidebarButton.hovered ? sidebarButton.hoverBackground : "transparent")
	            antialiasing: true
	            Behavior on color { ColorAnimation { duration: 120 } }
	        }

	        Image {
	            anchors.centerIn: parent
	            width: 16
	            height: 16
	            source: "qrc:/assets/header-" + sidebarButton.kind + "-" + sidebarButton.iconTone + ".svg"
	            sourceSize.width: 16
	            sourceSize.height: 16
	            smooth: true
	            opacity: sidebarButton.hovered ? 1 : 0.72
	            Behavior on opacity { NumberAnimation { duration: 120 } }
	        }

	        Rectangle {
	            z: 50
	            x: (sidebarButton.width - width) / 2
	            y: sidebarButton.height + 4
	            width: tooltipLabel.implicitWidth + 18
	            height: 28
	            radius: 6
	            visible: sidebarButton.tooltipText.length > 0
                         && sidebarButton.hovered
                         && !(sidebarButton.kind === "ai" && root.sidebarSummaryMenuOpen)
	            color: root.lightTheme ? Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.96) : Qt.rgba(45 / 255, 45 / 255, 45 / 255, 0.96)
	            border.width: 1
	            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.14)

	            D.Label {
	                id: tooltipLabel
	                anchors.centerIn: parent
	                text: sidebarButton.tooltipText
	                color: root.textColor
	                font.pixelSize: 12
	            }
	        }

	        MouseArea {
	            id: sidebarMouse
	            anchors.fill: parent
	            hoverEnabled: true
	            cursorShape: Qt.PointingHandCursor
	            acceptedButtons: Qt.LeftButton
	            preventStealing: true
	            onClicked: sidebarButton.clicked()
	        }
	    }

    component SummaryMenuItem: Item {
        id: menuItem
        width: parent ? parent.width : 110
        height: 32

        signal triggered()
        property string label: ""
        readonly property bool hovered: itemMouse.containsMouse

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: menuItem.hovered
                   ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.10))
                   : "transparent"
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        D.Label {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.label
            color: root.textColor
            font.pixelSize: 13
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            onClicked: menuItem.triggered()
        }
    }

    component SidebarContextMenuItem: QQC.MenuItem {
        id: menuItem
        implicitWidth: 146
        implicitHeight: 32
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        property string iconSource: ""

        background: Rectangle {
            radius: 6
            antialiasing: true
            color: menuItem.hovered
                   ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.10))
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }

        contentItem: RowLayout {
            spacing: 8

            Image {
                source: menuItem.iconSource
                sourceSize.width: 16
                sourceSize.height: 16
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.leftMargin: 9
                opacity: menuItem.enabled ? 1 : 0.45
            }

            D.Label {
                text: menuItem.text
                color: root.textColor
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
            }
        }
    }

	    component ActionButton: QQC.ToolButton {
	        id: actionButton
	        property string label: ""
	        property string iconSource: ""
	        property string hoverIconSource: iconSource
	        property string activeIconSource: hoverIconSource
	        property bool danger: false
	        property bool active: false
	        property bool emphasized: false
	        signal triggered()
	        readonly property bool strongState: active || emphasized || pressed

	        width: contentRow.implicitWidth
        height: 24
        hoverEnabled: true
        padding: 0
        onClicked: triggered()

        contentItem: Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 5

	            Image {
	                width: 16
	                height: 16
	                anchors.verticalCenter: parent.verticalCenter
	                source: actionButton.strongState
	                        ? actionButton.activeIconSource
	                        : (actionButton.hovered ? actionButton.hoverIconSource : actionButton.iconSource)
	                sourceSize.width: 16
	                sourceSize.height: 16
	                opacity: actionButton.hovered || actionButton.strongState ? 1 : 0.9
	            }

            D.Label {
	                anchors.verticalCenter: parent.verticalCenter
	                text: actionButton.label
	                color: actionButton.danger
	                       ? (actionButton.hovered || actionButton.strongState ? root.toolbarDangerHoverColor : root.textColor)
	                       : (actionButton.strongState
	                          ? root.toolbarAccentActiveColor
	                          : (actionButton.hovered ? root.toolbarAccentHoverColor : root.textColor))
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

	        background: Item {}
	    }

}
