import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root

    property bool showAddDialog: false
    property string newName: ""
    property string newCurrency: AppState.wallets.system || "USD"
    property string newInitialBalance: "0"
    property int newKind: 0 // 0: Debit, 1: Credit, 2: Custom

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
                    text: "Accounts"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 180; height: 1 }

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
                        onClicked: root.showAddDialog = true
                    }
                }
            }

            // Total Net Worth Card
            Rectangle {
                width: parent.width
                height: 100
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Text {
                        text: "Net Assets"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    MoneyLabel {
                        minor: AppState.wallets.totalMinor
                        currency: AppState.wallets.system
                        colored: false
                        font.pixelSize: Theme.fontTitleLarge
                    }

                    Text {
                        text: "Converted to " + (AppState.wallets.system || "USD")
                        font.pixelSize: 10
                        color: Theme.textMuted
                    }
                }
            }

            // Grouped Accounts List
            Repeater {
                model: root.buildGroupedSections()
                delegate: Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: modelData.groupName
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: modelData.accounts
                            delegate: Rectangle {
                                width: parent.width
                                height: 60
                                radius: Theme.radiusCard
                                color: Theme.cardBackground
                                border.color: Theme.cardBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // Account colored pill / icon
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: modelData.color ? (modelData.color.indexOf("#") === 0 ? modelData.color : "#" + modelData.color) : Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.kind === 2 ? "📊" : (modelData.kind === 1 ? "💳" : "💵")
                                            font.pixelSize: 16
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 48 - balCol.width - 12
                                        spacing: 2

                                        Text {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontHeading
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.kind === 1 ? "Credit Card" : (modelData.kind === 2 ? "Investment / Other" : "Debit / Cash")
                                            font.pixelSize: Theme.fontSub
                                            color: Theme.textSecondary
                                        }
                                    }

                                    Column {
                                        id: balCol
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            anchors.right: parent.right
                                            text: AppState.formatMoney(modelData.balance, modelData.currency)
                                            font.pixelSize: Theme.fontHeading
                                            font.bold: true
                                            color: modelData.balance < 0 ? Theme.expense : Theme.textPrimary
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            text: modelData.currency
                                            font.pixelSize: 10
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Add Account Dialog
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.showAddDialog

        MouseArea {
            anchors.fill: parent
            onClicked: root.showAddDialog = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 380)
            height: 320
            radius: Theme.radiusCard
            color: Theme.cardBackground

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Add Account"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                TextField {
                    id: nameIn
                    width: parent.width
                    placeholderText: "Account Name (e.g. Tinkoff RUB)"
                    text: root.newName
                    onTextChanged: root.newName = text
                }

                TextField {
                    id: curIn
                    width: parent.width
                    placeholderText: "Currency (USD, RUB, EUR, etc)"
                    text: root.newCurrency
                    onTextChanged: root.newCurrency = text.toUpperCase()
                }

                TextField {
                    id: balIn
                    width: parent.width
                    placeholderText: "Initial balance"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.newInitialBalance
                    onTextChanged: root.newInitialBalance = text
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Button {
                        text: "Cancel"
                        onClicked: root.showAddDialog = false
                    }

                    Button {
                        text: "Create"
                        color: Theme.primary
                        onClicked: root.createAccount()
                    }
                }
            }
        }
    }

    function buildGroupedSections() {
        var accts = AppState.accounts || [];
        var groups = AppState.groups || [];
        var assigned = {};
        var sections = [];

        for (var i = 0; i < groups.length; i++) {
            var g = groups[i];
            var inGroup = [];
            var idMap = {};
            for (var k = 0; k < g.accountIds.length; k++) {
                idMap[g.accountIds[k]] = true;
            }
            for (var j = 0; j < accts.length; j++) {
                if (idMap[accts[j].id]) {
                    inGroup.push(accts[j]);
                    assigned[accts[j].id] = true;
                }
            }
            if (inGroup.length > 0) {
                sections.push({ groupName: g.name, accounts: inGroup });
            }
        }

        // Ungrouped
        var rest = [];
        for (var i = 0; i < accts.length; i++) {
            if (!assigned[accts[i].id]) {
                rest.push(accts[i]);
            }
        }
        if (rest.length > 0) {
            sections.push({ groupName: "Other", accounts: rest });
        }
        return sections;
    }

    function createAccount() {
        if (!newName || newName.trim().length === 0) return;
        var initMinor = Math.round((parseFloat(newInitialBalance) || 0) * 100);
        var payload = {
            name: newName.trim(),
            currency: newCurrency || "USD",
            balance: initMinor,
            kind: newKind,
            inAssets: true,
            color: "FEDB5A"
        };
        Api.post("/api/accounts", payload, function(err, res) {
            if (!err) {
                showAddDialog = false;
                newName = "";
                newInitialBalance = "0";
                AppState.reload();
            }
        });
    }
}
