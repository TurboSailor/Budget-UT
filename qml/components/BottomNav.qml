import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

Item {
    id: root
    property int currentTab: AppState.activeTab
    signal tabSelected(int index)
    signal addClicked()

    height: units.gu(7.5)
    implicitWidth: units.gu(45)

    // White background card with top border
    Rectangle {
        anchors.fill: parent
        color: Theme.cardBackground
        border.color: Theme.cardBorder
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.cardBorder
        }
    }

    Row {
        anchors.fill: parent

        // 0: Home
        Rectangle {
            width: parent.width / 5
            height: parent.height
            color: "transparent"
            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.2)
                Text { text: "🏠"; font.pixelSize: units.dp(20); opacity: root.currentTab === 0 ? 1.0 : 0.4; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Home"; font.pixelSize: Theme.fontMicro; font.bold: root.currentTab === 0; color: root.currentTab === 0 ? Theme.textPrimary : Theme.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: root.tabSelected(0) }
        }

        // 1: Calendar
        Rectangle {
            width: parent.width / 5
            height: parent.height
            color: "transparent"
            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.2)
                Text { text: "📅"; font.pixelSize: units.dp(20); opacity: root.currentTab === 1 ? 1.0 : 0.4; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Calendar"; font.pixelSize: Theme.fontMicro; font.bold: root.currentTab === 1; color: root.currentTab === 1 ? Theme.textPrimary : Theme.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: root.tabSelected(1) }
        }

        // Center space for FAB
        Item {
            width: parent.width / 5
            height: parent.height
        }

        // 2: Budget
        Rectangle {
            width: parent.width / 5
            height: parent.height
            color: "transparent"
            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.2)
                Text { text: "🎯"; font.pixelSize: units.dp(20); opacity: root.currentTab === 2 ? 1.0 : 0.4; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Budget"; font.pixelSize: Theme.fontMicro; font.bold: root.currentTab === 2; color: root.currentTab === 2 ? Theme.textPrimary : Theme.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: root.tabSelected(2) }
        }

        // 3: Accounts
        Rectangle {
            width: parent.width / 5
            height: parent.height
            color: "transparent"
            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.2)
                Text { text: "💳"; font.pixelSize: units.dp(20); opacity: root.currentTab === 3 ? 1.0 : 0.4; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Cards"; font.pixelSize: Theme.fontMicro; font.bold: root.currentTab === 3; color: root.currentTab === 3 ? Theme.textPrimary : Theme.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: root.tabSelected(3) }
        }
    }

    // Center floating FAB [+]
    Rectangle {
        id: fab
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        width: units.gu(6.2)
        height: units.gu(6.2)
        radius: width / 2
        color: Theme.primary
        border.color: Theme.primaryDark
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: units.dp(30)
            font.bold: true
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.addClicked()
        }
    }
}
