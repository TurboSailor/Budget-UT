import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root

    property string period: "Month" // Month | Year | All
    property var statRows: []
    property int totalExpense: 0
    property int totalIncome: 0

    Flickable {
        anchors.fill: parent
        contentHeight: col.height + 40
        clip: true

        Column {
            id: col
            width: Math.min(parent.width - 24, 520)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Item { width: 1; height: 4 } // Top spacer

            // Header
            Text {
                text: "Statistics"
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textPrimary
            }

            // Period selector
            Rectangle {
                width: parent.width
                height: 36
                radius: 18
                color: "#EEF0F5"

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: [
                            { key: "Month", label: "This Month" },
                            { key: "Year", label: "This Year" },
                            { key: "All", label: "All Time" }
                        ]
                        delegate: Rectangle {
                            property bool active: root.period === modelData.key
                            width: parent.width / 3
                            height: parent.height
                            radius: 18
                            color: active ? Theme.cardBackground : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11
                                font.bold: active
                                color: active ? Theme.textPrimary : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.period = modelData.key;
                                    root.loadStats();
                                }
                            }
                        }
                    }
                }
            }

            // Overview Summary Card
            Rectangle {
                width: parent.width
                height: 86
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Row {
                    anchors.fill: parent
                    anchors.margins: 14

                    Column {
                        width: parent.width / 2
                        spacing: 2
                        Text { text: "Total Expense"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                        MoneyLabel {
                            minor: root.totalExpense
                            currency: AppState.wallets.system
                            isIncome: false
                            colored: true
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        width: parent.width / 2
                        spacing: 2
                        Text { text: "Total Income"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                        MoneyLabel {
                            minor: root.totalIncome
                            currency: AppState.wallets.system
                            isIncome: true
                            colored: true
                            font.pixelSize: 20
                        }
                    }
                }
            }

            // Category breakdown list
            Text {
                text: "Spending by Category"
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.textPrimary
            }

            Column {
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.statRows
                    delegate: Rectangle {
                        width: parent.width
                        height: 60
                        radius: Theme.radiusCard
                        color: Theme.cardBackground
                        border.color: Theme.cardBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Category icon
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: modelData.color ? (modelData.color.indexOf("#") === 0 ? modelData.color : "#" + modelData.color) : Theme.primary
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: AppState.categoryGlyph(modelData.icon, modelData.label)
                                    font.pixelSize: 18
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 50 - amtCol.width - 10
                                spacing: 4

                                Row {
                                    width: parent.width
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: Theme.fontHeading
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }
                                    Item { width: 8; height: 1 }
                                    Text {
                                        text: modelData.count + " tx"
                                        font.pixelSize: Theme.fontSub
                                        color: Theme.textMuted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Percentage bar
                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: "#F3F4F6"

                                    Rectangle {
                                        height: parent.height
                                        radius: 2
                                        width: root.totalExpense > 0 ? (parent.width * (modelData.expenseMinor / root.totalExpense)) : 0
                                        color: modelData.color ? (modelData.color.indexOf("#") === 0 ? modelData.color : "#" + modelData.color) : Theme.accent
                                    }
                                }
                            }

                            Column {
                                id: amtCol
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    anchors.right: parent.right
                                    text: AppState.formatMoney(modelData.expenseMinor, AppState.wallets.system)
                                    font.pixelSize: Theme.fontHeading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: root.totalExpense > 0 ? ((modelData.expenseMinor / root.totalExpense) * 100).toFixed(1) + "%" : "0%"
                                    font.pixelSize: 10
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    width: parent.width
                    height: 80
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    visible: root.statRows.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No expenses in this period"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
    }

    function loadStats() {
        var today = AppState.todayDay;
        var parts = today.split("-");
        var from = "2020-01-01";
        var to = today;

        if (period === "Month") {
            from = parts[0] + "-" + parts[1] + "-01";
        } else if (period === "Year") {
            from = parts[0] + "-01-01";
        }

        Api.get("/api/stats?from=" + from + "&to=" + to + "&group=category", function(err, res) {
            if (!err && res) {
                statRows = res;
                var exp = 0;
                var inc = 0;
                for (var i = 0; i < res.length; i++) {
                    exp += res[i].expenseMinor || 0;
                    inc += res[i].incomeMinor || 0;
                }
                totalExpense = exp;
                totalIncome = inc;
            }
        });
    }

    Component.onCompleted: loadStats()
    Connections {
        target: AppState
        function onTxChanged() { root.loadStats(); }
    }
}
