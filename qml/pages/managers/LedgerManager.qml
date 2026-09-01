import QtQuick 2.4
import Ubuntu.Components 1.3
import "../../theme"
import "../../store"
import "../../js/api.js" as Api

// LedgerManager — CRUD over /api/bills plus "make active"
// (POST /api/settings {"billId": id}). The active ledger is the settings key
// `billId`, so switching one re-bootstraps AppState.
Item {
    id: root

    property var bills: []
    property bool loading: false
    property string statusMsg: ""

    // editor state
    property bool editorOpen: false
    property string editId: ""
    property string editName: ""
    property string editColor: "#FEDB5A"

    readonly property string activeBillId: (AppState.settings && AppState.settings.billId) ? AppState.settings.billId : ""

    function hexColor(c, fallback) {
        if (!c || c.length === 0) return fallback;
        return c.indexOf("#") === 0 ? c : "#" + c;
    }

    function reload() {
        root.loading = true;
        Api.get("/api/bills", function(err, data) {
            root.loading = false;
            if (err) {
                root.statusMsg = "Load failed: " + err;
                return;
            }
            root.statusMsg = "";
            root.bills = data || [];
        });
    }

    function openCreate() {
        root.editId = "";
        root.editName = "";
        root.editColor = Theme.categoryPalette[0];
        root.editorOpen = true;
    }

    function openEdit(b) {
        root.editId = b.id;
        root.editName = b.name || "";
        root.editColor = root.hexColor(b.color, Theme.categoryPalette[0]);
        root.editorOpen = true;
    }

    function saveEditor() {
        var name = root.editName.trim();
        if (name.length === 0) {
            root.statusMsg = "Name cannot be empty";
            return;
        }
        var body = {
            name: name,
            icon: "daily_0",
            color: root.editColor,
            sorted: 0,
            status: 0
        };
        var done = function(err, res) {
            if (err) {
                root.statusMsg = "Save failed: " + err;
                return;
            }
            root.editorOpen = false;
            root.statusMsg = "Saved";
            root.reload();
        };
        if (root.editId.length > 0) {
            body.id = root.editId;
            Api.put("/api/bills/" + root.editId, body, done);
        } else {
            Api.post("/api/bills", body, done);
        }
    }

    function makeActive(id) {
        Api.post("/api/settings", { billId: id }, function(err) {
            if (err) {
                root.statusMsg = "Could not switch ledger: " + err;
                return;
            }
            root.statusMsg = "Active ledger switched";
            AppState.reload();
            AppState.txChanged();
        });
    }

    // The daemon owns the rules here: it refuses to delete the last ledger and
    // repoints settings `billId` by itself when the active one goes away, so a
    // bootstrap reload is mandatory after a successful delete.
    function removeBill(b) {
        Api.del("/api/bills/" + b.id, function(err) {
            if (err) {
                root.statusMsg = "Delete failed: " + err;
                return;
            }
            root.statusMsg = "Ledger deleted";
            AppState.reload();
            AppState.txChanged();
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

            Text {
                text: "Ledgers group every transaction, category and budget. Only the active one is shown across the app."
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSub
                color: Theme.textSecondary
            }

            Rectangle {
                width: parent.width
                height: units.gu(5)
                radius: Theme.radiusSmall
                color: addArea.pressed ? Theme.primaryDark : Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: "+  New ledger"
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

            Text {
                text: root.statusMsg
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.statusMsg.length > 0
                font.pixelSize: Theme.fontSub
                color: Theme.accent
            }

            Text {
                text: root.loading ? "Loading…" : "No ledgers yet"
                visible: root.loading || root.bills.length === 0
                font.pixelSize: Theme.fontSub
                color: Theme.textMuted
            }

            Repeater {
                model: root.bills

                delegate: Rectangle {
                    id: billRow
                    property bool isActive: modelData.id === root.activeBillId

                    width: col.width
                    height: units.gu(7.5)
                    radius: Theme.radiusCard
                    color: Theme.cardBackground
                    border.color: isActive ? Theme.primaryDark : Theme.cardBorder
                    border.width: isActive ? units.dp(2) : units.dp(1)

                    MouseArea {
                        anchors.fill: parent
                        enabled: !billRow.isActive
                        onClicked: root.makeActive(modelData.id)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: units.gu(1.2)
                        spacing: units.gu(1.2)

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.hexColor(modelData.color, Theme.primary)

                            Text {
                                anchors.centerIn: parent
                                text: "📒"
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
                                text: billRow.isActive ? "Active ledger" : "Tap to make active"
                                font.pixelSize: Theme.fontMicro
                                color: billRow.isActive ? Theme.income : Theme.textMuted
                            }
                        }

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: Theme.radiusSmall
                            anchors.verticalCenter: parent.verticalCenter
                            color: editArea.pressed ? Theme.divider : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✎"
                                font.pixelSize: units.dp(18)
                                color: Theme.textSecondary
                            }
                            MouseArea {
                                id: editArea
                                anchors.fill: parent
                                onClicked: root.openEdit(modelData)
                            }
                        }

                        Rectangle {
                            width: units.gu(4.4)
                            height: units.gu(4.4)
                            radius: Theme.radiusSmall
                            anchors.verticalCenter: parent.verticalCenter
                            color: delArea.pressed ? "#FEE2E2" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: units.dp(18)
                                color: Theme.expense
                            }
                            MouseArea {
                                id: delArea
                                anchors.fill: parent
                                onClicked: root.removeBill(modelData)
                            }
                        }
                    }
                }
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
            width: Math.min(parent.width - units.gu(4), units.gu(42))
            height: form.height + units.gu(4)
            radius: Theme.radiusCard
            color: Theme.cardBackground

            MouseArea {
                anchors.fill: parent
                onClicked: { /* keep the dialog open */ }
            }

            Column {
                id: form
                x: units.gu(2)
                y: units.gu(2)
                width: parent.width - units.gu(4)
                spacing: units.gu(1.4)

                Text {
                    text: root.editId.length > 0 ? "Edit ledger" : "New ledger"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                TextField {
                    width: parent.width
                    placeholderText: "Ledger name"
                    text: root.editName
                    onTextChanged: root.editName = text
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
            }
        }
    }

    Connections {
        target: AppState
        // QtQuick 2.4 has no Connections.enabled — guard inside the handler.
        function onDataRefreshed() {
            if (root.visible) root.reload();
        }
    }
}
