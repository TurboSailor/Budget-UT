import QtQuick 2.4
import Ubuntu.Components 1.3
import "../../theme"
import "../../store"
import "../../js/api.js" as Api

// AccountManager — CRUD over /api/accounts (+/{id}).
// Reads the list straight from AppState.accounts and re-bootstraps through
// AppState.reload() after every mutation, so balances stay consistent with the
// rest of the app. Balances are entered in MAJOR units and sent as MINOR.
Item {
    id: root

    // Explicit model property: a `model: visibleAccounts()` binding depends on
    // plain JS objects with no change notification, so the list could go stale
    // right after an edit. Rebuilt on every store refresh instead.
    property var rows: []
    property bool showHidden: false
    property string statusMsg: ""

    // editor state
    property bool editorOpen: false
    property string editId: ""
    property string editName: ""
    property string editCurrency: "USD"
    property int editKind: 0
    property string editBalance: "0"
    property bool editInAssets: true
    property bool editHidden: false
    property string editColor: "#5AA6FE"

    readonly property var kindNames: ["Debit / Cash", "Credit card", "Custom / Investment"]

    function hexColor(c, fallback) {
        if (!c || c.length === 0) return fallback;
        return c.indexOf("#") === 0 ? c : "#" + c;
    }

    function visibleAccounts() {
        var src = AppState.accounts || [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var a = src[i];
            if (a.status === 1) continue;
            if (a.hidden && !root.showHidden) continue;
            out.push(a);
        }
        return out;
    }
    function refreshRows() {
        root.rows = root.visibleAccounts();
    }

    function reload() {
        AppState.reload();
        root.refreshRows();
    }

    Component.onCompleted: root.refreshRows()

    Connections {
        target: AppState
        function onDataRefreshed() { root.refreshRows() }
    }

    function openCreate() {
        root.editId = "";
        root.editName = "";
        root.editCurrency = AppState.wallets.system || "USD";
        root.editKind = 0;
        root.editBalance = "0";
        root.editInAssets = true;
        root.editHidden = false;
        root.editColor = Theme.categoryPalette[1];
        root.editorOpen = true;
    }

    function openEdit(a) {
        root.editId = a.id;
        root.editName = a.name || "";
        root.editCurrency = a.currency || "USD";
        root.editKind = a.kind || 0;
        root.editBalance = "" + ((a.balance || 0) / 100);
        root.editInAssets = a.inAssets === true;
        root.editHidden = a.hidden === true;
        root.editColor = root.hexColor(a.color, Theme.categoryPalette[1]);
        root.editorOpen = true;
    }

    function saveEditor() {
        var name = root.editName.trim();
        if (name.length === 0) {
            root.statusMsg = "Name cannot be empty";
            return;
        }
        var major = parseFloat(root.editBalance);
        if (isNaN(major)) major = 0;

        var body = {
            kind: root.editKind,
            name: name,
            icon: root.editKind === 1 ? "icon_add_account_1" : "Cash",
            color: root.editColor,
            currency: root.editCurrency.toUpperCase(),
            creditLimit: 0,
            liability: 0,
            balance: Math.round(major * 100),
            financesType: root.editKind === 2 ? 3 : 0,
            code: "",
            inAssets: root.editInAssets,
            hidden: root.editHidden,
            sorted: 0,
            status: 0
        };

        var done = function(err) {
            if (err) {
                root.statusMsg = "Save failed: " + err;
                return;
            }
            root.editorOpen = false;
            root.statusMsg = "Account saved";
            AppState.reload();
        };

        if (root.editId.length > 0) {
            body.id = root.editId;
            Api.put("/api/accounts/" + root.editId, body, done);
        } else {
            Api.post("/api/accounts", body, done);
        }
    }

    function removeAccount(a) {
        Api.del("/api/accounts/" + a.id, function(err) {
            if (err) {
                root.statusMsg = "Delete failed: " + err;
                return;
            }
            root.statusMsg = "Account deleted";
            AppState.reload();
        });
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.height + units.gu(6)
        clip: true

        Column {
            id: col
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.2)

            Item { width: units.gu(1); height: units.gu(0.5) }

            Row {
                width: parent.width
                height: units.gu(5)
                spacing: units.gu(1.2)

                Rectangle {
                    width: (parent.width - units.gu(1.2)) * 0.58
                    height: units.gu(5)
                    radius: Theme.radiusSmall
                    color: addArea.pressed ? Theme.primaryDark : Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "+  New account"
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        color: Theme.primaryText
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        onClicked: root.openCreate()
                    }
                }

                Rectangle {
                    width: (parent.width - units.gu(1.2)) * 0.42
                    height: units.gu(5)
                    radius: Theme.radiusSmall
                    color: root.showHidden ? Theme.accent : Theme.cardBackground
                    border.color: Theme.cardBorder
                    border.width: units.dp(1)

                    Text {
                        anchors.centerIn: parent
                        text: "Hidden"
                        font.pixelSize: Theme.fontSub
                        font.bold: root.showHidden
                        color: root.showHidden ? Theme.textInverted : Theme.textSecondary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.showHidden = !root.showHidden; root.refreshRows() }
                    }
                }
            }

            Text {
                text: root.statusMsg
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.statusMsg.length > 0
                font.pixelSize: Theme.fontSub
                color: Theme.accent
            }

            Repeater {
                model: root.rows

                delegate: Rectangle {
                    width: col.width
                    height: units.gu(8.5)
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    border.color: Theme.cardBorder
                    border.width: units.dp(1)
                    opacity: modelData.hidden ? 0.55 : 1.0

                    Row {
                        anchors.fill: parent
                        anchors.margins: units.gu(1.2)
                        spacing: units.gu(1.2)

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.hexColor(modelData.color, Theme.accent)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.kind === 2 ? "📊" : (modelData.kind === 1 ? "💳" : "💵")
                                font.pixelSize: units.dp(18)
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(16.8)
                            spacing: units.gu(0.3)

                            Text {
                                text: modelData.name || "(unnamed)"
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontHeading
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Text {
                                text: AppState.formatMoney(modelData.balance, modelData.currency)
                                font.pixelSize: Theme.fontSub
                                color: modelData.balance < 0 ? Theme.expense : Theme.textSecondary
                            }

                            Text {
                                text: root.kindNames[modelData.kind] + " • " + modelData.currency
                                    + (modelData.inAssets ? "" : " • off net worth")
                                    + (modelData.hidden ? " • hidden" : "")
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textMuted
                            }
                        }

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: Theme.radiusSmall
                            anchors.verticalCenter: parent.verticalCenter
                            color: aEdit.pressed ? Theme.divider : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✎"
                                font.pixelSize: units.dp(18)
                                color: Theme.textSecondary
                            }
                            MouseArea {
                                id: aEdit
                                anchors.fill: parent
                                onClicked: root.openEdit(modelData)
                            }
                        }

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: Theme.radiusSmall
                            anchors.verticalCenter: parent.verticalCenter
                            color: aDel.pressed ? "#FEE2E2" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: units.dp(18)
                                color: Theme.expense
                            }
                            MouseArea {
                                id: aDel
                                anchors.fill: parent
                                onClicked: root.removeAccount(modelData)
                            }
                        }
                    }
                }
            }

            Text {
                text: "No accounts match the current filter"
                visible: root.visibleAccounts().length === 0
                font.pixelSize: Theme.fontSub
                color: Theme.textMuted
            }
        }
    }

    // ---- editor overlay ----
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.editorOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.editorOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - units.gu(3), units.gu(44))
            height: Math.min(form.height + units.gu(4), parent.height - units.gu(6))
            radius: Theme.radiusCard
            color: Theme.cardBackground

            MouseArea {
                anchors.fill: parent
                onClicked: { /* keep the dialog open */ }
            }

            Flickable {
                id: formFlick
                anchors.fill: parent
                anchors.margins: units.gu(2)
                contentHeight: form.height
                clip: true

                Column {
                    id: form
                    width: formFlick.width
                    spacing: units.gu(1.2)

                    Text {
                        text: root.editId.length > 0 ? "Edit account" : "New account"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Account name"
                        text: root.editName
                        onTextChanged: root.editName = text
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Currency (USD, RUB, EUR…)"
                        text: root.editCurrency
                        onTextChanged: root.editCurrency = text.toUpperCase()
                    }

                    Text {
                        text: "Balance (major units, e.g. 1234.56)"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "0.00"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        text: root.editBalance
                        onTextChanged: root.editBalance = text
                    }

                    Text {
                        text: "Kind"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(0.8)

                        Repeater {
                            model: [0, 1, 2]

                            delegate: Rectangle {
                                width: (form.width - units.gu(1.6)) / 3
                                height: units.gu(4.5)
                                radius: Theme.radiusSmall
                                color: root.editKind === modelData ? Theme.primary : "#F3F4F6"

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - units.gu(0.8)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData === 0 ? "Debit" : (modelData === 1 ? "Credit" : "Custom")
                                    font.pixelSize: Theme.fontSub
                                    font.bold: root.editKind === modelData
                                    color: Theme.textPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.editKind = modelData
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: units.gu(4.5)
                        radius: Theme.radiusSmall
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Counts towards net worth"
                            font.pixelSize: Theme.fontBody
                            color: Theme.textPrimary
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(7)
                            height: units.gu(3.4)
                            radius: height / 2
                            color: root.editInAssets ? Theme.income : "#E5E7EB"

                            Rectangle {
                                width: units.gu(2.8)
                                height: units.gu(2.8)
                                radius: width / 2
                                color: Theme.cardBackground
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.editInAssets ? parent.width - width - units.gu(0.3) : units.gu(0.3)
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.editInAssets = !root.editInAssets
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: units.gu(4.5)
                        radius: Theme.radiusSmall
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Hidden from lists"
                            font.pixelSize: Theme.fontBody
                            color: Theme.textPrimary
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(7)
                            height: units.gu(3.4)
                            radius: height / 2
                            color: root.editHidden ? Theme.accent : "#E5E7EB"

                            Rectangle {
                                width: units.gu(2.8)
                                height: units.gu(2.8)
                                radius: width / 2
                                color: Theme.cardBackground
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.editHidden ? parent.width - width - units.gu(0.3) : units.gu(0.3)
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.editHidden = !root.editHidden
                            }
                        }
                    }

                    Text {
                        text: "Colour"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Flow {
                        width: parent.width
                        spacing: units.gu(1)

                        Repeater {
                            model: Theme.categoryPalette

                            delegate: Rectangle {
                                width: units.gu(4)
                                height: units.gu(4)
                                radius: width / 2
                                color: modelData
                                border.color: root.editColor === modelData ? Theme.textPrimary : Theme.cardBorder
                                border.width: root.editColor === modelData ? units.dp(3) : units.dp(1)

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.editColor = modelData
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: units.gu(1.5)

                        Button {
                            text: "Cancel"
                            onClicked: root.editorOpen = false
                        }

                        Button {
                            text: "Save"
                            color: Theme.primary
                            onClicked: root.saveEditor()
                        }
                    }

                    Item { width: units.gu(1); height: units.gu(1) }
                }
            }
        }
    }
}
