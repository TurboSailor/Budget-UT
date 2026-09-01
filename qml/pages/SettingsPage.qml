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
        contentHeight: col.height + 40
        clip: true

        Column {
            id: col
            width: Math.min(parent.width - 24, 520)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            topPadding: 12

            Text {
                text: "Settings"
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textPrimary
            }

            // Pro Unlocked Banner
            Rectangle {
                width: parent.width
                height: 70
                radius: Theme.radiusCard
                color: "#FEF3C7" // Soft gold
                border.color: Theme.primaryDark

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "👑"
                        font.pixelSize: 28
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
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
                height: 120
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "General"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Row {
                        width: parent.width
                        height: 36
                        Text {
                            text: "Main Currency"
                            font.pixelSize: Theme.fontBody
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 160
                        }

                        // Currency selector chips
                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: ["USD", "EUR", "RUB", "CNY"]
                                delegate: Rectangle {
                                    width: 34
                                    height: 26
                                    radius: 13
                                    color: AppState.wallets.system === modelData ? Theme.primary : "#F3F4F6"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 10
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
                height: 260
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "Backup & Restore"
                        font.pixelSize: Theme.fontHeading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Import bundle path
                    Column {
                        width: parent.width
                        spacing: 4
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
                        spacing: 10
                        width: parent.width

                        Button {
                            width: (parent.width - 10) / 2
                            text: "Import Bundle"
                            color: Theme.primary
                            onClicked: root.doImportBundle()
                        }

                        Button {
                            width: (parent.width - 10) / 2
                            text: "Export Bundle"
                            onClicked: root.doExportBundle()
                        }
                    }

                    Row {
                        spacing: 10
                        width: parent.width

                        Button {
                            width: (parent.width - 10) / 2
                            text: "Export CSV"
                            onClicked: root.doExportCSV()
                        }

                        Button {
                            width: (parent.width - 10) / 2
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
                height: 100
                radius: Theme.radiusCard
                color: Theme.cardBackground
                border.color: Theme.cardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

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
                        font.pixelSize: Theme.fontSub
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
