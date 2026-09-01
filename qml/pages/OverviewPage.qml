import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root
    signal editTxRequested(var tx)
    signal settingsRequested()

    property string currentMonth: AppState.selectedMonth
    property var calendarDays: []
    property var transactions: []
    property string activeFilter: "Month" // Today | Week | Month | Year
    property int filterExpense: 0
    property int filterIncome: 0

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.height + 40
        clip: true

        Column {
            id: contentCol
            width: Math.min(parent.width - 24, 520)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            topPadding: 12

            // Top Header: Title + Gear
            Row {
                width: parent.width
                height: 36

                Text {
                    text: "My Wallet"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 200; height: 1 }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: Theme.cardBackground
                    border.color: Theme.cardBorder
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.settingsRequested()
                    }
                }
            }

            // Total Balance Card
            Rectangle {
                width: parent.width
                height: 110
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Text {
                        text: "Total Balance"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    MoneyLabel {
                        minor: AppState.wallets.totalMinor
                        currency: AppState.wallets.system
                        colored: false
                        font.pixelSize: Theme.fontTitleLarge
                    }

                    Row {
                        spacing: 20
                        topPadding: 2

                        Row {
                            spacing: 4
                            Text { text: "▲"; font.pixelSize: 10; color: Theme.income; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Income:"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                            MoneyLabel {
                                minor: AppState.wallets.incomeMinor
                                currency: AppState.wallets.system
                                isIncome: true
                                colored: true
                                font.pixelSize: Theme.fontSub
                            }
                        }

                        Row {
                            spacing: 4
                            Text { text: "▼"; font.pixelSize: 10; color: Theme.expense; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Expense:"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                            MoneyLabel {
                                minor: AppState.wallets.expenseMinor
                                currency: AppState.wallets.system
                                isIncome: false
                                colored: true
                                font.pixelSize: Theme.fontSub
                            }
                        }
                    }
                }
            }

            // Statistics / Month Bar Chart Card
            Rectangle {
                width: parent.width
                height: 200
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // Month navigator
                    Row {
                        width: parent.width
                        height: 28

                        Text {
                            text: "Daily Activity"
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - 240; height: 1 }

                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "◀"
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.shiftMonth(-1)
                                }
                            }

                            Text {
                                text: root.formatMonthHeader(root.currentMonth)
                                font.pixelSize: Theme.fontSub
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "▶"
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.shiftMonth(1)
                                }
                            }
                        }
                    }

                    BarChart {
                        width: parent.width
                        height: 145
                        days: root.calendarDays
                        selectedDay: AppState.selectedDay
                        onBarClicked: {
                            AppState.selectedDay = day;
                            root.loadTransactions();
                        }
                    }
                }
            }

            // Filter pills: Today | Week | Month | Year
            Row {
                width: parent.width
                height: 32
                spacing: 6

                Text {
                    text: "Transactions"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 220
                }

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    FilterPill { text: "Today"; active: root.activeFilter === "Today"; onClicked: { root.activeFilter = "Today"; root.loadTransactions(); } }
                    FilterPill { text: "Month"; active: root.activeFilter === "Month"; onClicked: { root.activeFilter = "Month"; root.loadTransactions(); } }
                    FilterPill { text: "All"; active: root.activeFilter === "All"; onClicked: { root.activeFilter = "All"; root.loadTransactions(); } }
                }
            }

            // Transaction list
            Column {
                width: parent.width
                spacing: 0

                Repeater {
                    model: root.transactions
                    delegate: TransactionRow {
                        width: parent.width
                        tx: modelData
                        onClicked: root.editTxRequested(modelData)
                    }
                }

                // Empty state
                Rectangle {
                    width: parent.width
                    height: 80
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    visible: root.transactions.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No transactions recorded"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
    }

    component FilterPill: Rectangle {
        property string text: ""
        property bool active: false
        signal clicked()

        width: lbl.width + 16
        height: 26
        radius: 13
        color: active ? Theme.primary : Theme.cardBackground
        border.color: active ? Theme.primaryDark : Theme.cardBorder

        Text {
            id: lbl
            anchors.centerIn: parent
            text: parent.text
            font.pixelSize: 11
            font.bold: active
            color: active ? Theme.primaryText : Theme.textSecondary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    function formatMonthHeader(m) {
        if (!m) return "";
        var parts = m.split("-");
        if (parts.length < 2) return m;
        var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var idx = parseInt(parts[1], 10) - 1;
        var name = (idx >= 0 && idx < 12) ? monthNames[idx] : parts[1];
        return name + " " + parts[0];
    }

    function shiftMonth(dir) {
        var parts = currentMonth.split("-");
        var y = parseInt(parts[0], 10);
        var m = parseInt(parts[1], 10) + dir;
        if (m < 1) { m = 12; y--; }
        if (m > 12) { m = 1; y++; }
        currentMonth = y + "-" + (m < 10 ? "0" + m : m);
        loadCalendar();
        loadTransactions();
    }

    function loadCalendar() {
        Api.get("/api/calendar?month=" + currentMonth, function(err, res) {
            if (!err && res && res.days) {
                calendarDays = res.days;
            }
        });
    }

    function loadTransactions() {
        var q = "/api/tx?limit=60";
        if (activeFilter === "Today") {
            q += "&from=" + AppState.todayDay + "&to=" + AppState.todayDay;
        } else if (activeFilter === "Month") {
            var y = currentMonth.split("-")[0];
            var m = currentMonth.split("-")[1];
            q += "&from=" + currentMonth + "-01&to=" + currentMonth + "-31";
        }
        Api.get(q, function(err, res) {
            if (!err && res && res.items) {
                transactions = res.items;
            }
        });
    }

    Component.onCompleted: {
        loadCalendar();
        loadTransactions();
    }

    Connections {
        target: AppState
        onTxChanged: {
            loadCalendar();
            loadTransactions();
        }
        onDataRefreshed: {
            loadCalendar();
            loadTransactions();
        }
    }
}
