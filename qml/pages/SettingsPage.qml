import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "managers"
import "../js/api.js" as Api

// SettingsPage — the root settings list plus a self-contained one-level
// navigation into the four managers. No StackView: `managerIndex` simply picks
// which surface is visible, and goBack() lets the shell consume the hardware /
// header back action.
//
//   0 root list   1 Ledgers   2 Accounts   3 Categories   4 Base currency
Item {
    id: root

    property int managerIndex: 0

    readonly property var managerTitles: ["Settings", "Ledgers", "Accounts", "Categories", "Base currency"]

    // overview
    property var summary: null
    property bool summaryLoading: false
    property string summaryError: ""

    // security
    property bool pinEnabled: false
    property string securityMsg: ""
    property int pinPurpose: 0          // 0 closed, 1 set/change, 2 disable

    // backup & restore
    property string importPath: "/home/phablet/Downloads/budget-bundle.json"
    property string statusMsg: ""

    // Returns true when the back action was consumed by this page.
    function goBack() {
        if (root.managerIndex !== 0) {
            root.managerIndex = 0;
            return true;
        }
        return false;
    }

    function openManager(idx) {
        root.managerIndex = idx;
    }

    // ---- overview ----

    function loadSummary() {
        root.summaryLoading = true;
        Api.get("/api/stats/summary", function(err, data) {
            root.summaryLoading = false;
            if (err) {
                root.summaryError = err;
                return;
            }
            root.summaryError = "";
            root.summary = data || {};
        });
    }

    function summaryTiles() {
        var s = root.summary || {};
        return [
            { label: "Transactions", value: "" + (s.transactions || 0) },
            { label: "Days with activity", value: "" + (s.daysWithTransactions || 0) },
            { label: "Expenses", value: "" + (s.expenseCount || 0) },
            { label: "Income", value: "" + (s.incomeCount || 0) },
            { label: "Transfers", value: "" + (s.transferCount || 0) },
            { label: "Accounts", value: "" + (s.accounts || 0) },
            { label: "Categories", value: "" + (s.categories || 0) },
            { label: "Budgets", value: "" + (s.budgets || 0) }
        ];
    }

    function summaryRange() {
        var s = root.summary;
        if (!s) return "—";
        if (!s.firstDay || s.firstDay.length === 0) return "No transactions recorded yet";
        return s.firstDay + "  →  " + s.lastDay;
    }

    // ---- security ----

    function loadSecurity() {
        Api.get("/api/security", function(err, data) {
            if (err) {
                root.securityMsg = "PIN state unavailable: " + err;
                return;
            }
            root.securityMsg = "";
            root.pinEnabled = !!(data && data.pinEnabled);
        });
    }

    function savePin(pin) {
        Api.post("/api/security/pin", { pin: pin }, function(err, data) {
            root.pinPurpose = 0;
            if (err) {
                root.securityMsg = "Could not update the PIN: " + err;
                return;
            }
            root.pinEnabled = !!(data && data.pinEnabled);
            root.securityMsg = root.pinEnabled ? "PIN enabled" : "PIN disabled";
        });
    }

    // ---- backup & restore ----

    function doImportBundle() {
        root.statusMsg = "Importing…";
        Api.post("/api/import/bundle", { path: root.importPath }, function(err, res) {
            if (err) {
                root.statusMsg = "Error: " + err;
                return;
            }
            root.statusMsg = "Imported " + (res.transactions || 0) + " transactions!";
            AppState.reload();
            AppState.txChanged();
            root.loadSummary();
        });
    }

    function doExportBundle() {
        root.statusMsg = "Exporting bundle…";
        Api.get("/api/export/bundle", function(err) {
            root.statusMsg = err ? "Export error: " + err : "Bundle export complete";
        });
    }

    function doExportCSV() {
        root.statusMsg = "Exporting CSV…";
        Api.get("/api/export/csv", function(err) {
            root.statusMsg = err ? "CSV export error: " + err : "CSV export complete";
        });
    }

    function doImportCSV() {
        root.statusMsg = "Importing from ~/Downloads/budget-import.csv…";
        Api.post("/api/import/csv", { path: "/home/phablet/Downloads/budget-import.csv" }, function(err, res) {
            if (err) {
                root.statusMsg = "CSV import error: " + err;
                return;
            }
            root.statusMsg = "Imported " + (res.imported || 0) + " rows!";
            AppState.reload();
            AppState.txChanged();
            root.loadSummary();
        });
    }

    // Wipes the database and re-imports the bundle shipped with the app, so a
    // bad/partial import can be redone from the original Budget.realm export.
    function doReset() {
        root.statusMsg = "Resetting and re-importing original backup…";
        Api.post("/api/reset", {}, function(err, res) {
            if (err) {
                root.statusMsg = "Reset error: " + err;
                return;
            }
            var c = (res && res.counts) ? res.counts : {};
            root.statusMsg = "Reset done: " + (c.transactions || 0) + " transactions, "
                + (c.accounts || 0) + " accounts, " + (c.categories || 0) + " categories.";
            AppState.reload();
            AppState.txChanged();
            root.loadSummary();
        });
    }

    Component.onCompleted: {
        root.loadSummary();
        root.loadSecurity();
    }

    onVisibleChanged: {
        if (visible) {
            root.loadSummary();
            root.loadSecurity();
        }
    }

    Connections {
        target: AppState
        // QtQuick 2.4 has no Connections.enabled — guard inside the handler.
        function onTxChanged() {
            if (root.visible && root.managerIndex === 0) root.loadSummary();
        }
    }

    // ==================== root list ====================
    Flickable {
        id: rootFlick
        anchors.fill: parent
        contentHeight: col.height + units.gu(6)
        clip: true
        visible: root.managerIndex === 0

        Column {
            id: col
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.5)

            Item { width: units.gu(1); height: units.gu(0.5) }

            Text {
                text: "Settings"
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textPrimary
            }

            // -------- Overview --------
            Text {
                text: "OVERVIEW"
                font.pixelSize: Theme.fontMicro
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                width: parent.width
                height: statCol.height + units.gu(3.6)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Column {
                    id: statCol
                    x: units.gu(1.8)
                    y: units.gu(1.8)
                    width: parent.width - units.gu(3.6)
                    spacing: units.gu(1)

                    Text {
                        text: root.summaryLoading && !root.summary ? "Loading statistics…" : root.summaryRange()
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Statistics unavailable: " + root.summaryError
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: root.summaryError.length > 0
                        font.pixelSize: Theme.fontSub
                        color: Theme.expense
                    }

                    Grid {
                        id: statGrid
                        width: parent.width
                        columns: 2
                        spacing: units.gu(1)

                        Repeater {
                            model: root.summaryTiles()

                            delegate: Rectangle {
                                width: (statGrid.width - units.gu(1)) / 2
                                height: units.gu(6.5)
                                radius: Theme.radiusSmall
                                color: "#F9FAFB"
                                border.color: Theme.divider
                                border.width: units.dp(1)

                                Column {
                                    x: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - units.gu(2)
                                    spacing: units.gu(0.2)

                                    Text {
                                        text: modelData.value
                                        font.pixelSize: Theme.fontTitle
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: modelData.label
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontMicro
                                        color: Theme.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -------- Managers --------
            Text {
                text: "MANAGERS"
                font.pixelSize: Theme.fontMicro
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                width: parent.width
                height: mgrCol.height + units.gu(2.4)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Column {
                    id: mgrCol
                    x: units.gu(1.2)
                    y: units.gu(1.2)
                    width: parent.width - units.gu(2.4)
                    spacing: units.gu(0.4)

                    Repeater {
                        model: [
                            { idx: 1, glyph: "📒", title: "Ledgers", sub: "Switch, rename or add a ledger" },
                            { idx: 2, glyph: "🏦", title: "Accounts", sub: "Balances, currencies, visibility" },
                            { idx: 3, glyph: "🏷", title: "Categories", sub: "Expense & income trees" },
                            { idx: 4, glyph: "💱", title: "Base currency", sub: "Daily FX rates and conversion base" }
                        ]

                        delegate: Rectangle {
                            width: mgrCol.width
                            height: units.gu(6.5)
                            radius: Theme.radiusSmall
                            color: mgrArea.pressed ? Theme.divider : "transparent"

                            MouseArea {
                                id: mgrArea
                                anchors.fill: parent
                                onClicked: root.openManager(modelData.idx)
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: units.gu(0.8)
                                spacing: units.gu(1.2)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.glyph
                                    width: units.gu(3.6)
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: units.dp(20)
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - units.gu(8)
                                    spacing: units.gu(0.2)

                                    Text {
                                        text: modelData.title
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: modelData.sub
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontMicro
                                        color: Theme.textMuted
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    width: units.gu(2)
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: units.dp(22)
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }
            }

            // -------- Security --------
            Text {
                text: "SECURITY"
                font.pixelSize: Theme.fontMicro
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                width: parent.width
                height: secCol.height + units.gu(3.6)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Column {
                    id: secCol
                    x: units.gu(1.8)
                    y: units.gu(1.8)
                    width: parent.width - units.gu(3.6)
                    spacing: units.gu(1.2)

                    Row {
                        width: parent.width
                        height: units.gu(4)
                        spacing: units.gu(1)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔒"
                            width: units.gu(3)
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: units.dp(18)
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(4)
                            spacing: units.gu(0.2)

                            Text {
                                text: "App PIN lock"
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Text {
                                text: root.pinEnabled
                                    ? "Enabled — asked for on every launch"
                                    : "Disabled — the app opens straight away"
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontMicro
                                color: root.pinEnabled ? Theme.income : Theme.textMuted
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(1.2)

                        Rectangle {
                            width: root.pinEnabled ? (parent.width - units.gu(1.2)) / 2 : parent.width
                            height: units.gu(4.5)
                            radius: Theme.radiusSmall
                            color: setPinArea.pressed ? Theme.primaryDark : Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: root.pinEnabled ? "Change PIN" : "Set PIN"
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                color: Theme.primaryText
                            }
                            MouseArea {
                                id: setPinArea
                                anchors.fill: parent
                                onClicked: root.pinPurpose = 1
                            }
                        }

                        Rectangle {
                            width: (parent.width - units.gu(1.2)) / 2
                            height: units.gu(4.5)
                            radius: Theme.radiusSmall
                            visible: root.pinEnabled
                            color: dropPinArea.pressed ? "#FCA5A5" : "#FEE2E2"

                            Text {
                                anchors.centerIn: parent
                                text: "Disable PIN"
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                color: Theme.expense
                            }
                            MouseArea {
                                id: dropPinArea
                                anchors.fill: parent
                                onClicked: root.pinPurpose = 2
                            }
                        }
                    }

                    Text {
                        text: root.securityMsg
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: root.securityMsg.length > 0
                        font.pixelSize: Theme.fontSub
                        color: Theme.accent
                    }
                }
            }

            // -------- Backup & Restore --------
            Text {
                text: "BACKUP & RESTORE"
                font.pixelSize: Theme.fontMicro
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                width: parent.width
                height: backupCol.height + units.gu(3.6)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Column {
                    id: backupCol
                    x: units.gu(1.8)
                    y: units.gu(1.8)
                    width: parent.width - units.gu(3.6)
                    spacing: units.gu(1.2)

                    Text {
                        text: "Import JSON bundle (converted Realm backup):"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    TextField {
                        width: parent.width
                        text: root.importPath
                        onTextChanged: root.importPath = text
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(1.2)

                        Button {
                            width: (parent.width - units.gu(1.2)) / 2
                            text: "Import Bundle"
                            color: Theme.primary
                            onClicked: root.doImportBundle()
                        }

                        Button {
                            width: (parent.width - units.gu(1.2)) / 2
                            text: "Export Bundle"
                            onClicked: root.doExportBundle()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(1.2)

                        Button {
                            width: (parent.width - units.gu(1.2)) / 2
                            text: "Export CSV"
                            onClicked: root.doExportCSV()
                        }

                        Button {
                            width: (parent.width - units.gu(1.2)) / 2
                            text: "Import CSV"
                            onClicked: root.doImportCSV()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: units.gu(4.5)
                        radius: Theme.radiusSmall
                        color: resetMouse.pressed ? "#FCA5A5" : "#FEE2E2"

                        Text {
                            anchors.centerIn: parent
                            text: "Reset & Re-import Original Backup"
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            color: Theme.expense
                        }
                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            onClicked: root.doReset()
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
                }
            }

            // -------- About --------
            Text {
                text: "ABOUT"
                font.pixelSize: Theme.fontMicro
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                width: parent.width
                height: aboutCol.height + units.gu(3.6)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Column {
                    id: aboutCol
                    x: units.gu(1.8)
                    y: units.gu(1.8)
                    width: parent.width - units.gu(3.6)
                    spacing: units.gu(0.5)

                    Text {
                        text: "👑  All premium features free"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.primaryText
                    }

                    Text {
                        text: "Version 0.1.0 • Built with Go & Lomiri QML"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Daemon: http://127.0.0.1:21990 • SQLite"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ==================== managers ====================
    Item {
        id: managerHost
        anchors.fill: parent
        visible: root.managerIndex !== 0

        Rectangle {
            id: backBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(6)
            color: Theme.background

            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    font.pixelSize: units.dp(28)
                    color: Theme.textPrimary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.managerTitles[root.managerIndex]
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.goBack()
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: units.dp(1)
                color: Theme.cardBorder
            }
        }

        LedgerManager {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.managerIndex === 1
            onVisibleChanged: {
                if (visible) reload();
            }
        }

        AccountManager {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.managerIndex === 2
        }

        CategoryManager {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.managerIndex === 3
        }

        CurrencyManager {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.managerIndex === 4
            onVisibleChanged: {
                if (visible) reload();
            }
        }
    }

    // ==================== PIN entry ====================
    PinLock {
        anchors.fill: parent
        z: 200
        visible: root.pinPurpose !== 0
        mode: root.pinPurpose === 1 ? "set" : "verify"
        subtitle: root.pinPurpose === 2 ? "Confirm your PIN to switch the lock off" : ""
        onPinSet: root.savePin(pin)
        onUnlocked: root.savePin("")
        onCancelled: root.pinPurpose = 0
    }
}
