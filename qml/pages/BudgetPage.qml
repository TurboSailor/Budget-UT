import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root

    property var budgetStatuses: []
    property int totalBudget: 0
    property int totalSpent: 0
    property int totalLeft: 0
    // Budgets carry their own currency (the source ledger budgets in RUB);
    // the summary uses it when every budget agrees, else the system currency.
    property string budgetCurrency: AppState.wallets.system
    property var editingBudget: null
    property bool showEditDialog: false
    property string editValStr: "0"

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

            // Header: Title + Add
            Row {
                width: parent.width
                height: units.gu(4.5)

                Text {
                    text: "Budget"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - units.gu(16); height: 1 }

                Rectangle {
                    width: units.gu(4)
                    height: units.gu(4)
                    radius: width / 2
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: units.dp(24)
                        font.bold: true
                        color: Theme.primaryText
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openNewBudget()
                    }
                }
            }

            // Top Budget Cards (Monthly & Daily)
            Row {
                width: parent.width
                spacing: units.gu(1.2)

                // Monthly Card: budget, what is already spent, what remains
                Rectangle {
                    width: (parent.width - units.gu(1.2)) / 2
                    height: units.gu(15)
                    radius: Theme.radiusCard
                    color: "#FEF3C7" // Soft yellow/orange

                    Column {
                        anchors.fill: parent
                        anchors.margins: units.gu(1.6)
                        spacing: units.gu(0.4)

                        Text {
                            text: "Monthly Budget"
                            font.pixelSize: Theme.fontSub
                            color: Theme.textSecondary
                        }

                        MoneyLabel {
                            minor: root.totalBudget
                            currency: root.budgetCurrency
                            colored: false
                            font.pixelSize: Theme.fontTitle
                        }

                        Rectangle {
                            width: parent.width
                            height: units.gu(0.7)
                            radius: height / 2
                            color: "#FFFFFF"

                            Rectangle {
                                height: parent.height
                                radius: height / 2
                                width: root.totalBudget > 0
                                       ? parent.width * Math.min(1, root.totalSpent / root.totalBudget)
                                       : 0
                                color: root.totalLeft < 0 ? Theme.expense : Theme.primaryDark
                            }
                        }

                        Text {
                            text: "Spent " + AppState.formatMoney(root.totalSpent, root.budgetCurrency)
                            font.pixelSize: Theme.fontMicro
                            color: Theme.textSecondary
                        }

                        Text {
                            text: (root.totalLeft < 0 ? "Over by " : "Left ")
                                  + AppState.formatMoney(Math.abs(root.totalLeft), root.budgetCurrency)
                            font.pixelSize: Theme.fontMicro
                            font.bold: true
                            color: root.totalLeft < 0 ? Theme.expense : Theme.income
                        }
                    }
                }

                // Daily allowance: what is still safe to spend per remaining day
                Rectangle {
                    width: (parent.width - units.gu(1.2)) / 2
                    height: units.gu(15)
                    radius: Theme.radiusCard
                    color: "#EDE9FE" // Soft lavender

                    Column {
                        anchors.fill: parent
                        anchors.margins: units.gu(1.6)
                        spacing: units.gu(0.4)

                        Text {
                            text: "Daily Budget"
                            font.pixelSize: Theme.fontSub
                            color: Theme.textSecondary
                        }

                        MoneyLabel {
                            minor: root.dailyAllowance()
                            currency: root.budgetCurrency
                            colored: false
                            font.pixelSize: Theme.fontTitle
                        }

                        Text {
                            text: root.daysLeftInMonth() + " days left this month"
                            font.pixelSize: Theme.fontMicro
                            color: Theme.textSecondary
                        }

                        Text {
                            text: "Plan " + AppState.formatMoney(root.planPerDay(), root.budgetCurrency) + "/day"
                            font.pixelSize: Theme.fontMicro
                            color: Theme.textMuted
                        }
                    }
                }
            }

            // Section label
            Text {
                text: "Category Budgets"
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.textPrimary
            }

            // Category budget rows
            Column {
                width: parent.width
                spacing: units.gu(1)

                Repeater {
                    model: root.budgetStatuses
                    delegate: Rectangle {
                        width: parent.width
                        height: units.gu(9.5)
                        radius: Theme.radiusCard
                        color: Theme.cardBackground
                        border.color: Theme.cardBorder

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openEdit(modelData.budget)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: units.gu(1.4)
                            spacing: units.gu(1.4)

                            CategoryIcon {
                                categoryId: modelData.budget.refId
                                size: units.gu(5.5)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - units.gu(7) - amountCol.width - units.gu(1.5)
                                spacing: units.gu(0.5)

                                Text {
                                    text: AppState.categoryName(modelData.budget.refId)
                                    font.pixelSize: Theme.fontHeading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                // Progress bar
                                Rectangle {
                                    width: parent.width
                                    height: units.gu(0.8)
                                    radius: height / 2
                                    color: "#F3F4F6"

                                    Rectangle {
                                        height: parent.height
                                        radius: height / 2
                                        width: {
                                            if (modelData.budget.value <= 0) return 0;
                                            var pct = modelData.spentMinor / modelData.budget.value;
                                            if (pct > 1.0) pct = 1.0;
                                            return parent.width * pct;
                                        }
                                        color: {
                                            if (modelData.spentMinor > modelData.budget.value) return Theme.expense;
                                            return AppState.categoryColor(modelData.budget.refId, Theme.accent);
                                        }
                                    }
                                }

                                Text {
                                    text: AppState.formatMoney(modelData.leftMinor, modelData.budget.currency) + " left"
                                    font.pixelSize: Theme.fontSub
                                    color: modelData.leftMinor < 0 ? Theme.expense : Theme.textSecondary
                                }
                            }

                            Column {
                                id: amountCol
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: units.gu(0.2)

                                Text {
                                    anchors.right: parent.right
                                    text: AppState.formatMoney(modelData.budget.value, modelData.budget.currency)
                                    font.pixelSize: Theme.fontHeading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: "per month"
                                    font.pixelSize: Theme.fontMicro
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }

                // Empty / All categories setup
                Rectangle {
                    width: parent.width
                    height: units.gu(11)
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    visible: root.budgetStatuses.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.6)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No category budgets set"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontBody
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Tap + above to allocate monthly budgets"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSub
                        }
                    }
                }
            }
        }
    }

    // Quick Edit Dialog
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.showEditDialog

        MouseArea {
            anchors.fill: parent
            onClicked: root.showEditDialog = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - units.gu(4), units.gu(42))
            height: units.gu(26)
            radius: Theme.radiusCard
            color: Theme.cardBackground

            Column {
                anchors.fill: parent
                anchors.margins: units.gu(2)
                spacing: units.gu(1.5)

                Text {
                    text: root.editingBudget ? "Set Budget: " + AppState.categoryName(root.editingBudget.refId) : "New Budget"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                TextField {
                    id: budgetInput
                    width: parent.width
                    placeholderText: "Monthly amount (e.g. 500)"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.editValStr
                    onTextChanged: root.editValStr = text
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1.5)

                    Button {
                        text: "Cancel"
                        onClicked: root.showEditDialog = false
                    }

                    Button {
                        text: "Save"
                        color: Theme.primary
                        onClicked: root.saveBudget()
                    }
                }
            }
        }
    }

    function loadBudgets() {
        Api.get("/api/budgets/status", function(err, res) {
            if (err || !res) return;
            budgetStatuses = res;

            // Pick the display currency: the shared one if every budget agrees,
            // otherwise fall back to the system currency and convert into it.
            var cur = "";
            var mixed = false;
            for (var i = 0; i < res.length; i++) {
                var c = res[i].budget.currency || AppState.wallets.system;
                if (cur === "") cur = c;
                else if (cur !== c) mixed = true;
            }
            if (cur === "" || mixed) cur = AppState.wallets.system;
            budgetCurrency = cur;

            var rateTarget = AppState.rateOf(cur);
            var total = 0;
            var spent = 0;
            for (var j = 0; j < res.length; j++) {
                var b = res[j].budget;
                var bc = b.currency || AppState.wallets.system;
                var k = (bc === cur) ? 1 : (rateTarget / AppState.rateOf(bc));
                total += Math.round((b.value || 0) * k);
                spent += Math.round((res[j].spentMinor || 0) * k);
            }
            totalBudget = total;
            totalSpent = spent;
            totalLeft = total - spent;
        });
    }

    function daysInMonth() {
        var p = AppState.todayDay.split("-");
        return new Date(parseInt(p[0], 10), parseInt(p[1], 10), 0).getDate();
    }

    function daysLeftInMonth() {
        var p = AppState.todayDay.split("-");
        return Math.max(1, daysInMonth() - parseInt(p[2], 10) + 1);
    }

    // What is still safe to spend per remaining day of the period.
    function dailyAllowance() {
        if (totalLeft <= 0) return 0;
        return Math.round(totalLeft / daysLeftInMonth());
    }

    // The flat plan figure: budget spread evenly across the whole month.
    function planPerDay() {
        return Math.round(totalBudget / daysInMonth());
    }

    function openEdit(b) {
        editingBudget = b;
        editValStr = ((b.value || 0) / 100).toFixed(0);
        showEditDialog = true;
    }

    function openNewBudget() {
        if (AppState.categories.length === 0) return;
        editingBudget = {
            id: "",
            scope: "category",
            refId: AppState.categories[0].id,
            period: 3,
            value: 0,
            currency: AppState.wallets.system || "USD"
        };
        editValStr = "100";
        showEditDialog = true;
    }

    function saveBudget() {
        if (!editingBudget) return;
        var val = parseFloat(editValStr) || 0;
        var minor = Math.round(val * 100);
        editingBudget.value = minor;

        if (editingBudget.id) {
            Api.put("/api/budgets/" + editingBudget.id, editingBudget, function(err, res) {
                showEditDialog = false;
                loadBudgets();
                AppState.reload();
            });
        } else {
            Api.post("/api/budgets", editingBudget, function(err, res) {
                showEditDialog = false;
                loadBudgets();
                AppState.reload();
            });
        }
    }

    Component.onCompleted: loadBudgets()

    Connections {
        target: AppState
        function onTxChanged() { root.loadBudgets(); }
        function onDataRefreshed() { root.loadBudgets(); }
    }
}
