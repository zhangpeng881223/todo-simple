import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.deepin.dtk 1.0 as D
import "components"

Item {
    id: root
    width: 350
    height: 500

    readonly property var hostWindow: Window.window
    readonly property bool systemLightTheme: D.ApplicationHelper.themeType === D.ApplicationHelper.LightType
    readonly property bool lightTheme: app.noteTheme === "light" || (app.noteTheme === "system" && systemLightTheme)
    readonly property real bgOpacity: Math.max(0, Math.min(100, app.opacity)) / 100
    readonly property color cardColor: lightTheme ? Qt.rgba(240 / 255, 240 / 255, 240 / 255, bgOpacity) : Qt.rgba(40 / 255, 40 / 255, 40 / 255, bgOpacity)
    readonly property color textColor: lightTheme ? "#333333" : "white"
    readonly property color mutedColor: lightTheme ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(1, 1, 1, 0.42)
    readonly property color weakColor: lightTheme ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(1, 1, 1, 0.30)
    property string pendingFocusId: ""
    property int pendingFocusIndex: -1
    property string draggingTodoId: ""
    property int dragStartIndex: -1
    property int dragTargetIndex: -1
    property real dragPointerY: 0
    property real dragGrabOffsetY: 0
    property bool dragSettling: false
    property string pendingDragTodoId: ""
    property int pendingDragStartIndex: -1
    property int pendingDragTargetIndex: -1
    property real pendingDragContentY: 0
    property bool committingTodoMove: false

    function displayTitle(title) {
        var text = String(title || "便签标题")
        var width = 0
        var result = ""
        for (var i = 0; i < text.length; ++i) {
            var code = text.charCodeAt(i)
            var charWidth = code <= 0x007f ? 1 : 2
            if (width + charWidth > 16) {
                return result + "..."
            }
            result += text.charAt(i)
            width += charWidth
        }
        return text
    }

    function windowLayerToast(layer) {
        if (layer === "bottom") {
            return "强制置底"
        }
        if (layer === "top") {
            return "强制置顶"
        }
        return "默认显示层级"
    }

    property int draggingIndex: -1
    property bool summaryTemplateDialogOpen: false
    property string summaryTemplateDraft: ""
    readonly property int rowDragStep: 36

    function priorityColor(priority) {
        if (priority === "red") return "#ff5f57"
        if (priority === "orange") return "#ffbd2e"
        if (priority === "blue") return "#1d8cf8"
        if (priority === "green") return "#28c840"
        return "#8e8e93"
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

    function unfinishedTodoCount() {
        var count = 0
        for (var i = 0; i < noteTodosModel.count; ++i) {
            if (!noteTodosModel.get(i).completed) {
                ++count
            }
        }
        return count
    }

    function dragDropIndexFromPointer(pointerY) {
        var total = unfinishedTodoCount()
        if (total <= 0) {
            return -1
        }
        var draggedTop = pointerY - dragGrabOffsetY
        var draggedCenter = draggedTop + 16
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
        dragSettling = false
    }

    function clearPendingDragCommit() {
        pendingDragTodoId = ""
        pendingDragStartIndex = -1
        pendingDragTargetIndex = -1
        pendingDragContentY = 0
    }

    function queueTodoDragCommit(todoId, start, target, contentY) {
        pendingDragTodoId = todoId
        pendingDragStartIndex = start
        pendingDragTargetIndex = target
        pendingDragContentY = contentY
        dragCommitTimer.restart()
    }

    function todoField(todo, fieldName, fallbackValue) {
        if (!todo || todo[fieldName] === undefined || todo[fieldName] === null) {
            return fallbackValue
        }
        return todo[fieldName]
    }

    function syncNoteTodos(force) {
        var todos = noteController.todos || []
        var sameShape = noteTodosModel.count === todos.length
        if (sameShape) {
            for (var i = 0; i < todos.length; ++i) {
                if (noteTodosModel.get(i).id !== todoField(todos[i], "id", "")) {
                    sameShape = false
                    break
                }
            }
        }
        if (force || !sameShape) {
            noteTodosModel.clear()
            for (var appendIndex = 0; appendIndex < todos.length; ++appendIndex) {
                noteTodosModel.append({
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
            noteTodosModel.setProperty(updateIndex, "text", todoField(todo, "text", ""))
            noteTodosModel.setProperty(updateIndex, "completed", !!todoField(todo, "completed", false))
            noteTodosModel.setProperty(updateIndex, "priority", todoField(todo, "priority", "gray"))
        }
    }

    function clampTodoContentY(contentY) {
        if (!todoList) {
            return 0
        }
        return Math.max(0, Math.min(todoList.contentHeight - todoList.height, contentY))
    }

    function restoreTodoContentY(contentY, retries) {
        Qt.callLater(function() {
            todoList.forceLayout()
            todoList.contentY = clampTodoContentY(contentY)
            if (retries > 0) {
                restoreTodoContentY(contentY, retries - 1)
            }
        })
    }

    function indexOfTodo(todoId) {
        for (var i = 0; i < noteTodosModel.count; ++i) {
            if (noteTodosModel.get(i).id === todoId) {
                return i
            }
        }
        return -1
    }

    function revealPendingFocus() {
        if (pendingFocusId.length === 0) {
            return
        }
        var foundIndex = indexOfTodo(pendingFocusId)
        if (foundIndex < 0) {
            return
        }
        pendingFocusIndex = foundIndex
        todoList.forceLayout()
        todoList.contentY = Math.max(0, Math.min(todoList.contentHeight - todoList.height, foundIndex * rowDragStep - todoList.height + 32))
        todoList.currentIndex = foundIndex
        todoList.positionViewAtIndex(foundIndex, ListView.End)
        Qt.callLater(function() {
            if (todoList.currentItem && todoList.currentItem.focusIfPending) {
                todoList.currentItem.focusIfPending()
            }
        })
    }

    function schedulePendingFocusReveal() {
        Qt.callLater(function() {
            revealPendingFocus()
            Qt.callLater(function() {
                revealPendingFocus()
                Qt.callLater(revealPendingFocus)
            })
        })
    }

    function addTodo(afterIndex) {
        var id = noteController.addTodo(afterIndex === undefined ? -1 : afterIndex)
        pendingFocusId = id
        pendingFocusIndex = -1
        schedulePendingFocusReveal()
    }

    function openSummaryTemplateDialog() {
        summaryTemplateDraft = noteController.summaryTemplate
        summaryTemplateDialogOpen = true
        Qt.callLater(function() {
            centerSummaryTemplateWindow()
            summaryTemplateWindow.raise()
            summaryTemplateWindow.requestActivate()
            summaryTemplateEdit.forceActiveFocus()
            summaryTemplateEdit.cursorPosition = summaryTemplateEdit.length
        })
    }

    function centerSummaryTemplateWindow() {
        summaryTemplateWindow.x = Math.round((Screen.width - summaryTemplateWindow.width) / 2)
        summaryTemplateWindow.y = Math.round((Screen.height - summaryTemplateWindow.height) / 2)
    }

    Component.onCompleted: syncNoteTodos(true)

    Connections {
        target: noteController
        function onNoteChanged() {
            root.syncNoteTodos(false)
        }
    }

    ListModel {
        id: noteTodosModel
    }

    component HeaderButton: Item {
        id: buttonRoot
        width: 28
        height: 32

        signal clicked()
        property string kind: "plus"
        property string tooltipText: ""
        property bool tooltipRightAligned: false
        property bool suppressTooltipOnClick: false
        property bool tooltipSuppressed: false
        readonly property color hoverBackground: root.lightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.12)
        readonly property bool hovered: mouse.containsMouse
        readonly property string iconTone: root.lightTheme ? "dark" : "light"

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: 5
            color: buttonRoot.hovered ? buttonRoot.hoverBackground : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: "qrc:/assets/header-" + buttonRoot.kind + "-" + buttonRoot.iconTone + ".svg"
            sourceSize.width: 16
            sourceSize.height: 16
            smooth: true
            opacity: buttonRoot.hovered ? 1 : 0.72
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            z: 120
            x: buttonRoot.tooltipRightAligned ? buttonRoot.width - width : (buttonRoot.width - width) / 2
            y: buttonRoot.height - 1
            width: tooltipLabel.implicitWidth + 18
            height: 28
            radius: 6
            visible: buttonRoot.tooltipText.length > 0 && buttonRoot.hovered && !buttonRoot.tooltipSuppressed
            color: root.lightTheme ? Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.96) : Qt.rgba(45 / 255, 45 / 255, 45 / 255, 0.96)
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.14)
            opacity: visible ? 1 : 0

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: buttonRoot.tooltipText
                color: root.textColor
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: buttonRoot.tooltipSuppressed = false
            onExited: buttonRoot.tooltipSuppressed = false
            onClicked: {
                if (buttonRoot.suppressTooltipOnClick) {
                    buttonRoot.tooltipSuppressed = true
                }
                buttonRoot.clicked()
            }
        }
    }

    component DialogButton: Rectangle {
        id: dialogButtonRoot
        width: 72
        height: 30
        radius: 6

        signal clicked()
        property string label: ""
        property bool primary: false
        readonly property bool hovered: dialogButtonMouse.containsMouse

        color: primary
               ? (hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.16))
               : (hovered ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10)) : "transparent")
        border.width: primary ? 0 : 1
        border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.14)

        Text {
            anchors.centerIn: parent
            text: dialogButtonRoot.label
            color: dialogButtonRoot.primary ? "white" : root.textColor
            font.pixelSize: 12
        }

        MouseArea {
            id: dialogButtonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dialogButtonRoot.clicked()
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 12
        antialiasing: true
        color: root.cardColor
        clip: true
        border.width: 1
        border.color: lightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 0

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemMove()
                }

                TextField {
                    id: titleEdit
                    Layout.minimumWidth: 60
                    Layout.maximumWidth: 230
                    Layout.preferredWidth: Math.min(230, Math.max(60, titleMetrics.width + 8))
                    property string editDraft: noteController.title
                    text: activeFocus ? editDraft : root.displayTitle(noteController.title)
                    color: root.textColor
                    placeholderText: "便签标题"
                    placeholderTextColor: root.mutedColor
                    selectByMouse: true
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    horizontalAlignment: TextInput.AlignLeft
                    background: Item {}
                    Component.onCompleted: {
                        focus = false
                        cursorPosition = 0
                    }
                    onTextEdited: if (activeFocus) editDraft = text
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            editDraft = noteController.title
                            cursorPosition = length
                        } else {
                            if (editDraft !== noteController.title) {
                                noteController.title = editDraft
                            }
                            cursorPosition = 0
                        }
                    }
                    onEditingFinished: {
                        if (activeFocus && editDraft !== noteController.title) {
                            noteController.title = editDraft
                        }
                    }

                    Connections {
                        target: noteController
                        function onNoteChanged() {
                            if (!titleEdit.activeFocus) {
                                titleEdit.cursorPosition = 0
                            }
                        }
                    }

                    TextMetrics {
                        id: titleMetrics
                        font: titleEdit.font
                        text: titleEdit.activeFocus ? titleEdit.editDraft : root.displayTitle(noteController.title)
                    }
                }

                Item { Layout.fillWidth: true; Layout.minimumWidth: 8 }

                HeaderButton {
                    id: summaryButton
                    kind: "ai"
                    tooltipText: "AI总结"
                    onClicked: toast.show(noteController.summarizeToday())
                }
                HeaderButton {
                    kind: "plus"
                    tooltipText: "新建待办"
                    onClicked: root.addTodo()
                }
                HeaderButton {
                    kind: "layer-" + noteController.windowLayer
                    tooltipText: "层级切换"
                    suppressTooltipOnClick: true
                    onClicked: {
                        noteController.cycleWindowLayer()
                        toast.show(root.windowLayerToast(noteController.windowLayer))
                    }
                }
                HeaderButton {
                    kind: "close"
                    tooltipText: "关闭"
                    tooltipRightAligned: true
                    onClicked: {
                        toast.show("便签已隐藏")
                        hideTimer.restart()
                    }
                }
            }

            ListView {
                id: todoList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 9
                Layout.rightMargin: 14
                Layout.bottomMargin: 0
                clip: true
                spacing: 4
                model: noteTodosModel
                boundsBehavior: Flickable.StopAtBounds
                displaced: Transition {
                    enabled: !root.committingTodoMove
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: row
                    width: todoList.width
                    height: 32
                    z: isDraggingThis ? 60 : (priorityMenu.visible ? 20 : 1)

                    property bool confirmingDelete: false
                    property string priority: model.priority || "gray"
                    property bool done: !!model.completed
                    property var appRoot: root
                    property int modelIndex: index
                    property bool menuVisible: priorityMouse.containsMouse || priorityMenu.hovered
                    property bool activeRow: rowHover.hovered || menuVisible || confirmingDelete || appRoot.draggingTodoId === model.id
                    readonly property bool hasPriorityStripe: app.priorityStyle !== "simple" && row.priority !== "gray" && row.priority !== "none"
                    readonly property bool isDraggingThis: appRoot.draggingTodoId === model.id
                    property real dragPreviewOffset: {
                        if (appRoot.draggingTodoId.length === 0 || row.done) {
                            return 0
                        }
                        if (row.isDraggingThis) {
                            return appRoot.dragPointerY - appRoot.dragGrabOffsetY - row.y
                        }
                        if (index > appRoot.dragStartIndex && index <= appRoot.dragTargetIndex) {
                            return -appRoot.rowDragStep
                        }
                        if (index >= appRoot.dragTargetIndex && index < appRoot.dragStartIndex) {
                            return appRoot.rowDragStep
                        }
                        return 0
                    }

                    onActiveRowChanged: rowSurface.requestPaint()
                    onPriorityChanged: rowSurface.requestPaint()
                    onHasPriorityStripeChanged: rowSurface.requestPaint()

                    transform: Translate { y: row.dragPreviewOffset }
                    Behavior on dragPreviewOffset {
                        enabled: !appRoot.committingTodoMove && (!row.isDraggingThis || appRoot.dragSettling)
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }

                    function focusIfPending() {
                        if (model.id === appRoot.pendingFocusId) {
                            Qt.callLater(function() {
                                todoEdit.forceActiveFocus()
                                todoEdit.selectAll()
                                row.appRoot.pendingFocusId = ""
                                row.appRoot.pendingFocusIndex = -1
                            })
                        }
                    }

                    Component.onCompleted: focusIfPending()
                    onVisibleChanged: if (visible) focusIfPending()

	                    Canvas {
	                        id: rowSurface
	                        anchors.left: parent.left
		                        anchors.leftMargin: 11
	                        anchors.right: parent.right
	                        anchors.top: parent.top
	                        anchors.bottom: parent.bottom
	                        antialiasing: true
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width
                            var h = height
                            var r = 2
                            ctx.clearRect(0, 0, w, h)

                            function roundedPath() {
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
                            }

                            ctx.fillStyle = row.activeRow
                                    ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(1, 1, 1, 0.05))
                                    : root.priorityBg(row.priority)
                            roundedPath()
                            ctx.fill()

                            if (row.hasPriorityStripe) {
                                ctx.fillStyle = root.priorityColor(row.priority)
                                var stripe = 3
                                var cap = 5
                                var outerR = 5
                                var innerR = 2
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

	                    HoverHandler {
	                        id: rowHover
	                    }

	                    Item {
	                        id: dragHandleSlot
	                        anchors.left: parent.left
	                        anchors.top: parent.top
	                        anchors.bottom: parent.bottom
	                        width: 9

	                        Canvas {
	                            id: dragCanvas
	                            anchors.centerIn: parent
	                            width: 6
	                            height: 12
	                            opacity: !row.done && row.activeRow ? 1 : 0
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
	                            anchors.fill: parent
	                            hoverEnabled: true
	                            enabled: !row.done
	                            preventStealing: true
	                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
	                            onContainsMouseChanged: dragCanvas.requestPaint()
	                            onPressed: function(mouse) {
	                                mouse.accepted = true
	                                todoList.interactive = false
	                                var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
	                                row.appRoot.draggingTodoId = model.id
	                                row.appRoot.dragStartIndex = index
	                                row.appRoot.dragTargetIndex = index
	                                row.appRoot.draggingIndex = index
	                                row.appRoot.dragPointerY = p.y
	                                row.appRoot.dragGrabOffsetY = p.y - row.y
	                            }
	                            onPositionChanged: function(mouse) {
	                                if (!pressed || row.appRoot.draggingTodoId.length === 0) {
	                                    return
	                                }
	                                mouse.accepted = true
	                                var p = mapToItem(todoList.contentItem, mouse.x, mouse.y)
	                                row.appRoot.dragPointerY = p.y
	                                row.appRoot.dragTargetIndex = row.appRoot.dragDropIndexFromPointer(p.y)
	                            }
	                            onReleased: {
	                                var todoId = row.appRoot.draggingTodoId
	                                var target = row.appRoot.dragTargetIndex
	                                var start = row.appRoot.dragStartIndex
	                                var releaseContentY = todoList.contentY
	                                if (todoId.length > 0 && target >= 0 && target !== start) {
	                                    row.appRoot.dragSettling = true
	                                    row.appRoot.dragPointerY = row.y + (target - start) * row.appRoot.rowDragStep + row.appRoot.dragGrabOffsetY
	                                    row.appRoot.queueTodoDragCommit(todoId, start, target, releaseContentY)
	                                } else {
	                                    row.appRoot.resetDragState()
	                                    todoList.interactive = true
	                                }
	                            }
	                            onCanceled: {
	                                dragCommitTimer.stop()
	                                row.appRoot.clearPendingDragCommit()
	                                row.appRoot.resetDragState()
	                                todoList.interactive = true
	                            }
	                        }
	                    }

	                    RowLayout {
	                        anchors.left: rowSurface.left
	                        anchors.right: rowSurface.right
	                        anchors.top: rowSurface.top
	                        anchors.bottom: rowSurface.bottom
		                        anchors.leftMargin: 10
	                        anchors.rightMargin: 0
	                        spacing: 2

	                        Rectangle {
                            id: checkbox
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            Layout.alignment: Qt.AlignVCenter
                            radius: 4
                            color: row.done ? (root.lightTheme ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.30)) : "transparent"
                            border.width: 1.2
                            border.color: row.done
                                          ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(1, 1, 1, 0.60))
                                          : (app.priorityStyle === "simple" || row.priority !== "gray" ? root.priorityColor(row.priority) : root.mutedColor)

                            Text {
                                anchors.centerIn: parent
                                y: -1
                                text: row.done ? "✓" : ""
                                color: root.lightTheme ? "#333333" : "white"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: noteController.toggleTodo(index)
                            }
                        }

                        TextField {
                            id: todoEdit
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            property bool removedByEditor: false
                            text: model.text || ""
                            placeholderText: "新待办"
                            placeholderTextColor: root.mutedColor
                            selectByMouse: true
                            color: row.done ? root.mutedColor : root.textColor
                            font.pixelSize: 13
                            font.strikeout: row.done
                            leftPadding: 6
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            background: Item {}
                            Component.onCompleted: cursorPosition = 0
                            onTextChanged: if (!activeFocus) cursorPosition = 0
                            onActiveFocusChanged: if (!activeFocus) cursorPosition = 0

                            function finishEditing(createNext) {
                                if (removedByEditor) {
                                    return
                                }
                                if (text.trim().length === 0) {
                                    removedByEditor = true
                                    noteController.deleteTodo(row.modelIndex)
                                    return
                                }
                                noteController.commitTodoText(row.modelIndex, text)
                                if (createNext) {
                                    row.appRoot.addTodo(row.modelIndex)
                                }
                            }

                            onAccepted: {
                                finishEditing(true)
                            }
                            Keys.onReturnPressed: function(event) {
                                finishEditing(true)
                                event.accepted = true
                            }
                            Keys.onEnterPressed: function(event) {
                                finishEditing(true)
                                event.accepted = true
                            }
                            onEditingFinished: {
                                finishEditing(false)
                            }
                            Keys.onEscapePressed: function(event) {
                                if (text.trim().length === 0) {
                                    finishEditing(false)
                                } else {
                                    focus = false
                                }
                                event.accepted = true
                            }
                        }

                        Item {
                            Layout.preferredWidth: row.confirmingDelete ? 86 : 42
                            Layout.fillHeight: true

                            Rectangle {
                                id: priorityDot
                                width: 12
                                height: 12
                                radius: 6
                                anchors.right: deleteButton.left
                                anchors.rightMargin: row.confirmingDelete ? 8 : 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.priorityColor(row.priority)
                                opacity: row.menuVisible ? 0 : (row.activeRow ? 1 : 0)
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
                                anchors.verticalCenter: parent.verticalCenter
                                z: 20
                                width: row.confirmingDelete ? 50 : 18
                                height: 24
                                radius: row.confirmingDelete ? 12 : 4
                                color: row.confirmingDelete ? "#ff5f57" : "transparent"
                                opacity: row.activeRow ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                Image {
                                    id: trashIconMuted
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    visible: !row.confirmingDelete
                                    source: "qrc:/assets/trash-muted.svg"
                                    sourceSize.width: 14
                                    sourceSize.height: 14
                                    smooth: true
                                    opacity: deleteMouse.containsMouse ? 0 : 0.85
                                    Behavior on opacity { NumberAnimation { duration: 90 } }
                                }

                                Image {
                                    id: trashIconHover
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    visible: !row.confirmingDelete
                                    source: "qrc:/assets/trash-hover.svg"
                                    sourceSize.width: 14
                                    sourceSize.height: 14
                                    smooth: true
                                    opacity: deleteMouse.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 90 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.confirmingDelete
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
                                        if (row.confirmingDelete) {
                                            noteController.deleteTodo(index)
                                        } else {
                                            row.confirmingDelete = true
                                            deleteTimer.restart()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: row.confirmingDelete
                                anchors.fill: deleteButton
                                radius: deleteButton.radius
                                color: "transparent"
                                opacity: 0.9
                                layer.enabled: true
                            }

                            PriorityMenu {
                                id: priorityMenu
                                x: parent.width - width - 22
                                anchors.verticalCenter: parent.verticalCenter
                                z: 40
                                visible: row.menuVisible
                                lightTheme: root.lightTheme
                                currentPriority: row.priority
                                onPrioritySelected: function(priority) {
                                    noteController.setPriority(index, priority)
                                }
                            }

                            Timer {
                                id: deleteTimer
                                interval: 1000
                                onTriggered: row.confirmingDelete = false
                            }
                        }
                    }

                }

                ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 43
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 0

                Label {
                    text: noteController.completedCount + "/" + noteController.totalCount + " 完成"
                    color: root.mutedColor
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: noteController.createdDateText
                    color: root.mutedColor
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            id: resizeHandle
            width: 20
            height: 20
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "transparent"
            Canvas {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 2
                anchors.bottomMargin: 2
                width: 16
                height: 16
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = root.lightTheme ? Qt.rgba(0,0,0,0.3) : Qt.rgba(1,1,1,0.4)
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    var cx = 6
                    var cy = 6
                    ctx.beginPath()
                    ctx.arc(cx, cy, 5, 0, Math.PI / 2, false)
                    ctx.stroke()
                }
            }
            DragHandler {
                target: null
                acceptedButtons: Qt.LeftButton
                onActiveChanged: if (active && root.hostWindow) root.hostWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
            }
        }
    }

    Window {
        id: summaryTemplateWindow
        width: 520
        height: 430
        minimumWidth: 460
        minimumHeight: 360
        visible: root.summaryTemplateDialogOpen
        title: "调整总结模板"
        modality: Qt.NonModal
        flags: Qt.Window | Qt.FramelessWindowHint
        color: "transparent"
        property real dragStartScreenX: 0
        property real dragStartScreenY: 0
        property real dragStartWindowX: 0
        property real dragStartWindowY: 0
        onVisibleChanged: {
            if (visible) {
                root.centerSummaryTemplateWindow()
            }
        }
        onClosing: function(close) {
            close.accepted = false
            root.summaryTemplateDialogOpen = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            antialiasing: true
            color: root.lightTheme ? "#f4f4f4" : "#2f2f2f"
            clip: true
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.14)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        acceptedButtons: Qt.LeftButton
                        onPressed: function(mouse) {
                            var globalPos = mapToGlobal(mouse.x, mouse.y)
                            summaryTemplateWindow.dragStartScreenX = globalPos.x
                            summaryTemplateWindow.dragStartScreenY = globalPos.y
                            summaryTemplateWindow.dragStartWindowX = summaryTemplateWindow.x
                            summaryTemplateWindow.dragStartWindowY = summaryTemplateWindow.y
                            mouse.accepted = true
                        }
                        onPositionChanged: function(mouse) {
                            if (!pressed) {
                                return
                            }
                            var globalPos = mapToGlobal(mouse.x, mouse.y)
                            summaryTemplateWindow.x = Math.round(summaryTemplateWindow.dragStartWindowX + globalPos.x - summaryTemplateWindow.dragStartScreenX)
                            summaryTemplateWindow.y = Math.round(summaryTemplateWindow.dragStartWindowY + globalPos.y - summaryTemplateWindow.dragStartScreenY)
                            mouse.accepted = true
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: "调整总结模板"
                            color: root.textColor
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 6
                            color: closeTemplateMouse.containsMouse
                                   ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10))
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.mutedColor
                                font.pixelSize: 22
                            }

                            MouseArea {
                                id: closeTemplateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.summaryTemplateDialogOpen = false
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "用于“总结本窗口内容”的提示词"
                    color: root.mutedColor
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                TextArea {
                    id: summaryTemplateEdit
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.summaryTemplateDraft
                    color: root.textColor
                    placeholderText: "请输入总结提示词"
                    placeholderTextColor: root.mutedColor
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 14
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 14
                    bottomPadding: 14
                    background: Rectangle {
                        radius: 8
                        color: root.lightTheme ? "#ffffff" : "#3b3b3b"
                        border.width: 1
                        border.color: summaryTemplateEdit.activeFocus
                                      ? (root.lightTheme ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(1, 1, 1, 0.24))
                                      : (root.lightTheme ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.12))
                    }
                    onTextChanged: root.summaryTemplateDraft = text
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    spacing: 10

                    DialogButton {
                        label: "恢复默认"
                        width: 86
                        height: 34
                        onClicked: {
                            noteController.resetSummaryTemplate()
                            root.summaryTemplateDraft = noteController.summaryTemplate
                        }
                    }

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        label: "取消"
                        height: 34
                        onClicked: root.summaryTemplateDialogOpen = false
                    }

                    DialogButton {
                        label: "保存"
                        height: 34
                        primary: true
                        onClicked: {
                            noteController.summaryTemplate = root.summaryTemplateDraft
                            root.summaryTemplateDialogOpen = false
                            toast.show("总结模板已保存")
                        }
                    }
                }
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

    Timer {
        id: hideTimer
        interval: 300
        onTriggered: noteController.hide()
    }

    Timer {
        id: dragCommitTimer
        interval: 120
        repeat: false
        onTriggered: {
            var todoId = root.pendingDragTodoId
            var start = root.pendingDragStartIndex
            var target = root.pendingDragTargetIndex
            var contentY = root.pendingDragContentY
            var shouldMove = todoId.length > 0 && target >= 0
            if (shouldMove) {
                root.committingTodoMove = true
                if (start >= 0 && start < noteTodosModel.count && target >= 0 && target < noteTodosModel.count && start !== target) {
                    noteTodosModel.move(start, target, 1)
                }
                noteController.moveTodoById(todoId, target)
            }
            root.resetDragState()
            root.clearPendingDragCommit()
            todoList.interactive = true
            if (shouldMove) {
                root.restoreTodoContentY(contentY, 3)
            }
            Qt.callLater(function() {
                root.committingTodoMove = false
                root.syncNoteTodos(false)
            })
        }
    }

}
