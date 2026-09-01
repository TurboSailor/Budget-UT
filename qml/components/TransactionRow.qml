import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

Rectangle {
    id: root
    property var tx: null
    signal clicked()

    width: parent ? parent.width : units.gu(40)
    height: units.gu(8)
    color: mouseArea.pressed ? "#F9FAFB" : Theme.cardBackground
    radius: Theme.radiusSmall

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Row {
        anchors.fill: parent
        anchors.margins: units.gu(1.2)
        spacing: units.gu(1.4)

        CategoryIcon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            categoryId: root.tx ? (root.tx.categoryId || "") : ""
            label: root.tx ? (root.tx.label || "") : ""
            size: units.gu(5.5)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - icon.width - amountLabel.width - units.gu(4)
            spacing: units.gu(0.4)

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    if (!root.tx) return "";
                    if (root.tx.label && root.tx.label.length > 0) return root.tx.label;
                    if (root.tx.kind === 1) return "Transfer";
                    var c = AppState.categoryById(root.tx.categoryId);
                    return c ? c.name : (root.tx.isIncome ? "Income" : "Expense");
                }
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    if (!root.tx) return "";
                    var sub = [];
                    if (root.tx.subcategoryId) {
                        var sc = AppState.subcategoryById(root.tx.subcategoryId);
                        if (sc) sub.push(sc.name);
                    }
                    if (root.tx.accountId) {
                        var a = AppState.accountById(root.tx.accountId);
                        if (a) sub.push(a.name);
                    }
                    if (root.tx.day) sub.push(root.tx.day);
                    if (root.tx.remark) sub.push(root.tx.remark);
                    return sub.join(" • ");
                }
                font.pixelSize: Theme.fontSub
                color: Theme.textSecondary
            }
        }

        MoneyLabel {
            id: amountLabel
            anchors.verticalCenter: parent.verticalCenter
            minor: root.tx ? (root.tx.originalCost || root.tx.amount) : 0
            currency: root.tx ? (root.tx.originalCurrency || root.tx.currency) : "USD"
            isIncome: root.tx ? root.tx.isIncome : false
            showSign: true
            colored: true
            font.pixelSize: Theme.fontHeading
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: units.gu(8)
        height: 1
        color: Theme.divider
    }
}
