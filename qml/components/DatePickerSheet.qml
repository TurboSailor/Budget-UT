import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

// Day picker used when recording a transaction on a past date.
// Month grid + Today/Yesterday shortcuts. Opens over the calling sheet.
Rectangle {
    id: root
    property string day: AppState.todayDay   // selected, "YYYY-MM-DD"
    property string viewMonth: AppState.selectedMonth
    property bool visibleSheet: false
    signal picked(string day)
    signal cancelled()

    color: "transparent"
    visible: visibleSheet

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - units.gu(4), units.gu(44))
        height: units.gu(52)
        radius: Theme.radiusCard
        color: Theme.cardBackground

        Column {
            anchors.fill: parent
            anchors.margins: units.gu(1.8)
            spacing: units.gu(1.2)

            Item {
                width: parent.width
                height: units.gu(4)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pick a date"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                MonthNavigator {
                    id: nav
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    month: root.viewMonth
                    longNames: false
                    onStepped: root.viewMonth = nav.shift(root.viewMonth, delta)
                }
            }

            // Quick shortcuts
            Row {
                width: parent.width
                spacing: units.gu(0.8)

                Repeater {
                    model: [
                        { label: "Today", offset: 0 },
                        { label: "Yesterday", offset: -1 },
                        { label: "2 days ago", offset: -2 }
                    ]
                    delegate: Rectangle {
                        property string target: root.dayWithOffset(modelData.offset)
                        width: (parent.width - units.gu(1.6)) / 3
                        height: units.gu(3.6)
                        radius: height / 2
                        color: root.day === target ? Theme.primary : "#F3F4F6"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontMicro
                            font.bold: root.day === target
                            color: Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.day = target
                                root.viewMonth = target.substring(0, 7)
                            }
                        }
                    }
                }
            }

            // Weekday header
            Row {
                width: parent.width
                height: units.gu(3)
                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    delegate: Text {
                        width: parent.width / 7
                        text: modelData
                        font.pixelSize: Theme.fontMicro
                        font.bold: true
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Day grid
            Grid {
                width: parent.width
                columns: 7
                spacing: units.gu(0.3)

                Repeater {
                    model: root.buildCells()
                    delegate: Rectangle {
                        width: (parent.width - units.gu(2)) / 7
                        height: units.gu(4.6)
                        radius: units.gu(0.8)
                        color: {
                            if (modelData.day === root.day) return Theme.primary
                            if (modelData.isToday) return "#FEF3C7"
                            return "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.dayNum
                            font.pixelSize: Theme.fontSub
                            font.bold: modelData.day === root.day || modelData.isToday
                            color: modelData.inMonth ? Theme.textPrimary : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.inMonth
                            onClicked: root.day = modelData.day
                        }
                    }
                }
            }

            Item { width: 1; height: units.gu(0.4) }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(1.5)

                Rectangle {
                    width: units.gu(14)
                    height: units.gu(4.5)
                    radius: Theme.radiusSmall
                    color: "#F3F4F6"
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Theme.fontBody
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }

                Rectangle {
                    width: units.gu(14)
                    height: units.gu(4.5)
                    radius: Theme.radiusSmall
                    color: Theme.primary
                    Text {
                        anchors.centerIn: parent
                        text: "Select"
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        color: Theme.primaryText
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.visibleSheet = false
                            root.picked(root.day)
                        }
                    }
                }
            }
        }
    }

    function open(current) {
        day = current || AppState.todayDay
        viewMonth = day.substring(0, 7)
        visibleSheet = true
    }

    function close() {
        visibleSheet = false
        root.cancelled()
    }

    function dayWithOffset(offset) {
        var p = AppState.todayDay.split("-")
        var d = new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
        d.setDate(d.getDate() + offset)
        return Qt.formatDate(d, "yyyy-MM-dd")
    }

    function buildCells() {
        var parts = viewMonth.split("-")
        var y = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10) - 1
        var startWeekday = new Date(y, m, 1).getDay()
        var daysInMonth = new Date(y, m + 1, 0).getDate()

        var cells = []
        for (var i = 0; i < startWeekday; i++) {
            cells.push({ dayNum: "", inMonth: false, day: "", isToday: false })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            var ds = y + "-" + (m + 1 < 10 ? "0" + (m + 1) : (m + 1)) + "-" + (d < 10 ? "0" + d : d)
            cells.push({
                dayNum: "" + d,
                inMonth: true,
                day: ds,
                isToday: ds === AppState.todayDay
            })
        }
        return cells
    }
}
