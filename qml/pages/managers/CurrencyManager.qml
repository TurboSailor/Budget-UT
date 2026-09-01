import QtQuick 2.4
import Ubuntu.Components 1.3
import "../../theme"
import "../../store"
import "../../js/api.js" as Api

// CurrencyManager — the FX surface.
//   GET  /api/rates          list + base + updatedAt + source
//   POST /api/rates/refresh  force a fetch now (502 on network failure)
//   POST /api/settings       {"systemCurrency": code} switches the base
// Rates are "units per USD" (see docs/DATA-MODEL.md).
Item {
    id: root

    property string base: ""        // rate reference, always USD
    property string systemCode: ""  // user-selectable base (settings systemCurrency)
    property string updatedAt: ""
    property string source: ""
    property var items: []

    property bool loading: false
    property bool refreshing: false
    property bool inUseOnly: true
    property string query: ""
    property string statusMsg: ""
    property bool statusIsError: false

    function say(msg, isError) {
        root.statusMsg = msg;
        root.statusIsError = isError === true;
    }

    function applyPayload(data) {
        root.base = (data && data.base) ? data.base : "";
        root.systemCode = (data && data.system) ? data.system : root.systemCode;
        root.updatedAt = (data && data.updatedAt) ? data.updatedAt : "";
        root.source = (data && data.source) ? data.source : "";
        root.items = (data && data.items) ? data.items : [];
    }

    function reload() {
        root.loading = true;
        Api.get("/api/rates", function(err, data) {
            root.loading = false;
            if (err) {
                root.say("Could not load rates: " + err, true);
                return;
            }
            root.applyPayload(data);
            root.say("", false);
        });
    }

    function refreshNow() {
        if (root.refreshing) return;
        root.refreshing = true;
        root.say("Fetching fresh rates…", false);
        Api.post("/api/rates/refresh", {}, function(err, data) {
            root.refreshing = false;
            if (err) {
                root.say("Refresh failed: " + err, true);
                return;
            }
            root.applyPayload(data);
            root.say("Rates updated" + (root.updatedAt.length > 0 ? " • " + root.prettyStamp(root.updatedAt) : ""), false);
        });
    }

    function setBase(code) {
        if (code === root.systemCode) return;
        Api.post("/api/settings", { systemCurrency: code }, function(err) {
            if (err) {
                root.say("Could not switch base currency: " + err, true);
                return;
            }
            root.systemCode = code;
            root.say("Base currency is now " + code, false);
            AppState.reload();
            AppState.txChanged();
            root.reload();
        });
    }

    function prettyStamp(iso) {
        if (!iso || iso.length === 0) return "never";
        var d = new Date(iso);
        if (isNaN(d.getTime())) return iso;
        return Qt.formatDateTime(d, "yyyy-MM-dd hh:mm");
    }

    function filtered() {
        var q = root.query.toUpperCase();
        var out = [];
        for (var i = 0; i < root.items.length; i++) {
            var c = root.items[i];
            if (root.inUseOnly && !c.inUse && c.code !== root.systemCode) continue;
            if (q.length > 0) {
                var hay = (c.code + " " + (c.name || "")).toUpperCase();
                if (hay.indexOf(q) < 0) continue;
            }
            out.push(c);
        }
        return out;
    }

    // The backend always quotes "units per USD"; the figure a user cares about
    // is relative to their own base currency, so divide client-side.
    function systemRate() {
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].code === root.systemCode && root.items[i].rate > 0) {
                return root.items[i].rate;
            }
        }
        return 1.0;
    }

    function relRate(c) {
        if (!c || !(c.rate > 0)) return 0;
        return c.rate / root.systemRate();
    }

    // ---- header ----
    Column {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: units.gu(1.5)
        spacing: units.gu(1.2)

        Rectangle {
            width: parent.width
            height: baseCol.height + units.gu(3.2)
            radius: Theme.radiusCard
            color: Theme.cardBackground
            border.color: Theme.cardBorder
            border.width: units.dp(1)

            Column {
                id: baseCol
                x: units.gu(1.6)
                y: units.gu(1.6)
                width: parent.width - units.gu(3.2)
                spacing: units.gu(0.4)

                Text {
                    text: "Base currency"
                    font.pixelSize: Theme.fontSub
                    color: Theme.textSecondary
                }

                Text {
                    text: root.systemCode.length > 0 ? root.systemCode : "—"
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "Updated " + root.prettyStamp(root.updatedAt)
                    font.pixelSize: Theme.fontSub
                    color: Theme.textSecondary
                }

                Text {
                    text: "Source: " + (root.source.length > 0 ? root.source : "unknown")
                        + " • quoted against " + (root.base.length > 0 ? root.base : "USD")
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontMicro
                    color: Theme.textMuted
                }
            }
        }

        Rectangle {
            width: parent.width
            height: units.gu(5)
            radius: Theme.radiusSmall
            color: root.refreshing
                ? Theme.divider
                : (refreshArea.pressed ? Theme.primaryDark : Theme.primary)

            Text {
                anchors.centerIn: parent
                text: root.refreshing ? "Refreshing…" : "↻  Refresh now"
                font.pixelSize: Theme.fontBody
                font.bold: true
                color: Theme.primaryText
            }
            MouseArea {
                id: refreshArea
                anchors.fill: parent
                enabled: !root.refreshing
                onClicked: root.refreshNow()
            }
        }

        Text {
            text: root.statusMsg
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.statusMsg.length > 0
            font.pixelSize: Theme.fontSub
            color: root.statusIsError ? Theme.expense : Theme.accent
        }

        Row {
            width: parent.width
            height: units.gu(4.5)
            spacing: units.gu(1)

            Rectangle {
                width: units.gu(11)
                height: units.gu(4.5)
                radius: Theme.radiusSmall
                anchors.verticalCenter: parent.verticalCenter
                color: root.inUseOnly ? Theme.accent : Theme.cardBackground
                border.color: Theme.cardBorder
                border.width: units.dp(1)

                Text {
                    anchors.centerIn: parent
                    text: "In use"
                    font.pixelSize: Theme.fontSub
                    font.bold: root.inUseOnly
                    color: root.inUseOnly ? Theme.textInverted : Theme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.inUseOnly = !root.inUseOnly
                }
            }

            TextField {
                width: parent.width - units.gu(12)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "Search code or name"
                text: root.query
                onTextChanged: root.query = text
            }
        }

        Text {
            text: root.loading
                ? "Loading rates…"
                : (root.filtered().length + " of " + root.items.length + " currencies • tap one to make it the base")
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontMicro
            color: Theme.textMuted
        }
    }

    // ---- rate list ----
    ListView {
        id: list
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: units.gu(1)
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        clip: true
        spacing: units.gu(0.8)
        model: root.filtered()

        delegate: Rectangle {
            id: rateRow

            property bool isBase: modelData.code === root.systemCode

            width: list.width
            height: units.gu(6.5)
            radius: Theme.radiusCard
            color: Theme.cardBackground
            border.color: isBase ? Theme.primaryDark : Theme.cardBorder
            border.width: isBase ? units.dp(2) : units.dp(1)

            MouseArea {
                anchors.fill: parent
                onClicked: root.setBase(modelData.code)
            }

            Row {
                anchors.fill: parent
                anchors.margins: units.gu(1.2)
                spacing: units.gu(1.2)

                Rectangle {
                    width: units.gu(4.2)
                    height: units.gu(4.2)
                    radius: Theme.radiusSmall
                    anchors.verticalCenter: parent.verticalCenter
                    color: rateRow.isBase ? Theme.primary : "#F3F4F6"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.symbol && modelData.symbol.length > 0 ? modelData.symbol : modelData.code.charAt(0)
                        font.pixelSize: units.dp(16)
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(4.2) - units.gu(2.4) - rateCol.width
                    spacing: units.gu(0.2)

                    Text {
                        text: modelData.code + (rateRow.isBase ? "  • base" : "")
                            + (modelData.inUse && !rateRow.isBase ? "  • in use" : "")
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        text: modelData.name && modelData.name.length > 0 ? modelData.name : modelData.code
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                    }
                }

                Column {
                    id: rateCol
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.2)

                    Text {
                        anchors.right: parent.right
                        text: root.relRate(modelData) > 0 ? root.relRate(modelData).toFixed(4) : "—"
                        font.pixelSize: Theme.fontBody
                        color: Theme.textPrimary
                    }

                    Text {
                        anchors.right: parent.right
                        text: "per 1 " + (root.systemCode.length > 0 ? root.systemCode : "USD")
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
