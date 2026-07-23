import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import org.deepin.dtk 1.0 as D

QQC.Popup {
    id: dialog

    property var appObject
    property bool lightTheme: true
    property string pendingNoteId: ""
    property date selectedDate: new Date()
    property int displayYear: selectedDate.getFullYear()
    property int displayMonth: selectedDate.getMonth()

    signal syncCompleted(string message)

    width: 440
    height: 462
    modal: true
    focus: true
    padding: 0
    closePolicy: QQC.Popup.CloseOnEscape
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    function openForNote(noteId) {
        pendingNoteId = noteId
        var today = new Date()
        selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        displayYear = selectedDate.getFullYear()
        displayMonth = selectedDate.getMonth()
        open()
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function mondayOffset(year, month) {
        return (new Date(year, month, 1).getDay() + 6) % 7
    }

    function dateForIndex(index) {
        var day = index - mondayOffset(displayYear, displayMonth) + 1
        return new Date(displayYear, displayMonth, day)
    }

    function sameDay(first, second) {
        return first.getFullYear() === second.getFullYear()
                && first.getMonth() === second.getMonth()
                && first.getDate() === second.getDate()
    }

    function twoDigits(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function isoDate(value) {
        return value.getFullYear() + "-" + twoDigits(value.getMonth() + 1)
                + "-" + twoDigits(value.getDate())
    }

    function changeMonth(delta) {
        var next = new Date(displayYear, displayMonth + delta, 1)
        displayYear = next.getFullYear()
        displayMonth = next.getMonth()
    }

    QQC.Overlay.modal: Rectangle {
        color: "#660f172a"
    }

    background: Rectangle {
        radius: 14
        color: dialog.lightTheme ? "#ffffff" : "#252629"
        border.width: 1
        border.color: dialog.lightTheme ? "#d6dee8" : "#46484d"
    }

    contentItem: Item {
        QQC.Label {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 19
            text: "选择同步日期"
            color: dialog.lightTheme ? "#1f2937" : "#f1f3f5"
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        // D.WindowButton requires a standalone Window. Match its DTK dialog
        // metrics here while keeping this modal attached to the main window.
        D.IconButton {
            id: closeButton
            anchors.top: parent.top
            anchors.right: parent.right

            implicitWidth: 50
            implicitHeight: 50
            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0
            icon.name: "window_close"
            icon.width: 50
            icon.height: 50
            Accessible.name: "关闭"
            onClicked: dialog.close()

            background: Shape {
                ShapePath {
                    fillColor: closeButton.down
                               ? (dialog.lightTheme
                                  ? Qt.rgba(0, 0, 0, 0.15)
                                  : Qt.rgba(1, 1, 1, 0.15))
                               : (closeButton.hovered
                                  ? (dialog.lightTheme
                                     ? Qt.rgba(0, 0, 0, 0.10)
                                     : Qt.rgba(1, 1, 1, 0.10))
                                  : "transparent")
                    strokeWidth: 0
                    startX: 0
                    startY: 0
                    PathLine { x: 36; y: 0 }
                    PathQuad { x: 50; y: 14; controlX: 50; controlY: 0 }
                    PathLine { x: 50; y: 50 }
                    PathLine { x: 0; y: 50 }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        Rectangle {
            x: 0
            y: 63
            width: parent.width
            height: 1
            color: dialog.lightTheme ? "#e8edf3" : "#3c3e43"
        }

        Rectangle {
            id: calendarCard
            x: 24
            y: 82
            width: 392
            height: 306
            radius: 10
            color: "transparent"
            border.width: 0

            D.IconButton {
                id: previousMonthButton
                x: 16
                y: 12
                icon.name: "arrow_ordinary_left"
                Accessible.name: "上个月"
                onClicked: dialog.changeMonth(-1)
            }

            QQC.Label {
                x: 112
                y: 18
                width: 168
                height: 24
                text: dialog.displayYear + "年" + (dialog.displayMonth + 1) + "月"
                color: dialog.lightTheme ? "#263244" : "#f1f3f5"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            D.IconButton {
                id: nextMonthButton
                x: 340
                y: 12
                icon.name: "arrow_ordinary_right"
                Accessible.name: "下个月"
                onClicked: dialog.changeMonth(1)
            }

            GridLayout {
                x: 16
                y: 58
                width: 360
                columns: 7
                columnSpacing: 4
                rowSpacing: 2

                Repeater {
                    model: ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

                    delegate: QQC.Label {
                        required property string modelData
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 28
                        text: modelData
                        color: dialog.lightTheme ? "#7b8797" : "#aeb5be"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: 42

                    delegate: QQC.AbstractButton {
                        id: dayButton
                        required property int index
                        property date cellDate: dialog.dateForIndex(index)
                        property bool currentMonth: cellDate.getMonth() === dialog.displayMonth
                                                    && cellDate.getFullYear() === dialog.displayYear
                        property bool selected: dialog.sameDay(cellDate, dialog.selectedDate)

                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 30

                        onClicked: {
                            dialog.selectedDate = new Date(cellDate.getFullYear(),
                                                           cellDate.getMonth(),
                                                           cellDate.getDate())
                            if (!currentMonth) {
                                dialog.displayYear = cellDate.getFullYear()
                                dialog.displayMonth = cellDate.getMonth()
                            }
                        }

                        background: Rectangle {
                            radius: 15
                            color: dayButton.selected
                                   ? "#4d89f5"
                                   : (dayButton.hovered
                                      ? (dialog.lightTheme ? "#edf3fc" : "#3d4653")
                                      : "transparent")
                        }

                        contentItem: QQC.Label {
                            text: dayButton.cellDate.getDate()
                            color: dayButton.selected
                                   ? "#ffffff"
                                   : (dayButton.currentMonth
                                      ? (dialog.lightTheme ? "#334155" : "#e7e9ec")
                                      : (dialog.lightTheme ? "#a8b0bb" : "#747b84"))
                            font.pixelSize: 13
                            font.weight: dayButton.selected ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            x: 0
            y: 400
            width: parent.width
            height: 1
            color: dialog.lightTheme ? "#e8edf3" : "#3c3e43"
        }

        D.Button {
            id: cancelButton
            x: 220
            y: 414
            width: 88
            height: 36
            text: "取消"
            onClicked: dialog.close()
        }

        D.RecommandButton {
            id: syncButton
            x: 320
            y: 414
            width: 96
            height: 36
            text: "马上同步"
            enabled: dialog.pendingNoteId.length > 0

            onClicked: {
                var message = dialog.appObject.syncNoteTodosToSystemCalendarOnDate(
                            dialog.pendingNoteId, dialog.isoDate(dialog.selectedDate))
                dialog.close()
                dialog.syncCompleted(message)
            }
        }
    }
}
