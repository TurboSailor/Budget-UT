import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

// Home = the recording surface: balance on top, then the category tiles
// (expenses first, income below). Tapping a tile books a transaction in that
// category; holding one edits the category.
Item {
    id: root
    signal editTxRequested(var tx)
    signal settingsRequested()
    signal statsRequested()
    signal quickAddRequested(var category)
    signal categoryEditRequested(var category)
    signal categoryCreateRequested(bool income)

    property var todayItems: []
    property int todayExpense: 0
    property int todayIncome: 0

    readonly property int tileColumns: 4

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.height + units.gu(6)
        clip: true

        Column {
            id: contentCol
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.5)

            Item { width: 1; height: units.gu(0.5) }

            // Header: title + stats/settings shortcuts
            Item {
                width: parent.width
                height: units.gu(4.5)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "My Wallet"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(1)

                    Rectangle {
                        width: units.gu(4.5)
                        height: units.gu(4.5)
                        radius: width / 2
                        color: Theme.cardBackground
                        border.color: Theme.cardBorder
                        Text {
                            anchors.centerIn: parent
                            text: "📊"
                            font.pixelSize: units.dp(17)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.statsRequested()
                        }
                    }

                    Rectangle {
                        width: units.gu(4.5)
                        height: units.gu(4.5)
                        radius: width / 2
                        color: Theme.cardBackground
                        border.color: Theme.cardBorder
                        Text {
                            anchors.centerIn: parent
                            text: "⚙"
                            font.pixelSize: units.dp(19)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.settingsRequested()
                        }
                    }
                }
            }

            // Balance card
            Rectangle {
                width: parent.width
                height: units.gu(13)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(0.5)

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
                            MoneyLabel {
                                minor: AppState.wallets.incomeMinor
                                currency: AppState.wallets.system
                                kind: 2
                                font.pixelSize: Theme.fontSub
                            }
                        }

                        Row {
                            spacing: units.gu(0.6)
                            Text { text: "▼"; font.pixelSize: units.dp(11); color: Theme.expense; anchors.verticalCenter: parent.verticalCenter }
                            MoneyLabel {
                                minor: AppState.wallets.expenseMinor
                                currency: AppState.wallets.system
                                kind: 0
                                font.pixelSize: Theme.fontSub
                            }
                        }
                    }
                }
            }

            // ---- Expense tiles ----
            Item {
                width: parent.width
                height: units.gu(3)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Expense"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "hold a tile to edit"
                    font.pixelSize: Theme.fontMicro
                    color: Theme.textMuted
                }
            }

            Rectangle {
                width: parent.width
                height: expenseGrid.height + units.gu(2)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Grid {
                    id: expenseGrid
                    anchors.centerIn: parent
                    width: parent.width - units.gu(2)
                    columns: root.tileColumns

                    Repeater {
                        model: root.categoriesOf(false)
                        delegate: CategoryTile {
                            width: expenseGrid.width / root.tileColumns
                            category: modelData
                            onPicked: root.quickAddRequested(modelData)
                            onEdit: root.categoryEditRequested(modelData)
                        }
                    }

                    CategoryTile {
                        width: expenseGrid.width / root.tileColumns
                        isAdd: true
                        onPicked: root.categoryCreateRequested(false)
                    }
                }
            }

            // ---- Income tiles ----
            Item {
                width: parent.width
                height: units.gu(3)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Income"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }
            }

            Rectangle {
                width: parent.width
                height: incomeGrid.height + units.gu(2)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Grid {
                    id: incomeGrid
                    anchors.centerIn: parent
                    width: parent.width - units.gu(2)
                    columns: root.tileColumns

                    Repeater {
                        model: root.categoriesOf(true)
                        delegate: CategoryTile {
                            width: incomeGrid.width / root.tileColumns
                            category: modelData
                            onPicked: root.quickAddRequested(modelData)
                            onEdit: root.categoryEditRequested(modelData)
                        }
                    }

                    CategoryTile {
                        width: incomeGrid.width / root.tileColumns
                        isAdd: true
                        onPicked: root.categoryCreateRequested(true)
                    }
                }
            }

            // ---- Today ----
            Item {
                width: parent.width
                height: units.gu(3.5)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(1.2)

                    Text {
                        text: "-" + AppState.formatMoney(root.todayExpense, AppState.wallets.system)
                        font.pixelSize: Theme.fontSub
                        font.bold: true
                        color: Theme.expense
                        visible: root.todayExpense > 0
                    }
                    Text {
                        text: "+" + AppState.formatMoney(root.todayIncome, AppState.wallets.system)
                        font.pixelSize: Theme.fontSub
                        font.bold: true
                        color: Theme.income
                        visible: root.todayIncome > 0
                    }
                }
            }

            Column {
                width: parent.width
                spacing: units.gu(0.4)

                Repeater {
                    model: root.todayItems
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
                    visible: root.todayItems.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: "Nothing recorded today — tap a category above"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSub
                    }
                }
            }
        }
    }

    function categoriesOf(income) {
        var out = []
        for (var i = 0; i < AppState.categories.length; i++) {
            var c = AppState.categories[i]
            if (c.status === 0 && Boolean(c.isIncome) === income) out.push(c)
        }
        return out
    }

    function loadToday() {
        Api.get("/api/overview?date=" + AppState.todayDay, function(err, res) {
            if (err || !res) return
            todayExpense = res.expenseMinor || 0
            todayIncome = res.incomeMinor || 0
            todayItems = res.items || []
        })
    }

    Component.onCompleted: loadToday()

    Connections {
        target: AppState
        function onTxChanged() { root.loadToday() }
        function onDataRefreshed() { root.loadToday() }
    }
}
