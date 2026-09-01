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
    property var editingBudget: null
    property bool showEditDialog: false
    property string editValStr: "0"

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

            // Header: Title + Add
            Row {
                width: parent.width
                height: 36

                Text {
                    text: "Budget"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 160; height: 1 }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 20
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
                spacing: 10

                // Monthly Card
                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 100
                    radius: Theme.radiusCard
                    color: "#FEF3C7" // Soft yellow/orange

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        Text {
                            text: "Monthly Budget"
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }

                        MoneyLabel {
                            minor: root.totalBudget
                            currency: AppState.wallets.system
                            colored: false
                            font.pixelSize: 20
                        }

                        Text {
                            text: "Spent: " + AppState.formatMoney(root.totalSpent, AppState.wallets.system)
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }
                }

                // Daily allowance card
                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 100
                    radius: Theme.radiusCard
                    color: "#EDE9FE" // Soft lavender

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        Text {
                            text: "Daily Budget"
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }

                        MoneyLabel {
                            minor: Math.round(root.totalBudget / 30)
                            currency: AppState.wallets.system
                            colored: false
                            font.pixelSize: 20
                        }

                        Text {
                            text: "per day allowance"
                            font.pixelSize: 10
                            color: Theme.textSecondary
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
                spacing: 8

                Repeater {
                    model: root.budgetStatuses
                    delegate: Rectangle {
                        width: parent.width
                        height: 72
                        radius: Theme.radiusCard
                        color: Theme.cardBackground
                        border.color: Theme.cardBorder

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openEdit(modelData.budget)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            CategoryIcon {
                                categoryId: modelData.budget.refId
                                size: 44
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 56 - amountCol.width - 12
                                spacing: 4

                                Text {
                                    text: AppState.categoryName(modelData.budget.refId)
                                    font.pixelSize: Theme.fontHeading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                // Progress bar
                                Rectangle {
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: "#F3F4F6"

                                    Rectangle {
                                        height: parent.height
                                        radius: 3
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
                                spacing: 2

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
                                    font.pixelSize: 10
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }

                // Empty / All categories setup
                Rectangle {
                    width: parent.width
                    height: 90
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    visible: root.budgetStatuses.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
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
            width: Math.min(parent.width - 48, 360)
            height: 220
            radius: Theme.radiusCard
            color: Theme.cardBackground

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

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
                    spacing: 12

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
            if (!err && res) {
                budgetStatuses = res;
                var total = 0;
                var spent = 0;
                for (var i = 0; i < res.length; i++) {
                    total += res[i].budget.value || 0;
                    spent += res[i].spentMinor || 0;
                }
                totalBudget = total;
                totalSpent = spent;
            }
        });
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
