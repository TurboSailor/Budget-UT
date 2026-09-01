import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root
    signal editTxRequested(var tx)

    property string currentMonth: AppState.selectedMonth
    property string selectedDay: AppState.selectedDay
    property var monthDaysMap: ({}) // day -> {expenseMinor, incomeMinor, count}
    property var dayTransactions: []
    property int dayExpense: 0
    property int dayIncome: 0

    Flickable {
        anchors.fill: parent
        contentHeight: col.height + units.gu(6)
        clip: true

        Column {
            id: col
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.5)

            Item { width: 1; height: units.gu(0.5) } // Top spacer

            // Month Header. Anchored, not spacer-computed: long month names
            // used to push the ▶ arrow past the screen edge.
            Item {
                width: parent.width
                height: units.gu(4.5)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - nav.width - units.gu(1)
                    elide: Text.ElideRight
                    text: "Calendar"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                }

                MonthNavigator {
                    id: nav
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    month: root.currentMonth
                    longNames: true
                    onStepped: root.shiftMonth(delta)
                }
            }

            // Month Calendar Card
            Rectangle {
                width: parent.width
                height: units.gu(36)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.2)
                    spacing: units.gu(0.5)

                    // Weekday header row
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

                    // 6x7 days grid
                    Grid {
                        width: parent.width
                        columns: 7
                        spacing: units.gu(0.3)

                        Repeater {
                            model: root.buildMonthCells()
                            delegate: Rectangle {
                                width: (parent.width - units.gu(2)) / 7
                                height: units.gu(4.6)
                                radius: units.gu(0.8)
                                color: {
                                    if (modelData.day === root.selectedDay) return Theme.primary
                                    if (modelData.isToday) return "#FEF3C7"
                                    return "transparent"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: units.gu(0.2)

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.dayNum
                                        font.pixelSize: Theme.fontSub
                                        font.bold: modelData.day === root.selectedDay || modelData.isToday
                                        color: modelData.inMonth ? Theme.textPrimary : Theme.textMuted
                                    }

                                    // Dot indicator for transactions
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: units.gu(0.6)
                                        height: units.gu(0.6)
                                        radius: width / 2
                                        color: modelData.hasExpense ? Theme.expense : (modelData.hasIncome ? Theme.income : "transparent")
                                        visible: modelData.hasTx
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.inMonth
                                    onClicked: {
                                        root.selectedDay = modelData.day
                                        AppState.selectedDay = modelData.day
                                        root.loadDay()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Selected Day Summary
            Row {
                width: parent.width
                height: units.gu(3.5)

                Text {
                    text: root.selectedDay === AppState.todayDay ? "Today (" + root.selectedDay + ")" : root.selectedDay
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(20)
                }

                Row {
                    spacing: units.gu(1.2)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "-" + AppState.formatMoney(root.dayExpense, AppState.wallets.system)
                        color: Theme.expense
                        font.pixelSize: Theme.fontSub
                        font.bold: true
                        visible: root.dayExpense > 0
                    }
                    Text {
                        text: "+" + AppState.formatMoney(root.dayIncome, AppState.wallets.system)
                        color: Theme.income
                        font.pixelSize: Theme.fontSub
                        font.bold: true
                        visible: root.dayIncome > 0
                    }
                }
            }

            // Day's transaction list
            Column {
                width: parent.width
                spacing: units.gu(0.4)

                Repeater {
                    model: root.dayTransactions
                    delegate: TransactionRow {
                        width: parent.width
                        tx: modelData
                        onClicked: root.editTxRequested(modelData)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: units.gu(8)
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    visible: root.dayTransactions.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No transactions on this day"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
    }

    function monthTitle() {
        var parts = currentMonth.split("-")
        if (parts.length < 2) return currentMonth
        var monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        var idx = parseInt(parts[1], 10) - 1
        return (idx >= 0 && idx < 12 ? monthNames[idx] : parts[1]) + " " + parts[0]
    }

    function shiftMonth(dir) {
        var parts = currentMonth.split("-")
        var y = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10) + dir
        if (m < 1) { m = 12; y--; }
        if (m > 12) { m = 1; y++; }
        currentMonth = y + "-" + (m < 10 ? "0" + m : m)
        loadMonth()
    }

    function buildMonthCells() {
        var parts = currentMonth.split("-")
        var y = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10) - 1
        var firstDay = new Date(y, m, 1)
        var startWeekday = firstDay.getDay() // 0 = Sun
        var daysInMonth = new Date(y, m + 1, 0).getDate()

        var cells = []
        // Leading padding days
        for (var i = 0; i < startWeekday; i++) {
            cells.push({ dayNum: "", inMonth: false, hasTx: false, day: "", isToday: false, hasExpense: false, hasIncome: false })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            var dayStr = y + "-" + (m + 1 < 10 ? "0" + (m + 1) : (m + 1)) + "-" + (d < 10 ? "0" + d : d)
            var st = monthDaysMap[dayStr] || null
            var hasExp = st && st.expenseMinor > 0
            var hasInc = st && st.incomeMinor > 0
            cells.push({
                dayNum: "" + d,
                inMonth: true,
                day: dayStr,
                isToday: dayStr === AppState.todayDay,
                hasTx: (hasExp || hasInc),
                hasExpense: hasExp,
                hasIncome: hasInc
            })
        }
        return cells
    }

    function loadMonth() {
        Api.get("/api/calendar?month=" + currentMonth, function(err, res) {
            if (!err && res && res.days) {
                var map = {}
                for (var i = 0; i < res.days.length; i++) {
                    map[res.days[i].day] = res.days[i]
                }
                monthDaysMap = map
            }
        })
    }

    function loadDay() {
        Api.get("/api/overview?date=" + selectedDay, function(err, res) {
            if (!err && res) {
                dayExpense = res.expenseMinor || 0
                dayIncome = res.incomeMinor || 0
                dayTransactions = res.items || []
            }
        })
    }

    Component.onCompleted: {
        loadMonth()
        loadDay()
    }

    Connections {
        target: AppState
        function onTxChanged() {
            root.loadMonth()
            root.loadDay()
        }
    }
}
