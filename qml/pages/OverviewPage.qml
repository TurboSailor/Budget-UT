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
    property string activeFilter: "Month" // Today | Month | All

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.height + units.gu(6)
        clip: true

        Column {
            id: contentCol
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.5)

            Item { width: 1; height: units.gu(0.5) } // Top spacer

            // Top Header: Title + Gear
            Row {
                width: parent.width
                height: units.gu(4.5)

                Text {
                    text: "My Wallet"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - units.gu(22); height: 1 }

                Rectangle {
                    width: units.gu(4.5)
                    height: units.gu(4.5)
                    radius: width / 2
                    color: Theme.cardBackground
                    border.color: Theme.cardBorder
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        font.pixelSize: units.dp(20)
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
                height: units.gu(14)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(0.6)

                    Text {
                        text: "Total Balance"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    MoneyLabel {
                        minor: AppState.wallets.totalMinor
                        currency: AppState.wallets.system
                        colored: false
                        font.pixelSize: Theme.fontHero
                    }

                    Row {
                        spacing: units.gu(2.5)

                        Row {
                            spacing: units.gu(0.6)
                            Text { text: "▲"; font.pixelSize: units.dp(11); color: Theme.income; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Income:"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                            MoneyLabel {
                                minor: AppState.wallets.incomeMinor
                                currency: AppState.wallets.system
                                kind: 2
                                colored: true
                                font.pixelSize: Theme.fontSub
                            }
                        }

                        Row {
                            spacing: units.gu(0.6)
                            Text { text: "▼"; font.pixelSize: units.dp(11); color: Theme.expense; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Expense:"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                            MoneyLabel {
                                minor: AppState.wallets.expenseMinor
                                currency: AppState.wallets.system
                                kind: 0
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
                height: units.gu(25)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.4)
                    spacing: units.gu(0.6)

                    // Month navigator
                    Row {
                        width: parent.width
                        height: units.gu(3.5)

                        Text {
                            text: "Daily Activity"
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - units.gu(28); height: 1 }

                        Row {
                            spacing: units.gu(1)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "◀"
                                font.pixelSize: units.dp(14)
                                color: Theme.textSecondary
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -units.gu(0.8)
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
                                font.pixelSize: units.dp(14)
                                color: Theme.textSecondary
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -units.gu(0.8)
                                    onClicked: root.shiftMonth(1)
                                }
                            }
                        }
                    }

                    BarChart {
                        width: parent.width
                        height: units.gu(18)
                        days: root.calendarDays
                        selectedDay: AppState.selectedDay
                        onBarClicked: {
                            AppState.selectedDay = day;
                            root.loadTransactions();
                        }
                    }
                }
            }

            // Filter pills: Today | Month | All
            Row {
                width: parent.width
                height: units.gu(4)
                spacing: units.gu(0.8)

                Text {
                    text: "Transactions"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(24)
                }

                Row {
                    spacing: units.gu(0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: ["Today", "Month", "All"]
                        delegate: Rectangle {
                            property bool active: root.activeFilter === modelData
                            width: filterLbl.width + units.gu(2)
                            height: units.gu(3.2)
                            radius: height / 2
                            color: active ? Theme.primary : Theme.cardBackground
                            border.color: active ? Theme.primaryDark : Theme.cardBorder

                            Text {
                                id: filterLbl
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontMicro
                                font.bold: active
                                color: active ? Theme.primaryText : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeFilter = modelData;
                                    root.loadTransactions();
                                }
                            }
                        }
                    }
                }
            }

            // Transaction list
            Column {
                width: parent.width
                spacing: units.gu(0.4)

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
                    height: units.gu(10)
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
        function onTxChanged() {
            root.loadCalendar();
            root.loadTransactions();
        }
        function onDataRefreshed() {
            root.loadCalendar();
            root.loadTransactions();
        }
    }
}
