import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../js/api.js" as Api

Item {
    id: root

    property string importPath: "/home/phablet/Downloads/budget-bundle.json"
    property string statusMsg: ""

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

            Text {
                text: "Settings"
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textPrimary
            }

            // Pro Unlocked Banner
            Rectangle {
                width: parent.width
                height: units.gu(9.5)
                radius: Theme.radiusCard
                color: "#FEF3C7" // Soft gold
                border.color: Theme.primaryDark

                Row {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.6)
                    spacing: units.gu(1.6)

                    Text {
                        text: "👑"
                        font.pixelSize: units.dp(30)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.3)
                        Text {
                            text: "All Premium Features Free"
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                            color: Theme.primaryText
                        }
                        Text {
                            text: "Open-source Budget App for Ubuntu Touch"
                            font.pixelSize: Theme.fontSub
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            // General Settings Card
            Rectangle {
                width: parent.width
                height: units.gu(14)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(1.2)

                    Text {
                        text: "General"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Row {
                        width: parent.width
                        height: units.gu(4.5)
                        Text {
                            text: "Main Currency"
                            font.pixelSize: Theme.fontBody
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(22)
                        }

                        // Currency selector chips
                        Row {
                            spacing: units.gu(0.6)
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: ["USD", "EUR", "RUB", "CNY"]
                                delegate: Rectangle {
                                    width: units.gu(4.8)
                                    height: units.gu(3.6)
                                    radius: height / 2
                                    color: AppState.wallets.system === modelData ? Theme.primary : "#F3F4F6"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontMicro
                                        font.bold: AppState.wallets.system === modelData
                                        color: Theme.textPrimary
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Api.post("/api/settings", { systemCurrency: modelData }, function() {
                                                AppState.reload();
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Data Management Card (Import / Export)
            Rectangle {
                width: parent.width
                height: units.gu(32)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(1.4)

                    Text {
                        text: "Backup & Restore"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Import bundle path
                    Column {
                        width: parent.width
                        spacing: units.gu(0.5)
                        Text {
                            text: "Import JSON Bundle (converted Realm backup):"
                            font.pixelSize: Theme.fontSub
                            color: Theme.textSecondary
                        }
                        TextField {
                            id: pathIn
                            width: parent.width
                            text: root.importPath
                            onTextChanged: root.importPath = text
                        }
                    }

                    Row {
                        spacing: units.gu(1.2)
                        width: parent.width

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
                        spacing: units.gu(1.2)
                        width: parent.width

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

                    Text {
                        text: root.statusMsg
                        font.pixelSize: Theme.fontSub
                        color: Theme.accent
                        visible: root.statusMsg.length > 0
                    }
                }
            }

            // About Card
            Rectangle {
                width: parent.width
                height: units.gu(12)
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: units.gu(1.8)
                    spacing: units.gu(0.5)

                    Text {
                        text: "About Budget"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "Version 0.1.0 • Built with Go & Lomiri QML"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Daemon: http://127.0.0.1:21990 • SQLite"
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    function doImportBundle() {
        root.statusMsg = "Importing...";
        Api.post("/api/import/bundle", { path: importPath }, function(err, res) {
            if (err) {
                root.statusMsg = "Error: " + err;
            } else {
                root.statusMsg = "Imported " + (res.transactions || 0) + " transactions!";
                AppState.reload();
            }
        });
    }

    function doExportBundle() {
        root.statusMsg = "Exporting to ~/Downloads/budget-bundle-export.json...";
        Api.get("/api/export/bundle", function(err, res) {
            root.statusMsg = err ? "Export error: " + err : "Export complete!";
        });
    }

    function doExportCSV() {
        root.statusMsg = "Exporting to ~/Downloads/budget-export.csv...";
        Api.get("/api/export/csv", function(err, res) {
            root.statusMsg = err ? "CSV export error: " + err : "CSV export complete!";
        });
    }

    function doImportCSV() {
        root.statusMsg = "Importing from ~/Downloads/budget-import.csv...";
        Api.post("/api/import/csv", { path: "/home/phablet/Downloads/budget-import.csv" }, function(err, res) {
            if (err) {
                root.statusMsg = "CSV import error: " + err;
            } else {
                root.statusMsg = "Imported " + (res.imported || 0) + " rows!";
                AppState.reload();
            }
        });
    }
}
