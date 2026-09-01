import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../js/api.js" as Api

Item {
    id: root

    property var sections: []
    property bool showAddDialog: false
    property string newName: ""
    property string newCurrency: AppState.wallets.system || "USD"
    property string newInitialBalance: "0"
    property int newKind: 0 // 0: Debit, 1: Credit, 2: Custom

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

            // Header: Title + Add. Anchored, not spacer-arithmetic, so it
            // adapts to any width instead of pushing the button off-screen.
            Item {
                width: parent.width
                height: units.gu(4.5)

                Text {
                    anchors.left: parent.left
                    anchors.right: addAccountBtn.left
                    anchors.rightMargin: units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: "Accounts"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                }

                Rectangle {
                    id: addAccountBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(4)
                    height: units.gu(4)
                    radius: width / 2
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: units.dp(24)
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
                height: units.gu(13)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(0.5)

                    Text {
                        text: "Net Assets"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    MoneyLabel {
                        minor: AppState.wallets.totalMinor
                        currency: AppState.wallets.system
                        colored: false
                        font.pixelSize: Theme.fontHero
                    }

                    Text {
                        text: "Converted to " + (AppState.wallets.system || "USD")
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                    }
                }
            }

            // Grouped Accounts List. The model is an explicit property, not a
            // direct function call: the sections are plain JS objects with no
            // change notification, so edits made elsewhere (Settings ->
            // Account manager) never reached this list on their own.
            Repeater {
                model: root.sections
                delegate: Column {
                    width: parent.width
                    spacing: units.gu(0.8)

                    Text {
                        text: modelData.groupName
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Column {
                        width: parent.width
                        spacing: units.gu(0.8)

                        Repeater {
                            model: modelData.accounts
                            delegate: Rectangle {
                                width: parent.width
                                height: units.gu(7.5)
                                radius: Theme.radiusCard
                                color: rowMouse.pressed ? "#F9FAFB" : Theme.cardBackground
                                border.color: Theme.cardBorder

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    onClicked: accountSheet.open(modelData)
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: units.gu(1.2)
                                    spacing: units.gu(1.4)

                                    // Account colored pill / icon
                                    Rectangle {
                                        width: units.gu(4.8)
                                        height: units.gu(4.8)
                                        radius: width / 2
                                        color: modelData.color ? (modelData.color.indexOf("#") === 0 ? modelData.color : "#" + modelData.color) : Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.kind === 2 ? "📊" : (modelData.kind === 1 ? "💳" : "💵")
                                            font.pixelSize: units.dp(18)
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - units.gu(6) - balCol.width - units.gu(2)
                                        spacing: units.gu(0.3)

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
                                        spacing: units.gu(0.2)

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
                                            font.pixelSize: Theme.fontMicro
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
            width: Math.min(parent.width - units.gu(4), units.gu(42))
            height: units.gu(36)
            radius: Theme.radiusCard
            color: Theme.cardBackground

            Column {
                anchors.fill: parent
                anchors.margins: units.gu(2)
                spacing: units.gu(1.4)

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
                    spacing: units.gu(1.5)

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
        // Deleting an account is a soft delete (status=1) and the group still
        // lists its id, so filter here too — the server already drops them, and
        // this keeps a stale payload from resurrecting a deleted card.
        var all = AppState.accounts || [];
        var accts = [];
        for (var n = 0; n < all.length; n++) {
            if (all[n].status === 0) accts.push(all[n]);
        }
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
    // Account card: balance correction + change history
    AccountSheet {
        id: accountSheet
        anchors.fill: parent
        z: 90
        onChanged: AppState.reload()
    }

    // Rebuild whenever the store changes: account edits also happen in
    // Settings -> Account manager and in the account card sheet.
    function refreshSections() {
        root.sections = root.buildGroupedSections()
    }

    Component.onCompleted: root.refreshSections()

    Connections {
        target: AppState
        function onDataRefreshed() { root.refreshSections() }
        function onTxChanged() { root.refreshSections() }
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
