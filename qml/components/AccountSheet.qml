import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../js/api.js" as Api

// Account card: current balance, manual balance correction through the same
// calculator keypad used for transactions, and the full change log.
Rectangle {
    id: root
    property var account: null
    property bool visibleSheet: false
    property string mode: "view"      // view | balance | edit
    property var logItems: []
    property string statusMsg: ""

    // edit-mode buffers
    property string editName: ""
    property string editCurrency: ""
    property int editKind: 0
    property bool editInAssets: true
    property bool editHidden: false

    signal changed()

    color: "transparent"
    visible: visibleSheet

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(parent.height * 0.94, units.gu(80))
        radius: Theme.radiusCard
        color: Theme.cardBackground

        // Header
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(6)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "view" ? "Close" : "Back"
                font.pixelSize: Theme.fontBody
                color: Theme.textSecondary
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -units.gu(1)
                    onClicked: {
                        if (root.mode === "view") root.close()
                        else root.mode = "view"
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - units.gu(18)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.account ? root.account.name : ""
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "edit" ? "Save" : ""
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.accent
                visible: root.mode === "edit"
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -units.gu(1)
                    onClicked: root.saveDetails()
                }
            }
        }

        // ---------- VIEW: balance + log ----------
        Item {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.mode === "view"

            Column {
                id: viewHead
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: units.gu(2)
                spacing: units.gu(0.6)

                Text {
                    text: "Current balance"
                    font.pixelSize: Theme.fontSub
                    color: Theme.textSecondary
                }

                Text {
                    text: root.account ? AppState.formatMoney(root.account.balance, root.account.currency) : ""
                    font.pixelSize: Theme.fontHero
                    font.bold: true
                    color: (root.account && root.account.balance < 0) ? Theme.expense : Theme.textPrimary
                }

                Text {
                    text: {
                        if (!root.account) return ""
                        var kindName = root.account.kind === 1 ? "Credit card"
                                     : (root.account.kind === 2 ? "Investment / Other" : "Debit / Cash")
                        return kindName + " · " + root.account.currency
                               + (root.account.inAssets ? "" : " · excluded from net assets")
                               + (root.account.hidden ? " · hidden" : "")
                    }
                    font.pixelSize: Theme.fontSub
                    color: Theme.textMuted
                }

                Item { width: 1; height: units.gu(0.6) }

                Row {
                    width: parent.width
                    spacing: units.gu(1.2)

                    Rectangle {
                        width: (parent.width - units.gu(1.2)) / 2
                        height: units.gu(4.5)
                        radius: Theme.radiusSmall
                        color: Theme.primary
                        Text {
                            anchors.centerIn: parent
                            text: "Set balance"
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            color: Theme.primaryText
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.startBalanceEdit()
                        }
                    }

                    Rectangle {
                        width: (parent.width - units.gu(1.2)) / 2
                        height: units.gu(4.5)
                        radius: Theme.radiusSmall
                        color: "#F3F4F6"
                        Text {
                            anchors.centerIn: parent
                            text: "Edit account"
                            font.pixelSize: Theme.fontBody
                            color: Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.startDetailsEdit()
                        }
                    }
                }

                Text {
                    text: root.statusMsg
                    font.pixelSize: Theme.fontSub
                    color: Theme.accent
                    visible: root.statusMsg.length > 0
                }

                Item { width: 1; height: units.gu(0.4) }

                Text {
                    text: "History"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }
            }

            ListView {
                anchors.top: viewHead.bottom
                anchors.topMargin: units.gu(1)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: units.gu(2)
                anchors.rightMargin: units.gu(2)
                clip: true
                model: root.logItems
                spacing: units.gu(0.4)

                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: units.gu(7)
                    radius: Theme.radiusSmall
                    color: "#F9FAFB"

                    Row {
                        anchors.fill: parent
                        anchors.margins: units.gu(1.2)
                        spacing: units.gu(1)

                        Rectangle {
                            width: units.gu(4)
                            height: units.gu(4)
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.kind === 0 ? "#EDE9FE"
                                 : (modelData.kind === 2 ? "#E5E7EB" : (modelData.delta < 0 ? "#FEE2E2" : "#DCFCE7"))
                            Text {
                                anchors.centerIn: parent
                                text: modelData.kind === 0 ? "✎" : (modelData.kind === 2 ? "⛁" : (modelData.delta < 0 ? "↓" : "↑"))
                                font.pixelSize: units.dp(15)
                                color: Theme.textPrimary
                            }
                        }

                        Column {
                            id: logTextCol
                            anchors.verticalCenter: parent.verticalCenter
                            // Derived from siblings, not magic constants, so the
                            // row reflows instead of overflowing on narrow screens.
                            width: parent.width - units.gu(4) - logAmountCol.width - units.gu(2)
                            spacing: units.gu(0.2)

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.note && modelData.note.length > 0 ? modelData.note
                                      : (modelData.kind === 0 ? "Manual adjustment" : "Transaction")
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: modelData.day
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textMuted
                            }
                        }

                        Column {
                            id: logAmountCol
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(units.gu(13), parent.width * 0.36)
                            spacing: units.gu(0.2)

                            Text {
                                anchors.right: parent.right
                                text: (modelData.delta > 0 ? "+" : "")
                                      + AppState.formatMoney(modelData.delta, modelData.currency)
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                color: modelData.delta < 0 ? Theme.expense : Theme.income
                            }
                            Text {
                                anchors.right: parent.right
                                // Imported Realm rows carry balanceAfter=0 (the
                                // source backup never stored it), so only show a
                                // running balance where it is real.
                                visible: !(modelData.kind === 2 && modelData.txId && modelData.txId.length > 0)
                                text: AppState.formatMoney(modelData.balanceAfter, modelData.currency)
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.logItems.length === 0
                    text: "No changes recorded yet"
                    font.pixelSize: Theme.fontBody
                    color: Theme.textMuted
                }
            }
        }

        // ---------- BALANCE: calculator ----------
        Item {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.mode === "balance"

            Column {
                id: balHead
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: units.gu(2)
                spacing: units.gu(0.4)

                Text {
                    text: "New balance"
                    font.pixelSize: Theme.fontSub
                    color: Theme.textSecondary
                }
                Text {
                    text: root.account
                          ? "was " + AppState.formatMoney(root.account.balance, root.account.currency)
                          : ""
                    font.pixelSize: Theme.fontMicro
                    color: Theme.textMuted
                }

                TextField {
                    id: noteField
                    width: parent.width
                    placeholderText: "Note (optional), e.g. cash count"
                }
            }

            CalcKeypad {
                id: balKeypad
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                currencySymbol: root.account ? AppState.currencySymbol(root.account.currency) : "$"
                valueColor: Theme.textPrimary
                onSaveRequested: root.applyBalance()
            }
        }

        // ---------- EDIT: details ----------
        Flickable {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: units.gu(2)
            visible: root.mode === "edit"
            contentHeight: editCol.height + units.gu(4)
            clip: true

            Column {
                id: editCol
                width: parent.width
                spacing: units.gu(1.2)

                Text { text: "Name"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                TextField {
                    width: parent.width
                    text: root.editName
                    onTextChanged: root.editName = text
                }

                Text { text: "Currency"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                TextField {
                    width: parent.width
                    text: root.editCurrency
                    onTextChanged: root.editCurrency = text.toUpperCase()
                }

                Text { text: "Type"; font.pixelSize: Theme.fontSub; color: Theme.textSecondary }
                Row {
                    width: parent.width
                    spacing: units.gu(0.8)
                    Repeater {
                        model: [
                            { idx: 0, label: "Debit" },
                            { idx: 1, label: "Credit" },
                            { idx: 2, label: "Other" }
                        ]
                        delegate: Rectangle {
                            width: (parent.width - units.gu(1.6)) / 3
                            height: units.gu(4)
                            radius: height / 2
                            color: root.editKind === modelData.idx ? Theme.primary : "#F3F4F6"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSub
                                font.bold: root.editKind === modelData.idx
                                color: Theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.editKind = modelData.idx
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: units.gu(0.8)

                    Rectangle {
                        width: (parent.width - units.gu(0.8)) / 2
                        height: units.gu(4)
                        radius: height / 2
                        color: root.editInAssets ? Theme.income : "#F3F4F6"
                        Text {
                            anchors.centerIn: parent
                            text: "In net assets"
                            font.pixelSize: Theme.fontSub
                            color: root.editInAssets ? "#FFFFFF" : Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.editInAssets = !root.editInAssets
                        }
                    }

                    Rectangle {
                        width: (parent.width - units.gu(0.8)) / 2
                        height: units.gu(4)
                        radius: height / 2
                        color: root.editHidden ? Theme.textSecondary : "#F3F4F6"
                        Text {
                            anchors.centerIn: parent
                            text: "Hidden"
                            font.pixelSize: Theme.fontSub
                            color: root.editHidden ? "#FFFFFF" : Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.editHidden = !root.editHidden
                        }
                    }
                }
            }
        }
    }

    // ---- behaviour ----

    function open(acct) {
        account = acct
        mode = "view"
        statusMsg = ""
        logItems = []
        visibleSheet = true
        loadLog()
    }

    function close() {
        visibleSheet = false
    }

    function loadLog() {
        if (!account) return
        Api.get("/api/accounts/" + account.id + "/logs?limit=200", function(err, res) {
            if (err || !res) return
            logItems = res.items || []
        })
    }

    function startBalanceEdit() {
        if (!account) return
        mode = "balance"
        balKeypad.setValue(account.balance / 100)
    }

    function startDetailsEdit() {
        if (!account) return
        editName = account.name
        editCurrency = account.currency
        editKind = account.kind
        editInAssets = account.inAssets
        editHidden = account.hidden
        mode = "edit"
    }

    function applyBalance() {
        if (!account) return
        var target = balKeypad.valueMinor()
        Api.post("/api/accounts/" + account.id + "/adjust",
                 { newBalance: target, note: noteField.text }, function(err, res) {
            if (err) {
                statusMsg = "Error: " + err
                mode = "view"
                return
            }
            if (res && res.account) account = res.account
            statusMsg = "Balance updated"
            noteField.text = ""
            mode = "view"
            loadLog()
            AppState.reload()
            root.changed()
        })
    }

    function saveDetails() {
        if (!account) return
        var payload = {
            id: account.id,
            name: editName,
            currency: editCurrency,
            kind: editKind,
            balance: account.balance,
            creditLimit: account.creditLimit,
            liability: account.liability,
            financesType: account.financesType,
            code: account.code,
            inAssets: editInAssets,
            hidden: editHidden,
            sorted: account.sorted,
            color: account.color,
            icon: account.icon,
            status: account.status
        }
        Api.put("/api/accounts/" + account.id, payload, function(err, res) {
            if (err) {
                statusMsg = "Error: " + err
                return
            }
            if (res) account = res
            statusMsg = "Account saved"
            mode = "view"
            AppState.reload()
            root.changed()
        })
    }
}
